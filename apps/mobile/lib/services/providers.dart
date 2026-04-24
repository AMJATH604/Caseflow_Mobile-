import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'retry_helper.dart';
import 'repositories/base_repository.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import '../models/caveat_models.dart';
import 'caveat_service.dart';

// ─── Auth State ─────────────────────────────────────

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
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
  return RetryHelper.retry(() => SupabaseService.fetchProfile());
});

// ─── GLOBAL REFRESH TRIGGER ────────────────────────────────────
// When this counter changes, ALL data providers that watch it
// will automatically re-fetch fresh data from Supabase.
// Increment via: ref.read(dataRefreshProvider.notifier).state++;

final dataRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Data Providers (with retry) ──────────────────────────────────

final clientsProvider = FutureProvider<List<ClientModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchClients());
});

final casesProvider = FutureProvider<List<CaseModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchCases());
});

final caseDetailProvider = FutureProvider.family<CaseModel?, String>((ref, id) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchCaseById(id));
});

final hearingsProvider = FutureProvider<List<Hearing>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchHearings());
});

final caseHearingsProvider = FutureProvider.family<List<Hearing>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchHearings(caseId: caseId));
});

final paymentsProvider = FutureProvider<List<Payment>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchPayments());
});

final casePaymentsProvider = FutureProvider.family<List<Payment>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchPayments(caseId: caseId));
});

final efilingProvider = FutureProvider<List<EFilingRecord>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchEfilingRecords());
});

final caseEfilingProvider = FutureProvider.family<List<EFilingRecord>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchEfilingRecords(caseId: caseId));
});

final tasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchTasks());
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchDashboardStats());
});

final certifiedCopiesProvider = FutureProvider<List<CertifiedCopy>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchCertifiedCopies());
});

final caseDocumentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchDocuments(caseId));
});

final evidenceChecklistProvider = FutureProvider.family<List<EvidenceChecklist>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchEvidenceChecklist(caseId));
});

final witnessNotesProvider = FutureProvider.family<List<WitnessNote>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchWitnessNotes(caseId));
});

final evidencePhotosProvider = FutureProvider.family<List<EvidencePhoto>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider); // ← watches refresh trigger
  return RetryHelper.retry(() => SupabaseService.fetchEvidencePhotos(caseId));
});

final caseDiscussionsProvider = StreamProvider.family<List<CaseComment>, String>((ref, caseId) {
  ref.watch(authStateProvider);
  return SupabaseService.discussionsStream(caseId: caseId);
});

final firmNoticesProvider = StreamProvider.family<List<CaseComment>, String>((ref, firmId) {
  ref.watch(authStateProvider);
  return SupabaseService.discussionsStream(firmId: firmId);
});

// ─── eCourt Dossier Providers ─────────────────────────

final caseActsProvider = FutureProvider.family<List<CaseAct>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchCaseActs(caseId));
});

final caseIAProvider = FutureProvider.family<List<CaseIAApplication>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchCaseIAs(caseId));
});

final caseInterimOrdersProvider = FutureProvider.family<List<CaseInterimOrder>, String>((ref, caseId) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => SupabaseService.fetchInterimOrders(caseId));
});

// ─── Caveats ─────────────────────────────────────────

final caveatsProvider = FutureProvider<List<Caveat>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return RetryHelper.retry(() => CaveatService.fetchCaveats());
});

// ─── UI State ────────────────────────────────────────

final navigationIndexProvider = StateProvider<int>((ref) => 0);
final pageTitleProvider = StateProvider<String>((ref) => "CaseFlow");
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
