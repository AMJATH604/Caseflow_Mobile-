import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../services/providers.dart';

/// Everything one commission's screens need, loaded together.
class CommissionBundle {
  final Commission commission;
  final List<CommissionParty> parties;
  final List<CommissionVisit> visits;
  final List<CommissionMeasurement> measurements;
  final List<CommissionObservation> observations;
  final List<CommissionEvidence> evidence;
  final List<CommissionWitness> witnesses;
  final List<CommissionSketch> sketches;
  final List<CommissionExpense> expenses;
  final List<Map<String, dynamic>> documents;

  CommissionBundle({
    required this.commission,
    required this.parties,
    required this.visits,
    required this.measurements,
    required this.observations,
    required this.evidence,
    required this.witnesses,
    required this.sketches,
    required this.expenses,
    required this.documents,
  });

  CommissionProgress get progress => CommissionProgress.of(
        c: commission,
        parties: parties,
        visits: visits,
        measurements: measurements,
      );

  CommissionVisit? get activeVisit {
    for (final v in visits) {
      if (v.visitStatus == VisitStatus.checkedIn) return v;
    }
    return null;
  }

  double get expenseTotal => expenses.fold(0, (s, e) => s + e.amount);
}

Future<List<T>> _orEmpty<T>(Future<List<T>> f) async {
  try {
    return await f;
  } catch (e) {
    debugPrint('Commission: a list failed to load: $e');
    return <T>[];
  }
}

/// Invalidate with `ref.invalidate(commissionBundleProvider(id))` after an edit.
final commissionBundleProvider = FutureProvider.autoDispose.family<CommissionBundle, String>((ref, id) async {
  ref.watch(dataRefreshProvider);
  final c = CommissionService.fetchCommissionById(id);
  final parties = _orEmpty(CommissionService.fetchParties(id));
  final visits = _orEmpty(CommissionService.fetchVisits(id));
  final measurements = _orEmpty(CommissionService.fetchMeasurements(id));
  final observations = _orEmpty(CommissionService.fetchObservations(id));
  final evidence = _orEmpty(CommissionService.fetchEvidence(id));
  final witnesses = _orEmpty(CommissionService.fetchWitnesses(id));
  final sketches = _orEmpty(CommissionService.fetchSketches(id));
  final expenses = _orEmpty(CommissionService.fetchExpenses(id));
  final documents = _orEmpty(CommissionService.fetchCommissionDocuments(id));
  return CommissionBundle(
    commission: await c,
    parties: await parties,
    visits: await visits,
    measurements: await measurements,
    observations: await observations,
    evidence: await evidence,
    witnesses: await witnesses,
    sketches: await sketches,
    expenses: await expenses,
    documents: await documents,
  );
});
