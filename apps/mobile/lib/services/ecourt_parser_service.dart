import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Parses raw text from eCourts/eFiling portal into structured case data
/// using the Gemini AI via Edge Function proxy.
///
/// **Security:** All AI calls are routed through the `gemini-proxy` Edge Function.
/// No API keys are present in the client binary.
class EcourtParserService {
  static const String _parserPrompt = '''You are a legal data parser for Indian court records.
Parse the following text copied/extracted from the eCourts India or eFiling portal and extract structured data.

IMPORTANT RULES:
1. Extract ALL dates in YYYY-MM-DD format
2. Extract ALL hearing history rows — every single one
3. If a field is not found, use null
4. Return ONLY valid JSON — no markdown, no explanation
5. Parse party names, advocate names, judge names carefully
6. "Business on Date" means what happened on that hearing date

Return this exact JSON structure:
{
  "cnr_number": "string or null",
  "case_type": "string or null",
  "case_number": "string or null",
  "filing_number": "string or null",
  "filing_date": "YYYY-MM-DD or null",
  "registration_date": "YYYY-MM-DD or null",
  "registration_number": "string or null",
  "case_status": "pending|disposed|transferred|not_available",
  "next_hearing_date": "YYYY-MM-DD or null",
  "decision_date": "YYYY-MM-DD or null",
  "nature_of_disposal": "string or null",
  "court_name": "string or null",
  "court_number": "string or null",
  "judge_name": "string or null",
  "state": "string or null",
  "district": "string or null",
  "petitioner_name": "string or null",
  "respondent_name": "string or null",
  "petitioner_advocate": "string or null",
  "respondent_advocate": "string or null",
  "hearing_history": [
    {
      "judge": "string or null",
      "hearing_date": "YYYY-MM-DD",
      "purpose": "string describing purpose of hearing",
      "business_done": "string describing what happened",
      "next_date": "YYYY-MM-DD or null"
    }
  ],
  "orders": [
    {
      "order_number": "number or null",
      "order_date": "YYYY-MM-DD",
      "order_details": "string"
    }
  ],
  "ia_details": [
    {
      "ia_number": "string",
      "ia_filing_date": "YYYY-MM-DD or null",
      "ia_status": "string",
      "ia_party": "string or null",
      "ia_classification": "string or null"
    }
  ],
  "acts_sections": [
    {
      "act_name": "string",
      "section": "string or null"
    }
  ],
  "fir_details": {
    "police_station": "string or null",
    "fir_number": "string or null",
    "year": "string or null"
  }
}''';

  static const String _dashboardPrompt = '''You are a legal data parser for Indian eFiling portal dashboards.
Parse the following text which contains a list of cases from an advocate's dashboard (typically a table with columns like Case No, CNR, Parties, etc.)
Extract a structured list of all cases found.

IMPORTANT:
1. Return ONLY valid JSON.
2. If CNR is not found, use Case Number as the identifier.
3. Clean up party names (e.g. "PETITIONER NAME VS RESPONDENT NAME").

Return this exact JSON structure:
{
  "cases": [
    {
      "cnr_number": "string or null",
      "case_number": "string or null",
      "case_title": "string or null",
      "court_name": "string or null",
      "status": "pending|disposed|not_available"
    }
  ]
}''';

  /// Parse raw eCourt page text into structured JSON using Gemini AI proxy.
  static Future<Map<String, dynamic>?> parseEcourtText(String rawText) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: {
          'prompt': '$_parserPrompt\n\nTEXT TO PARSE:\n---\n$rawText\n---',
        },
      );

      if (response.status != 200) return _fallbackExtract(rawText);

      final text = response.data?['text'];
      if (text == null) return null;

      // Clean JSON — remove markdown fences if present
      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```json?\s*'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\s*```$'), '');
      }

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      return _fallbackExtract(rawText);
    }
  }

  /// Parse raw advocate dashboard text into a structured list of cases.
  static Future<Map<String, dynamic>?> parsePortalDashboard(
      String rawText) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: {
          'prompt':
              '$_dashboardPrompt\n\nTEXT TO PARSE:\n---\n$rawText\n---',
        },
      );

      if (response.status != 200) return null;

      final text = response.data?['text'];
      if (text == null) return null;

      String cleanJson = text.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```json?\s*'), '');
        cleanJson = cleanJson.replaceAll(RegExp(r'\s*```$'), '');
      }

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Simple regex-based fallback if Gemini fails
  static Map<String, dynamic>? _fallbackExtract(String text) {
    try {
      final Map<String, dynamic> result = {};

      // Try to extract CNR number (16 alphanumeric chars)
      final cnrMatch = RegExp(r'[A-Z]{4}\d{12}').firstMatch(text);
      if (cnrMatch != null) result['cnr_number'] = cnrMatch.group(0);

      // Try to extract dates (DD-MM-YYYY or DD/MM/YYYY)
      final dateMatches =
          RegExp(r'(\d{2}[-/]\d{2}[-/]\d{4})').allMatches(text);
      final dates = dateMatches.map((m) {
        final parts = m.group(1)!.split(RegExp(r'[-/]'));
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }).toList();

      if (dates.isNotEmpty) {
        result['next_hearing_date'] = dates.last;
      }

      // Try to extract case status
      final statusLower = text.toLowerCase();
      if (statusLower.contains('disposed') ||
          statusLower.contains('closed')) {
        result['case_status'] = 'disposed';
      } else if (statusLower.contains('pending') ||
          statusLower.contains('listed')) {
        result['case_status'] = 'pending';
      } else if (statusLower.contains('transferred')) {
        result['case_status'] = 'transferred';
      }

      return result.isNotEmpty ? result : null;
    } catch (_) {
      return null;
    }
  }
}
