

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/commission_models.dart';

class CommissionService {
  static final _client = Supabase.instance.client;

  // ─── GPS Helper (Phase 2 — Real GPS) ──────────────────────

  /// Get current device GPS position with permission handling
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      debugPrint('GPS Error: $e');
      return null;
    }
  }

  // ─── Commissions CRUD ──────────────────────────────────────

  static Future<List<Commission>> fetchCommissions() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('commissions')
        .select('*, cases(case_title)')
        .or('created_by.eq.${user.id},commissioner_id.eq.${user.id}')
        .order('created_at', ascending: false);

    return (response as List).map((json) => Commission.fromJson(json)).toList();
  }

  static Future<Commission> fetchCommissionById(String id) async {
    final response = await _client
        .from('commissions')
        .select('*, cases(case_title)')
        .eq('id', id)
        .single();
    return Commission.fromJson(response);
  }

  static Future<Commission> createCommission(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final response = await _client.from('commissions').insert({
      ...data,
      'created_by': user.id,
      'commissioner_id': user.id,
    }).select('*, cases(case_title)').single();
    return Commission.fromJson(response);
  }

  static Future<void> updateCommission(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('commissions').update(updates).eq('id', id);
  }

  static Future<void> deleteCommission(String id) async {
    await _client.from('commissions').delete().eq('id', id);
  }

  // ─── Visits CRUD ───────────────────────────────────────────

  static Future<List<CommissionVisit>> fetchVisits(String commissionId) async {
    final response = await _client
        .from('commission_visits')
        .select()
        .eq('commission_id', commissionId)
        .order('visit_date', ascending: false);
    return (response as List).map((json) => CommissionVisit.fromJson(json)).toList();
  }

  static Future<CommissionVisit> createVisit(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final response = await _client.from('commission_visits').insert({
      ...data,
      'created_by': user.id,
    }).select().single();
    return CommissionVisit.fromJson(response);
  }

  /// GPS Check-in: Records REAL GPS coordinates and time (Phase 2)
  static Future<CommissionVisit> checkIn(String commissionId, {String? address}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    // Get real GPS coordinates
    final position = await getCurrentLocation();
    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;

    final now = DateTime.now().toIso8601String();
    final response = await _client.from('commission_visits').insert({
      'commission_id': commissionId,
      'visit_date': DateTime.now().toIso8601String().split('T')[0],
      'checkin_time': now,
      'checkin_lat': lat,
      'checkin_lng': lng,
      'checkin_address': address ?? (position != null ? 'GPS: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' : 'Location unavailable'),
      'visit_status': 'checked_in',
      'created_by': user.id,
    }).select().single();

    // Update commission status to in_progress
    await updateCommission(commissionId, {'status': 'in_progress'});

    return CommissionVisit.fromJson(response);
  }

  /// GPS Check-out: Records REAL checkout GPS coordinates and time (Phase 2)
  static Future<void> checkOut(String visitId, {String? address}) async {
    final position = await getCurrentLocation();
    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;

    await _client.from('commission_visits').update({
      'checkout_time': DateTime.now().toIso8601String(),
      'checkout_lat': lat,
      'checkout_lng': lng,
      'checkout_address': address ?? (position != null ? 'GPS: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' : 'Location unavailable'),
      'visit_status': 'completed',
    }).eq('id', visitId);
  }

  static Future<void> reportObstruction(String visitId, String details) async {
    await _client.from('commission_visits').update({
      'visit_status': 'obstructed',
      'obstruction_details': details,
      'checkout_time': DateTime.now().toIso8601String(),
    }).eq('id', visitId);
  }

  static Future<void> updateVisit(String id, Map<String, dynamic> updates) async {
    await _client.from('commission_visits').update(updates).eq('id', id);
  }

  // ─── Observations CRUD ─────────────────────────────────────

  static Future<List<CommissionObservation>> fetchObservations(String commissionId) async {
    final response = await _client
        .from('commission_observations')
        .select()
        .eq('commission_id', commissionId)
        .order('sequence_order', ascending: true);
    return (response as List).map((json) => CommissionObservation.fromJson(json)).toList();
  }

  static Future<List<CommissionObservation>> fetchVisitObservations(String visitId) async {
    final response = await _client
        .from('commission_observations')
        .select()
        .eq('visit_id', visitId)
        .order('created_at', ascending: true);
    return (response as List).map((json) => CommissionObservation.fromJson(json)).toList();
  }

  static Future<void> createObservation(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    await _client.from('commission_observations').insert({
      ...data,
      'created_by': user.id,
    });
  }

  static Future<void> updateObservation(String id, Map<String, dynamic> updates) async {
    await _client.from('commission_observations').update(updates).eq('id', id);
  }

  static Future<void> deleteObservation(String id) async {
    await _client.from('commission_observations').delete().eq('id', id);
  }

  // ─── Evidence CRUD ─────────────────────────────────────────

  static Future<List<CommissionEvidence>> fetchEvidence(String commissionId) async {
    final response = await _client
        .from('commission_evidence')
        .select()
        .eq('commission_id', commissionId)
        .order('sequence_number', ascending: true);
    return (response as List).map((json) => CommissionEvidence.fromJson(json)).toList();
  }

  /// Upload photo evidence with GPS metadata and SHA-256 hash
  static Future<CommissionEvidence> uploadEvidence({
    required String commissionId,
    required String visitId,
    required Uint8List fileBytes,
    required String fileName,
    String? caption,
    String? direction,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    // Get real GPS
    final position = await getCurrentLocation();

    // Generate SHA-256 hash for tamper detection
    final hash = sha256.convert(fileBytes).toString();
    
    // Upload to Supabase Storage
    final storagePath = '$commissionId/$visitId/$fileName';
    await _client.storage.from('commission-evidence').uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final fileUrl = _client.storage.from('commission-evidence').getPublicUrl(storagePath);

    // Get current evidence count for sequence numbering
    final existing = await fetchEvidence(commissionId);

    // Save metadata to database
    final response = await _client.from('commission_evidence').insert({
      'commission_id': commissionId,
      'visit_id': visitId,
      'file_type': 'photo',
      'file_url': fileUrl,
      'caption': caption,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'direction': direction,
      'sha256_hash': hash,
      'sequence_number': existing.length + 1,
      'created_by': user.id,
    }).select().single();

    return CommissionEvidence.fromJson(response);
  }

  static Future<void> updateEvidenceCaption(String id, String caption) async {
    await _client.from('commission_evidence').update({'caption': caption}).eq('id', id);
  }

  static Future<void> deleteEvidence(String id) async {
    await _client.from('commission_evidence').delete().eq('id', id);
  }

  // ─── Expenses CRUD ─────────────────────────────────────────

  static Future<List<CommissionExpense>> fetchExpenses(String commissionId) async {
    final response = await _client
        .from('commission_expenses')
        .select()
        .eq('commission_id', commissionId)
        .order('expense_date', ascending: false);
    return (response as List).map((json) => CommissionExpense.fromJson(json)).toList();
  }

  static Future<void> createExpense(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    await _client.from('commission_expenses').insert({
      ...data,
      'created_by': user.id,
    });
  }

  static Future<void> deleteExpense(String id) async {
    await _client.from('commission_expenses').delete().eq('id', id);
  }

  static Future<Map<String, double>> fetchExpenseSummary(String commissionId) async {
    final expenses = await fetchExpenses(commissionId);
    double total = 0;
    final Map<String, double> byType = {};
    for (final e in expenses) {
      total += e.amount;
      final type = e.expenseType.label;
      byType[type] = (byType[type] ?? 0) + e.amount;
    }
    return {'total': total, ...byType};
  }

  // ─── Reports CRUD ──────────────────────────────────────────

  static Future<List<CommissionReport>> fetchReports(String commissionId) async {
    final response = await _client
        .from('commission_reports')
        .select()
        .eq('commission_id', commissionId)
        .order('version', ascending: false);
    return (response as List).map((json) => CommissionReport.fromJson(json)).toList();
  }

  static Future<CommissionReport> createReport(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final response = await _client.from('commission_reports').insert({
      ...data,
      'created_by': user.id,
    }).select().single();
    return CommissionReport.fromJson(response);
  }

  static Future<void> updateReport(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('commission_reports').update(updates).eq('id', id);
  }

  // ─── Witnesses CRUD (Phase 2) ─────────────────────────────

  static Future<List<CommissionWitness>> fetchWitnesses(String commissionId) async {
    final response = await _client
        .from('commission_witnesses')
        .select()
        .eq('commission_id', commissionId)
        .order('created_at', ascending: true);
    return (response as List).map((json) => CommissionWitness.fromJson(json)).toList();
  }

  static Future<CommissionWitness> createWitness(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    // Attach GPS coordinates
    final position = await getCurrentLocation();

    final response = await _client.from('commission_witnesses').insert({
      ...data,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'created_by': user.id,
    }).select().single();
    return CommissionWitness.fromJson(response);
  }

  static Future<void> updateWitness(String id, Map<String, dynamic> updates) async {
    await _client.from('commission_witnesses').update(updates).eq('id', id);
  }

  static Future<void> deleteWitness(String id) async {
    await _client.from('commission_witnesses').delete().eq('id', id);
  }

  /// Upload witness photo/audio/signature to storage
  static Future<String> uploadWitnessFile({
    required String commissionId,
    required String witnessId,
    required Uint8List fileBytes,
    required String fileName,
    required String folder, // 'photos', 'audio', 'signatures'
  }) async {
    final storagePath = '$commissionId/$witnessId/$folder/$fileName';
    await _client.storage.from('commission-witnesses').uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return _client.storage.from('commission-witnesses').getPublicUrl(storagePath);
  }

  /// Download file from storage for PDF embedding (NEW)
  static Future<Uint8List?> downloadFile(String bucket, String path) async {
    try {
      final sanitizedPath = path.contains('public/') ? path.split('public/').last : path;
      // If path is a full URL, extract the relative path
      String relativePath = sanitizedPath;
      if (sanitizedPath.startsWith('http')) {
         final uri = Uri.parse(sanitizedPath);
         final segments = uri.pathSegments;
         // Usually: storage/v1/object/public/bucket/path...
         final publicIdx = segments.indexOf('public');
         if (publicIdx != -1 && segments.length > publicIdx + 2) {
           relativePath = segments.sublist(publicIdx + 2).join('/');
         }
      }

      return await _client.storage.from(bucket).download(relativePath);
    } catch (e) {
      debugPrint('Download error ($bucket/$path): $e');
      return null;
    }
  }

  // ─── Sketches CRUD (Phase 2) ──────────────────────────────

  static Future<List<CommissionSketch>> fetchSketches(String commissionId) async {
    final response = await _client
        .from('commission_sketches')
        .select()
        .eq('commission_id', commissionId)
        .order('created_at', ascending: false);
    return (response as List).map((json) => CommissionSketch.fromJson(json)).toList();
  }

  static Future<CommissionSketch> createSketch(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final response = await _client.from('commission_sketches').insert({
      ...data,
      'created_by': user.id,
    }).select().single();
    return CommissionSketch.fromJson(response);
  }

  static Future<void> updateSketch(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('commission_sketches').update(updates).eq('id', id);
  }

  static Future<void> deleteSketch(String id) async {
    await _client.from('commission_sketches').delete().eq('id', id);
  }

  /// Upload sketch PNG export to storage
  static Future<String> uploadSketchImage({
    required String commissionId,
    required String sketchId,
    required Uint8List imageBytes,
  }) async {
    final storagePath = '$commissionId/$sketchId/sketch_${DateTime.now().millisecondsSinceEpoch}.png';
    await _client.storage.from('commission-sketches').uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
    );
    return _client.storage.from('commission-sketches').getPublicUrl(storagePath);
  }

  // ─── Dashboard Stats ───────────────────────────────────────

  static Future<Map<String, int>> fetchCommissionStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    final all = await fetchCommissions();
    
    return {
      'total': all.length,
      'pending': all.where((c) => c.status == CommissionStatus.pending).length,
      'inProgress': all.where((c) => c.status == CommissionStatus.inProgress).length,
      'completed': all.where((c) => c.status == CommissionStatus.submitted || c.status == CommissionStatus.closed).length,
      'overdue': all.where((c) => c.isOverdue).length,
    };
  }
}
