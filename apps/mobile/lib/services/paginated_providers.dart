import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'paginated_notifier.dart';
import 'providers.dart';
import 'repositories/case_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/hearing_repository.dart';
import 'repositories/payment_repository.dart';

/// Concrete paginated notifiers for each entity.
///
/// These wire up the existing [PaginatedNotifier] framework to the
/// domain repositories, enabling infinite-scroll pagination on all
/// main list screens.
///
/// **Refresh contract.** Every provider below watches [authStateProvider] and
/// [dataRefreshProvider], mirroring what the `FutureProvider`s in
/// `providers.dart` already do. Without this, a [PaginatedNotifier] — which
/// holds no `Ref` — never saw a global refresh, so data written elsewhere
/// (notably the eCourts import) only appeared after an app restart, because
/// restarting was the only thing that recreated the notifier.
///
/// Watching here recreates the notifier, whose constructor calls
/// `loadInitial()`. Pagination resetting to page 1 on a global refresh is the
/// intended behaviour.

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
  (ref) {
    ref.watch(authStateProvider);
    ref.watch(dataRefreshProvider);
    return CasesPaginatedNotifier();
  },
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
  (ref) {
    ref.watch(authStateProvider);
    ref.watch(dataRefreshProvider);
    return HearingsPaginatedNotifier();
  },
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
  (ref) {
    ref.watch(authStateProvider);
    ref.watch(dataRefreshProvider);
    return PaymentsPaginatedNotifier();
  },
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
  (ref) {
    ref.watch(authStateProvider);
    ref.watch(dataRefreshProvider);
    return ClientsPaginatedNotifier();
  },
);
