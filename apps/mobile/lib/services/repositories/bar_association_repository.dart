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

  /// Claims this user's place on an association's roll.
  ///
  /// The association enters its register first — a name and an enrolment
  /// number per member, with no account attached — and an advocate then
  /// claims the row that is already there. That claim is what makes the
  /// account a verified advocate: the bar, which is the body that actually
  /// knows who practises in its court, has vouched for them.
  ///
  /// This replaced a join that *created* a member for whoever presented the
  /// code. A six-letter code shared with every member of a bar is no gate at
  /// all, so anyone who saw it became an active member in the database.
  ///
  /// Both the code and the identifier are checked on the server, where
  /// failed attempts are rate limited.
  static Future<BarAssociation> claimMembership(
    String inviteCode,
    String enrolmentOrMobile,
  ) async {
    BaseRepository.requireAuth();

    try {
      final assocRow = await BaseRepository.client.rpc(
        'claim_bar_membership',
        params: {
          'p_invite_code': inviteCode,
          'p_identifier': enrolmentOrMobile,
        },
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

  // ─── Events ────────────────────────────────────────────────

  /// Gets all events for an association.
  /// Condolences published by the association, most recent first.
  static Future<List<BarCondolence>> getCondolences(
    String associationId, {
    int limit = 30,
  }) async {
    final rows = await BaseRepository.client
        .from('bar_condolences')
        .select()
        .eq('association_id', associationId)
        .order('date_of_death', ascending: false)
        .limit(limit);

    return (rows as List).map((r) => BarCondolence.fromJson(r)).toList();
  }

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
