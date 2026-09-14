/// Data models for the Cross-Examination Preparation feature.
///
/// Privacy-first: All data stored locally in Supabase.
/// No AI, no third-party APIs involved.
library;

import '../utils/safe_date.dart';

// ─── Enums ────────────────────────────────────────────────────

/// Categories for cross-examination questions.
enum QuestionCategory {
  factEstablishment,
  contradiction,
  credibility,
  timeline,
  motive,
  character,
  documentConfrontation;

  String get label {
    switch (this) {
      case factEstablishment:
        return 'Fact';
      case contradiction:
        return 'Contradiction';
      case credibility:
        return 'Credibility';
      case timeline:
        return 'Timeline';
      case motive:
        return 'Motive';
      case character:
        return 'Character';
      case documentConfrontation:
        return 'Document';
    }
  }

  String get emoji {
    switch (this) {
      case factEstablishment:
        return '📋';
      case contradiction:
        return '🔄';
      case credibility:
        return '🎯';
      case timeline:
        return '⏱️';
      case motive:
        return '🔍';
      case character:
        return '👤';
      case documentConfrontation:
        return '📄';
    }
  }

  String get dbValue {
    switch (this) {
      case factEstablishment:
        return 'fact_establishment';
      case contradiction:
        return 'contradiction';
      case credibility:
        return 'credibility';
      case timeline:
        return 'timeline';
      case motive:
        return 'motive';
      case character:
        return 'character';
      case documentConfrontation:
        return 'document_confrontation';
    }
  }

  static QuestionCategory fromString(String value) {
    switch (value) {
      case 'contradiction':
        return QuestionCategory.contradiction;
      case 'credibility':
        return QuestionCategory.credibility;
      case 'timeline':
        return QuestionCategory.timeline;
      case 'motive':
        return QuestionCategory.motive;
      case 'character':
        return QuestionCategory.character;
      case 'document_confrontation':
        return QuestionCategory.documentConfrontation;
      default:
        return QuestionCategory.factEstablishment;
    }
  }
}

/// Priority levels for cross-examination questions.
enum QuestionPriority {
  low,
  medium,
  high,
  critical;

  String get label => name[0].toUpperCase() + name.substring(1);

  String get emoji {
    switch (this) {
      case low:
        return '🟢';
      case medium:
        return '🟡';
      case high:
        return '🟠';
      case critical:
        return '🔴';
    }
  }

  static QuestionPriority fromString(String value) {
    return QuestionPriority.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => QuestionPriority.medium,
    );
  }
}

/// Status of a cross-examination preparation session.
enum SessionStatus {
  draft,
  preparing,
  ready,
  completed;

  String get label {
    switch (this) {
      case draft:
        return 'Draft';
      case preparing:
        return 'Preparing';
      case ready:
        return 'Ready';
      case completed:
        return 'Completed';
    }
  }

  String get emoji {
    switch (this) {
      case draft:
        return '📝';
      case preparing:
        return '⚡';
      case ready:
        return '✅';
      case completed:
        return '🏁';
    }
  }

  static SessionStatus fromString(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => SessionStatus.draft,
    );
  }
}

// ─── Models ───────────────────────────────────────────────────

/// A cross-examination preparation session linked to a case and witness.
class CrossExamSession {
  final String id;
  final String caseId;
  final String? witnessId;
  final String userId;
  final String? firmId;
  final String witnessName;
  final String witnessTag;
  final SessionStatus status;
  final DateTime? hearingDate;
  final String? notes;
  final String? caseTitle; // Denormalized from join
  final int questionCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CrossExamSession({
    required this.id,
    required this.caseId,
    this.witnessId,
    required this.userId,
    this.firmId,
    required this.witnessName,
    this.witnessTag = 'PW1',
    this.status = SessionStatus.draft,
    this.hearingDate,
    this.notes,
    this.caseTitle,
    this.questionCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrossExamSession.fromJson(Map<String, dynamic> json) {
    // Handle question count from Supabase aggregate join
    int qCount = 0;
    if (json['cross_exam_questions'] is List) {
      final list = json['cross_exam_questions'] as List;
      if (list.isNotEmpty && list[0] is Map && list[0]['count'] != null) {
        qCount = list[0]['count'] as int;
      } else {
        qCount = list.length;
      }
    }

    return CrossExamSession(
      id: json['id'] ?? '',
      caseId: json['case_id'] ?? '',
      witnessId: json['witness_id'],
      userId: json['user_id'] ?? '',
      firmId: json['firm_id'],
      witnessName: json['witness_name'] ?? '',
      witnessTag: json['witness_tag'] ?? 'PW1',
      status: SessionStatus.fromString(json['status'] ?? 'draft'),
      hearingDate: parseDateOrNull(json['hearing_date']),
      notes: json['notes'],
      caseTitle: json['cases']?['title'],
      questionCount: qCount,
      createdAt: parseDateOr(json['created_at'], DateTime.now()),
      updatedAt: parseDateOr(json['updated_at'], DateTime.now()),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'case_id': caseId,
    'witness_id': witnessId,
    'user_id': userId,
    'firm_id': firmId,
    'witness_name': witnessName,
    'witness_tag': witnessTag,
    'status': status.name,
    'hearing_date': hearingDate?.toIso8601String().split('T').first,
    'notes': notes,
  };

  /// Days until the hearing date (negative = overdue).
  int? get daysUntilHearing =>
      hearingDate?.difference(DateTime.now()).inDays;

  /// Witness tag prefix (PW, DW, CW) without the number.
  String get witnessTagPrefix => witnessTag.replaceAll(RegExp(r'[0-9]'), '');

  CrossExamSession copyWith({
    SessionStatus? status,
    DateTime? hearingDate,
    String? notes,
    int? questionCount,
  }) {
    return CrossExamSession(
      id: id,
      caseId: caseId,
      witnessId: witnessId,
      userId: userId,
      firmId: firmId,
      witnessName: witnessName,
      witnessTag: witnessTag,
      status: status ?? this.status,
      hearingDate: hearingDate ?? this.hearingDate,
      notes: notes ?? this.notes,
      caseTitle: caseTitle,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// A single cross-examination question within a session.
class CrossExamQuestion {
  final String id;
  final String sessionId;
  final String questionText;
  final QuestionCategory category;
  final int position;
  final QuestionPriority priority;
  final bool isKeyQuestion;
  final String? expectedAnswer;
  final String? followUpIfYes;
  final String? followUpIfNo;
  final String? advocateNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CrossExamQuestion({
    required this.id,
    required this.sessionId,
    required this.questionText,
    this.category = QuestionCategory.factEstablishment,
    this.position = 0,
    this.priority = QuestionPriority.medium,
    this.isKeyQuestion = false,
    this.expectedAnswer,
    this.followUpIfYes,
    this.followUpIfNo,
    this.advocateNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrossExamQuestion.fromJson(Map<String, dynamic> json) =>
      CrossExamQuestion(
        id: json['id'] ?? '',
        sessionId: json['session_id'] ?? '',
        questionText: json['question_text'] ?? '',
        category: QuestionCategory.fromString(
            json['category'] ?? 'fact_establishment'),
        position: json['position'] ?? 0,
        priority: QuestionPriority.fromString(json['priority'] ?? 'medium'),
        isKeyQuestion: json['is_key_question'] ?? false,
        expectedAnswer: json['expected_answer'],
        followUpIfYes: json['follow_up_if_yes'],
        followUpIfNo: json['follow_up_if_no'],
        advocateNotes: json['advocate_notes'],
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
        updatedAt: parseDateOr(json['updated_at'], DateTime.now()),
      );

  Map<String, dynamic> toInsertJson() => {
    'session_id': sessionId,
    'question_text': questionText,
    'category': category.dbValue,
    'position': position,
    'priority': priority.name,
    'is_key_question': isKeyQuestion,
    'expected_answer': expectedAnswer,
    'follow_up_if_yes': followUpIfYes,
    'follow_up_if_no': followUpIfNo,
    'advocate_notes': advocateNotes,
  };

  /// Whether this question has any prep notes filled in.
  bool get hasNotes =>
      (expectedAnswer?.isNotEmpty ?? false) ||
      (followUpIfYes?.isNotEmpty ?? false) ||
      (followUpIfNo?.isNotEmpty ?? false) ||
      (advocateNotes?.isNotEmpty ?? false);

  CrossExamQuestion copyWith({
    String? questionText,
    QuestionCategory? category,
    int? position,
    QuestionPriority? priority,
    bool? isKeyQuestion,
    String? expectedAnswer,
    String? followUpIfYes,
    String? followUpIfNo,
    String? advocateNotes,
  }) {
    return CrossExamQuestion(
      id: id,
      sessionId: sessionId,
      questionText: questionText ?? this.questionText,
      category: category ?? this.category,
      position: position ?? this.position,
      priority: priority ?? this.priority,
      isKeyQuestion: isKeyQuestion ?? this.isKeyQuestion,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
      followUpIfYes: followUpIfYes ?? this.followUpIfYes,
      followUpIfNo: followUpIfNo ?? this.followUpIfNo,
      advocateNotes: advocateNotes ?? this.advocateNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
