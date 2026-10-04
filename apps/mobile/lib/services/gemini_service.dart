import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_constants.dart';
import 'repositories/base_repository.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  bool isLoading;
  final String? imagePath; // Local file path for user-sent images
  final String? imageBase64; // Base64 encoded image data
  final String? dbId; // Database ID for persistence
  final List<Map<String, dynamic>> ragSources; // RAG citation sources

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isLoading = false,
    this.imagePath,
    this.imageBase64,
    this.dbId,
    this.ragSources = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasImage => imagePath != null || imageBase64 != null;
  bool get hasSources => ragSources.isNotEmpty;
}

/// Represents a chat session (conversation thread).
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// AI-powered legal assistant using Gemini via Edge Function proxy.
///
/// **Security:** All requests are routed through `gemini-proxy` Edge Function.
/// The API key is stored as a Supabase secret and never reaches the client.
/// The proxy also validates the user's JWT, ensuring only authenticated
/// CaseFlow users can access the AI.
///
/// **Multimodal:** Supports image analysis via Gemini Vision.
/// **Persistence:** Chat history is saved to Supabase for cross-session continuity.
/// **Sessions:** Supports multiple chat sessions (conversations) like ChatGPT.
class GeminiService {
  static const String _advocateSystemPrompt =
      '''You are **CaseFlow AI** — an expert Indian legal assistant built into the CaseFlow legal practice management app.

Your expertise covers:
• Indian Penal Code (IPC) / Bharatiya Nyaya Sanhita (BNS) 2023
• Code of Criminal Procedure (CrPC) / Bharatiya Nagarik Suraksha Sanhita (BNSS) 2023
• Indian Evidence Act / Bharatiya Sakshya Adhiniyam (BSA) 2023
• Code of Civil Procedure (CPC) 1908
• Constitution of India (all 395+ Articles, Schedules, Amendments)
• Hindu Law: Hindu Marriage Act, Hindu Succession Act, Hindu Minority & Guardianship Act, Hindu Adoptions & Maintenance Act
• Muslim Personal Law / Mohammedan Law
• Special Marriage Act, 1954
• Guardians and Wards Act, 1890
• Motor Accident Claims (MACT)
• Limitation Act, 1963
• Negotiable Instruments Act (Section 138 etc.)
• Court procedures, filing, e-filing, certified copies
• Legal drafting, petition writing, application formats

Guidelines:
1. Always cite the specific Section, Act, and Year when referring to law
2. If a new law (BNS/BNSS/BSA) has replaced an old provision, mention BOTH old and new
3. Keep answers concise but thorough — lawyers are busy professionals
4. Use bullet points and structured formatting for readability
5. If asked about something outside Indian law, politely redirect
6. Always add a disclaimer: responses are for reference only, not formal legal advice
7. When relevant, mention landmark Supreme Court / High Court judgments
8. Format currency in ₹ (Indian Rupees)
9. Respond in English by default, but support Hindi legal terminology when asked
10. When analyzing images of legal documents, extract all relevant text and provide legal interpretation
11. **Generative UI Tags:** When discussing specific entities, inject these exact tags into your response so the app can render interactive widgets:
    - Cases: `<genui-case title="..." cnr="..." court="..." nextHearing="..." status="..." />`
    - Payments: `<genui-payment total="..." paid="..." balance="..." status="..." caseTitle="..." />`
    - Calculators: `<genui-calculators />` (Inject this when asked to show or recommend calculators)
    - Act Sections: `<genui-section act="..." section="..." title="..." content="..." />` (content should be the bare act text)''';

  static const String _citizenSystemPrompt =
      '''You are **CaseFlow AI** — a helpful Indian legal assistant for citizens. 

Your goals:
1. Explain basic legal rights, definitions, and procedures in simple, layman terms.
2. Direct citizens to the CaseFlow tools (e.g. Bare Acts, Calculators, Legal Dictionary).
3. If they enter a CNR number, show them how to track it using the CaseFlow case tracking tool.

CRITICAL DIRECTIVES:
- Do NOT provide specific, actionable legal advice for a user's personal case.
- You must always advise the user to consult a professional human advocate for any serious legal representation or specific legal advice.
- When asked for specific advice, explain that you are an AI assistant and steer them to the **CaseFlow Advocate Directory** (route: `/advocate-directory`) to connect with qualified legal professionals.
- Do NOT encourage self-representation in complex court cases.
- Always include a clear disclaimer at the end of your response: "Disclaimer: This information is for educational purposes only. I am an AI, not a lawyer. Please consult a qualified advocate for legal representation."

Guidelines:
1. Keep explanations very easy to understand (avoid heavy legal jargon, or explain it if used).
2. Cite general Acts/Sections if helpful, but emphasize that application of law depends on facts.
3. Use bullet points and structured formatting.
4. Format currency in ₹ (Indian Rupees).
5. Respond in English by default, but support Hindi legal terms if asked.
6. **Generative UI Tags:** When discussing specific entities, inject these exact tags into your response so the app can render interactive widgets:
   - Cases: `<genui-case title="..." cnr="..." court="..." nextHearing="..." status="..." />`
   - Payments: `<genui-payment total="..." paid="..." balance="..." status="..." caseTitle="..." />`
   - Calculators: `<genui-calculators />` (Inject this when asked to show or recommend calculators)
   - Act Sections: `<genui-section act="..." section="..." title="..." content="..." />` (content should be the bare act text)''';

  final List<ChatMessage> _history = [];
  bool _historyLoaded = false;

  /// Maximum allowed prompt length (characters) — mirrored from server-side.
  static const int _maxPromptLength = 10000;

  /// Approximate max tokens for conversation context before truncation.
  static const int _maxContextTokens = 90000;

  // ─── Session Management ─────────────────────────────────
  String? _currentSessionId;
  List<ChatSession> _sessions = [];
  bool _sessionsLoaded = false;

  String? get currentSessionId => _currentSessionId;
  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  bool get sessionsLoaded => _sessionsLoaded;

  /// Get the title of the current session (or null).
  String? get currentSessionTitle {
    if (_currentSessionId == null) return null;
    try {
      return _sessions
          .firstWhere((s) => s.id == _currentSessionId)
          .title;
    } catch (_) {
      return null;
    }
  }

  List<ChatMessage> get history => List.unmodifiable(_history);
  bool get historyLoaded => _historyLoaded;

  // ─── Input Validation ──────────────────────────────────

  /// Validates and sanitizes user input before sending to the AI proxy.
  /// Returns null if valid, or an error message string if invalid.
  static String? validatePrompt(String message) {
    if (message.trim().isEmpty) {
      return 'Please enter a message.';
    }
    if (message.length > _maxPromptLength) {
      return 'Message is too long (max $_maxPromptLength characters). Please shorten your message.';
    }
    return null; // Valid
  }

  /// Rough token estimate: ~4 chars per token for English text.
  /// Used to prevent sending conversations that exceed the model's context window.
  static int _estimateTokens(List<Map<String, dynamic>> history) {
    int totalChars = 0;
    for (final msg in history) {
      final parts = msg['parts'] as List<dynamic>?;
      if (parts != null) {
        for (final part in parts) {
          if (part is Map && part['text'] != null) {
            totalChars += (part['text'] as String).length;
          }
        }
      }
    }
    return totalChars ~/ 4;
  }

  /// Drops the oldest turns (never the persona pair at the start) until the
  /// payload fits [_maxContextTokens]. History is already capped at 20
  /// messages; this guards against twenty very long ones.
  static void _trimToBudget(List<Map<String, dynamic>> history) {
    while (history.length > 2 && _estimateTokens(history) > _maxContextTokens) {
      history.removeAt(2);
    }
  }

  // ─── SESSION MANAGEMENT ─────────────────────────────────

  /// Fetch all chat sessions for the current user.
  Future<List<ChatSession>> fetchSessions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await Supabase.instance.client
          .from('ai_chat_sessions')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      _sessions =
          (data as List).map((json) => ChatSession.fromJson(json)).toList();
      _sessionsLoaded = true;
      return _sessions;
    } catch (e) {
      debugPrint('Failed to fetch chat sessions: $e');
      return [];
    }
  }

  /// Create a new chat session and switch to it.
  Future<String?> createNewSession() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await Supabase.instance.client
          .from('ai_chat_sessions')
          .insert({
            'user_id': userId,
            'title': 'New Chat',
          })
          .select()
          .single();

      final newSession = ChatSession.fromJson(response);
      _sessions.insert(0, newSession);
      _currentSessionId = newSession.id;
      _history.clear();
      _historyLoaded = true;

      return newSession.id;
    } catch (e) {
      debugPrint('Failed to create new session: $e');
      return null;
    }
  }

  /// Load messages for a specific session.
  Future<void> loadSession(String sessionId) async {
    try {
      _currentSessionId = sessionId;
      _history.clear();

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final data = await Supabase.instance.client
          .from('ai_chat_history')
          .select()
          .eq('user_id', userId)
          .eq('session_id', sessionId)
          .order('created_at', ascending: true)
          .limit(100);

      for (final row in data) {
        _history.add(
          ChatMessage(
            role: row['role'] as String,
            text: row['message'] as String,
            timestamp: DateTime.parse(row['created_at'] as String),
            dbId: row['id'] as String,
          ),
        );
      }
      _historyLoaded = true;
    } catch (e) {
      debugPrint('Failed to load session $sessionId: $e');
    }
  }

  /// Delete a session and all its messages.
  Future<void> deleteSession(String sessionId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('ai_chat_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('user_id', userId);

      _sessions.removeWhere((s) => s.id == sessionId);

      // If we deleted the current session, switch to the most recent one
      if (_currentSessionId == sessionId) {
        _history.clear();
        _currentSessionId = null;
        _historyLoaded = false;
        if (_sessions.isNotEmpty) {
          await loadSession(_sessions.first.id);
        }
      }
    } catch (e) {
      debugPrint('Failed to delete session $sessionId: $e');
    }
  }

  /// Auto-generate a session title from the first user message.
  Future<void> _autoGenerateTitle(String firstMessage) async {
    if (_currentSessionId == null) return;
    try {
      // Truncate to 50 chars max, clean up
      String title = firstMessage.trim();
      if (title.length > 50) {
        title = '${title.substring(0, 47)}...';
      }
      // Remove newlines
      title = title.replaceAll(RegExp(r'\s+'), ' ');

      await Supabase.instance.client
          .from('ai_chat_sessions')
          .update({'title': title})
          .eq('id', _currentSessionId!);

      // Update local cache
      final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
      if (idx >= 0) {
        _sessions[idx] = ChatSession(
          id: _sessions[idx].id,
          title: title,
          createdAt: _sessions[idx].createdAt,
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Failed to update session title: $e');
    }
  }

  // ─── PERSISTENCE: Load chat history from Supabase ──────

  /// Load previous chat messages from the database.
  /// Called once when the AI chat screen initializes.
  /// Loads the most recent session automatically.
  Future<void> loadHistory() async {
    if (_historyLoaded) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Load sessions first
      await fetchSessions();

      if (_sessions.isEmpty) {
        _historyLoaded = true;
        return;
      }

      // Load the most recent session
      final latestSession = _sessions.first;
      await loadSession(latestSession.id);
    } catch (e) {
      debugPrint('Failed to load AI chat history: $e');
      // Non-fatal: chat works without history
    }
  }

  /// Ensure there's an active session. Creates one if needed.
  Future<void> _ensureSession() async {
    if (_currentSessionId != null) return;
    await createNewSession();
  }

  /// Save a single message to the database (fire-and-forget).
  Future<void> _persistMessage(
    ChatMessage msg, {
    bool hasAttachment = false,
    String? attachmentType,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client.from('ai_chat_history').insert({
        'user_id': userId,
        'role': msg.role,
        'message': msg.text,
        'has_attachment': hasAttachment,
        'attachment_type': attachmentType,
        'session_id': _currentSessionId,
      });
    } catch (e) {
      debugPrint('Failed to persist AI message: $e');
      // Non-fatal: don't break the chat experience
    }
  }

  /// Send a message to Gemini via the secure Edge Function proxy.
  /// Optionally include an image file for multimodal analysis.
  ///
  /// [isRetry] is set by [sendMessageStream] when it falls back here: the
  /// question is already saved and titled, and saving it again showed it
  /// twice when the conversation was reopened.
  Future<String> sendMessage(
    String userMessage, {
    File? imageFile,
    bool isRetry = false,
  }) async {
    // Client-side validation before sending to proxy
    final validationError = validatePrompt(userMessage);
    if (validationError != null) {
      return '⚠️ $validationError';
    }

    // Ensure we have an active session
    await _ensureSession();

    // Check if this is the first message in the session (for auto-titling)
    final isFirstMessage = _history.isEmpty;

    // Encode image to base64 if provided
    String? imageBase64;
    String? imagePath;
    String? attachmentType;
    if (imageFile != null) {
      try {
        final bytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(bytes);
        imagePath = imageFile.path;
        attachmentType = imageFile.path.split('.').last.toLowerCase();
      } catch (e) {
        debugPrint('Image encoding error: $e');
      }
    }

    // Add user message to history
    final userMsg = ChatMessage(
      role: 'user',
      text: userMessage,
      imagePath: imagePath,
      imageBase64: imageBase64,
    );
    _history.add(userMsg);

    if (!isRetry) {
      // Persist user message
      _persistMessage(
        userMsg,
        hasAttachment: imageFile != null,
        attachmentType: attachmentType,
      );

      // Auto-generate title from first message
      if (isFirstMessage) {
        _autoGenerateTitle(userMessage);
      }
    }

    // Add loading placeholder
    _history.add(ChatMessage(role: 'model', text: '', isLoading: true));

    try {
      String activePrompt = _advocateSystemPrompt;
      try {
        final profile = await BaseRepository.getCachedProfile();
        if (profile.isCitizen) {
          activePrompt = _citizenSystemPrompt;
        }
      } catch (_) {
        activePrompt = _citizenSystemPrompt;
      }

      // Build conversation history for context (last 20 messages)
      // The earlier conversation only: the last two entries are this
      // question and its placeholder. gemini-proxy appends `prompt` as the
      // final user turn, so including the question here sent it twice.
      final recentHistory =
          _history.length > 22
              ? _history.sublist(_history.length - 22, _history.length - 2)
              : _history.sublist(0, _history.length - 2);

      final historyPayload = <Map<String, dynamic>>[];

      // Add system prompt context as first exchange
      historyPayload.add({
        'role': 'user',
        'parts': [
          {'text': activePrompt},
        ],
      });
      historyPayload.add({
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am CaseFlow AI, your expert Indian legal assistant. How can I help you today?',
          },
        ],
      });

      for (final msg in recentHistory) {
        if (msg.isLoading) continue;

        final parts = <Map<String, dynamic>>[];
        parts.add({'text': msg.text});

        // Don't include images in history (too large), only in current message
        historyPayload.add({'role': msg.role, 'parts': parts});
      }

      // Build request body
      _trimToBudget(historyPayload);

      final body = <String, dynamic>{
        'prompt': userMessage,
        'history': historyPayload,
      };

      // Add image if present (for current message only)
      if (imageBase64 != null) {
        body['image'] = imageBase64;
        body['mimeType'] = _getMimeType(imageFile!.path);
      }

      // Call the Edge Function proxy
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: body,
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unknown error';
        _history.removeLast();
        final displayError = '⚠️ AI Error: $errorMsg';
        _history.add(
          ChatMessage(role: 'model', text: displayError, isLoading: false),
        );
        return displayError;
      }

      final text =
          response.data?['text'] ??
          'I apologize, I could not generate a response. Please try again.';

      // Parse RAG sources from response
      final rawSources = response.data?['sources'] as List<dynamic>? ?? [];
      final sources = rawSources
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      // Replace loading message with actual response
      _history.removeLast();
      final modelMsg = ChatMessage(
        role: 'model',
        text: text,
        isLoading: false,
        ragSources: sources,
      );
      _history.add(modelMsg);

      // Persist model response
      _persistMessage(modelMsg);

      return text;
    } on FunctionException catch (e) {
      _history.removeLast();
      String errorMessage = '⚠️ AI Error: Something went wrong.';
      if (e.status == 429) {
        errorMessage =
            '⚠️ Rate Limit: You have reached the maximum number of AI requests per hour. Please wait a while and try again.';
      } else if (e.status == 401) {
        errorMessage = '⚠️ Session expired. Please sign out and sign back in.';
      } else if (e.status == 413) {
        errorMessage =
            '⚠️ Message too large. Please send a shorter message or a smaller image.';
      } else {
        final Map<String, dynamic>? details =
            e.details as Map<String, dynamic>?;
        errorMessage =
            '⚠️ AI Error (${e.status}): ${details?['error'] ?? e.reasonPhrase ?? 'Unknown API error.'}';
      }
      _history.add(
        ChatMessage(role: 'model', text: errorMessage, isLoading: false),
      );
      return errorMessage;
    } catch (e) {
      _history.removeLast();
      _history.add(
        ChatMessage(
          role: 'model',
          text:
              '⚠️ Connection error. Please check your internet and try again.',
        ),
      );
      return '⚠️ Connection error: $e';
    }
  }

  /// Send a message with STREAMING response (ChatGPT-like word-by-word).
  /// [onChunk] is called for each text chunk received from the stream.
  Future<String> sendMessageStream(
    String userMessage, {
    File? imageFile,

    required void Function(String fullText) onChunk,
  }) async {
    // Ensure we have an active session
    await _ensureSession();

    // Check if this is the first message in the session (for auto-titling)
    final isFirstMessage = _history.isEmpty;

    // Encode image to base64 if provided
    String? imageBase64;
    String? imagePath;
    String? attachmentType;
    if (imageFile != null) {
      try {
        final bytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(bytes);
        imagePath = imageFile.path;
        attachmentType = imageFile.path.split('.').last.toLowerCase();
      } catch (e) {
        debugPrint('Image encoding error: $e');
      }
    }

    // Add user message to history
    final userMsg = ChatMessage(
      role: 'user',
      text: userMessage,
      imagePath: imagePath,
      imageBase64: imageBase64,
    );
    _history.add(userMsg);
    _persistMessage(
      userMsg,
      hasAttachment: imageFile != null,
      attachmentType: attachmentType,
    );

    // Auto-generate title from first message
    if (isFirstMessage) {
      _autoGenerateTitle(userMessage);
    }

    // Add streaming placeholder
    _history.add(ChatMessage(role: 'model', text: '', isLoading: true));

    try {
      String activePrompt = _advocateSystemPrompt;
      try {
        final profile = await BaseRepository.getCachedProfile();
        if (profile.isCitizen) {
          activePrompt = _citizenSystemPrompt;
        }
      } catch (_) {
        activePrompt = _citizenSystemPrompt;
      }

      // Build conversation history for context
      // The earlier conversation only: the last two entries are this
      // question and its placeholder. gemini-proxy appends `prompt` as the
      // final user turn, so including the question here sent it twice.
      final recentHistory =
          _history.length > 22
              ? _history.sublist(_history.length - 22, _history.length - 2)
              : _history.sublist(0, _history.length - 2);

      final historyPayload = <Map<String, dynamic>>[];
      historyPayload.add({
        'role': 'user',
        'parts': [
          {'text': activePrompt},
        ],
      });
      historyPayload.add({
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am CaseFlow AI, your expert Indian legal assistant. How can I help you today?',
          },
        ],
      });

      for (final msg in recentHistory) {
        if (msg.isLoading) continue;
        historyPayload.add({
          'role': msg.role,
          'parts': [
            {'text': msg.text},
          ],
        });
      }

      _trimToBudget(historyPayload);

      final body = <String, dynamic>{
        'prompt': userMessage,
        'history': historyPayload,
        'stream': true,
      };

      if (imageBase64 != null) {
        body['image'] = imageBase64;
        body['mimeType'] = _getMimeType(imageFile!.path);
      }

      // Direct HTTP call to edge function for streaming
      final session = Supabase.instance.client.auth.currentSession;
      const url = '${AppConstants.supabaseUrl}/functions/v1/gemini-proxy';

      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session?.accessToken ?? ''}',
        'apikey': AppConstants.supabaseAnonKey,
      });
      request.body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        // Fall back to non-streaming
        _history.removeLast();
        _history.removeLast(); // remove user msg too
        return sendMessage(userMessage, imageFile: imageFile, isRetry: true);
      }

      final fullBuffer = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        // Parse SSE: lines starting with "data: "
        for (final line in chunk.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final jsonStr = line.substring(6).trim();
          if (jsonStr.isEmpty) continue;

          try {
            final data = jsonDecode(jsonStr);
            final text =
                data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null && text is String) {
              fullBuffer.write(text);
              // Update the loading message in-place
              _history.last = ChatMessage(
                role: 'model',
                text: fullBuffer.toString(),
                isLoading: true,
              );
              onChunk(fullBuffer.toString());
            }
          } catch (_) {
            // Skip malformed SSE lines
          }
        }
      }

      final finalText =
          fullBuffer.toString().isEmpty
              ? 'I apologize, I could not generate a response. Please try again.'
              : fullBuffer.toString();

      // Finalize the message
      _history.removeLast();
      final modelMsg = ChatMessage(
        role: 'model',
        text: finalText,
        isLoading: false,
      );
      _history.add(modelMsg);
      _persistMessage(modelMsg);

      return finalText;
    } catch (e) {
      debugPrint('Streaming error, falling back: $e');
      // Fall back to non-streaming on error
      _history.removeLast(); // remove loading
      _history.removeLast(); // remove user msg
      return sendMessage(userMessage, imageFile: imageFile, isRetry: true);
    }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'image/jpeg';
    }
  }

  /// Clear chat history for the current session only.
  Future<void> clearHistory() async {
    _history.clear();

    if (_currentSessionId != null) {
      await deleteSession(_currentSessionId!);
    }
    _historyLoaded = false;
  }

  /// Start a fresh new chat (clears current view and creates new session).
  Future<void> startNewChat() async {
    _history.clear();
    _currentSessionId = null;
    _historyLoaded = true;
    // Session will be auto-created on first message via _ensureSession()
  }

  /// Get suggested prompts for new users
  static List<Map<String, String>> get suggestedPrompts => [
    {
      'icon': '⚖️',
      'title': 'Section 138 NI Act',
      'prompt':
          'Explain Section 138 of Negotiable Instruments Act — cheque bounce procedure, limitation period, and punishment',
    },
    {
      'icon': '📝',
      'title': 'Bail Application',
      'prompt':
          'What are the grounds for bail under BNSS? What factors does the court consider?',
    },
    {
      'icon': '🏛️',
      'title': 'Limitation Period',
      'prompt':
          'What is the limitation period for filing a civil suit for recovery of money under Limitation Act 1963?',
    },
    {
      'icon': '👨‍👩‍👧',
      'title': 'Maintenance Rights',
      'prompt':
          'Explain maintenance rights under Section 144 BNSS (earlier Sec 125 CrPC) — who can claim and procedure',
    },
    {
      'icon': '🏠',
      'title': 'Property Dispute',
      'prompt':
          'What is the procedure for partition suit under CPC? What documents are needed?',
    },
    {
      'icon': '📋',
      'title': 'FIR Procedure',
      'prompt':
          'Explain the procedure for filing FIR under BNSS. What are the rights of the complainant?',
    },
  ];
}
