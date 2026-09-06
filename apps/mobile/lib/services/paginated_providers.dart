import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'paginated_notifier.dart';
import 'repositories/case_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/hearing_repository.dart';
import 'repositories/payment_repository.dart';

/// Concrete paginated notifiers for each entity.
///
/// These wire up the existing [PaginatedNotifier] framework to the
/// domain repositories, enabling infinite-scroll pagination on all
/// main list screens.

// ─── Cases ──────────────────────────────────────────────

class CasesPaginatedNotifier extends PaginatedNotifier<CaseModel> {
  CasesPaginatedNotifier() : super(pageSize: 20);

  @override
  Future<List<CaseModel>> fetchPage(int offset, int limit) {
    return CaseRepository.fetchCases(limit: limit, offset: offset);
  }
}

final paginatedCasesProvider =
    StateNotifierProvider<CasesPaginatedNotifier, PaginatedState<CaseModel>>(
  (ref) => CasesPaginatedNotifier(),
);

// ─── Hearings ───────────────────────────────────────────

class HearingsPaginatedNotifier extends PaginatedNotifier<Hearing> {
  HearingsPaginatedNotifier() : super(pageSize: 20);

  @override
  Future<List<Hearing>> fetchPage(int offset, int limit) {
    return HearingRepository.fetchHearings(limit: limit, offset: offset);
  }
}

final paginatedHearingsProvider =
    StateNotifierProvider<HearingsPaginatedNotifier, PaginatedState<Hearing>>(
  (ref) => HearingsPaginatedNotifier(),
);

// ─── Payments ───────────────────────────────────────────

class PaymentsPaginatedNotifier extends PaginatedNotifier<Payment> {
  PaymentsPaginatedNotifier() : super(pageSize: 20);

  @override
  Future<List<Payment>> fetchPage(int offset, int limit) {
    return PaymentRepository.fetchPayments(limit: limit, offset: offset);
  }
}

final paginatedPaymentsProvider =
    StateNotifierProvider<PaymentsPaginatedNotifier, PaginatedState<Payment>>(
  (ref) => PaymentsPaginatedNotifier(),
);

// ─── Clients ────────────────────────────────────────────

class ClientsPaginatedNotifier extends PaginatedNotifier<ClientModel> {
  ClientsPaginatedNotifier() : super(pageSize: 20);

  @override
  Future<List<ClientModel>> fetchPage(int offset, int limit) {
    return ClientRepository.fetchClients(limit: limit, offset: offset);
  }
}

final paginatedClientsProvider =
    StateNotifierProvider<ClientsPaginatedNotifier, PaginatedState<ClientModel>>(
  (ref) => ClientsPaginatedNotifier(),
);
