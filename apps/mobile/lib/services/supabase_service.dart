import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import 'fcm_service.dart';
import 'offline_cache_service.dart';
import 'repositories/base_repository.dart';
import 'repositories/case_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/hearing_repository.dart';
import 'repositories/payment_repository.dart';
import 'repositories/evidence_repository.dart';
import 'repositories/filing_repository.dart';
import 'repositories/content_repository.dart';
import 'repositories/discussion_repository.dart';
import 'repositories/direct_message_repository.dart';


/// Backward-compatible facade that delegates to domain repositories.
///
/// **Architecture upgrade:**
/// Previously this was a 986-line "God file" containing ALL database logic.
/// Now it's a thin delegation layer — each domain has its own repository:
///
/// - [CaseRepository]       → Cases, dossier (acts, IAs, orders), search, workspace
/// - [ClientRepository]     → Clients CRUD
/// - [HearingRepository]    → Hearings, adjourn workflow
/// - [PaymentRepository]    → Payments, ledger, installments
/// - [EvidenceRepository]   → Evidence checklists, witness notes, photos
/// - [FilingRepository]     → E-filing records, certified copies
/// - [ContentRepository]    → Bare acts, stamps, templates, documents, tasks, portals
/// - [DiscussionRepository] → Case discussions with Supabase Realtime (no more polling!)
/// - [BaseRepository]       → Profile caching, auth guards, visibility filters
///
/// All existing call sites (`SupabaseService.fetchCases()`) continue to work
/// unchanged — zero screen modifications required.
class SupabaseService {
  static final client = Supabase.instance.client;

  static void updateOffset(DateTime serverTime) =>
      BaseRepository.updateOffset(serverTime);

  static DateTime get syncedNow => BaseRepository.syncedNow;

  // ─── Authentication ──────────────────────────────────

  static Future<AuthResponse> signIn(String email, String password) async {
    BaseRepository.invalidateProfileCache();
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await FcmService().removeToken();
    BaseRepository.invalidateProfileCache();
    await OfflineCacheService.clearAll(); // Clear offline cache on logout
    await client.auth.signOut();
  }

  /// Cached profile fetch — eliminates the N+1 problem.
  /// Previously called fresh from DB inside every data method.
  /// Now returns cached value (TTL: 5 min) via [BaseRepository].
  static Future<UserProfile> fetchProfile() =>
      BaseRepository.getCachedProfile();

  // ─── Clients ────────────────────────────────────────

  static Future<List<ClientModel>> fetchClients() =>
      ClientRepository.fetchClients();

  static Future<ClientModel> createClient(Map<String, dynamic> data) =>
      ClientRepository.createClient(data);

  static Future<void> updateClient(String id, Map<String, dynamic> updates) =>
      ClientRepository.updateClient(id, updates);

  static Future<void> deleteClient(String id) =>
      ClientRepository.deleteClient(id);

  // ─── Cases ──────────────────────────────────────────

  static Future<List<CaseModel>> fetchCases() => CaseRepository.fetchCases();

  static Future<CaseModel> fetchCaseById(String id) =>
      CaseRepository.fetchCaseById(id);

  static Future<CaseModel> createCase(Map<String, dynamic> data) =>
      CaseRepository.createCase(data);

  static Future<void> updateCase(String id, Map<String, dynamic> updates) =>
      CaseRepository.updateCase(id, updates);

  static Future<void> deleteCase(String id) => CaseRepository.deleteCase(id);

  static Future<void> updateCaseCnr(String id, String cnr) =>
      CaseRepository.updateCaseCnr(id, cnr);

  // ─── Hearings ───────────────────────────────────────

  static Future<List<Hearing>> fetchHearings({String? caseId}) =>
      HearingRepository.fetchHearings(caseId: caseId);

  static Future<Hearing> createHearing(Map<String, dynamic> data) =>
      HearingRepository.createHearing(data);

  static Future<Hearing?> adjournHearing(
    String id,
    Map<String, dynamic> data,
  ) => HearingRepository.adjournHearing(id, data);

  static Future<void> deleteHearing(String id) =>
      HearingRepository.deleteHearing(id);

  // ─── E-Filing ───────────────────────────────────────

  static Future<List<EFilingRecord>> fetchEfilingRecords({String? caseId}) =>
      FilingRepository.fetchEfilingRecords(caseId: caseId);

  static Future<void> createEfilingRecord(Map<String, dynamic> record) =>
      FilingRepository.createEfilingRecord(record);

  // ─── Payments ───────────────────────────────────────

  static Future<List<Payment>> fetchPayments({String? caseId}) =>
      PaymentRepository.fetchPayments(caseId: caseId);

  static Future<void> createPayment(Map<String, dynamic> payment) =>
      PaymentRepository.createPayment(payment);

  static Future<void> deletePayment(String id) =>
      PaymentRepository.deletePayment(id);

  static Future<Map<String, double>> fetchCasePaymentSummary(String caseId) =>
      PaymentRepository.fetchCasePaymentSummary(caseId);

  static Future<void> addPaymentInstallment(Map<String, dynamic> payment) =>
      PaymentRepository.addPaymentInstallment(payment);

  // ─── Tasks ──────────────────────────────────────────

  static Future<List<TaskModel>> fetchTasks() => ContentRepository.fetchTasks();

  static Stream<List<TaskModel>> tasksStream() =>
      ContentRepository.tasksStream();

  static Future<void> createTask(String title) =>
      ContentRepository.createTask(title);

  static Future<void> updateTask(String id, Map<String, dynamic> updates) =>
      ContentRepository.updateTask(id, updates);

  static Future<void> deleteTask(String id) => ContentRepository.deleteTask(id);

  // ─── Certified Copies ────────────────────────────────

  static Future<List<CertifiedCopy>> fetchCertifiedCopies() =>
      FilingRepository.fetchCertifiedCopies();

  static Future<void> createCertifiedCopy(Map<String, dynamic> data) =>
      FilingRepository.createCertifiedCopy(data);

  static Future<void> updateCertifiedCopy(
    String id,
    Map<String, dynamic> updates,
  ) => FilingRepository.updateCertifiedCopy(id, updates);

  static Future<void> deleteCertifiedCopy(String id) =>
      FilingRepository.deleteCertifiedCopy(id);

  // ─── Documents (Supabase Storage) ──────────────────

  static Future<List<Map<String, dynamic>>> fetchDocuments(String caseId) =>
      ContentRepository.fetchDocuments(caseId);

  static Future<void> uploadDocument(
    String caseId,
    Uint8List file,
    String fileName,
  ) => ContentRepository.uploadDocument(caseId, file, fileName);

  static Future<void> deleteDocument(String caseId, String fileName) =>
      ContentRepository.deleteDocument(caseId, fileName);

  // ─── Bare Acts ──────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchBareActs() =>
      ContentRepository.fetchBareActs();

  static Future<List<dynamic>> fetchSections(String actId) =>
      ContentRepository.fetchSections(actId);

  static Future<List<dynamic>> searchBareActs(String query, {String? actId}) =>
      ContentRepository.searchBareActs(query, actId: actId);

  static Future<List<Map<String, dynamic>>> fetchStampValues({
    String stateId = 'TN',
  }) => ContentRepository.fetchStampValues(stateId: stateId);

  static Future<List<LegalTemplate>> fetchLegalTemplates() =>
      ContentRepository.fetchLegalTemplates();

  static Future<List<LegalTemplate>> searchLegalTemplates(String query) =>
      ContentRepository.searchLegalTemplates(query);

  // ─── Dashboard Stats (Parallelized) ─────────────────

  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final user = client.auth.currentUser;
    if (user == null) return {};

    final profile = await BaseRepository.getCachedProfile();
    final today = DateTime.now().toIso8601String().split('T')[0];

    final orFilter = BaseRepository.buildVisibilityFilter(profile, user.id);

    // Step 1: Get visible case IDs (required for all sub-queries)
    final totalCasesRes = await client
        .from('cases')
        .select('id, status')
        .or(orFilter);
    final List casesList = totalCasesRes as List;
    final List<String> visibleCaseIds =
        casesList.map((c) => c['id'] as String).toList();

    if (visibleCaseIds.isEmpty) {
      return {
        'activeCasesCount': 0,
        'totalCasesCount': 0,
        'upcomingHearingsCount': 0,
        'clientsCount': 0,
        'filingsCount': 0,
        'todayHearings': <Hearing>[],
      };
    }

    final int activeCount =
        casesList.where((c) => c['status'] == 'active').length;
    final int disposedCount =
        casesList.where((c) => c['status'] == 'disposed').length;
    final int dismissedCount =
        casesList
            .where((c) => c['status'] == 'dismissed' || c['status'] == 'closed')
            .length;

    // Step 2: Parallel fetch with error isolation — each query fails
    // gracefully so a single failure doesn't crash the entire dashboard.
    Future<List> safeQuery(Future<List> query) async {
      try {
        return await query;
      } catch (e) {
        debugPrint('Dashboard query failed (degrading gracefully): $e');
        return [];
      }
    }

    final results = await Future.wait([
      safeQuery(
        client
            .from('hearings')
            .select('id')
            .gte('hearing_date', today)
            .inFilter('case_id', visibleCaseIds),
      ),
      safeQuery(
        client
            .from('efiling_records')
            .select('id')
            .inFilter('case_id', visibleCaseIds),
      ),
      safeQuery(client.from('clients').select('id')),
      safeQuery(
        client
            .from('hearings')
            .select('*, cases(case_title, case_number, firm_id)')
            .eq('hearing_date', today)
            .inFilter('case_id', visibleCaseIds)
            .order('created_at', ascending: false)
            .limit(5),
      ),
      safeQuery(
        client
            .from('payments')
            .select('id, balance_amount')
            .gt('balance_amount', 0)
            .inFilter('case_id', visibleCaseIds),
      ),
    ]);

    final pendingPayments = results[4];

    return {
      'activeCasesCount': activeCount,
      'totalCasesCount': casesList.length,
      'upcomingHearingsCount': results[0].length,
      'filingsCount': results[1].length,
      'clientsCount': results[2].length,
      'disposedCasesCount': disposedCount,
      'dismissedCasesCount': dismissedCount,
      'pendingPaymentsCount': pendingPayments.length,
      'todayHearings':
          results[3].map((json) => Hearing.fromJson(json)).toList(),
    };
  }

  // ─── Evidence Lab ──────────────────────────────────

  static Future<List<EvidenceChecklist>> fetchEvidenceChecklist(
    String caseId,
  ) => EvidenceRepository.fetchEvidenceChecklist(caseId);

  static Future<void> createEvidenceChecklistItem(Map<String, dynamic> data) =>
      EvidenceRepository.createEvidenceChecklistItem(data);

  static Future<void> updateEvidenceChecklistItem(
    String id,
    Map<String, dynamic> updates,
  ) => EvidenceRepository.updateEvidenceChecklistItem(id, updates);

  static Future<void> deleteEvidenceChecklistItem(String id) =>
      EvidenceRepository.deleteEvidenceChecklistItem(id);

  static Future<List<WitnessNote>> fetchWitnessNotes(String caseId) =>
      EvidenceRepository.fetchWitnessNotes(caseId);

  static Future<void> createWitnessNote(Map<String, dynamic> data) =>
      EvidenceRepository.createWitnessNote(data);

  static Future<void> updateWitnessNote(
    String id,
    Map<String, dynamic> updates,
  ) => EvidenceRepository.updateWitnessNote(id, updates);

  static Future<void> deleteWitnessNote(String id) =>
      EvidenceRepository.deleteWitnessNote(id);

  static Future<List<EvidencePhoto>> fetchEvidencePhotos(String caseId) =>
      EvidenceRepository.fetchEvidencePhotos(caseId);

  static Future<void> createEvidencePhoto(Map<String, dynamic> data) =>
      EvidenceRepository.createEvidencePhoto(data);

  static Future<void> deleteEvidencePhoto(String id) =>
      EvidenceRepository.deleteEvidencePhoto(id);

  // ─── Case Discussion & Notices ──────────────────────

  static Future<List<CaseComment>> fetchDiscussions({
    String? caseId,
    String? firmId,
  }) => DiscussionRepository.fetchDiscussions(caseId: caseId, firmId: firmId);

  /// Now uses Supabase Realtime instead of 2-second polling.
  static Stream<List<CaseComment>> discussionsStream({
    String? caseId,
    String? firmId,
  }) => DiscussionRepository.discussionsStream(caseId: caseId, firmId: firmId);

  static Future<void> postDiscussion(Map<String, dynamic> data) =>
      DiscussionRepository.postDiscussion(data);

  static Future<void> deleteDiscussion(String id) =>
      DiscussionRepository.deleteDiscussion(id);

  // ─── Direct Messages ────────────────────────────────

  static Future<List<DirectConversation>> fetchDirectConversations() =>
      DirectMessageRepository.fetchConversations();

  static Future<List<DirectMessage>> fetchDirectMessages(
    String conversationId,
  ) => DirectMessageRepository.fetchDirectMessages(conversationId);

  static Stream<List<DirectMessage>> directMessagesStream(
    String conversationId,
  ) => DirectMessageRepository.directMessagesStream(conversationId);

  static Future<void> sendDirectMessage(
    String conversationId,
    String message, {
    String? attachmentUrl,
    String? attachmentType,
    String? replyToId,
    String? replyToMessage,
    String? replyToSender,
  }) => DirectMessageRepository.sendDirectMessage(
    conversationId,
    message,
    attachmentUrl: attachmentUrl,
    attachmentType: attachmentType,
    replyToId: replyToId,
    replyToMessage: replyToMessage,
    replyToSender: replyToSender,
  );

  static Future<void> markDirectMessagesRead(String conversationId) =>
      DirectMessageRepository.markMessagesRead(conversationId);

  static Future<String> createOrGetDirectConversation(String partnerId) =>
      DirectMessageRepository.createOrGetConversation(partnerId);

  static Future<void> deleteDirectMessage(String id) =>
      DirectMessageRepository.deleteDirectMessage(id);

  static Future<String?> uploadDirectMessageAttachment({
    required File file,
    required String conversationId,
  }) => DirectMessageRepository.uploadAttachment(
    file: file,
    conversationId: conversationId,
  );



  // ─── District Portals ──────────────────────────────────

  static Future<String?> getDistrictPortalUrl(
    String state,
    String district,
    String type,
  ) => ContentRepository.getDistrictPortalUrl(state, district, type);

  // ─── Global Search ──────────────────────────────────

  static Future<Map<String, List<dynamic>>> searchAll(String query) =>
      CaseRepository.searchAll(query);

  // ─── Workspace Reset ───────────────────────────────

  static Future<void> resetUserWorkspace() =>
      CaseRepository.resetUserWorkspace();

  // ─── Case Acts (eCourt Dossier) ────────────────────

  static Future<List<CaseAct>> fetchCaseActs(String caseId) =>
      CaseRepository.fetchCaseActs(caseId);

  static Future<void> createCaseAct(Map<String, dynamic> data) =>
      CaseRepository.createCaseAct(data);

  static Future<void> upsertCaseAct(Map<String, dynamic> data) =>
      CaseRepository.upsertCaseAct(data);

  static Future<void> deleteCaseAct(String id) =>
      CaseRepository.deleteCaseAct(id);

  static Future<void> upsertCaseActs(List<Map<String, dynamic>> acts) =>
      CaseRepository.upsertCaseActs(acts);

  // ─── Case IA Applications (eCourt Dossier) ─────────

  static Future<List<CaseIAApplication>> fetchCaseIAs(String caseId) =>
      CaseRepository.fetchCaseIAs(caseId);

  static Future<void> createCaseIA(Map<String, dynamic> data) =>
      CaseRepository.createCaseIA(data);

  static Future<void> upsertCaseIA(Map<String, dynamic> data) =>
      CaseRepository.upsertCaseIA(data);

  static Future<void> updateCaseIA(String id, Map<String, dynamic> updates) =>
      CaseRepository.updateCaseIA(id, updates);

  static Future<void> deleteCaseIA(String id) =>
      CaseRepository.deleteCaseIA(id);

  static Future<void> upsertCaseIAs(List<Map<String, dynamic>> ias) =>
      CaseRepository.upsertCaseIAs(ias);

  // ─── Interim Orders (eCourt Dossier) ──────────────

  static Future<List<CaseInterimOrder>> fetchInterimOrders(String caseId) =>
      CaseRepository.fetchInterimOrders(caseId);

  static Future<void> createInterimOrder(Map<String, dynamic> data) =>
      CaseRepository.createInterimOrder(data);

  static Future<void> upsertInterimOrder(Map<String, dynamic> data) =>
      CaseRepository.upsertInterimOrder(data);

  static Future<void> deleteInterimOrder(String id) =>
      CaseRepository.deleteInterimOrder(id);

  static Future<void> upsertInterimOrders(List<Map<String, dynamic>> orders) =>
      CaseRepository.upsertInterimOrders(orders);

  // ─── Carousel Slides ──────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchCarouselSlides() =>
      ContentRepository.fetchCarouselSlides();

  // ─── Profile Photo ──────────────────────────────────

  static Future<String> updateProfilePhoto(
    String userId,
    Uint8List imageBytes,
  ) => BaseRepository.updateProfilePhoto(userId, imageBytes);

  static Future<void> removeProfilePhoto(String userId) =>
      BaseRepository.removeProfilePhoto(userId);
}
