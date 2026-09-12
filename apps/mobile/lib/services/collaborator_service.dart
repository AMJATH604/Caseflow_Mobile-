import 'package:supabase_flutter/supabase_flutter.dart';

class CollaboratorService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Invites a colleague to collaborate on a specific case.
  static Future<void> inviteCollaborator(String caseId, String email) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if the user already exists to pre-link the ID
    final profile =
        await _client
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

    // onConflict must name the unique constraint. Without it PostgREST targets
    // the primary key, so re-inviting someone who previously declined hit
    // UNIQUE (case_id, collaborator_email) and failed with 23505 — once an
    // advocate rejected a case, they could never be invited to it again.
    //
    // Resetting status/responded_at is what re-surfaces the invitation
    // (fetchMyInvitations filters on 'pending') and fires the notification
    // trigger, which listens for any transition into 'pending'.
    await _client.from('case_collaborations').upsert({
      'case_id': caseId,
      'owner_id': user.id,
      'collaborator_email': email,
      'collaborator_id': profile?['id'],
      'status': 'pending',
      'responded_at': null,
    }, onConflict: 'case_id,collaborator_email');
  }

  /// Fetches all case invitations for the current user.
  static Future<List<Map<String, dynamic>>> fetchMyInvitations() async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return [];

    // Fetch collaborations where email match OR ID match
    final response = await _client
        .from('case_collaborations')
        .select(
          '*, cases(case_title, case_number, court_name), profiles:owner_id(full_name)',
        )
        .or('collaborator_email.eq.${user.email},collaborator_id.eq.${user.id}')
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Responds to a case invitation.
  static Future<void> respondToInvitation(
    String invitationId,
    String status,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // `.select()` guards against an RLS-filtered write, which matches zero
    // rows yet still returns success — the failure mode that hid the firm
    // decline bug.
    final responded = await _client
        .from('case_collaborations')
        .update({
          'status': status,
          'collaborator_id': user.id, // Ensure ID is linked on response
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', invitationId)
        .select('id');

    if ((responded as List).isEmpty) {
      throw Exception('Could not respond to this invitation. It may have been withdrawn.');
    }
  }

  /// Fetches collaborators for a specific case (includes who shared it).
  ///
  /// Excludes rejected rows — they are kept so the owner can be notified and
  /// so the advocate can be re-invited, but someone who declined is not a
  /// collaborator and must not appear in the case dossier.
  static Future<List<Map<String, dynamic>>> fetchCaseCollaborators(
    String caseId,
  ) async {
    final response = await _client
        .from('case_collaborations')
        .select(
          '*, profiles:collaborator_id(full_name, email), owner:owner_id(full_name, email)',
        )
        .eq('case_id', caseId)
        .neq('status', 'rejected');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Revokes a case collaboration (removes access).
  static Future<void> deleteCollaboration(String id) async {
    await _client.from('case_collaborations').delete().eq('id', id);
  }
}
