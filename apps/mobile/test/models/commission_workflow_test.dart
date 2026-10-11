import 'package:caseflow/models/commission_models.dart';
import 'package:flutter_test/flutter_test.dart';

Commission _c({
  CommissionStatus status = CommissionStatus.pending,
  CommissionType type = CommissionType.localInvestigation,
  DateTime? inspectionAt,
}) =>
    Commission(
      id: 'c1',
      createdBy: 'u1',
      createdAt: DateTime(2026, 9, 1),
      status: status,
      commissionType: type,
      inspectionAt: inspectionAt,
    );

CommissionParty _p(NoticeStatus s) => CommissionParty(id: 'p${s.index}', commissionId: 'c1', name: 'Selvi', noticeStatus: s);

CommissionVisit _v(VisitStatus s) => CommissionVisit(
      id: 'v1',
      commissionId: 'c1',
      visitDate: DateTime(2026, 10, 11),
      visitStatus: s,
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 11),
    );

CommissionMeasurement _m({bool complete = true}) => CommissionMeasurement(
      id: 'm1',
      commissionId: 'c1',
      label: 'Lot A',
      northBy: 'Road',
      southBy: 'Land of Ganesan',
      eastBy: 'Common wall',
      westBy: complete ? 'Channel' : null,
      extent: 2520,
      createdAt: DateTime(2026, 10, 11),
    );

void main() {
  group('CommissionProgress — the next step follows the work', () {
    test('a new commission asks for the parties first', () {
      final p = CommissionProgress.of(c: _c(), parties: [], visits: [], measurements: []);
      expect(p.current, CommissionStage.notice);
      expect(p.nextAction, 'notice');
    });

    test('parties without an inspection date ask for the date', () {
      final p = CommissionProgress.of(c: _c(), parties: [_p(NoticeStatus.pending)], visits: [], measurements: []);
      expect(p.nextTitle, 'Fix the date of inspection');
    });

    test('notice still to be served is counted', () {
      final p = CommissionProgress.of(
        c: _c(inspectionAt: DateTime(2026, 10, 11, 10, 30)),
        parties: [_p(NoticeStatus.served), _p(NoticeStatus.pending)],
        visits: [],
        measurements: [],
      );
      expect(p.nextTitle, 'Serve notice on 1 party');
    });

    test('a refusal counts as notice given', () {
      expect(NoticeStatus.refused.noticeGiven, isTrue);
      expect(NoticeStatus.notServed.noticeGiven, isFalse);
    });

    test('with notice given, the next step is the site visit', () {
      final p = CommissionProgress.of(
        c: _c(inspectionAt: DateTime(2026, 10, 11)),
        parties: [_p(NoticeStatus.served)],
        visits: [],
        measurements: [],
      );
      expect(p.current, CommissionStage.visit);
      expect(p.nextAction, 'visit');
    });

    test('an open visit is continued', () {
      final p = CommissionProgress.of(
        c: _c(inspectionAt: DateTime(2026, 10, 11)),
        parties: [_p(NoticeStatus.served)],
        visits: [_v(VisitStatus.checkedIn)],
        measurements: [],
      );
      expect(p.nextTitle, 'Continue the site visit');
    });

    test('site work after a visit asks for boundaries, then their missing sides', () {
      final args = (
        c: _c(inspectionAt: DateTime(2026, 10, 11)),
        parties: [_p(NoticeStatus.served)],
        visits: [_v(VisitStatus.completed)],
      );
      expect(
        CommissionProgress.of(c: args.c, parties: args.parties, visits: args.visits, measurements: []).nextAction,
        'measure',
      );
      expect(
        CommissionProgress.of(c: args.c, parties: args.parties, visits: args.visits, measurements: [_m(complete: false)]).nextTitle,
        'Complete Lot A',
      );
      expect(
        CommissionProgress.of(c: args.c, parties: args.parties, visits: args.visits, measurements: [_m()]).nextAction,
        'report',
      );
    });

    test('an evidence commission does not ask for boundaries', () {
      final p = CommissionProgress.of(
        c: _c(type: CommissionType.recordingEvidence, inspectionAt: DateTime(2026, 10, 11)),
        parties: [_p(NoticeStatus.served)],
        visits: [_v(VisitStatus.completed)],
        measurements: [],
      );
      expect(p.nextAction, 'report');
    });

    test('a filed report has nothing left to do', () {
      final p = CommissionProgress.of(c: _c(status: CommissionStatus.submitted), parties: [], visits: [], measurements: []);
      expect(p.current, CommissionStage.submitted);
      expect(p.nextAction, 'none');
    });
  });

  group('AreaUnit — extent conversions used in the report', () {
    test('one cent is 435.6 square feet', () {
      expect(AreaUnit.cents.convert(1, AreaUnit.sqFt), closeTo(435.6, 1e-9));
    });
    test('one acre is one hundred cents', () {
      expect(AreaUnit.acres.convert(1, AreaUnit.cents), closeTo(100, 1e-9));
    });
    test('2,541 sq ft is about 5.83 cents', () {
      expect(AreaUnit.sqFt.convert(2541, AreaUnit.cents), closeTo(5.833, 0.001));
    });
  });

  group('Witness ID in reports', () {
    CommissionWitness w(String type, String? n) => CommissionWitness(
          id: 'w',
          visitId: 'v',
          commissionId: 'c',
          witnessName: 'K. Raman',
          idType: type,
          idNumber: n,
          createdBy: 'u',
          createdAt: DateTime(2026),
        );

    test('an Aadhaar number is masked to its last four digits', () {
      expect(w('aadhaar', '1234 5678 9012').displayIdNumber, 'XXXX XXXX 9012');
    });
    test('other IDs are shown as entered', () {
      expect(w('voter_id', 'TN/12/345/678').displayIdNumber, 'TN/12/345/678');
    });
    test('no number shows nothing', () {
      expect(w('aadhaar', null).displayIdNumber, isNull);
    });
  });

  test('every commission type names its Order XXVI rule', () {
    for (final t in CommissionType.values) {
      expect(t.rule, startsWith('O. XXVI r.'));
      expect(CommissionType.fromString(t.dbValue), t);
    }
  });
}
