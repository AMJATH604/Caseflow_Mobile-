import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  bool isLoading;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI-powered legal assistant using Gemini via Edge Function proxy.
///
/// **Security:** All requests are routed through `gemini-proxy` Edge Function.
/// The API key is stored as a Supabase secret and never reaches the client.
/// The proxy also validates the user's JWT, ensuring only authenticated
/// CaseFlow users can access the AI.
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
9. Respond in English by default, but support Hindi legal terminology when asked''';

  final List<ChatMessage> _history = [];

  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Send a message to Gemini via the secure Edge Function proxy.
  ///
  /// The proxy (`supabase/functions/gemini-proxy`) holds the GEMINI_API_KEY
  /// as a server-side secret and validates the user's auth token.
  Future<String> sendMessage(String userMessage) async {
    // Add user message to history
    _history.add(ChatMessage(role: 'user', text: userMessage));

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
        historyPayload.add({
          'role': msg.role,
          'parts': [
            {'text': msg.text}
          ]
        });
      }

      // Call the Edge Function proxy (API key stays server-side)
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: {
          'prompt': userMessage,
          'history': historyPayload,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unknown error';
        _history.removeLast();
        final displayError = '⚠️ AI Error: $errorMsg';
        _history
            .add(ChatMessage(role: 'model', text: displayError, isLoading: false));
        return displayError;
      }

      final text = response.data?['text'] ??
          'I apologize, I could not generate a response. Please try again.';

      // Replace loading message with actual response
      _history.removeLast();
      _history.add(ChatMessage(role: 'model', text: text, isLoading: false));

      return text;
    } catch (e) {
      _history.removeLast();
      _history.add(ChatMessage(
          role: 'model',
          text:
              '⚠️ Connection error. Please check your internet and try again.'));
      return '⚠️ Connection error: $e';
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
