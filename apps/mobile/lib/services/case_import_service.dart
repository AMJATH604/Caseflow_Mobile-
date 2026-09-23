import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'repositories/base_repository.dart';
import '../models/models.dart';
import '../utils/ecourts_case_number.dart';

/// Outcome of a batch import.
///
/// Hearing creation is reported separately from case creation because the two
/// can diverge: a case may import cleanly while its hearing is rejected (an
/// unparseable date, an RLS failure). That used to be swallowed silently,
/// which is what made an empty Court Diary so hard to diagnose.
class CaseImportResult {
  final List<String> caseIds;
  final int hearingsCreated;
  final int hearingsSkipped;

  const CaseImportResult({
    required this.caseIds,
    this.hearingsCreated = 0,
    this.hearingsSkipped = 0,
  });

  int get caseCount => caseIds.length;

  /// Human-readable summary for the completion SnackBar.
  String get summary {
    final buffer = StringBuffer('$caseCount case(s) imported/synced');
    if (hearingsCreated > 0) {
      buffer.write(' · $hearingsCreated hearing(s) added');
    }
    if (hearingsSkipped > 0) {
      buffer.write(' · $hearingsSkipped hearing(s) skipped');
    }
    return buffer.toString();
  }
}

class CaseImportService {
  // ─── eCOURTS TXT IMPORT ─────────────────────────────────

  /// Parses the mycases.txt or eCourts JSON exported from eCourts app.
  static List<Map<String, String>> parseECourtsTxt(String content) {
    // 1. Try to parse as the new JSON array format provided by user
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return _parseECourtsJson(decoded);
      }
    } catch (_) {
      // Not a pure JSON array, continue to line-by-line parsing
    }

    final cases = <Map<String, String>>[];
    final lines =
        content
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    for (var line in lines) {
      // 2. Try to parse individual line as JSON (sometimes exports are line-by-line JSON)
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          final mapped = _mapECourtsJsonFields(decoded);
          if (mapped.isNotEmpty) cases.add(mapped);
          continue;
        } else if (decoded is List) {
          cases.addAll(_parseECourtsJson(decoded));
          continue;
        }
      } catch (_) {}

      // 3. Fallback to delimited/free-form parsing
      if (line.toLowerCase().contains('cnr number') ||
          line.toLowerCase().contains('sr.no') ||
          line.toLowerCase().startsWith('---') ||
          line.toLowerCase().startsWith('===')) {
        continue;
      }

      Map<String, String>? parsed;
      if (line.contains('\t')) {
        parsed = _parseDelimited(line, '\t');
      } else if (line.contains('|')) {
        parsed = _parseDelimited(line, '|');
      } else if (line.contains(',') && line.split(',').length >= 3) {
        parsed = _parseDelimited(line, ',');
      } else {
        parsed = _parseFreeForm(line);
      }

      if (parsed != null && parsed.isNotEmpty) {
        cases.add(parsed);
      }
    }

    return cases;
  }

  static List<Map<String, String>> _parseECourtsJson(List<dynamic> jsonList) {
    final result = <Map<String, String>>[];
    for (var item in jsonList) {
      try {
        Map<String, dynamic> data;
        if (item is String) {
          data = jsonDecode(item) as Map<String, dynamic>;
        } else if (item is Map<String, dynamic>) {
          data = item;
        } else {
          continue;
        }

        final mapped = _mapECourtsJsonFields(data);
        if (mapped.isNotEmpty) result.add(mapped);
      } catch (_) {}
    }
    return result;
  }

  static Map<String, String> _mapECourtsJsonFields(Map<String, dynamic> data) {
    final result = <String, String>{};

    // CNR Mapping
    final cnr = data['cino'] ?? data['cnr'] ?? data['cnr_number'];
    if (cnr != null) result['cnr_number'] = cnr.toString();

    // Parties
    final pet =
        data['petparty_name'] ?? data['pet_name'] ?? data['lpetparty_name'];
    final res =
        data['resparty_name'] ?? data['res_name'] ?? data['lresparty_name'];
    if (pet != null) result['petitioner'] = pet.toString();
    if (res != null) result['respondent'] = res.toString();

    // Court and Location
    final court =
        data['establishment_name'] ?? data['court_name'] ?? data['court_name1'];
    if (court != null) result['court_name'] = court.toString();

    if (data['state_name'] != null) {
      result['state'] = data['state_name'].toString();
    }
    if (data['district_name'] != null) {
      result['district'] = data['district_name'].toString();
    }

    // Case number as the court board shows it. Joining type/reg_no/reg_year
    // directly printed OS/300194/2014 for OS 194/2014 (reg_no carries a
    // series digit) and EP/0/0 for a filed-but-unregistered case — see
    // ECourtsCaseNumber for how each is recovered.
    final caseNumber = ECourtsCaseNumber.fromJson(data);
    if (caseNumber != null) result['case_number'] = caseNumber;

    // Dates
    //
    // eCourts sends dates as DD-MM-YYYY, which `DateTime.parse` rejects and
    // Postgres may or may not coerce depending on DateStyle. Normalise once,
    // here, so every downstream consumer (the cases row AND the hearings row)
    // gets a valid ISO-8601 date. If the format is unrecognised the key is
    // left unset rather than storing a value nothing can parse.
    if (data['date_next_list'] != null) {
      final normalized = BaseRepository.normalizeDateStr(
        data['date_next_list'].toString(),
      );
      if (normalized != null) {
        result['next_hearing_date'] = normalized;
      } else {
        debugPrint(
          'Import: unrecognised next-hearing date format '
          '"${data['date_next_list']}" — skipping date for this case',
        );
      }
    }

    // Title
    if (result.containsKey('petitioner') && result.containsKey('respondent')) {
      result['case_title'] =
          "${result['petitioner']} vs ${result['respondent']}";
    } else if (data['lpetparty_name'] != null) {
      result['case_title'] = data['lpetparty_name'].toString();
    }

    // Advocates
    if (data['pet_adv'] != null) {
      result['pet_advocate'] = data['pet_adv'].toString();
    }
    if (data['res_adv'] != null) {
      result['res_advocate'] = data['res_adv'].toString();
    }
    if (data['pet_adv_phone'] != null) {
      result['pet_adv_phone'] = data['pet_adv_phone'].toString();
    }
    if (data['res_adv_phone'] != null) {
      result['res_adv_phone'] = data['res_adv_phone'].toString();
    }

    return result;
  }

  static Map<String, String>? _parseDelimited(String line, String delimiter) {
    final parts = line.split(delimiter).map((p) => p.trim()).toList();
    if (parts.length < 2) return null;

    final result = <String, String>{};

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];

      // Detect CNR (16-char alphanumeric)
      if (RegExp(r'^[A-Z]{4}\d{12}$').hasMatch(part.replaceAll(' ', ''))) {
        result['cnr_number'] = part;
      }
      // Detect case number pattern (e.g., CS/123/2024, CC/456/2025)
      else if (RegExp(
        r'[A-Z]{1,5}[/\-]\d+[/\-]\d{4}',
        caseSensitive: false,
      ).hasMatch(part)) {
        result['case_number'] = part;
      }
      // Detect "vs" or "v/s" pattern for party names
      else if (part.toLowerCase().contains(' vs ') ||
          part.toLowerCase().contains(' v/s ')) {
        final separator =
            part.toLowerCase().contains(' vs ') ? ' vs ' : ' v/s ';
        final partyParts = part.split(RegExp(separator, caseSensitive: false));
        if (partyParts.length >= 2) {
          result['petitioner'] = partyParts[0].trim();
          result['respondent'] = partyParts[1].trim();
        }
      }
      // Detect court names
      else if (part.toLowerCase().contains('court') ||
          part.toLowerCase().contains('tribunal') ||
          part.toLowerCase().contains('bench')) {
        result['court_name'] = part;
      }
      // Common status values
      else if ([
        'pending',
        'disposed',
        'case disposed',
        'listed',
        'under process',
      ].contains(part.toLowerCase())) {
        result['status'] = part;
      }
      // If nothing matched and it's the first unmatched, treat as case title
      else if (!result.containsKey('case_title') && part.length > 3) {
        result['case_title'] = part;
      }
    }

    // Build case title from parties if not yet set
    if (!result.containsKey('case_title') && result.containsKey('petitioner')) {
      result['case_title'] =
          '${result['petitioner']} vs ${result['respondent'] ?? 'Unknown'}';
    }

    return result.isNotEmpty ? result : null;
  }

  static Map<String, String>? _parseFreeForm(String line) {
    final result = <String, String>{};

    // Try to find CNR
    final cnrMatch = RegExp(r'[A-Z]{4}\d{12}').firstMatch(line);
    if (cnrMatch != null) result['cnr_number'] = cnrMatch.group(0)!;

    // Try to find case number
    final caseMatch = RegExp(r'[A-Z]{1,5}[/\-]\d+[/\-]\d{4}').firstMatch(line);
    if (caseMatch != null) result['case_number'] = caseMatch.group(0)!;

    // Try "vs" pattern
    final vsMatch = RegExp(
      r'(.+?)\s+(?:vs|v/s)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(line);
    if (vsMatch != null) {
      result['petitioner'] = vsMatch.group(1)!.trim();
      result['respondent'] = vsMatch.group(2)!.trim();
      result['case_title'] =
          '${result['petitioner']} vs ${result['respondent']}';
    }

    return result.isNotEmpty ? result : null;
  }

  /// BATCH Import: Pre-fetches all data ONCE, then imports all cases.
  /// This eliminates N+1 queries and makes importing 90+ cases near-instant.
  static Future<CaseImportResult> batchImportECourtsCases(
    List<Map<String, String>> parsedCases,
    Map<int, String> roles,
  ) async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // 1. Pre-fetch ALL existing data ONCE (instead of per-case)
    final allCases = await SupabaseService.fetchCases();
    final allClients = await SupabaseService.fetchClients();
    final existingCnrs = <String, CaseModel>{};
    for (final c in allCases) {
      if (c.cnrNumber != null && c.cnrNumber!.isNotEmpty) {
        existingCnrs[c.cnrNumber!] = c;
      }
    }
    // Mutable client cache (grows as new clients are created)
    final clientCache = <String, String>{};
    for (final c in allClients) {
      clientCache[c.name.toLowerCase()] = c.id;
    }

    final List<String> importedIds = [];
    int hearingsCreated = 0;
    int hearingsSkipped = 0;

    // 2. Process each case using cached data
    for (int i = 0; i < parsedCases.length; i++) {
      try {
        final parsedCase = parsedCases[i];
        // No fallback. This used to read `roles[i] ?? 'petitioner'`, which
        // made the first name in "X vs Y" the client whenever the caller had
        // not said otherwise — wrong for every case argued from the other
        // side, and silent about it. The preview now requires an answer for
        // each case, so a missing one is a programming error, not a default.
        final representationType = roles[i];
        if (representationType == null) {
          throw StateError(
            'No side chosen for case ${i + 1} '
            '("${parsedCase['case_title'] ?? 'untitled'}"). '
            'The client cannot be determined without it.',
          );
        }
        final String? cnr = parsedCase['cnr_number'];

        // Check for existing case by CNR (from cache)
        CaseModel? existingCase;
        if (cnr != null && cnr.isNotEmpty) {
          existingCase = existingCnrs[cnr];
        }

        // Role-Based Mapping
        final String petitioner =
            parsedCase['petitioner'] ?? 'Unknown Petitioner';
        final String respondent =
            parsedCase['respondent'] ?? 'Unknown Respondent';
        String clientName;
        String opposingParty;
        final String? petitionerAdvocate = parsedCase['pet_advocate'];
        final String? petitionerPhone = parsedCase['pet_adv_phone'];
        final String? respondentAdvocate = parsedCase['res_advocate'];
        final String? respondentPhone = parsedCase['res_adv_phone'];

        if (representationType == 'respondent') {
          clientName = respondent;
          opposingParty = petitioner;
        } else {
          clientName = petitioner;
          opposingParty = respondent;
        }

        // Find or Create Client (from cache)
        String? clientId = clientCache[clientName.toLowerCase()];
        if (clientId == null) {
          final newClient = await SupabaseService.createClient({
            'name': clientName,
          });
          clientId = newClient.id;
          clientCache[clientName.toLowerCase()] = clientId;
        }

        // Prepare Case Data
        final caseData = {
          'case_title':
              parsedCase['case_title'] ?? '$petitioner vs $respondent',
          'case_number': parsedCase['case_number'] ?? cnr,
          'court_name': parsedCase['court_name'],
          'client_id': clientId,
          'status': 'active',
          'stage': parsedCase['status'] ?? 'pending',
          'next_hearing_date': parsedCase['next_hearing_date'],
          'state': parsedCase['state'],
          'district': parsedCase['district'],
          'cnr_number': cnr,
          'representation_type': representationType,
          'opposing_party': opposingParty,
          'petitioner_advocate': petitionerAdvocate,
          'petitioner_advocate_phone': petitionerPhone,
          'opposing_advocate': respondentAdvocate,
          'opposing_advocate_phone': respondentPhone,
        };

        String caseId;
        if (existingCase != null) {
          await SupabaseService.updateCase(existingCase.id, caseData);
          caseId = existingCase.id;
        } else {
          final created = await SupabaseService.createCase(caseData);
          caseId = created.id;
          // Update cache
          if (cnr != null && cnr.isNotEmpty) {
            existingCnrs[cnr] = created;
          }
        }

        // Create Hearing if a usable date exists.
        //
        // The date was normalised to ISO-8601 at extraction, so tryParse here
        // is a validity check rather than a format conversion. Without the
        // normalisation this branch never ran for DD-MM-YYYY dates, which is
        // why imported cases appeared with an empty Court Diary.
        final rawHearingDate = parsedCase['next_hearing_date'];
        if (rawHearingDate != null && rawHearingDate.isNotEmpty) {
          if (DateTime.tryParse(rawHearingDate) != null) {
            try {
              // Upsert, not insert. Re-syncing a case whose date has not
              // moved must be a no-op; inserting blindly is what left 25
              // cases showing the same hearing twice in the Court Diary.
              final result = await SupabaseService.upsertHearing({
                'case_id': caseId,
                'hearing_date': rawHearingDate,
                'stage': parsedCase['status'] ?? 'Listed',
                'purpose': 'Hearing',
                'status': 'scheduled',
                'notes':
                    existingCase != null
                        ? 'Synced from eCourts Update'
                        : 'Imported from eCourts',
              });
              if (result.created) {
                hearingsCreated++;
              } else {
                // Already listed for that date — nothing to do, and not a
                // failure worth reporting as one.
                hearingsSkipped++;
              }
            } catch (e) {
              hearingsSkipped++;
              debugPrint(
                'Import: hearing creation failed for case $caseId: $e',
              );
            }
          } else {
            hearingsSkipped++;
            debugPrint(
              'Import: unparseable hearing date "$rawHearingDate" '
              'for case $caseId',
            );
          }
        }

        importedIds.add(caseId);
      } catch (e) {
        // Skip individual case errors, continue with the rest
        debugPrint('Import: case ${i + 1} failed, continuing: $e');
        continue;
      }
    }

    return CaseImportResult(
      caseIds: importedIds,
      hearingsCreated: hearingsCreated,
      hearingsSkipped: hearingsSkipped,
    );
  }

  /// Import or Sync a single parsed eCourts case into CaseFlow
  static Future<String?> importECourtsCase(
    Map<String, String> parsedCase, {
    String representationType = 'petitioner',
  }) async {
    final result = await batchImportECourtsCases(
      [parsedCase],
      {0: representationType},
    );
    return result.caseIds.isNotEmpty ? result.caseIds.first : null;
  }

  // ─── CASEFLOW JSON IMPORT ──────────────────────────────

  /// Validates and parses a CaseFlow JSON backup
  static Map<String, dynamic>? parseCaseFlowJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data['app'] != 'CaseFlow' || data['version'] == null) return null;
      if (data['case'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Import a full CaseFlow JSON backup into the database
  static Future<String?> importCaseFlowJson(Map<String, dynamic> data) async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final caseData = data['case'] as Map<String, dynamic>;
      final hearingsData = data['hearings'] as List? ?? [];
      final paymentsData = data['payments'] as List? ?? [];
      final efilingsData = data['efiling_records'] as List? ?? [];

      // Create or find client
      String? clientId;
      final clientName = caseData['client_name'] ?? 'Unknown Client';
      final existingClients = await SupabaseService.fetchClients();
      final match = existingClients.where(
        (c) => c.name.toLowerCase() == clientName.toString().toLowerCase(),
      );
      if (match.isNotEmpty) {
        clientId = match.first.id;
      } else {
        final newClient = await SupabaseService.createClient({
          'name': clientName,
        });
        clientId = newClient.id;
      }

      // Create the case
      final created = await SupabaseService.createCase({
        'case_title': caseData['case_title'] ?? 'Imported Case',
        'case_number': caseData['case_number'],
        'case_type': caseData['case_type'],
        'court_name': caseData['court_name'],
        'client_id': clientId,
        'status': caseData['status'] ?? 'active',
        'stage': caseData['stage'] ?? 'filing',
        'filing_date': BaseRepository.normalizeDateStr(
          caseData['filing_date']?.toString(),
        ),
        'next_hearing_date': BaseRepository.normalizeDateStr(
          caseData['next_hearing_date']?.toString(),
        ),
        'state': caseData['state'],
        'district': caseData['district'],
        'cnr_number': caseData['cnr_number'],
        'representation_type': caseData['representation_type'] ?? 'petitioner',
        'opposing_party': caseData['opposing_party'],
        'opposing_advocate': caseData['opposing_advocate'],
        'opposing_advocate_phone': caseData['opposing_advocate_phone'],
        'petitioner_advocate': caseData['petitioner_advocate'],
        'petitioner_advocate_phone': caseData['petitioner_advocate_phone'],
      });

      final caseId = created.id;

      // Import hearings. A hearing row with no valid date is useless — it
      // would never surface in the Court Diary or the Hearings calendar — so
      // skip it rather than writing an unusable record.
      for (var h in hearingsData) {
        final hearingDate = BaseRepository.normalizeDateStr(
          h['hearing_date']?.toString(),
        );
        if (hearingDate == null) {
          debugPrint(
            'Restore: skipping hearing with unusable date '
            '"${h['hearing_date']}"',
          );
          continue;
        }
        // Upsert: a backup taken before hearings had a unique key can itself
        // hold two rows for one date, and an insert would abort the whole
        // restore over a duplicate the user cannot see or fix.
        await SupabaseService.upsertHearing({
          'case_id': caseId,
          'hearing_date': hearingDate,
          'stage': h['stage'],
          'purpose': h['purpose'],
          'status': h['status'] ?? 'scheduled',
          'notes': h['notes'],
        });
      }

      // Import payments. Unlike a hearing, a payment is still worth keeping
      // when its date is unusable — the amount is the point — so normalise the
      // date and fall back to null rather than dropping the whole record.
      //
      // Normalising here is not cosmetic: an unnormalised date reaches the DB
      // as written, and `Payment.fromJson` would then throw while parsing it,
      // which fails the entire payments query rather than the single row.
      for (var p in paymentsData) {
        final paidDate = BaseRepository.normalizeDateStr(
          p['paid_date']?.toString(),
        );
        if (paidDate == null && p['paid_date'] != null) {
          debugPrint(
            'Restore: dropping unusable payment date "${p['paid_date']}"',
          );
        }
        await SupabaseService.createPayment({
          'case_id': caseId,
          'total_fee': p['total_fee'] ?? 0,
          'paid_amount': p['paid_amount'] ?? 0,
          'balance_amount': p['balance_amount'] ?? 0,
          'paid_date': paidDate,
          'payment_mode': p['payment_mode'],
        });
      }

      // Import e-filing records. Same reasoning as payments: keep the record,
      // drop only a date that cannot be stored safely.
      for (var r in efilingsData) {
        final filingDate = BaseRepository.normalizeDateStr(
          r['filing_date']?.toString(),
        );
        if (filingDate == null && r['filing_date'] != null) {
          debugPrint(
            'Restore: dropping unusable filing date "${r['filing_date']}"',
          );
        }
        await SupabaseService.createEfilingRecord({
          'case_id': caseId,
          'document_type': r['document_type'] ?? 'other',
          'status': r['status'] ?? 'drafting',
          'filing_date': filingDate,
        });
      }

      return caseId;
    } catch (e) {
      rethrow;
    }
  }

  /// Get a summary of what will be imported from JSON
  static Map<String, int> getImportSummary(Map<String, dynamic> data) {
    return {
      'hearings': (data['hearings'] as List?)?.length ?? 0,
      'payments': (data['payments'] as List?)?.length ?? 0,
      'efiling_records': (data['efiling_records'] as List?)?.length ?? 0,
    };
  }
}
