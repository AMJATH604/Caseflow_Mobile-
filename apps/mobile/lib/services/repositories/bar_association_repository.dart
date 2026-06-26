import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'base_repository.dart';
import '../../models/bar_association_models.dart';

/// Repository for all Bar Association data operations.
///
/// Follows the existing CaseFlow [BaseRepository] pattern with static methods
/// and direct Supabase client access via [BaseRepository.client].
class BarAssociationRepository extends BaseRepository {
  // ─── Salt for vote hashing (must match DB function) ─────
  static const _voteSalt = 'caseflow_bar_election_salt_2026';

  // ═══════════════════════════════════════════════════════════
  // Association
  // ═══════════════════════════════════════════════════════════

  /// Fetches all associations the current user is a member of.
  static Future<List<BarAssociation>> getMyAssociations() async {
    final user = requireAuth();

    // Get all association IDs where user is a member
    final memberRows = await client
        .from('bar_members')
        .select('association_id')
        .eq('user_id', user.id);

    if ((memberRows as List).isEmpty) return [];

    final assocIds =
        memberRows.map((r) => r['association_id'] as String).toList();

    final rows = await client
        .from('bar_associations')
        .select()
        .inFilter('id', assocIds);

    // Get member counts for each association
    final List<BarAssociation> associations = [];
    for (final row in (rows as List)) {
      final countRes = await client
          .from('bar_members')
          .select()
          .eq('association_id', row['id'])
          .eq('status', 'active');
      final map = Map<String, dynamic>.from(row);
      map['member_count'] = (countRes as List).length;
      associations.add(BarAssociation.fromJson(map));
    }
    return associations;
  }

  /// Fetches a single association by ID.
  static Future<BarAssociation?> getAssociation(String associationId) async {
    final row = await client
        .from('bar_associations')
        .select()
        .eq('id', associationId)
        .maybeSingle();

    if (row == null) return null;

    final countRes = await client
        .from('bar_members')
        .select()
        .eq('association_id', associationId)
        .eq('status', 'active');

    final map = Map<String, dynamic>.from(row);
    map['member_count'] = (countRes as List).length;
    return BarAssociation.fromJson(map);
  }

  /// Joins an association using a 6-character invite code.
  /// Creates a bar_member record linking the user.
  static Future<BarAssociation> joinAssociation(String inviteCode) async {
    final user = requireAuth();
    final profile = await getCachedProfile();

    // 1. Look up the association by invite code
    final assocRow = await client
        .from('bar_associations')
        .select()
        .eq('invite_code', inviteCode.toUpperCase().trim())
        .maybeSingle();

    if (assocRow == null) {
      throw Exception('Invalid invite code. Please check and try again.');
    }

    final associationId = assocRow['id'] as String;

    // 2. Check if already a member
    final existing = await client
        .from('bar_members')
        .select()
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      throw Exception('You are already a member of this association.');
    }

    // 3. Create the member record
    await client.from('bar_members').insert({
      'association_id': associationId,
      'user_id': user.id,
      'name': profile.fullName,
      'mobile': user.phone ?? '',
      'email': user.email,
      'membership_type': 'regular',
      'status': 'active',
      'joined_year': DateTime.now().year,
      'is_caseflow_user': true,
    });

    // 4. Update profile with primary bar_association_id
    await client
        .from('profiles')
        .update({'bar_association_id': associationId})
        .eq('id', user.id);

    invalidateProfileCache();

    return BarAssociation.fromJson(assocRow);
  }

  // ═══════════════════════════════════════════════════════════
  // Membership
  // ═══════════════════════════════════════════════════════════

  /// Gets the current user's member record for a given association.
  static Future<BarMember?> getMyMembership(String associationId) async {
    final user = requireAuth();

    final row = await client
        .from('bar_members')
        .select()
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return null;
    return BarMember.fromJson(row);
  }

  /// Gets all members of an association (for admins).
  static Future<List<BarMember>> getMembers(String associationId) async {
    final rows = await client
        .from('bar_members')
        .select()
        .eq('association_id', associationId)
        .order('name');

    return (rows as List).map((r) => BarMember.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // Notices
  // ═══════════════════════════════════════════════════════════

  /// Fetches all notices for an association with read status for current user.
  static Future<List<BarNotice>> getNotices(String associationId) async {
    final user = requireAuth();

    // Get member ID for read tracking
    final memberRow = await client
        .from('bar_members')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    final memberId = memberRow?['id'] as String?;

    // Get all notices
    final rows = await client
        .from('bar_notices')
        .select()
        .eq('association_id', associationId)
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false);

    // Get read notice IDs for current member
    Set<String> readNoticeIds = {};
    if (memberId != null) {
      final readRows = await client
          .from('bar_notice_reads')
          .select('notice_id')
          .eq('member_id', memberId);
      readNoticeIds = (readRows as List)
          .map((r) => r['notice_id'] as String)
          .toSet();
    }

    return (rows as List)
        .map((r) => BarNotice.fromJson(r, isRead: readNoticeIds.contains(r['id'])))
        .toList();
  }

  /// Marks a notice as read by the current user.
  static Future<void> markNoticeRead(
    String noticeId,
    String associationId,
  ) async {
    final user = requireAuth();

    final memberRow = await client
        .from('bar_members')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (memberRow == null) return;
    final memberId = memberRow['id'] as String;

    // Upsert to avoid duplicate errors
    await client.from('bar_notice_reads').upsert({
      'notice_id': noticeId,
      'member_id': memberId,
    }, onConflict: 'notice_id,member_id');
  }

  // ═══════════════════════════════════════════════════════════
  // Fee Payments
  // ═══════════════════════════════════════════════════════════

  /// Gets fee payment history for the current member.
  static Future<List<BarFeePayment>> getFeeHistory(String memberId) async {
    final rows = await client
        .from('bar_fee_payments')
        .select()
        .eq('member_id', memberId)
        .order('fee_year', ascending: false);

    return (rows as List).map((r) => BarFeePayment.fromJson(r)).toList();
  }

  /// Creates a pending fee payment record (before Razorpay checkout).
  static Future<BarFeePayment> createFeePayment({
    required String associationId,
    required String memberId,
    required double amount,
    required int feeYear,
  }) async {
    // Generate receipt number via DB function
    final receiptRes = await client.rpc(
      'generate_bar_receipt_number',
      params: {'p_association_id': associationId},
    );

    final receiptNumber = receiptRes as String;

    final row = await client
        .from('bar_fee_payments')
        .insert({
          'association_id': associationId,
          'member_id': memberId,
          'amount': amount,
          'fee_year': feeYear,
          'payment_method': 'razorpay',
          'status': 'pending',
          'receipt_number': receiptNumber,
        })
        .select()
        .single();

    return BarFeePayment.fromJson(row);
  }

  /// Updates a fee payment with Razorpay transaction details.
  static Future<void> updateFeePayment({
    required String paymentId,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String status,
  }) async {
    await client.from('bar_fee_payments').update({
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'status': status,
      'paid_at': status == 'paid' ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', paymentId);
  }

  // ═══════════════════════════════════════════════════════════
  // Elections
  // ═══════════════════════════════════════════════════════════

  /// Gets the active (non-completed, non-cancelled) election for an association.
  static Future<BarElection?> getActiveElection(String associationId) async {
    final row = await client
        .from('bar_elections')
        .select()
        .eq('association_id', associationId)
        .inFilter('status', ['nominations', 'voting', 'completed'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return BarElection.fromJson(row);
  }

  /// Gets all posts for an election.
  static Future<List<BarElectionPost>> getElectionPosts(
    String electionId,
  ) async {
    final rows = await client
        .from('bar_election_posts')
        .select()
        .eq('election_id', electionId)
        .order('created_at');

    return (rows as List).map((r) => BarElectionPost.fromJson(r)).toList();
  }

  /// Gets approved nominations for a post with nominee details.
  static Future<List<BarNomination>> getNominations(String postId) async {
    final rows = await client
        .from('bar_nominations')
        .select('''
          *,
          nominee:nominee_member_id(name, photo_url),
          proposer:proposer_member_id(name),
          seconder:seconder_member_id(name)
        ''')
        .eq('post_id', postId)
        .eq('status', 'approved')
        .order('created_at');

    return (rows as List).map((r) => BarNomination.fromJson(r)).toList();
  }

  /// Checks if the current user has already voted in this election.
  static Future<bool> hasVoted(String electionId, String memberId) async {
    final row = await client
        .from('bar_voter_participation')
        .select('id')
        .eq('election_id', electionId)
        .eq('member_id', memberId)
        .maybeSingle();

    return row != null;
  }

  /// Casts votes for all posts in an election.
  /// [votes] is a map of postId -> nominationId.
  static Future<void> castVotes({
    required String electionId,
    required String memberId,
    required Map<String, String> votes,
  }) async {
    // 1. Generate voter hash (same as DB function)
    final voterHash = _generateVoterHash(memberId, electionId);

    // 2. Insert anonymous votes
    final voteRecords = votes.entries.map((entry) => {
      'post_id': entry.key,
      'nomination_id': entry.value,
      'voter_hash': voterHash,
    }).toList();

    await client.from('bar_votes').insert(voteRecords);

    // 3. Record participation (non-anonymous)
    await client.from('bar_voter_participation').insert({
      'election_id': electionId,
      'member_id': memberId,
      'otp_verified': true,
    });
  }

  /// Gets vote counts per nomination for a post (for results).
  static Future<Map<String, int>> getVoteCounts(String postId) async {
    final rows = await client.rpc(
      'get_vote_counts',
      params: {'p_post_id': postId},
    );

    final Map<String, int> counts = {};
    for (final row in (rows as List)) {
      counts[row['nomination_id'] as String] = (row['vote_count'] as num).toInt();
    }
    return counts;
  }

  /// Generate SHA-256 voter hash matching the database function.
  static String _generateVoterHash(String memberId, String electionId) {
    final input = '$memberId$electionId$_voteSalt';
    final bytes = utf8.encode(input);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // Events
  // ═══════════════════════════════════════════════════════════

  /// Gets all events for an association.
  static Future<List<BarEvent>> getEvents(String associationId) async {
    final rows = await client
        .from('bar_events')
        .select()
        .eq('association_id', associationId)
        .order('event_date', ascending: true);

    return (rows as List).map((r) => BarEvent.fromJson(r)).toList();
  }

  /// Gets events for a specific month.
  static Future<List<BarEvent>> getEventsForMonth(
    String associationId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final rows = await client
        .from('bar_events')
        .select()
        .eq('association_id', associationId)
        .gte('event_date', startDate.toIso8601String().split('T')[0])
        .lte('event_date', endDate.toIso8601String().split('T')[0])
        .order('event_date');

    return (rows as List).map((r) => BarEvent.fromJson(r)).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // Admin Check
  // ═══════════════════════════════════════════════════════════

  /// Checks if the current user is an admin of the given association.
  static Future<bool> isAdmin(String associationId) async {
    final user = requireAuth();
    final row = await client
        .from('bar_admins')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    return row != null;
  }
}
