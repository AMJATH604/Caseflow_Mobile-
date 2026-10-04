import '../utils/safe_date.dart';

// ─── Advocate Commissioner Module — Data Models ───────────────

// ─── Enums ────────────────────────────────────────────────────

enum CommissionType {
  localInvestigation,
  partition,
  survey,
  recordingEvidence,
  sale;

  String get label {
    switch (this) {
      case CommissionType.localInvestigation:
        return 'Local Investigation';
      case CommissionType.partition:
        return 'Partition';
      case CommissionType.survey:
        return 'Survey & Demarcation';
      case CommissionType.recordingEvidence:
        return 'Recording Evidence';
      case CommissionType.sale:
        return 'Sale of Property';
    }
  }

  String get dbValue {
    switch (this) {
      case CommissionType.localInvestigation:
        return 'local_investigation';
      case CommissionType.partition:
        return 'partition';
      case CommissionType.survey:
        return 'survey';
      case CommissionType.recordingEvidence:
        return 'recording_evidence';
      case CommissionType.sale:
        return 'sale';
    }
  }

  static CommissionType fromString(String value) {
    switch (value) {
      case 'partition':
        return CommissionType.partition;
      case 'survey':
        return CommissionType.survey;
      case 'recording_evidence':
        return CommissionType.recordingEvidence;
      case 'sale':
        return CommissionType.sale;
      default:
        return CommissionType.localInvestigation;
    }
  }
}

enum CommissionStatus {
  pending,
  inProgress,
  visitCompleted,
  reportDrafting,
  submitted,
  objections,
  closed;

  String get label {
    switch (this) {
      case CommissionStatus.pending:
        return 'Pending';
      case CommissionStatus.inProgress:
        return 'In Progress';
      case CommissionStatus.visitCompleted:
        return 'Visit Done';
      case CommissionStatus.reportDrafting:
        return 'Drafting Report';
      case CommissionStatus.submitted:
        return 'Submitted';
      case CommissionStatus.objections:
        return 'Objections';
      case CommissionStatus.closed:
        return 'Closed';
    }
  }

  String get dbValue {
    switch (this) {
      case CommissionStatus.pending:
        return 'pending';
      case CommissionStatus.inProgress:
        return 'in_progress';
      case CommissionStatus.visitCompleted:
        return 'visit_completed';
      case CommissionStatus.reportDrafting:
        return 'report_drafting';
      case CommissionStatus.submitted:
        return 'submitted';
      case CommissionStatus.objections:
        return 'objections';
      case CommissionStatus.closed:
        return 'closed';
    }
  }

  static CommissionStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return CommissionStatus.inProgress;
      case 'visit_completed':
        return CommissionStatus.visitCompleted;
      case 'report_drafting':
        return CommissionStatus.reportDrafting;
      case 'submitted':
        return CommissionStatus.submitted;
      case 'objections':
        return CommissionStatus.objections;
      case 'closed':
        return CommissionStatus.closed;
      default:
        return CommissionStatus.pending;
    }
  }
}

enum VisitStatus {
  planned,
  checkedIn,
  completed,
  obstructed;

  String get label {
    switch (this) {
      case VisitStatus.planned:
        return 'Planned';
      case VisitStatus.checkedIn:
        return 'Checked In';
      case VisitStatus.completed:
        return 'Completed';
      case VisitStatus.obstructed:
        return 'Obstructed';
    }
  }

  String get dbValue {
    switch (this) {
      case VisitStatus.planned:
        return 'planned';
      case VisitStatus.checkedIn:
        return 'checked_in';
      case VisitStatus.completed:
        return 'completed';
      case VisitStatus.obstructed:
        return 'obstructed';
    }
  }

  static VisitStatus fromString(String value) {
    switch (value) {
      case 'checked_in':
        return VisitStatus.checkedIn;
      case 'completed':
        return VisitStatus.completed;
      case 'obstructed':
        return VisitStatus.obstructed;
      default:
        return VisitStatus.planned;
    }
  }
}

enum ExpenseType {
  travel,
  clerical,
  photography,
  stampPaper,
  printing,
  miscellaneous;

  String get label {
    switch (this) {
      case ExpenseType.travel:
        return 'Travel';
      case ExpenseType.clerical:
        return 'Clerical';
      case ExpenseType.photography:
        return 'Photography';
      case ExpenseType.stampPaper:
        return 'Stamp Paper';
      case ExpenseType.printing:
        return 'Printing';
      case ExpenseType.miscellaneous:
        return 'Miscellaneous';
    }
  }

  String get dbValue {
    switch (this) {
      case ExpenseType.travel:
        return 'travel';
      case ExpenseType.clerical:
        return 'clerical';
      case ExpenseType.photography:
        return 'photography';
      case ExpenseType.stampPaper:
        return 'stamp_paper';
      case ExpenseType.printing:
        return 'printing';
      case ExpenseType.miscellaneous:
        return 'miscellaneous';
    }
  }

  static ExpenseType fromString(String value) {
    switch (value) {
      case 'clerical':
        return ExpenseType.clerical;
      case 'photography':
        return ExpenseType.photography;
      case 'stamp_paper':
        return ExpenseType.stampPaper;
      case 'printing':
        return ExpenseType.printing;
      case 'miscellaneous':
        return ExpenseType.miscellaneous;
      default:
        return ExpenseType.travel;
    }
  }
}

// ─── Models ───────────────────────────────────────────────────

class Commission {
  final String id;
  final String? caseId;
  final String? commissionerId;
  final CommissionType commissionType;
  final DateTime? warrantDate;
  final DateTime? executionDate;
  final DateTime? deadlineDate;
  final CommissionStatus status;
  final String? scopeOfWork;
  final String? propertyDescription;
  final String? surveyNumber;
  final String? village;
  final String? taluk;
  final String? district;
  final String? state;
  final String? partyPetitioner;
  final String? partyRespondent;
  final String? courtName;
  final String? caseNumberRef;
  final String? notes;
  final String createdBy;
  final String? firmId;
  final DateTime createdAt;
  // Joined fields
  final String? caseTitle;

  Commission({
    required this.id,
    this.caseId,
    this.commissionerId,
    this.commissionType = CommissionType.localInvestigation,
    this.warrantDate,
    this.executionDate,
    this.deadlineDate,
    this.status = CommissionStatus.pending,
    this.scopeOfWork,
    this.propertyDescription,
    this.surveyNumber,
    this.village,
    this.taluk,
    this.district,
    this.state,
    this.partyPetitioner,
    this.partyRespondent,
    this.courtName,
    this.caseNumberRef,
    this.notes,
    required this.createdBy,
    this.firmId,
    required this.createdAt,
    this.caseTitle,
  });

  factory Commission.fromJson(Map<String, dynamic> json) => Commission(
    id: json['id'] ?? '',
    caseId: json['case_id'],
    commissionerId: json['commissioner_id'],
    commissionType: CommissionType.fromString(
      json['commission_type'] ?? 'local_investigation',
    ),
    warrantDate:
        parseDateOrNull(json['warrant_date']),
    executionDate:
        parseDateOrNull(json['execution_date']),
    deadlineDate:
        parseDateOrNull(json['deadline_date']),
    status: CommissionStatus.fromString(json['status'] ?? 'pending'),
    scopeOfWork: json['scope_of_work'],
    propertyDescription: json['property_description'],
    surveyNumber: json['survey_number'],
    village: json['village'],
    taluk: json['taluk'],
    district: json['district'],
    state: json['state'],
    partyPetitioner: json['party_petitioner'],
    partyRespondent: json['party_respondent'],
    courtName: json['court_name'],
    caseNumberRef: json['case_number_ref'],
    notes: json['notes'],
    createdBy: json['created_by'] ?? '',
    firmId: json['firm_id'],
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
    caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
  );

  String get locationSummary {
    final parts = [
      village,
      taluk,
      district,
      state,
    ].where((e) => e != null && e.isNotEmpty);
    return parts.isNotEmpty ? parts.join(', ') : 'No location specified';
  }

  bool get isOverdue {
    if (deadlineDate == null) return false;
    if (status == CommissionStatus.submitted ||
        status == CommissionStatus.closed) {
      return false;
    }
    return DateTime.now().isAfter(deadlineDate!);
  }

  int? get daysRemaining {
    if (deadlineDate == null) return null;
    return deadlineDate!.difference(DateTime.now()).inDays;
  }
}

class CommissionVisit {
  final String id;
  final String commissionId;
  final DateTime visitDate;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final double? checkinLat;
  final double? checkinLng;
  final double? checkoutLat;
  final double? checkoutLng;
  final String? checkinAddress;
  final String? checkoutAddress;
  final VisitStatus visitStatus;
  final String? obstructionDetails;
  final String? weatherConditions;
  final String? personsPresent;
  final String createdBy;
  final DateTime createdAt;

  CommissionVisit({
    required this.id,
    required this.commissionId,
    required this.visitDate,
    this.checkinTime,
    this.checkoutTime,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    this.checkinAddress,
    this.checkoutAddress,
    this.visitStatus = VisitStatus.planned,
    this.obstructionDetails,
    this.weatherConditions,
    this.personsPresent,
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionVisit.fromJson(Map<String, dynamic> json) =>
      CommissionVisit(
        id: json['id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        visitDate: parseDateOr(json['visit_date'], DateTime.now()),
        checkinTime:
            parseDateOrNull(json['checkin_time']),
        checkoutTime:
            parseDateOrNull(json['checkout_time']),
        checkinLat: json['checkin_lat']?.toDouble(),
        checkinLng: json['checkin_lng']?.toDouble(),
        checkoutLat: json['checkout_lat']?.toDouble(),
        checkoutLng: json['checkout_lng']?.toDouble(),
        checkinAddress: json['checkin_address'],
        checkoutAddress: json['checkout_address'],
        visitStatus: VisitStatus.fromString(json['visit_status'] ?? 'planned'),
        obstructionDetails: json['obstruction_details'],
        weatherConditions: json['weather_conditions'],
        personsPresent: json['persons_present'],
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );

  bool get isActive => visitStatus == VisitStatus.checkedIn;

  String? get durationText {
    if (checkinTime == null || checkoutTime == null) return null;
    final diff = checkoutTime!.difference(checkinTime!);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}

class CommissionObservation {
  final String id;
  final String visitId;
  final String commissionId;
  final String observationType;
  final String content;
  final String? voiceNoteUrl;
  final int sequenceOrder;
  final List<String> tags;
  final String createdBy;
  final DateTime createdAt;

  CommissionObservation({
    required this.id,
    required this.visitId,
    required this.commissionId,
    this.observationType = 'general',
    required this.content,
    this.voiceNoteUrl,
    this.sequenceOrder = 0,
    this.tags = const [],
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionObservation.fromJson(Map<String, dynamic> json) =>
      CommissionObservation(
        id: json['id'] ?? '',
        visitId: json['visit_id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        observationType: json['observation_type'] ?? 'general',
        content: json['content'] ?? '',
        voiceNoteUrl: json['voice_note_url'],
        sequenceOrder: json['sequence_order'] ?? 0,
        tags: List<String>.from(json['tags'] ?? []),
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );
}

class CommissionEvidence {
  final String id;
  final String visitId;
  final String commissionId;
  final String fileType;
  final String fileUrl;
  final String? thumbnailUrl;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final String? direction;
  final String? sha256Hash;
  final int sequenceNumber;
  final String createdBy;
  final DateTime createdAt;

  CommissionEvidence({
    required this.id,
    required this.visitId,
    required this.commissionId,
    this.fileType = 'photo',
    required this.fileUrl,
    this.thumbnailUrl,
    this.caption,
    this.latitude,
    this.longitude,
    this.direction,
    this.sha256Hash,
    this.sequenceNumber = 0,
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionEvidence.fromJson(Map<String, dynamic> json) =>
      CommissionEvidence(
        id: json['id'] ?? '',
        visitId: json['visit_id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        fileType: json['file_type'] ?? 'photo',
        fileUrl: json['file_url'] ?? '',
        thumbnailUrl: json['thumbnail_url'],
        caption: json['caption'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        direction: json['direction'],
        sha256Hash: json['sha256_hash'],
        sequenceNumber: json['sequence_number'] ?? 0,
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );

  String get locationText {
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return 'No GPS data';
  }
}

class CommissionExpense {
  final String id;
  final String commissionId;
  final ExpenseType expenseType;
  final double amount;
  final String? description;
  final DateTime expenseDate;
  final String? receiptUrl;
  final String createdBy;
  final DateTime createdAt;

  CommissionExpense({
    required this.id,
    required this.commissionId,
    this.expenseType = ExpenseType.travel,
    required this.amount,
    this.description,
    required this.expenseDate,
    this.receiptUrl,
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionExpense.fromJson(Map<String, dynamic> json) =>
      CommissionExpense(
        id: json['id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        expenseType: ExpenseType.fromString(json['expense_type'] ?? 'travel'),
        amount: (json['amount'] ?? 0).toDouble(),
        description: json['description'],
        expenseDate: parseDateOr(json['expense_date'], DateTime.now()),
        receiptUrl: json['receipt_url'],
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );
}

class CommissionReport {
  final String id;
  final String commissionId;
  final int version;
  final String? reportContent;
  final String? pdfUrl;
  final DateTime? submittedDate;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  CommissionReport({
    required this.id,
    required this.commissionId,
    this.version = 1,
    this.reportContent,
    this.pdfUrl,
    this.submittedDate,
    this.status = 'draft',
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionReport.fromJson(Map<String, dynamic> json) =>
      CommissionReport(
        id: json['id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        version: json['version'] ?? 1,
        reportContent: json['report_content'],
        pdfUrl: json['pdf_url'],
        submittedDate:
            parseDateOrNull(json['submitted_date']),
        status: json['status'] ?? 'draft',
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );
}

// ─── Phase 2 Models ──────────────────────────────────────────

class CommissionWitness {
  final String id;
  final String visitId;
  final String commissionId;
  final String witnessName;
  final String idType;
  final String? idNumber;
  final String? photoUrl;
  final String? statementText;
  final String? audioUrl;
  final String? signatureUrl;
  final double? latitude;
  final double? longitude;
  final String createdBy;
  final DateTime createdAt;

  CommissionWitness({
    required this.id,
    required this.visitId,
    required this.commissionId,
    required this.witnessName,
    this.idType = 'aadhaar',
    this.idNumber,
    this.photoUrl,
    this.statementText,
    this.audioUrl,
    this.signatureUrl,
    this.latitude,
    this.longitude,
    required this.createdBy,
    required this.createdAt,
  });

  factory CommissionWitness.fromJson(Map<String, dynamic> json) =>
      CommissionWitness(
        id: json['id'] ?? '',
        visitId: json['visit_id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        witnessName: json['witness_name'] ?? '',
        idType: json['id_type'] ?? 'aadhaar',
        idNumber: json['id_number'],
        photoUrl: json['photo_url'],
        statementText: json['statement_text'],
        audioUrl: json['audio_url'],
        signatureUrl: json['signature_url'],
        latitude: json['latitude']?.toDouble(),
        longitude: json['longitude']?.toDouble(),
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );

  String get idLabel {
    switch (idType) {
      case 'aadhaar':
        return 'Aadhaar';
      case 'voter_id':
        return 'Voter ID';
      case 'pan':
        return 'PAN';
      case 'driving_license':
        return 'Driving License';
      case 'passport':
        return 'Passport';
      default:
        return 'Other';
    }
  }

  String get locationText {
    if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
    }
    return 'No GPS data';
  }

  /// The ID number as it may appear in a report. An Aadhaar number is shown
  /// masked to its last four digits, the form UIDAI prescribes for display.
  String? get displayIdNumber {
    final n = idNumber?.trim();
    if (n == null || n.isEmpty) return null;
    if (idType != 'aadhaar') return n;
    final digits = n.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return 'XXXX XXXX XXXX';
    return 'XXXX XXXX ${digits.substring(digits.length - 4)}';
  }
}

class CommissionSketch {
  final String id;
  final String? visitId;
  final String commissionId;
  final String title;
  final String sketchType;
  final Map<String, dynamic>? sketchData;
  final String? sketchImageUrl;
  final List<Map<String, dynamic>> annotations;
  final double northAngle;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommissionSketch({
    required this.id,
    this.visitId,
    required this.commissionId,
    this.title = 'Untitled Sketch',
    this.sketchType = 'general',
    this.sketchData,
    this.sketchImageUrl,
    this.annotations = const [],
    this.northAngle = 0,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommissionSketch.fromJson(Map<String, dynamic> json) =>
      CommissionSketch(
        id: json['id'] ?? '',
        visitId: json['visit_id'],
        commissionId: json['commission_id'] ?? '',
        title: json['title'] ?? 'Untitled Sketch',
        sketchType: json['sketch_type'] ?? 'general',
        sketchData:
            json['sketch_data'] is Map
                ? Map<String, dynamic>.from(json['sketch_data'])
                : null,
        sketchImageUrl: json['sketch_image_url'],
        annotations:
            json['annotations'] is List
                ? (json['annotations'] as List)
                    .map((a) => Map<String, dynamic>.from(a))
                    .toList()
                : [],
        northAngle: (json['north_angle'] ?? 0).toDouble(),
        createdBy: json['created_by'] ?? '',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
        updatedAt: parseDateOr(json['updated_at'], DateTime.now()),
      );

  String get sketchTypeLabel {
    switch (sketchType) {
      case 'property_layout':
        return 'Property Layout';
      case 'boundary':
        return 'Boundary Marking';
      case 'measurement':
        return 'Measurement';
      default:
        return 'General';
    }
  }
}
