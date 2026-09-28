import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'base_repository.dart';

/// The outcome of [HearingRepository.upsertHearing].
class HearingUpsert {
  const HearingUpsert(this.hearing, this.created);

  /// The row now in the database — the new one, or the one already there.
  final Hearing? hearing;

  /// False when the case was already listed on that date and nothing was
  /// written. Callers that report counts should not call that a failure.
  final bool created;
}

/// Repository for hearing management including the adjourn workflow.
class HearingRepository {
  static final _client = BaseRepository.client;

  /// True when the database refused a second hearing for a case on a date it
  /// is already listed on, so a screen can say that in plain words instead of
  /// showing the raw constraint violation.
  static bool isDuplicateHearing(Object error) =>
      error is PostgrestException &&
      (error.code == '23505' ||
          error.message.contains('hearings_unique_date_per_case'));

  static Future<List<Hearing>> fetchHearings({
    String? caseId,
    int? limit,
    int? offset,
  }) async {
    // Throws rather than returning an empty list when the session is missing
    // or its token has expired. Returning [] made "not signed in yet" look
    // exactly like "no hearings", so the Court Diary rendered its empty state
    // on a cold start and the provider cached that empty list — it only
    // filled in once something else happened to refresh it.
    final user = await BaseRepository.requireActiveSession();

    final profile = await BaseRepository.getCachedProfile();
    final visibleCaseIds = await BaseRepository.getVisibleCaseIds(
      profile,
      user.id,
    );

    // Authoritative: the query above either succeeded or threw, so an empty
    // list here means the user really has no cases.
    if (visibleCaseIds.isEmpty) return [];

    var query = _client
        .from('hearings')
        .select(
          '*, cases(case_title, court_name, case_number, cnr_number, firm_id)',
        );

    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    // Apply pagination and ordering in a single chain to avoid type mismatch
    final List response;
    if (limit != null && offset != null) {
      response = await query
          .order('hearing_date')
          .range(offset, offset + limit - 1);
    } else if (limit != null) {
      response = await query.order('hearing_date').limit(limit);
    } else {
      response = await query.order('hearing_date');
    }
    return response.map((json) => Hearing.fromJson(json)).toList();
  }

  static const String _hearingSelect =
      '*, cases(case_title, court_name, case_number, cnr_number, firm_id)';

  static Future<Hearing> createHearing(Map<String, dynamic> hearingData) async {
    final user = BaseRepository.requireAuth();
    final response =
        await _client
            .from('hearings')
            .insert({...hearingData, 'created_by': user.id})
            .select(_hearingSelect)
            .single();
    return Hearing.fromJson(response);
  }

  /// Ensures the case is listed on this date, without ever adding a second
  /// row for a date it is already listed on.
  ///
  /// Sync, restore and adjourn all want "make sure this date is listed"
  /// rather than "add a row". Asking for the latter is what left 25 cases
  /// holding duplicate hearings before `hearings_unique_date_per_case`
  /// existed, because a re-run of the eCourts import inserted a second row
  /// and the caller counted the resulting failure as a skip.
  ///
  /// A collision keeps the row already there rather than overwriting it: the
  /// existing row may carry notes the advocate typed, and a re-sync of the
  /// same date has nothing new to say about it.
  static Future<HearingUpsert> upsertHearing(
    Map<String, dynamic> hearingData,
  ) async {
    final user = BaseRepository.requireAuth();

    final inserted = await _client
        .from('hearings')
        .upsert(
          {...hearingData, 'created_by': user.id},
          onConflict: 'case_id,hearing_date',
          ignoreDuplicates: true,
        )
        .select(_hearingSelect);

    if (inserted.isNotEmpty) {
      return HearingUpsert(Hearing.fromJson(inserted.first), true);
    }

    // Already listed. Hand back what is there so a caller that needs the row
    // — adjourn does — is not left holding null.
    final existing =
        await _client
            .from('hearings')
            .select(_hearingSelect)
            .eq('case_id', hearingData['case_id'])
            .eq('hearing_date', hearingData['hearing_date'])
            .maybeSingle();

    return HearingUpsert(
      existing == null ? null : Hearing.fromJson(existing),
      false,
    );
  }

  /// Adjourn workflow:
  /// 1. Delete the old (just completed) hearing
  /// 2. If not disposed/dismissed, create a new future hearing
  /// 3. Update the case status and next_hearing_date
  static Future<Hearing?> adjournHearing(
    String id,
    Map<String, dynamic> data,
  ) async {
    BaseRepository.requireAuth();

    final String nextStage = data['next_stage'] ?? 'Next Hearing';
    final bool isFinal =
        nextStage == 'Case Disposed' || nextStage == 'Case Dismissed';

    // 1. Delete the old hearing
    await _client.from('hearings').delete().eq('id', id);

    Hearing? newHearing;

    if (!isFinal) {
      // 2. List the next date. Upsert rather than insert: the old hearing has
      // already been deleted above, so a unique violation here would destroy
      // it and leave nothing in its place. Adjourning onto a date the case is
      // already listed on simply reuses that listing.
      final result = await upsertHearing({
        'case_id': data['case_id'],
        'hearing_date': data['next_date'],
        'stage': nextStage,
      });
      newHearing = result.hearing;
    }

    // 3. Update case status
    final Map<String, dynamic> caseUpdates = {'stage': nextStage};
    if (isFinal) {
      caseUpdates['status'] =
          nextStage == 'Case Disposed' ? 'disposed' : 'dismissed';
      caseUpdates['next_hearing_date'] = null;
    } else {
      caseUpdates['next_hearing_date'] = data['next_date'];
    }

    await _client.from('cases').update(caseUpdates).eq('id', data['case_id']);

    return newHearing;
  }

  /// Deletes a hearing and points its case at whatever hearing is now next.
  ///
  /// Deleting the row alone left `cases.next_hearing_date` on the removed
  /// date, so the Case Dossier and the case list went on announcing a hearing
  /// that no longer existed. That is the usual reason for deleting at all —
  /// undoing a wrong adjournment — so the stale date was exactly the one the
  /// advocate was trying to get rid of.
  static Future<void> deleteHearing(String id) async {
    BaseRepository.requireAuth();

    final row =
        await _client
            .from('hearings')
            .select('case_id')
            .eq('id', id)
            .maybeSingle();

    await _client.from('hearings').delete().eq('id', id);

    final caseId = row?['case_id'];
    if (caseId != null) await resyncNextHearingDate(caseId.toString());
  }

  /// Sets `cases.next_hearing_date` to the earliest hearing still listed from
  /// today on, or clears it when none is left.
  static Future<void> resyncNextHearingDate(String caseId) async {
    final today = BaseRepository.normalizeDateStr(
      DateTime.now().toIso8601String(),
    );

    final next =
        await _client
            .from('hearings')
            .select('hearing_date')
            .eq('case_id', caseId)
            .gte('hearing_date', today!)
            .order('hearing_date')
            .limit(1)
            .maybeSingle();

    await _client
        .from('cases')
        .update({'next_hearing_date': next?['hearing_date']})
        .eq('id', caseId);
  }
}
