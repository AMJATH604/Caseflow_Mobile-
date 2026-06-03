import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for payment management including ledger entries.
class PaymentRepository {
  static final _client = BaseRepository.client;

  static Future<List<Payment>> fetchPayments({String? caseId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final visibleCaseIds = await BaseRepository.getVisibleCaseIds(
      profile,
      user.id,
    );

    if (visibleCaseIds.isEmpty) return [];

    var query = _client
        .from('payments')
        .select('*, cases(case_title, case_number, cnr_number, firm_id)');

    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    final response = await query.order('paid_date', ascending: false);
    return (response as List).map((json) => Payment.fromJson(json)).toList();
  }

  static Future<void> createPayment(Map<String, dynamic> payment) async {
    final user = BaseRepository.requireAuth();
    await _client.from('payments').insert({
      ...payment,
      'created_by': user.id,
      'transaction_type': payment['transaction_type'] ?? 'revenue',
    });
  }

  static Future<void> deletePayment(String id) async {
    await _client.from('payments').delete().eq('id', id);
  }

  /// Fee summary with ledger logic: revenue vs expenses.
  static Future<Map<String, double>> fetchCasePaymentSummary(
    String caseId,
  ) async {
    final response = await _client
        .from('payments')
        .select('total_fee, paid_amount, transaction_type')
        .eq('case_id', caseId);

    final payments = response as List;
    if (payments.isEmpty) {
      return {
        'total_fee': 0,
        'total_paid': 0,
        'total_expenses': 0,
        'balance': 0,
      };
    }

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

  /// Adds a new ledger entry (Payment or Expense).
  static Future<void> addPaymentInstallment(
    Map<String, dynamic> payment,
  ) async {
    final user = BaseRepository.requireAuth();
    await _client.from('payments').insert({
      ...payment,
      'created_by': user.id,
      'transaction_type': payment['transaction_type'] ?? 'revenue',
    });
  }
}
