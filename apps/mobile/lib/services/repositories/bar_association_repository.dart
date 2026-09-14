import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_repository.dart';
import '../../models/bar_association_models.dart';

/// Repository for all Bar Association data operations.
///
/// Follows the existing CaseFlow [BaseRepository] pattern with static methods
/// and direct Supabase client access via [BaseRepository.client].
class BarAssociationRepository extends BaseRepository {
  // Every column except invite_code, which only association administrators may
  // read (through get_association_invite_code on the server).
  static const _associationColumns =
      'id, name, district, court, address, logo_url, annual_fee, '
      'subscription_plan, subscription_expires_at, created_at, updated_at';

  // ═══════════════════════════════════════════════════════════
  // Association
  // ═══════════════════════════════════════════════════════════

  /// Fetches all associations the current user is a member of.
  static Future<List<BarAssociation>> getMyAssociations() async {
    final user = BaseRepository.requireAuth();

    // Get all association IDs where user is a member
    // Only include associations where the user has 'active' membership
    final memberRows = await BaseRepository.client
        .from('bar_members')
        .select('association_id')
        .eq('user_id', user.id)
        .eq('status', 'active');

    if ((memberRows as List).isEmpty) return [];

    final assocIds =
        memberRows.map((r) => r['association_id'] as String).toList();

    final rows = await BaseRepository.client
        .from('bar_associations')
        .select(_associationColumns)
        .inFilter('id', assocIds);

    // Get member counts for each association
    final List<BarAssociation> associations = [];
    for (final row in (rows as List)) {
      final countRes = await BaseRepository.client
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
    final row = await BaseRepository.client
        .from('bar_associations')
        .select(_associationColumns)
        .eq('id', associationId)
        .maybeSingle();

    if (row == null) return null;

    final countRes = await BaseRepository.client
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
    BaseRepository.requireAuth();

    // The invite code is checked on the server: codes are not readable by
    // ordinary users, and failed attempts are rate limited there.
    try {
      final assocRow = await BaseRepository.client.rpc(
        'join_bar_association',
        params: {'p_invite_code': inviteCode},
      );
      BaseRepository.invalidateProfileCache();
      return BarAssociation.fromJson(Map<String, dynamic>.from(assocRow as Map));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Membership
  // ═══════════════════════════════════════════════════════════

  /// Gets the current user's member record for a given association.
  static Future<BarMember?> getMyMembership(String associationId) async {
    final user = BaseRepository.requireAuth();

    final row = await BaseRepository.client
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
    final rows = await BaseRepository.client
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
    final user = BaseRepository.requireAuth();

    // Get member ID for read tracking
    final memberRow = await BaseRepository.client
        .from('bar_members')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    final memberId = memberRow?['id'] as String?;

    // Get all notices
    final rows = await BaseRepository.client
        .from('bar_notices')
        .select()
        .eq('association_id', associationId)
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false);

    // Get read notice IDs for current member
    Set<String> readNoticeIds = {};
    if (memberId != null) {
      final readRows = await BaseRepository.client
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
    final user = BaseRepository.requireAuth();

    final memberRow = await BaseRepository.client
        .from('bar_members')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (memberRow == null) return;
    final memberId = memberRow['id'] as String;

    // Upsert to avoid duplicate errors
    await BaseRepository.client.from('bar_notice_reads').upsert({
      'notice_id': noticeId,
      'member_id': memberId,
    }, onConflict: 'notice_id,member_id');
  }

  // ─── Fee Payments ──────────────────────────────────────────

  /// Gets fee payment history for the current member.
  static Future<List<BarFeePayment>> getFeeHistory(String memberId) async {
    final rows = await BaseRepository.client
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
    final receiptRes = await BaseRepository.client.rpc(
      'generate_bar_receipt_number',
      params: {'p_association_id': associationId},
    );

    final receiptNumber = receiptRes as String;

    final row = await BaseRepository.client
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
    await BaseRepository.client.from('bar_fee_payments').update({
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_order_id': razorpayOrderId,
      'status': status,
      'paid_at': status == 'paid' ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', paymentId);
  }

  // ─── Elections ─────────────────────────────────────────────

  /// Gets the active (non-completed, non-cancelled) election for an association.
  static Future<BarElection?> getActiveElection(String associationId) async {
    final row = await BaseRepository.client
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
    final rows = await BaseRepository.client
        .from('bar_election_posts')
        .select()
        .eq('election_id', electionId)
        .order('created_at');

    return (rows as List).map((r) => BarElectionPost.fromJson(r)).toList();
  }

  /// Gets approved nominations for a post with nominee details.
  static Future<List<BarNomination>> getNominations(String postId) async {
    final rows = await BaseRepository.client
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
    final row = await BaseRepository.client
        .from('bar_voter_participation')
        .select('id')
        .eq('election_id', electionId)
        .eq('member_id', memberId)
        .maybeSingle();

    return row != null;
  }

  /// Casts votes for all posts in an election.
  /// [votes] is a map of postId -> nominationId.
  ///
  /// Cast on the server in one transaction: it checks membership, that voting
  /// is open, that the candidates belong to this election and that you have
  /// not voted, then stores the ballot under a voter hash keyed with a server
  /// secret. The previous client-side hash used a salt published in the app,
  /// so anyone could link ballots to members.
  static Future<void> castVotes({
    required String electionId,
    required String memberId,
    required Map<String, String> votes,
  }) async {
    try {
      await BaseRepository.client.rpc(
        'cast_bar_votes',
        params: {'p_election_id': electionId, 'p_votes': votes},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Alias for castVotes.
  static Future<void> castVote({
    required String electionId,
    required String memberId,
    required Map<String, String> votes,
  }) => castVotes(electionId: electionId, memberId: memberId, votes: votes);

  /// Gets approved nominations for a post with vote counts included.
  static Future<List<BarNomination>> getNominationsWithVotes(String postId) async {
    final nominations = await getNominations(postId);
    final voteCounts = await getVoteCounts(postId);

    return nominations.map((nom) {
      final count = voteCounts[nom.id] ?? 0;
      return BarNomination(
        id: nom.id,
        postId: nom.postId,
        nomineeMemberId: nom.nomineeMemberId,
        proposerMemberId: nom.proposerMemberId,
        seconderMemberId: nom.seconderMemberId,
        status: nom.status,
        bio: nom.bio,
        photoUrl: nom.photoUrl,
        createdAt: nom.createdAt,
        nomineeName: nom.nomineeName,
        proposerName: nom.proposerName,
        seconderName: nom.seconderName,
        voteCount: count,
      );
    }).toList();
  }

  /// Gets vote counts per nomination for a post (for results).
  static Future<Map<String, int>> getVoteCounts(String postId) async {
    final rows = await BaseRepository.client.rpc(
      'get_vote_counts',
      params: {'p_post_id': postId},
    );

    final Map<String, int> counts = {};
    for (final row in (rows as List)) {
      counts[row['nomination_id'] as String] = (row['vote_count'] as num).toInt();
    }
    return counts;
  }

  // ─── Events ────────────────────────────────────────────────

  /// Gets all events for an association.
  static Future<List<BarEvent>> getEvents(String associationId) async {
    final rows = await BaseRepository.client
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

    final rows = await BaseRepository.client
        .from('bar_events')
        .select()
        .eq('association_id', associationId)
        .gte('event_date', startDate.toIso8601String().split('T')[0])
        .lte('event_date', endDate.toIso8601String().split('T')[0])
        .order('event_date');

    return (rows as List).map((r) => BarEvent.fromJson(r)).toList();
  }

  // ─── Admin Check ───────────────────────────────────────────

  /// Checks if the current user is an admin of the given association.
  static Future<bool> isAdmin(String associationId) async {
    final user = BaseRepository.requireAuth();
    final row = await BaseRepository.client
        .from('bar_admins')
        .select('id')
        .eq('association_id', associationId)
        .eq('user_id', user.id)
        .maybeSingle();

    return row != null;
  }
}
