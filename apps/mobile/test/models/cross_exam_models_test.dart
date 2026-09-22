import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/models/cross_exam_models.dart';

void main() {
  group('QuestionCategory', () {
    test('fromString parses all standard categories', () {
      expect(QuestionCategory.fromString('fact_establishment'),
          QuestionCategory.factEstablishment);
      expect(QuestionCategory.fromString('contradiction'),
          QuestionCategory.contradiction);
      expect(QuestionCategory.fromString('credibility'),
          QuestionCategory.credibility);
      expect(QuestionCategory.fromString('timeline'),
          QuestionCategory.timeline);
      expect(QuestionCategory.fromString('motive'),
          QuestionCategory.motive);
      expect(QuestionCategory.fromString('character'),
          QuestionCategory.character);
      expect(QuestionCategory.fromString('document_confrontation'),
          QuestionCategory.documentConfrontation);
    });

    test('fromString falls back to factEstablishment on unknown value', () {
      expect(QuestionCategory.fromString('invalid_cat'),
          QuestionCategory.factEstablishment);
    });

    test('dbValue formats as snake_case', () {
      expect(QuestionCategory.factEstablishment.dbValue, 'fact_establishment');
      expect(QuestionCategory.documentConfrontation.dbValue,
          'document_confrontation');
      expect(QuestionCategory.contradiction.dbValue, 'contradiction');
    });

    test('labels and emojis are present', () {
      for (final cat in QuestionCategory.values) {
        expect(cat.label.isNotEmpty, true);
        expect(cat.emoji.isNotEmpty, true);
      }
    });
  });

  group('QuestionPriority', () {
    test('fromString handles all priorities', () {
      expect(QuestionPriority.fromString('low'), QuestionPriority.low);
      expect(QuestionPriority.fromString('medium'), QuestionPriority.medium);
      expect(QuestionPriority.fromString('high'), QuestionPriority.high);
      expect(QuestionPriority.fromString('critical'), QuestionPriority.critical);
      expect(QuestionPriority.fromString('unknown'), QuestionPriority.medium);
    });

    test('labels and emojis are formatted properly', () {
      expect(QuestionPriority.low.label, 'Low');
      expect(QuestionPriority.critical.label, 'Critical');
      expect(QuestionPriority.critical.emoji, '🔴');
    });
  });

  group('SessionStatus', () {
    test('fromString handles all statuses', () {
      expect(SessionStatus.fromString('draft'), SessionStatus.draft);
      expect(SessionStatus.fromString('preparing'), SessionStatus.preparing);
      expect(SessionStatus.fromString('ready'), SessionStatus.ready);
      expect(SessionStatus.fromString('completed'), SessionStatus.completed);
      expect(SessionStatus.fromString('unknown'), SessionStatus.draft);
    });

    test('labels and emojis', () {
      expect(SessionStatus.draft.label, 'Draft');
      expect(SessionStatus.ready.emoji, '✅');
    });
  });

  group('CrossExamSession', () {
    test('fromJson parses correctly with joins and question count', () {
      final json = {
        'id': 'session-001',
        'case_id': 'case-123',
        'witness_id': 'witness-456',
        'user_id': 'user-789',
        'firm_id': 'firm-999',
        'witness_name': 'Inspector Ramesh Kumar',
        'witness_tag': 'PW1',
        'status': 'preparing',
        'hearing_date': '2026-10-15',
        'notes': 'Key police witness',
        'cases': {'title': 'State vs. Sharma'},
        'cross_exam_questions': [
          {'count': 12}
        ],
        'created_at': '2026-09-14T10:00:00Z',
        'updated_at': '2026-09-14T10:30:00Z',
      };

      final session = CrossExamSession.fromJson(json);

      expect(session.id, 'session-001');
      expect(session.caseId, 'case-123');
      expect(session.witnessId, 'witness-456');
      expect(session.witnessName, 'Inspector Ramesh Kumar');
      expect(session.witnessTag, 'PW1');
      expect(session.witnessTagPrefix, 'PW');
      expect(session.status, SessionStatus.preparing);
      expect(session.caseTitle, 'State vs. Sharma');
      expect(session.questionCount, 12);
      expect(session.hearingDate, DateTime(2026, 10, 15));
    });

    test('toInsertJson formats database payload correctly', () {
      final session = CrossExamSession(
        id: 's-1',
        caseId: 'c-1',
        userId: 'u-1',
        witnessName: 'Dr. Sen',
        witnessTag: 'DW2',
        status: SessionStatus.ready,
        hearingDate: DateTime.utc(2026, 11, 20),
        notes: 'Forensic expert',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final insertJson = session.toInsertJson();

      expect(insertJson['case_id'], 'c-1');
      expect(insertJson['user_id'], 'u-1');
      expect(insertJson['witness_name'], 'Dr. Sen');
      expect(insertJson['witness_tag'], 'DW2');
      expect(insertJson['status'], 'ready');
      expect(insertJson['hearing_date'], '2026-11-20');
      expect(insertJson['notes'], 'Forensic expert');
    });

    test('copyWith updates specified fields', () {
      final session = CrossExamSession(
        id: 's-1',
        caseId: 'c-1',
        userId: 'u-1',
        witnessName: 'Witness',
        status: SessionStatus.draft,
        questionCount: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = session.copyWith(
        status: SessionStatus.ready,
        questionCount: 10,
      );

      expect(updated.status, SessionStatus.ready);
      expect(updated.questionCount, 10);
      expect(updated.witnessName, 'Witness');
    });
  });

  group('CrossExamQuestion', () {
    test('fromJson deserializes question correctly', () {
      final json = {
        'id': 'q-101',
        'session_id': 'session-001',
        'question_text': 'Were you present at the scene at 10:00 PM?',
        'category': 'timeline',
        'position': 3,
        'priority': 'critical',
        'is_key_question': true,
        'expected_answer': 'Will claim he was at office',
        'follow_up_if_yes': 'Ask who saw him there',
        'follow_up_if_no': 'Produce GPS log exhibit D-3',
        'advocate_notes': 'Contradicts statement under Sec 161 CrPC',
        'created_at': '2026-09-14T10:00:00Z',
        'updated_at': '2026-09-14T10:05:00Z',
      };

      final q = CrossExamQuestion.fromJson(json);

      expect(q.id, 'q-101');
      expect(q.sessionId, 'session-001');
      expect(q.questionText, 'Were you present at the scene at 10:00 PM?');
      expect(q.category, QuestionCategory.timeline);
      expect(q.position, 3);
      expect(q.priority, QuestionPriority.critical);
      expect(q.isKeyQuestion, true);
      expect(q.expectedAnswer, 'Will claim he was at office');
      expect(q.followUpIfYes, 'Ask who saw him there');
      expect(q.followUpIfNo, 'Produce GPS log exhibit D-3');
      expect(q.advocateNotes, 'Contradicts statement under Sec 161 CrPC');
      expect(q.hasNotes, true);
    });

    test('hasNotes returns false when all notes fields are null or empty', () {
      final q = CrossExamQuestion(
        id: 'q-1',
        sessionId: 's-1',
        questionText: 'Simple question?',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(q.hasNotes, false);
    });

    test('toInsertJson includes all fields for persistence', () {
      final q = CrossExamQuestion(
        id: 'q-2',
        sessionId: 's-1',
        questionText: 'Did you sign the memo?',
        category: QuestionCategory.documentConfrontation,
        position: 1,
        priority: QuestionPriority.high,
        isKeyQuestion: true,
        advocateNotes: 'Show Ex P-12',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final insertMap = q.toInsertJson();

      expect(insertMap['session_id'], 's-1');
      expect(insertMap['question_text'], 'Did you sign the memo?');
      expect(insertMap['category'], 'document_confrontation');
      expect(insertMap['position'], 1);
      expect(insertMap['priority'], 'high');
      expect(insertMap['is_key_question'], true);
      expect(insertMap['advocate_notes'], 'Show Ex P-12');
    });

    test('copyWith works as expected', () {
      final q = CrossExamQuestion(
        id: 'q-1',
        sessionId: 's-1',
        questionText: 'Original text',
        priority: QuestionPriority.low,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = q.copyWith(
        questionText: 'Revised text',
        priority: QuestionPriority.critical,
        isKeyQuestion: true,
      );

      expect(updated.questionText, 'Revised text');
      expect(updated.priority, QuestionPriority.critical);
      expect(updated.isKeyQuestion, true);
      expect(updated.id, 'q-1');
    });
  });
}
