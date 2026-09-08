import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_association_models.dart';
import 'repositories/bar_association_repository.dart';
import 'supabase_service.dart';
import 'retry_helper.dart';
import 'offline_cache_service.dart';
import 'repositories/base_repository.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import '../models/caveat_models.dart';
import '../models/strategy_models.dart';
import 'caveat_service.dart';
import 'locale_service.dart';
import 'repositories/strategy_repository.dart';
import 'firm_service.dart';
import 'collaborator_service.dart';

// ─── Auth State ─────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Live count of pending invitations (firm-recruitment + case-sharing) for the
/// current user — powers the "Invitations" badge on the dashboard.
///
/// Emits an initial count immediately, then re-emits whenever the user's
/// invitation rows change in realtime (a new invite arrives, or one is
/// accepted/rejected) — so the badge updates without a manual refresh. Requires
/// `firm_members` and `case_collaborations` to be in the `supabase_realtime`
/// publication (see migration 20260913_invitation_badge_realtime.sql).
final pendingInvitationsCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  ref.watch(authStateProvider);
  final client = Supabase.instance.client;
  final controller = StreamController<int>();

  Future<void> emit() async {
    try {
      final firm = await FirmService.fetchInvitations();
      final cases = await CollaboratorService.fetchMyInvitations();
      if (!controller.isClosed) controller.add(firm.length + cases.length);
    } catch (_) {
      if (!controller.isClosed) controller.add(0);
    }
  }

  // Initial value.
  emit();

  // Live refresh when the user's invitation rows change.
  final channel = client.channel('pending_invitations_badge')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'firm_members',
      callback: (_) => emit(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'case_collaborations',
      callback: (_) => emit(),
    )
    ..subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

final connectivityStreamProvider = StreamProvider<bool>((ref) {
  return OfflineCacheService.connectivityStream;
});

final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentSession;
});

final userProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// **Performance fix:** Profile is now cached with keepAlive.
/// Previously, `fetchProfile()` was called inside EVERY data-fetching method
/// (fetchCases, fetchClients, fetchHearings, etc.) causing 5-7 redundant
/// DB calls per screen load.
///
/// Now the profile is fetched ONCE and cached for 5 minutes via
/// [BaseRepository.getCachedProfile()]. The cache is invalidated on:
/// - Sign in / sign out
/// - Auth state change (watched below)
/// - Manual refresh via `ref.invalidate(userProfileProvider)`
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  ref.watch(authStateProvider);
  // Invalidate the static cache when auth state changes
  BaseRepository.invalidateProfileCache();
  // Clear Flutter's image cache so profile photos load fresh
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  return RetryHelper.retry(() => SupabaseService.fetchProfile());
});

final userRoleProvider = Provider<String>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.valueOrNull?.userRole ?? 'advocate';
});

// ─── GLOBAL REFRESH TRIGGER ────────────────────────────────────
// When this counter changes, ALL data providers that watch it
// will automatically re-fetch fresh data from Supabase.
// Increment via: ref.read(dataRefreshProvider.notifier).state++;

final dataRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Data Providers (with retry) ──────────────────────────────────

final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  try {
    final clients = await RetryHelper.retry(
      () => SupabaseService.fetchClients(),
    );
    OfflineCacheService.cacheClients(clients.map((c) => c.toJson()).toList());
    return clients;
  } catch (e) {
    final cached = await OfflineCacheService.getCachedClients();
    if (cached.isNotEmpty) {
      debugPrint('Offline: Returning ${cached.length} cached clients');
      return cached.map((json) => ClientModel.fromJson(json)).toList();
    }
    rethrow;
  }
});

final casesProvider = FutureProvider<List<CaseModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  try {
    final cases = await RetryHelper.retry(() => SupabaseService.fetchCases());
    // Cache for offline use (fire-and-forget)
    OfflineCacheService.cacheCases(cases.map((c) => c.toJson()).toList());
    return cases;
  } catch (e) {
    // If offline, return cached data
    final cached = await OfflineCacheService.getCachedCases();
    if (cached.isNotEmpty) {
      debugPrint('Offline: Returning ${cached.length} cached cases');
      return cached.map((json) => CaseModel.fromJson(json)).toList();
    }
    rethrow;
  }
});

final caseDetailProvider = FutureProvider.family<CaseModel?, String>((
  ref,
  id,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchCaseById(id));
});

final hearingsProvider = FutureProvider<List<Hearing>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  try {
    final hearings = await RetryHelper.retry(
      () => SupabaseService.fetchHearings(),
    );
    OfflineCacheService.cacheHearings(hearings.map((h) => h.toJson()).toList());
    return hearings;
  } catch (e) {
    final cached = await OfflineCacheService.getCachedHearings();
    if (cached.isNotEmpty) {
      debugPrint('Offline: Returning ${cached.length} cached hearings');
      return cached.map((json) => Hearing.fromJson(json)).toList();
    }
    rethrow;
  }
});

final caseHearingsProvider = FutureProvider.family<List<Hearing>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchHearings(caseId: caseId));
});

final paymentsProvider = FutureProvider<List<Payment>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchPayments());
});

final casePaymentsProvider = FutureProvider.family<List<Payment>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchPayments(caseId: caseId));
});

final efilingProvider = FutureProvider<List<EFilingRecord>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchEfilingRecords());
});

final caseEfilingProvider = FutureProvider.family<List<EFilingRecord>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(
    () => SupabaseService.fetchEfilingRecords(caseId: caseId),
  );
});

final tasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchTasks());
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchDashboardStats());
});

final certifiedCopiesProvider = FutureProvider<List<CertifiedCopy>>((
  ref,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchCertifiedCopies());
});

final caseDocumentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      caseId,
    ) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider); // ← watches refresh trigger
      return RetryHelper.retry(() => SupabaseService.fetchDocuments(caseId));
    });

final evidenceChecklistProvider =
    FutureProvider.family<List<EvidenceChecklist>, String>((ref, caseId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider); // ← watches refresh trigger
      return RetryHelper.retry(
        () => SupabaseService.fetchEvidenceChecklist(caseId),
      );
    });

final witnessNotesProvider = FutureProvider.family<List<WitnessNote>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchWitnessNotes(caseId));
});

final evidencePhotosProvider =
    FutureProvider.family<List<EvidencePhoto>, String>((ref, caseId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider); // ← watches refresh trigger
      return RetryHelper.retry(
        () => SupabaseService.fetchEvidencePhotos(caseId),
      );
    });

final caseDiscussionsProvider =
    StreamProvider.family<List<CaseComment>, String>((ref, caseId) {
      ref.watch(authStateProvider);
      return SupabaseService.discussionsStream(caseId: caseId);
    });

final firmNoticesProvider = StreamProvider.family<List<CaseComment>, String>((
  ref,
  firmId,
) {
  ref.watch(authStateProvider);
  return SupabaseService.discussionsStream(firmId: firmId);
});

// ─── eCourt Dossier Providers ─────────────────────────

final caseActsProvider = FutureProvider.family<List<CaseAct>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchCaseActs(caseId));
});

final caseIAProvider = FutureProvider.family<List<CaseIAApplication>, String>((
  ref,
  caseId,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchCaseIAs(caseId));
});

final caseInterimOrdersProvider =
    FutureProvider.family<List<CaseInterimOrder>, String>((ref, caseId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => SupabaseService.fetchInterimOrders(caseId),
      );
    });

// ─── Caveats ─────────────────────────────────────────

final caveatsProvider = FutureProvider<List<Caveat>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => CaveatService.fetchCaveats());
});

// ─── UI State ────────────────────────────────────────

final navigationIndexProvider = StateProvider<int>((ref) => 0);
final pageTitleProvider = StateProvider<String>((ref) => 'CaseFlow');
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ─── Display Language ────────────────────────────────

/// Holds the active display language and persists every change.
///
/// The initial value is seeded in `main()` from [LocaleService.load] via a
/// provider override, so the app opens directly in the saved language rather
/// than rendering English for a frame and then switching.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(super.initial);

  /// Switches the app's language and writes it to disk.
  ///
  /// State is updated first so the UI switches immediately; persistence
  /// failures are swallowed inside [LocaleService.save].
  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == state.languageCode) return;
    state = locale;
    await LocaleService.save(locale);
  }
}

/// The app's current display language. Watched by `MaterialApp.router`.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(LocaleService.fallback),
);

// ─── Carousel Slides ──────────────────────────────────
final carouselSlidesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchCarouselSlides());
});

// ─── Bar Association ──────────────────────────────

/// All bar associations the current user is a member of.
final barAssociationsProvider = FutureProvider<List<BarAssociation>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => BarAssociationRepository.getMyAssociations());
});

/// Currently selected association ID (for multi-association switcher).
final selectedBarAssociationIdProvider = StateProvider<String?>((ref) => null);

/// Single association details.
final barAssociationDetailProvider =
    FutureProvider.family<BarAssociation?, String>((ref, assocId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getAssociation(assocId),
      );
    });

/// Notices for an association (with read status).
final barNoticesProvider =
    FutureProvider.family<List<BarNotice>, String>((ref, assocId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getNotices(assocId),
      );
    });

/// Events for an association.
final barEventsProvider =
    FutureProvider.family<List<BarEvent>, String>((ref, assocId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getEvents(assocId),
      );
    });

/// Active election for an association.
final barElectionProvider =
    FutureProvider.family<BarElection?, String>((ref, assocId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getActiveElection(assocId),
      );
    });

/// Current user's membership in an association.
final barMembershipProvider =
    FutureProvider.family<BarMember?, String>((ref, assocId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getMyMembership(assocId),
      );
    });

/// Fee payment history for a member.
final barFeeHistoryProvider =
    FutureProvider.family<List<BarFeePayment>, String>((ref, memberId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => BarAssociationRepository.getFeeHistory(memberId),
      );
    });

// ─── Strategy Board ──────────────────────────────────

/// All tasks for a specific case (for the board view).
final strategyTasksProvider =
    FutureProvider.family<List<StrategyTask>, String>((ref, caseId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(
        () => StrategyRepository.fetchTasks(caseId),
      );
    });

/// Tasks assigned to the current user across all cases.
final myStrategyTasksProvider =
    FutureProvider<List<StrategyTask>>((ref) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return RetryHelper.retry(() => StrategyRepository.fetchMyTasks());
    });

/// Board summary stats (for case detail header badge).
final strategyBoardSummaryProvider =
    FutureProvider.family<Map<String, int>, String>((ref, caseId) async {
      ref.watch(authStateProvider);
      ref.watch(dataRefreshProvider);
      return StrategyRepository.fetchBoardSummary(caseId);
    });

