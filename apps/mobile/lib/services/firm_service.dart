import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class FirmService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Fetches all members of a firm.
  /// If [explicitOwnerId] is provided, fetches members for that firm (used by associates).
  /// Otherwise, fetches for the current user's own firm.
  static Future<List<FirmMember>> fetchFirmMembers({
    String? explicitOwnerId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final String targetId = explicitOwnerId ?? user.id;

    final response = await client
        .from('firm_members')
        .select('*, profiles:member_id(full_name)')
        .eq('owner_id', targetId);

    return (response as List).map((json) => FirmMember.fromJson(json)).toList();
  }

  /// Invites a member to the firm by email. No member limit.
  static Future<void> inviteMember(String email) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if they are already in the firm (or pending)
    final existing =
        await client
            .from('firm_members')
            .select()
            .eq('owner_id', user.id)
            .eq('member_email', email)
            .maybeSingle();

    if (existing != null) {
      if (existing['status'] == 'accepted') {
        throw Exception(
          'An advocate with this email is already a member of your team.',
        );
      } else {
        // Re-invite: reset the row to pending.
        //
        // This used to only touch created_at, which left a 'rejected' row
        // rejected — fetchInvitations filters on status = 'pending', so the
        // invitee never saw it again and the senior could not re-invite them.
        // Writing the status back is also what fires the notification trigger,
        // which listens for any transition *into* 'pending'.
        await client
            .from('firm_members')
            .update({
              'status': 'pending',
              'responded_at': null,
              'created_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
        return;
      }
    }

    // Check if member already has a profile to pre-link
    final existingUserId =
        await client.rpc(
              'find_profile_id_by_email',
              params: {'p_email': email},
            )
            as String?;

    await client.from('firm_members').insert({
      'owner_id': user.id,
      'member_email': email,
      'member_id': existingUserId,
      'status': 'pending',
    });
  }

  /// Removes a member from the firm and cleans up their access/assignments.
  static Future<void> removeMember(String recordId) async {
    // 1. Get the member_id from the record
    final record =
        await client
            .from('firm_members')
            .select('member_id')
            .eq('id', recordId)
            .maybeSingle();

    final memberId = record?['member_id'];

    if (memberId != null) {
      // 2. Clear their firm_id in profiles
      await client
          .from('profiles')
          .update({'firm_id': null})
          .eq('id', memberId);

      // 3. Unassign all cases currently assigned to them
      await client
          .from('cases')
          .update({'assigned_to': null})
          .eq('assigned_to', memberId);
    }

    // 4. Delete the firm membership record
    await client.from('firm_members').delete().eq('id', recordId);
  }

  /// For Members: Fetch invitations addressed to their email.
  static Future<List<FirmMember>> fetchInvitations() async {
    final user = client.auth.currentUser;
    if (user == null || user.email == null) return [];

    final response = await client
        .from('firm_members')
        .select('*, profiles:owner_id(full_name)')
        .eq('member_email', user.email!)
        .eq('status', 'pending');

    return (response as List).map((json) => FirmMember.fromJson(json)).toList();
  }

  /// For Members: Accept a firm invitation.
  static Future<void> acceptInvitation(String invitationId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // 1. Update invitation status.
    //
    // `.select()` is not cosmetic: an RLS-filtered write matches zero rows and
    // still returns success, which is exactly how the decline bug went
    // unnoticed. Checking the returned rows turns that into a real error.
    final accepted = await client
        .from('firm_members')
        .update({
          'member_id': user.id,
          'status': 'accepted',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', invitationId)
        .select('id');

    if ((accepted as List).isEmpty) {
      throw Exception('Could not accept this invitation. It may have been withdrawn.');
    }

    // 2. Link the profile to the firm (Owner's ID)
    final invitation =
        await client
            .from('firm_members')
            .select('owner_id')
            .eq('id', invitationId)
            .single();

    await client
        .from('profiles')
        .update({'firm_id': invitation['owner_id']})
        .eq('id', user.id);
  }

  /// For Members: Decline (reject) a firm invitation.
  ///
  /// Marks the row 'rejected' rather than deleting it.
  ///
  /// The previous DELETE was silently a no-op. Every DELETE policy on
  /// firm_members is owner-scoped (auth.uid() = owner_id), so for the invited
  /// junior RLS filtered the row out, the statement matched zero rows, and
  /// PostgREST still returned success — no exception was thrown, the UI showed
  /// "Invitation Rejected", and the still-pending invitation reappeared on the
  /// next refresh.
  ///
  /// Keeping the row is also what makes it possible to tell the senior who
  /// invited them: a deleted row leaves nothing for the response trigger to
  /// fire on. `inviteMember` resets a rejected row to pending, so re-inviting
  /// still works.
  static Future<void> declineInvitation(String invitationId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // member_id must be the caller — the RLS policy's WITH CHECK requires it,
    // and the response trigger uses it to name who declined.
    final rejected = await client
        .from('firm_members')
        .update({
          'status': 'rejected',
          'member_id': user.id,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', invitationId)
        .select('id');

    if ((rejected as List).isEmpty) {
      throw Exception('Could not decline this invitation. It may have been withdrawn.');
    }
  }

  /// Assigns a case to a specific member.
  static Future<void> assignCase(String caseId, String? memberId) async {
    await client
        .from('cases')
        .update({'assigned_to': memberId})
        .eq('id', caseId);
  }
}
