import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import 'fcm_service.dart';

class SupabaseService {
  static final client = Supabase.instance.client;
  static Duration _serverTimeOffset = Duration.zero;

  static void updateOffset(DateTime serverTime) {
    _serverTimeOffset = serverTime.toUtc().difference(DateTime.now().toUtc());
  }

  static DateTime get syncedNow => DateTime.now().add(_serverTimeOffset);

  // ─── Authentication ──────────────────────────────────

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    // Remove FCM token before signing out
    await FcmService().removeToken();
    await client.auth.signOut();
  }

  static Future<UserProfile> fetchProfile() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    
    final response = await client.from('profiles').select().eq('id', user.id).maybeSingle();
    
    if (response == null) {
      // Create a default profile if it doesn't exist
      final newProfile = {
        'id': user.id,
        'full_name': user.email?.split('@')[0] ?? 'User',
        'subscription_tier': 'free',
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from('profiles').insert(newProfile);
      return UserProfile.fromJson(newProfile);
    }

    final Map<String, dynamic> profileData = Map<String, dynamic>.from(response);

    final String? currentFirmId = profileData['firm_id'];

    if (currentFirmId != null) {
      // ─── Membership Verification ───────────────────────────────────────────
      // If the user has a firm_id, we MUST verify they are still in the 
      // firm_members table. If the owner removed them, we revoke access here.
      final membership = await client
          .from('firm_members')
          .select()
          .eq('member_id', user.id)
          .eq('owner_id', currentFirmId)
          .eq('status', 'accepted')
          .maybeSingle();
      
      if (membership == null) {
        // Membership was revoked or record deleted! 
        // We update the profiles table from the user's OWN session (allowed by RLS).
        await client.from('profiles').update({'firm_id': null}).eq('id', user.id);
        profileData['firm_id'] = null; 
      }
    }
    
    return UserProfile.fromJson(profileData);
  }


  // ─── Clients ────────────────────────────────────────

  static Future<List<ClientModel>> fetchClients() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // Construct OR filter for dual visibility:
    String orFilter = 'created_by.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    final response = await client.from('clients').select().or(orFilter).order('created_at', ascending: false);
    return (response as List).map((json) => ClientModel.fromJson(json)).toList();
  }

  static Future<ClientModel> createClient(Map<String, dynamic> clientData) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    
    final profile = await fetchProfile();
    final String targetFirmId = profile.firmId ?? user.id;

    final response = await client.from('clients').insert({ 
      ...clientData, 
      'created_by': user.id,
      'firm_id': targetFirmId
    }).select().single();
    return ClientModel.fromJson(response);
  }

  static Future<void> updateClient(String id, Map<String, dynamic> updates) async {
    await client.from('clients').update(updates).eq('id', id);
  }

  static Future<void> deleteClient(String id) async {
    await client.from('clients').delete().eq('id', id);
  }

  // ─── Cases ──────────────────────────────────────────

  static Future<List<CaseModel>> fetchCases() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // 1. Construct OR filter for cases owned by user or their firm
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // 2. Fetch IDs of cases where user is an accepted collaborator
    final collabRes = await client
        .from('case_collaborations')
        .select('case_id')
        .or('collaborator_email.eq.${user.email},collaborator_id.eq.${user.id}')
        .eq('status', 'accepted');
    
    final List<String> collaborationCaseIds = (collabRes as List).map((c) => c['case_id'] as String).toList();

    // 3. Combine both filters
    var query = client.from('cases').select('*, clients(name)');
    
    if (collaborationCaseIds.isEmpty) {
        query = query.or(orFilter);
    } else {
        // We use a complex OR that includes both the original filter AND the shared IDs
        final List<String> inClause = collaborationCaseIds.map((id) => 'id.eq.$id').toList();
        final String fullFilter = '$orFilter,${inClause.join(',')}';
        query = query.or(fullFilter);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List).map((json) => CaseModel.fromJson(json)).toList();
  }

  static Future<CaseModel> fetchCaseById(String id) async {
    final response = await client.from('cases').select('*, clients(name, phone, email)').eq('id', id).single();
    return CaseModel.fromJson(response);
  }

  static Future<CaseModel> createCase(Map<String, dynamic> caseData) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    
    final profile = await fetchProfile();
    
    // Creation Logic:
    // A user with a firmId joined a firm -> Create in JOINED firm
    // Else -> Solo or Own firm
    final String targetFirmId = profile.firmId ?? user.id;

    
    final response = await client.from('cases').insert({ 
      ...caseData, 
      'created_by': user.id,
      'firm_id': targetFirmId
    }).select().single();
    return CaseModel.fromJson(response);
  }

  static Future<void> updateCase(String id, Map<String, dynamic> updates) async {
    await client.from('cases').update(updates).eq('id', id);
  }

  static Future<void> deleteCase(String id) async {
    // Delete related records first
    await client.from('ecourt_sync_records').delete().eq('case_id', id);
    await client.from('ecourt_hearing_history').delete().eq('case_id', id);
    await client.from('hearings').delete().eq('case_id', id);
    await client.from('payments').delete().eq('case_id', id);
    await client.from('efiling_records').delete().eq('case_id', id);
    await client.from('certified_copies').delete().eq('case_id', id);
    await client.from('evidence_checklists').delete().eq('case_id', id);
    await client.from('witness_examination_notes').delete().eq('case_id', id);
    await client.from('evidence_photos').delete().eq('case_id', id);
    await client.from('cases').delete().eq('id', id);
  }


  static Future<void> updateCaseCnr(String id, String cnr) async {
    await client.from('cases').update({
      'cnr_number': cnr,
    }).eq('id', id);
  }

  // ─── Hearings ───────────────────────────────────────

  static Future<List<Hearing>> fetchHearings({String? caseId}) async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // Construct OR filter
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // Fetch visible case IDs first to filter other entities
    final totalCasesRes = await client.from('cases').select('id').or(orFilter);
    final List<String> visibleCaseIds = (totalCasesRes as List).map((c) => c['id'] as String).toList();
    
    if (visibleCaseIds.isEmpty) return [];

    var query = client.from('hearings').select('*, cases(case_title, court_name, case_number, cnr_number, firm_id)');
    
    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    final response = await query.order('hearing_date');
    return (response as List).map((json) => Hearing.fromJson(json)).toList();
  }

  static Future<Hearing> createHearing(Map<String, dynamic> hearingData) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    final response = await client.from('hearings').insert({ ...hearingData, 'created_by': user.id }).select('*, cases(case_title, court_name, case_number, cnr_number, firm_id)').single();
    return Hearing.fromJson(response);
  }

  static Future<Hearing?> adjournHearing(String id, Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final String nextStage = data['next_stage'] ?? 'Next Hearing';
    final bool isFinal = nextStage == 'Case Disposed' || nextStage == 'Case Dismissed';

    // 1. Delete the OLD hearing record (the one that just happened)
    await client.from('hearings').delete().eq('id', id);

    Hearing? newHearing;

    if (!isFinal) {
      // 2. Insert the NEW future hearing only if NOT disposed/dismissed
      final response = await client.from('hearings').insert({
        'case_id': data['case_id'],
        'hearing_date': data['next_date'],
        'stage': nextStage,
        'created_by': user.id
      }).select('*, cases(case_title, court_name, case_number, cnr_number, firm_id)').single();
      newHearing = Hearing.fromJson(response);
    }

    // 3. Update the CASE status and details
    final Map<String, dynamic> caseUpdates = {
      'stage': nextStage,
    };

    if (isFinal) {
      caseUpdates['status'] = nextStage == 'Case Disposed' ? 'disposed' : 'dismissed';
      caseUpdates['next_hearing_date'] = null;
    } else {
      caseUpdates['next_hearing_date'] = data['next_date'];
    }

    await client.from('cases').update(caseUpdates).eq('id', data['case_id']);
    
    return newHearing;
  }

  static Future<void> deleteHearing(String id) async {
    await client.from('hearings').delete().eq('id', id);
  }

  // ─── E-Filing ───────────────────────────────────────

  static Future<List<EFilingRecord>> fetchEfilingRecords({String? caseId}) async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // Construct OR filter
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // Fetch visible case IDs
    final totalCasesRes = await client.from('cases').select('id').or(orFilter);
    final List<String> visibleCaseIds = (totalCasesRes as List).map((c) => c['id'] as String).toList();
    
    if (visibleCaseIds.isEmpty) return [];

    var query = client.from('efiling_records').select('*, cases(case_title, case_number, cnr_number, firm_id)');
    
    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    final response = await query.order('updated_at', ascending: false);
    return (response as List).map((json) => EFilingRecord.fromJson(json)).toList();
  }

  static Future<void> createEfilingRecord(Map<String, dynamic> record) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('efiling_records').insert({ ...record, 'created_by': user.id });
  }

  // ─── Payments ───────────────────────────────────────

  static Future<List<Payment>> fetchPayments({String? caseId}) async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // Construct OR filter
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // Fetch visible case IDs
    final totalCasesRes = await client.from('cases').select('id').or(orFilter);
    final List<String> visibleCaseIds = (totalCasesRes as List).map((c) => c['id'] as String).toList();
    
    if (visibleCaseIds.isEmpty) return [];

    var query = client.from('payments').select('*, cases(case_title, case_number, cnr_number, firm_id)');
    
    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    final response = await query.order('paid_date', ascending: false);
    return (response as List).map((json) => Payment.fromJson(json)).toList();
  }

  static Future<void> createPayment(Map<String, dynamic> payment) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('payments').insert({ 
      ...payment, 
      'created_by': user.id,
      'transaction_type': payment['transaction_type'] ?? 'revenue'
    });
  }

  static Future<void> deletePayment(String id) async {
    await client.from('payments').delete().eq('id', id);
  }

  // ─── Tasks ──────────────────────────────────────────

  static Future<List<TaskModel>> fetchTasks() async {
    final user = client.auth.currentUser;
    if (user == null) return [];
    final response = await client
        .from('tasks')
        .select()
        .eq('created_by', user.id)
        .order('created_at');
    return (response as List).map((json) => TaskModel.fromJson(json)).toList();
  }

  static Stream<List<TaskModel>> tasksStream() {
    return client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) => data.map((json) => TaskModel.fromJson(json)).toList());
  }

  static Future<void> createTask(String title) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('tasks').insert({'title': title, 'created_by': user.id});
  }

  static Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    await client.from('tasks').update(updates).eq('id', id);
  }

  static Future<void> deleteTask(String id) async {
    await client.from('tasks').delete().eq('id', id);
  }

  /// Fetches the total payment summary for a specific case with ledger logic
  static Future<Map<String, double>> fetchCasePaymentSummary(String caseId) async {
    final response = await client
        .from('payments')
        .select('total_fee, paid_amount, transaction_type')
        .eq('case_id', caseId);

    final payments = response as List;
    if (payments.isEmpty) return {'total_fee': 0, 'total_paid': 0, 'total_expenses': 0, 'balance': 0};

    // Base fee is from any record (usually the first/primary one)
    final double baseFee = (payments.first['total_fee'] ?? 0).toDouble();
    
    double totalPaid = 0;
    double totalExpenses = 0;

    for (var p in payments) {
      final type = p['transaction_type'] ?? 'revenue';
      final amount = (p['paid_amount'] ?? 0).toDouble();
      
      if (type == 'revenue') {
        totalPaid += amount;
      } else if (type == 'expense') {
        totalExpenses += amount;
      }
    }
    
    return {
      'total_fee': baseFee,
      'total_paid': totalPaid,
      'total_expenses': totalExpenses,
      'balance': (baseFee + totalExpenses) - totalPaid,
    };
  }

  /// Adds a new ledger entry (Payment or Expense)
  static Future<void> addPaymentInstallment(Map<String, dynamic> payment) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('payments').insert({ 
      ...payment, 
      'created_by': user.id,
      'transaction_type': payment['transaction_type'] ?? 'revenue'
    });
  }

  // ─── Certified Copies ────────────────────────────────

  static Future<List<CertifiedCopy>> fetchCertifiedCopies() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    final profile = await fetchProfile();
    
    // Construct OR filter
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // Fetch visible case IDs
    final totalCasesRes = await client.from('cases').select('id').or(orFilter);
    final List<String> visibleCaseIds = (totalCasesRes as List).map((c) => c['id'] as String).toList();
    
    if (visibleCaseIds.isEmpty) return [];

    final response = await client.from('certified_copies')
        .select('*, cases(case_title, case_number, cnr_number, firm_id)')
        .inFilter('case_id', visibleCaseIds)
        .order('created_at', ascending: false);
        
    return (response as List).map((json) => CertifiedCopy.fromJson(json)).toList();
  }

  static Future<void> createCertifiedCopy(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('certified_copies').insert({ ...data, 'created_by': user.id });
  }

  static Future<void> updateCertifiedCopy(String id, Map<String, dynamic> updates) async {
    await client.from('certified_copies').update(updates).eq('id', id);
  }

  static Future<void> deleteCertifiedCopy(String id) async {
    await client.from('certified_copies').delete().eq('id', id);
  }

  // ─── Documents (Supabase Storage) ──────────────────

  static Future<List<Map<String, dynamic>>> fetchDocuments(String caseId) async {
    try {
      final files = await client.storage.from('case-documents').list(path: caseId);
      return files.map((f) => {
        'name': f.name,
        'size': f.metadata?['size'] ?? 0,
        'created_at': f.createdAt ?? '',
        'url': client.storage.from('case-documents').getPublicUrl('$caseId/${f.name}'),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> uploadDocument(String caseId, Uint8List file, String fileName) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.storage.from('case-documents').uploadBinary(
      '$caseId/$fileName',
      file,
      fileOptions: const FileOptions(upsert: true),
    );
  }

  static Future<void> deleteDocument(String caseId, String fileName) async {
    await client.storage.from('case-documents').remove(['$caseId/$fileName']);
  }

  // ─── Bare Acts ──────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchBareActs() async {
    final response = await client.from('bare_acts').select().eq('is_active', true).order('title');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<dynamic>> fetchSections(String actId) async {
    final response = await client
        .from('bare_act_sections')
        .select('*')
        .eq('act_id', actId)
        .order('sequence_order', ascending: true);
    return response as List<dynamic>;
  }

  static Future<List<dynamic>> searchBareActs(String query, {String? actId}) async {
    // 1. Better normalization: Handle Art15, Art.15, Article 15, Sec 15, etc.
    // This regex strips prefixes with or without spaces.
    String cleanQuery = query.replaceAll(RegExp(r'^(art|article|sec|section|§|art\.|sec\.)\s*', caseSensitive: false), '').trim();
    
    // If it didn't match the space-based prefix, try stripping without space (e.g., Art15)
    if (cleanQuery == query.trim()) {
      cleanQuery = query.replaceAll(RegExp(r'^(art|article|sec|section|§|art\.|sec\.)', caseSensitive: false), '').trim();
    }

    var queryBuilder = client
        .from('bare_act_sections')
        .select('*, bare_acts(id, title, short_title)');

    // 2. Build smart OR logic
    // We prioritize: exact section match, then keyword in title, then keyword in text.
    // For section_number, we use .eq if cleanQuery is purely numeric to avoid broad ILIKE matching.
    bool isNumeric = RegExp(r'^\d*[a-zA-Z]?$').hasMatch(cleanQuery);
    
    String orFilter;
    if (isNumeric && cleanQuery.isNotEmpty) {
      // Prioritize exact match on section_number, but also allow title/text search
      orFilter = 'section_number.ilike.$cleanQuery,section_number.ilike.$cleanQuery%,section_title.ilike.%$query%,section_text.ilike.%$query%';
    } else {
      orFilter = 'section_title.ilike.%$query%,section_text.ilike.%$query%,section_number.ilike.%$query%';
    }

    queryBuilder = queryBuilder.or(orFilter);

    if (actId != null) {
      queryBuilder = queryBuilder.eq('act_id', actId);
    }

    // 3. Increase limit slightly to ensure we don't miss later-added acts (like Constitution)
    final response = await queryBuilder.limit(50);
    return response as List<dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchStampValues({String stateId = 'TN'}) async {
    final response = await client
        .from('stamp_values')
        .select()
        .eq('state_id', stateId)
        .order('category', ascending: true)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }


  static Future<List<LegalTemplate>> fetchLegalTemplates() async {
    final response = await client
        .from('legal_templates')
        .select('*')
        .order('category', ascending: true)
        .order('title', ascending: true);
    return (response as List).map((json) => LegalTemplate.fromJson(json)).toList();
  }

  static Future<List<LegalTemplate>> searchLegalTemplates(String query) async {
    final response = await client
        .from('legal_templates')
        .select('*')
        .or('title.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%')
        .limit(20);
    return (response as List).map((json) => LegalTemplate.fromJson(json)).toList();
  }

  // ─── Dashboard Stats ────────────────────────────────

  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final user = client.auth.currentUser;
    if (user == null) return {};

    final profile = await fetchProfile();
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Construct the same visibility filter as fetchCases
    String orFilter = 'assigned_to.eq.${user.id}';
    if (profile.firmId != null) {
      orFilter += ',firm_id.eq.${profile.firmId}';
    }
    if (profile.isFirmOwner) {
      orFilter += ',firm_id.eq.${user.id}';
    }

    // Fetch visible case IDs first to filter other entities
    final totalCasesRes = await client.from('cases').select('id, status').or(orFilter);
    final List casesList = totalCasesRes as List;
    final List<String> visibleCaseIds = casesList.map((c) => c['id'] as String).toList();
    
    if (visibleCaseIds.isEmpty) {
      return {
        'activeCasesCount': 0,
        'totalCasesCount': 0,
        'upcomingHearingsCount': 0,
        'clientsCount': 0,
        'filingsCount': 0,
        'todayHearings': [],
      };
    }

    final int activeCount = casesList.where((c) => c['status'] == 'active').length;

    // Filtered counts
    final upcomingHearingsRes = await client.from('hearings')
        .select('id')
        .gte('hearing_date', today)
        .inFilter('case_id', visibleCaseIds);
        
    final filingsRes = await client.from('efiling_records')
        .select('id')
        .inFilter('case_id', visibleCaseIds);

    // Clients: Simplified for now
    final clientsRes = await client.from('clients').select('id');

    final todayHearingsRes = await client.from('hearings')
        .select('*, cases(case_title, case_number, firm_id)')
        .eq('hearing_date', today)
        .inFilter('case_id', visibleCaseIds)
        .order('created_at', ascending: false)
        .limit(5);

    return {
      'activeCasesCount': activeCount,
      'totalCasesCount': casesList.length,
      'upcomingHearingsCount': (upcomingHearingsRes as List).length,
      'clientsCount': (clientsRes as List).length,
      'filingsCount': (filingsRes as List).length,
      'todayHearings': (todayHearingsRes as List).map((json) => Hearing.fromJson(json)).toList(),
    };
  }

  // ─── Evidence Lab ──────────────────────────────────

  static Future<List<EvidenceChecklist>> fetchEvidenceChecklist(String caseId) async {
    final response = await client.from('evidence_checklists').select().eq('case_id', caseId).order('created_at');
    return (response as List).map((json) => EvidenceChecklist.fromJson(json)).toList();
  }

  static Future<void> createEvidenceChecklistItem(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('evidence_checklists').insert({ ...data, 'created_by': user.id });
  }

  static Future<void> updateEvidenceChecklistItem(String id, Map<String, dynamic> updates) async {
    await client.from('evidence_checklists').update(updates).eq('id', id);
  }

  static Future<void> deleteEvidenceChecklistItem(String id) async {
    await client.from('evidence_checklists').delete().eq('id', id);
  }

  static Future<List<WitnessNote>> fetchWitnessNotes(String caseId) async {
    final response = await client.from('witness_examination_notes').select().eq('case_id', caseId).order('created_at');
    return (response as List).map((json) => WitnessNote.fromJson(json)).toList();
  }

  static Future<void> createWitnessNote(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('witness_examination_notes').insert({ ...data, 'created_by': user.id });
  }

  static Future<void> updateWitnessNote(String id, Map<String, dynamic> updates) async {
    await client.from('witness_examination_notes').update(updates).eq('id', id);
  }

  static Future<void> deleteWitnessNote(String id) async {
    await client.from('witness_examination_notes').delete().eq('id', id);
  }

  static Future<List<EvidencePhoto>> fetchEvidencePhotos(String caseId) async {
    final response = await client.from('evidence_photos').select().eq('case_id', caseId).order('created_at', ascending: false);
    return (response as List).map((json) => EvidencePhoto.fromJson(json)).toList();
  }

  static Future<void> createEvidencePhoto(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('evidence_photos').insert({ ...data, 'created_by': user.id });
  }

  static Future<void> deleteEvidencePhoto(String id) async {
    await client.from('evidence_photos').delete().eq('id', id);
  }

  // ─── Case Discussion & Notices ──────────────────────

  static Future<List<CaseComment>> fetchDiscussions({String? caseId, String? firmId}) async {
    var query = client.from('case_discussions').select('*');
    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else if (firmId != null) {
      query = query.isFilter('case_id', null).eq('firm_id', firmId);
    }
    final response = await query.order('created_at', ascending: true);
    return (response as List).map((json) => CaseComment.fromJson(json)).toList();
  }

  static Stream<List<CaseComment>> discussionsStream({String? caseId, String? firmId}) async* {
    while (true) {
      try {
        final list = await fetchDiscussions(caseId: caseId, firmId: firmId);
        yield list;
      } catch (e) {
        debugPrint("Fetch Discussions Polling Error: $e");
        // Ignore network errors in stream and wait for next tick
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  static Future<void> postDiscussion(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('case_discussions').insert({
      ...data,
      'sender_id': user.id,
    });
  }

  static Future<void> deleteDiscussion(String id) async {
    await client.from('case_discussions').delete().eq('id', id);
  }

  // ─── Post-Integration & Portals ────────────────────────

  static Future<String?> getDistrictPortalUrl(String state, String district, String type) async {
    try {
      // 1. Check custom mapping in database
      final response = await client
          .from('district_portals')
          .select('url')
          .eq('state', state)
          .eq('district', district)
          .eq('portal_type', type)
          .maybeSingle();

      if (response != null && response['url'] != null) {
        return response['url'] as String;
      }

      // 2. Smart Fallback Rule for Tamil Nadu
      if (state == "Tamil Nadu") {
        final cleanDistrict = district.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        
        if (type == 'certified_copy') {
          return 'https://$cleanDistrict.dcourts.gov.in/copyist-section/';
        } else if (type == 'video_conference') {
          return 'https://$cleanDistrict.dcourts.gov.in/hybrid-vc-microsoft-teams-video-conference-link-for-courts-in-$cleanDistrict-district/';
        } else if (type == 'holiday_list') {
          return 'https://$cleanDistrict.dcourts.gov.in/holiday-list/';
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Global Search ──────────────────────────────────

  static Future<Map<String, List<dynamic>>> searchAll(String query) async {
    final cases = await client.from('cases').select('id, case_title, case_number').or('case_title.ilike.%$query%,case_number.ilike.%$query%').limit(5);
    final clients = await client.from('clients').select('id, name').ilike('name', '%$query%').limit(5);
    
    return {
      'cases': cases as List,
      'clients': clients as List,
    };
  }

  // ─── Workspace Reset ───────────────────────────────
  
  /// Wipes all user-owned data records while preserving the account itself.
  static Future<void> resetUserWorkspace() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final userId = user.id;

    // Ordered deletion to minimize foreign key conflicts
    // 1. Child entities (dependent on cases)
    await client.from('hearings').delete().eq('created_by', userId);
    await client.from('payments').delete().eq('created_by', userId);
    await client.from('efiling_records').delete().eq('created_by', userId);
    await client.from('certified_copies').delete().eq('created_by', userId);
    await client.from('evidence_checklists').delete().eq('created_by', userId);
    await client.from('witness_examination_notes').delete().eq('created_by', userId);
    await client.from('evidence_photos').delete().eq('created_by', userId);
    await client.from('case_discussions').delete().eq('sender_id', userId);

    // 2. Main entities
    await client.from('tasks').delete().eq('created_by', userId);
    await client.from('cases').delete().eq('created_by', userId);
    await client.from('clients').delete().eq('created_by', userId);
    
    // Note: UserProfile is NOT deleted as it's required for app session.
  }

  // ─── Case Acts (eCourt Dossier) ────────────────────
  
  static Future<List<CaseAct>> fetchCaseActs(String caseId) async {
    final response = await client
        .from('case_acts')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: true);
    return (response as List).map((json) => CaseAct.fromJson(json)).toList();
  }

  static Future<void> createCaseAct(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('case_acts').insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertCaseAct(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('case_acts').upsert(
      {...data, 'created_by': user.id},
      onConflict: 'case_id,act_name,section_number',
    );
  }

  static Future<void> deleteCaseAct(String id) async {
    await client.from('case_acts').delete().eq('id', id);
  }

  // ─── Case IA Applications (eCourt Dossier) ─────────

  static Future<List<CaseIAApplication>> fetchCaseIAs(String caseId) async {
    final response = await client
        .from('case_ia_applications')
        .select()
        .eq('case_id', caseId)
        .order('filing_date', ascending: true);
    return (response as List).map((json) => CaseIAApplication.fromJson(json)).toList();
  }

  static Future<void> createCaseIA(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('case_ia_applications').insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertCaseIA(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    
    // Normalize dates
    if (data['filing_date'] != null) data['filing_date'] = _normalizeDateStr(data['filing_date'].toString());
    if (data['next_date'] != null) data['next_date'] = _normalizeDateStr(data['next_date'].toString());

    await client.from('case_ia_applications').upsert(
      {...data, 'created_by': user.id},
      onConflict: 'case_id,ia_number',
    );
  }

  static Future<void> updateCaseIA(String id, Map<String, dynamic> updates) async {
    await client.from('case_ia_applications').update(updates).eq('id', id);
  }

  static Future<void> deleteCaseIA(String id) async {
    await client.from('case_ia_applications').delete().eq('id', id);
  }

  // ─── Case Interim Orders (eCourt Dossier) ──────────

  static Future<List<CaseInterimOrder>> fetchInterimOrders(String caseId) async {
    final response = await client
        .from('case_interim_orders')
        .select()
        .eq('case_id', caseId)
        .order('order_date', ascending: true);
    return (response as List).map((json) => CaseInterimOrder.fromJson(json)).toList();
  }

  static Future<void> createInterimOrder(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    await client.from('case_interim_orders').insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertInterimOrder(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");
    
    // Normalize date
    if (data['order_date'] != null) data['order_date'] = _normalizeDateStr(data['order_date'].toString());

    await client.from('case_interim_orders').upsert(
      {...data, 'created_by': user.id},
      onConflict: 'case_id,order_date,order_summary',
    );
  }

  static Future<void> deleteInterimOrder(String id) async {
    await client.from('case_interim_orders').delete().eq('id', id);
  }

  // ─── eCourt Sync ───────────────────────────────────


  /// Normalize date strings: DD-MM-YYYY or DD/MM/YYYY → YYYY-MM-DD
  static String? _normalizeDateStr(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final s = dateStr.trim();

    // Already YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    // DD-MM-YYYY or DD/MM/YYYY
    final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$').firstMatch(s);
    if (match != null) {
      return '${match.group(3)}-${match.group(2)}-${match.group(1)}';
    }

    return null;
  }
}
