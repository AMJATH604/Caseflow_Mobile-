import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_constants.dart';

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

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent';

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

  /// Send a message to Gemini and get a response
  Future<String> sendMessage(String userMessage) async {
    final apiKey = AppConstants.geminiApiKey;

    if (apiKey.isEmpty) {
      return '⚠️ Gemini API key not configured. Please add GEMINI_API_KEY to your environment variables.';
    }

    // Add user message to history
    _history.add(ChatMessage(role: 'user', text: userMessage));

    // Add loading placeholder
    _history.add(ChatMessage(role: 'model', text: '', isLoading: true));

    try {
      // Build conversation history for context
      final contents = <Map<String, dynamic>>[];

      // Add system instruction as first user turn for context
      contents.add({
        'role': 'user',
        'parts': [
          {'text': _systemPrompt}
        ]
      });
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I am CaseFlow AI, your expert Indian legal assistant. I will provide accurate legal information with proper citations. How can I help you today?'
          }
        ]
      });

      // Add conversation history (last 20 messages for context window)
      final recentHistory = _history.length > 22
          ? _history.sublist(_history.length - 22, _history.length - 1)
          : _history.sublist(0, _history.length - 1);

      for (final msg in recentHistory) {
        if (msg.isLoading) continue;
        contents.add({
          'role': msg.role,
          'parts': [
            {'text': msg.text}
          ]
        });
      }

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 2048,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_ONLY_HIGH'
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          print('Gemini API Error (No Candidates): ${response.body}');
          final text = 'I apologize, I could not generate a response. (No candidates found)';
          _history.removeLast();
          _history.add(ChatMessage(role: 'model', text: text, isLoading: false));
          return text;
        }
        
        final text = data['candidates'][0]['content']?['parts']?[0]
                ?['text'] ??
            'I apologize, I could not generate a response. Please try again.';

        // Replace loading message with actual response
        _history.removeLast();
        _history.add(ChatMessage(role: 'model', text: text, isLoading: false));

        return text;
      } else {
        print('Gemini API HTTP Error Status: ${response.statusCode}');
        print('Gemini API Error Body: ${response.body}');
        
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? 'Unknown error occurred';
        final statusCode = errorBody['error']?['status'] ?? 'ERROR';
        
        _history.removeLast();
        final displayError = '⚠️ API Error ($statusCode): $errorMsg';
        _history.add(ChatMessage(role: 'model', text: displayError, isLoading: false));
        return displayError;
      }
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
