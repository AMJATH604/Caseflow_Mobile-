import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/caveat_models.dart';

class CaveatService {
  static final _supabase = Supabase.instance.client;

  /// Fetches all caveats for the authenticated user, ordered by closest expiry date.
  static Future<List<Caveat>> fetchCaveats() async {
    final response = await _supabase
        .from('caveats')
        .select('*')
        .order('expiry_date', ascending: true);
        
    return (response as List).map((json) => Caveat.fromJson(json)).toList();
  }

  /// Creates a new caveat. 
  /// The [expiryDate] will automatically be set exactly 90 days from the filing date.
  static Future<Caveat> createCaveat({
    required String courtName,
    String? caseType,
    required String caveatorName,
    required String opponentName,
    String? subjectMatter,
    String? caveatNumber,
    required DateTime filingDate,
    String? notes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Caveats expire after exactly 90 days from filing
    final expiryDate = filingDate.add(const Duration(days: 90));

    final caveat = Caveat(
      id: '', // Supabase will generate UUID
      userId: userId,
      courtName: courtName,
      caseType: caseType,
      caveatorName: caveatorName,
      opponentName: opponentName,
      subjectMatter: subjectMatter,
      caveatNumber: caveatNumber,
      filingDate: filingDate,
      expiryDate: expiryDate,
      status: 'active',
      notes: notes,
    );

    final payload = caveat.toJson();
    payload.remove('id'); // Ensure ID is not sent for insert

    final response = await _supabase
        .from('caveats')
        .insert(payload)
        .select()
        .single();

    return Caveat.fromJson(response);
  }

  /// Updates an existing caveat
  static Future<void> updateCaveat(String id, Map<String, dynamic> updates) async {
    // If filing date is being updated, we must recalculate expiry
    if (updates.containsKey('filing_date')) {
      final newFilingDate = DateTime.parse(updates['filing_date'] as String);
      final newExpiryDate = newFilingDate.add(const Duration(days: 90));
      updates['expiry_date'] = newExpiryDate.toIso8601String().split('T')[0];
    }

    await _supabase
        .from('caveats')
        .update(updates)
        .eq('id', id);
  }

  /// Deletes a caveat
  static Future<void> deleteCaveat(String id) async {
    await _supabase
        .from('caveats')
        .delete()
        .eq('id', id);
  }

  /// Runs a check on active caveats and auto-updates status to 'expired' if days passed.
  /// Could be used locally on app load to sync state if Edge Function isn't handling status updates.
  static Future<void> cleanupExpiredCaveatsLocally() async {
    final now = DateTime.now().toIso8601String().split('T')[0];
    
    await _supabase
        .from('caveats')
        .update({'status': 'expired'})
        .eq('status', 'active')
        .lt('expiry_date', now);
  }
}
