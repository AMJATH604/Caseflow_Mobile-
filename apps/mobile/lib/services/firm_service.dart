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
        // Refresh the pending invitation
        await client
            .from('firm_members')
            .update({'created_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
        return;
      }
    }

    // Check if member already has a profile to pre-link
    final memberProfile =
        await client
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

    await client.from('firm_members').insert({
      'owner_id': user.id,
      'member_email': email,
      'member_id': memberProfile?['id'],
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

    // 1. Update invitation status
    await client
        .from('firm_members')
        .update({'member_id': user.id, 'status': 'accepted'})
        .eq('id', invitationId);

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
  /// Deletes the pending row rather than marking it 'rejected' so that the
  /// owner can cleanly re-invite the same email later — inviteMember() keys off
  /// the existence of a row, so a lingering 'rejected' row would block a fresh
  /// pending invite.
  static Future<void> declineInvitation(String invitationId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await client.from('firm_members').delete().eq('id', invitationId);
  }

  /// Assigns a case to a specific member.
  static Future<void> assignCase(String caseId, String? memberId) async {
    await client
        .from('cases')
        .update({'assigned_to': memberId})
        .eq('id', caseId);
  }
}
