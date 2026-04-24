import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  bool isLoading;
  final String? imagePath; // Local file path for user-sent images
  final String? imageBase64; // Base64 encoded image data

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isLoading = false,
    this.imagePath,
    this.imageBase64,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasImage => imagePath != null || imageBase64 != null;
}

/// AI-powered legal assistant using Gemini via Edge Function proxy.
///
/// **Security:** All requests are routed through `gemini-proxy` Edge Function.
/// The API key is stored as a Supabase secret and never reaches the client.
/// The proxy also validates the user's JWT, ensuring only authenticated
/// CaseFlow users can access the AI.
///
/// **Multimodal:** Supports image analysis via Gemini Vision.
class GeminiService {
  static const String _systemPrompt = '''You are **CaseFlow AI** — an expert Indian legal assistant built into the CaseFlow legal practice management app.

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
10. When analyzing images of legal documents, extract all relevant text and provide legal interpretation''';

  final List<ChatMessage> _history = [];

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Send a message to Gemini via the secure Edge Function proxy.
  /// Optionally include an image file for multimodal analysis.
  Future<String> sendMessage(String userMessage, {File? imageFile}) async {
    // Encode image to base64 if provided
    String? imageBase64;
    String? imagePath;
    if (imageFile != null) {
      try {
        final bytes = await imageFile.readAsBytes();
        imageBase64 = base64Encode(bytes);
        imagePath = imageFile.path;
      } catch (e) {
        debugPrint('Image encoding error: $e');
      }
    }

    // Add user message to history
    _history.add(ChatMessage(
      role: 'user',
      text: userMessage,
      imagePath: imagePath,
      imageBase64: imageBase64,
    ));

    // Add loading placeholder
    _history.add(ChatMessage(role: 'model', text: '', isLoading: true));

    try {
      // Build conversation history for context (last 20 messages)
      final recentHistory = _history.length > 22
          ? _history.sublist(_history.length - 22, _history.length - 1)
          : _history.sublist(0, _history.length - 1);

      final historyPayload = <Map<String, dynamic>>[];

      // Add system prompt context as first exchange
      historyPayload.add({
        'role': 'user',
        'parts': [{'text': _systemPrompt}]
      });
      historyPayload.add({
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am CaseFlow AI, your expert Indian legal assistant. I will provide accurate legal information with proper citations. How can I help you today?'
          }
        ]
      });

      for (final msg in recentHistory) {
        if (msg.isLoading) continue;

        final parts = <Map<String, dynamic>>[];
        parts.add({'text': msg.text});

        // Don't include images in history (too large), only in current message
        historyPayload.add({
          'role': msg.role,
          'parts': parts,
        });
      }

      // Build request body
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
        _history.add(ChatMessage(role: 'model', text: displayError, isLoading: false));
        return displayError;
      }

      final text = response.data?['text'] ??
          'I apologize, I could not generate a response. Please try again.';

      // Replace loading message with actual response
      _history.removeLast();
      _history.add(ChatMessage(role: 'model', text: text, isLoading: false));

      return text;
    } on FunctionException catch (e) {
      _history.removeLast();
      String errorMessage = '⚠️ AI Error: Something went wrong.';
      if (e.status == 429) {
        errorMessage = '⚠️ AI Quota Exceeded: It looks like your Gemini API key has run out of its free quota. Please check your Google AI Studio billing.';
      } else if (e.status == 401) {
        errorMessage = '⚠️ AI Error: Unauthorized. Please check your GEMINI_API_KEY in Supabase dashboard.';
      } else {
        final Map<String, dynamic>? details = e.details as Map<String, dynamic>?;
        errorMessage = '⚠️ AI Error (${e.status}): ${details?['error'] ?? e.reasonPhrase ?? 'Unknown API error.'}';
      }
      _history.add(ChatMessage(role: 'model', text: errorMessage, isLoading: false));
      return errorMessage;
    } catch (e) {
      _history.removeLast();
      _history.add(ChatMessage(
          role: 'model',
          text: '⚠️ Connection error. Please check your internet and try again.'));
      return '⚠️ Connection error: $e';
    }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }

  /// Clear chat history
  void clearHistory() {
    _history.clear();
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
