import '../utils/safe_date.dart';

// ─── Advocate Commissioner Module — Data Models ───────────────

// ─── Enums ────────────────────────────────────────────────────

enum CommissionType {
  localInvestigation,
  partition,
  survey,
  recordingEvidence,
  sale,
  accounts,
  scientificInvestigation,
  ministerialAct;

  /// The Order XXVI CPC rule each kind of commission is issued under.
  String get rule {
    switch (this) {
      case CommissionType.recordingEvidence:
        return 'O. XXVI r. 1–8';
      case CommissionType.localInvestigation:
        return 'O. XXVI r. 9';
      case CommissionType.survey:
        return 'O. XXVI r. 9';
      case CommissionType.scientificInvestigation:
        return 'O. XXVI r. 10A';
      case CommissionType.ministerialAct:
        return 'O. XXVI r. 10B';
      case CommissionType.sale:
        return 'O. XXVI r. 10C';
      case CommissionType.accounts:
        return 'O. XXVI r. 11';
      case CommissionType.partition:
        return 'O. XXVI r. 13';
    }
  }

  /// Whether the work needs site visits and boundaries (as opposed to
  /// examining witnesses or accounts at a table).
  bool get isSiteWork =>
      this == CommissionType.localInvestigation ||
      this == CommissionType.partition ||
      this == CommissionType.survey ||
      this == CommissionType.scientificInvestigation ||
      this == CommissionType.sale;

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
      case CommissionType.accounts:
        return 'Examination of Accounts';
      case CommissionType.scientificInvestigation:
        return 'Scientific Investigation';
      case CommissionType.ministerialAct:
        return 'Ministerial Act';
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
      case CommissionType.accounts:
        return 'accounts';
      case CommissionType.scientificInvestigation:
        return 'scientific_investigation';
      case CommissionType.ministerialAct:
        return 'ministerial_act';
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
      case 'accounts':
        return CommissionType.accounts;
      case 'scientific_investigation':
        return CommissionType.scientificInvestigation;
      case 'ministerial_act':
        return CommissionType.ministerialAct;
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
  // The inspection fixed in the notice to parties.
  final DateTime? inspectionAt;
  final String? inspectionPlace;
  // The commission fee (batta) fixed by the court.
  final double? feeFixed;
  final String? feeDepositedBy;
  final double? feeReceived;
  final DateTime? feeReceivedOn;
  final DateTime? submittedOn;
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
    this.inspectionAt,
    this.inspectionPlace,
    this.feeFixed,
    this.feeDepositedBy,
    this.feeReceived,
    this.feeReceivedOn,
    this.submittedOn,
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
    inspectionAt: parseDateOrNull(json['inspection_at']),
    inspectionPlace: json['inspection_place'],
    feeFixed: (json['fee_fixed'] as num?)?.toDouble(),
    feeDepositedBy: json['fee_deposited_by'],
    feeReceived: (json['fee_received'] as num?)?.toDouble(),
    feeReceivedOn: parseDateOrNull(json['fee_received_on']),
    submittedOn: parseDateOrNull(json['submitted_on']),
    caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
  );

  /// "O.S. 105/2020" or the court, whichever identifies it best.
  String get displayRef {
    final ref = caseNumberRef?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    return commissionType.label;
  }

  /// "Selvi vs Murugan" when both parties are known.
  String? get partiesTitle {
    final p = partyPetitioner?.trim() ?? '';
    final r = partyRespondent?.trim() ?? '';
    if (p.isEmpty && r.isEmpty) return null;
    if (r.isEmpty) return p;
    if (p.isEmpty) return r;
    return '$p vs $r';
  }

  double? get feeBalance =>
      feeFixed == null ? null : (feeFixed! - (feeReceived ?? 0));

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


// ─── Notice to parties ────────────────────────────────────────

enum NoticeStatus {
  pending,
  served,
  refused,
  informed,
  notServed;

  String get label {
    switch (this) {
      case NoticeStatus.pending:
        return 'Not yet sent';
      case NoticeStatus.served:
        return 'Served';
      case NoticeStatus.refused:
        return 'Refused';
      case NoticeStatus.informed:
        return 'Informed';
      case NoticeStatus.notServed:
        return 'Not served';
    }
  }

  String get dbValue => this == NoticeStatus.notServed ? 'not_served' : name;

  /// Served, informed or refused all count as notice given: a party who
  /// refuses to take notice is still bound by it.
  bool get noticeGiven =>
      this == NoticeStatus.served ||
      this == NoticeStatus.informed ||
      this == NoticeStatus.refused;

  static NoticeStatus fromString(String? v) {
    switch (v) {
      case 'served':
        return NoticeStatus.served;
      case 'refused':
        return NoticeStatus.refused;
      case 'informed':
        return NoticeStatus.informed;
      case 'not_served':
        return NoticeStatus.notServed;
      default:
        return NoticeStatus.pending;
    }
  }
}

class CommissionParty {
  final String id;
  final String commissionId;
  final String name;
  final String role; // plaintiff, petitioner, defendant, respondent, party, official, other
  final String? roleLabel; // "1st Defendant", "Revenue Inspector"
  final String? advocate;
  final String? phone;
  final NoticeStatus noticeStatus;
  final DateTime? servedOn;
  final String? servedHow;
  final bool? attended;
  final int sortOrder;

  CommissionParty({
    required this.id,
    required this.commissionId,
    required this.name,
    this.role = 'party',
    this.roleLabel,
    this.advocate,
    this.phone,
    this.noticeStatus = NoticeStatus.pending,
    this.servedOn,
    this.servedHow,
    this.attended,
    this.sortOrder = 0,
  });

  factory CommissionParty.fromJson(Map<String, dynamic> json) => CommissionParty(
        id: json['id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        name: json['name'] ?? '',
        role: json['role'] ?? 'party',
        roleLabel: json['role_label'],
        advocate: json['advocate'],
        phone: json['phone'],
        noticeStatus: NoticeStatus.fromString(json['notice_status']),
        servedOn: parseDateOrNull(json['served_on']),
        servedHow: json['served_how'],
        attended: json['attended'],
        sortOrder: json['sort_order'] ?? 0,
      );

  /// "1st Defendant" when given, else the role in words.
  String get roleText {
    if (roleLabel != null && roleLabel!.trim().isNotEmpty) return roleLabel!.trim();
    switch (role) {
      case 'plaintiff':
        return 'Plaintiff';
      case 'petitioner':
        return 'Petitioner';
      case 'defendant':
        return 'Defendant';
      case 'respondent':
        return 'Respondent';
      case 'official':
        return 'Official';
      case 'other':
        return 'Other';
      default:
        return 'Party';
    }
  }
}

// ─── Boundaries and extent ────────────────────────────────────

enum AreaUnit {
  sqFt('sq_ft', 'sq ft'),
  sqM('sq_m', 'sq m'),
  cents('cents', 'cents'),
  acres('acres', 'acres'),
  hectares('hectares', 'ha');

  const AreaUnit(this.dbValue, this.short);
  final String dbValue;
  final String short;

  /// Square feet in one unit. 1 cent = 1/100 acre = 435.6 sq ft.
  double get sqFtPerUnit {
    switch (this) {
      case AreaUnit.sqFt:
        return 1;
      case AreaUnit.sqM:
        return 10.7639104;
      case AreaUnit.cents:
        return 435.6;
      case AreaUnit.acres:
        return 43560;
      case AreaUnit.hectares:
        return 107639.104;
    }
  }

  static AreaUnit fromString(String? v) =>
      AreaUnit.values.firstWhere((u) => u.dbValue == v, orElse: () => AreaUnit.sqFt);

  /// [value] in this unit, converted to [to].
  double convert(double value, AreaUnit to) => value * sqFtPerUnit / to.sqFtPerUnit;
}

class CommissionMeasurement {
  final String id;
  final String commissionId;
  final String? visitId;
  final String label;
  final String? northBy, northLen, southBy, southLen, eastBy, eastLen, westBy, westLen;
  final double? extent;
  final AreaUnit unit;
  final double? scheduleExtent;
  final String? notes;
  final int sortOrder;
  final DateTime createdAt;

  CommissionMeasurement({
    required this.id,
    required this.commissionId,
    this.visitId,
    required this.label,
    this.northBy,
    this.northLen,
    this.southBy,
    this.southLen,
    this.eastBy,
    this.eastLen,
    this.westBy,
    this.westLen,
    this.extent,
    this.unit = AreaUnit.sqFt,
    this.scheduleExtent,
    this.notes,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CommissionMeasurement.fromJson(Map<String, dynamic> json) => CommissionMeasurement(
        id: json['id'] ?? '',
        commissionId: json['commission_id'] ?? '',
        visitId: json['visit_id'],
        label: json['label'] ?? 'Schedule property',
        northBy: json['north_by'],
        northLen: json['north_len'],
        southBy: json['south_by'],
        southLen: json['south_len'],
        eastBy: json['east_by'],
        eastLen: json['east_len'],
        westBy: json['west_by'],
        westLen: json['west_len'],
        extent: (json['extent'] as num?)?.toDouble(),
        unit: AreaUnit.fromString(json['extent_unit']),
        scheduleExtent: (json['schedule_extent'] as num?)?.toDouble(),
        notes: json['notes'],
        sortOrder: json['sort_order'] ?? 0,
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
      );

  /// All four sides have something recorded.
  bool get isComplete =>
      [northBy, southBy, eastBy, westBy].every((v) => v != null && v.trim().isNotEmpty) &&
      extent != null;

  /// Found minus schedule, in this measurement's unit.
  double? get difference =>
      extent != null && scheduleExtent != null ? extent! - scheduleExtent! : null;
}

// ─── Where a commission stands ────────────────────────────────

enum CommissionStage {
  warrant('Warrant'),
  notice('Notice'),
  visit('Site visit'),
  record('Record'),
  report('Report'),
  submitted('Submitted');

  const CommissionStage(this.label);
  final String label;
}

/// The commission's progress through its six stages, and the one thing to
/// do next — worked out from what has actually been recorded.
class CommissionProgress {
  final CommissionStage current;
  final String nextTitle;
  final String nextDetail;
  final String nextAction; // notice | visit | record | measure | report | fees | submit | none

  const CommissionProgress(this.current, this.nextTitle, this.nextDetail, this.nextAction);

  int get doneCount => current.index;

  static CommissionProgress of({
    required Commission c,
    required List<CommissionParty> parties,
    required List<CommissionVisit> visits,
    required List<CommissionMeasurement> measurements,
  }) {
    if (c.status == CommissionStatus.submitted ||
        c.status == CommissionStatus.objections ||
        c.status == CommissionStatus.closed) {
      if (c.status == CommissionStatus.objections) {
        return const CommissionProgress(CommissionStage.submitted, 'Answer the objections',
            'Objections were filed to the report. Record your reply or a further inquiry.', 'record');
      }
      return const CommissionProgress(CommissionStage.submitted, 'Report filed',
          'Nothing left to do unless the court calls for more.', 'none');
    }
    final site = c.commissionType.isSiteWork;
    if (parties.isEmpty) {
      return const CommissionProgress(CommissionStage.notice, 'Add the parties to give notice',
          'List each party and their advocate, then fix the date and place.', 'notice');
    }
    if (c.inspectionAt == null) {
      return const CommissionProgress(CommissionStage.notice, 'Fix the date of inspection',
          'Choose when and where you will execute the commission.', 'notice');
    }
    final pending = parties.where((p) => !p.noticeStatus.noticeGiven).length;
    if (pending > 0) {
      return CommissionProgress(CommissionStage.notice,
          'Serve notice on $pending ${pending == 1 ? 'party' : 'parties'}',
          'Mark each party served, refused or informed, with how and when.', 'notice');
    }
    final active = visits.where((v) => v.visitStatus == VisitStatus.checkedIn).toList();
    if (active.isNotEmpty) {
      return const CommissionProgress(CommissionStage.visit, 'Continue the site visit',
          'A visit is open. Finish recording and check out.', 'visit');
    }
    final done = visits.where((v) => v.visitStatus == VisitStatus.completed || v.visitStatus == VisitStatus.obstructed);
    if (done.isEmpty) {
      return CommissionProgress(CommissionStage.visit, site ? 'Start the site visit' : 'Start the sitting',
          site ? 'Check in at the property — time and GPS are recorded.' : 'Open the sitting to record what happens.',
          'visit');
    }
    if (site && measurements.isEmpty) {
      return const CommissionProgress(CommissionStage.record, 'Record boundaries and extent',
          'North, south, east, west and the extent found at site.', 'measure');
    }
    final incomplete = measurements.where((m) => !m.isComplete).toList();
    if (site && incomplete.isNotEmpty) {
      return CommissionProgress(CommissionStage.record, 'Complete ${incomplete.first.label}',
          'Some boundaries or the extent are still missing.', 'measure');
    }
    if (c.status != CommissionStatus.reportDrafting) {
      return const CommissionProgress(CommissionStage.report, 'Prepare the report',
          'Check each section, then preview the report.', 'report');
    }
    return const CommissionProgress(CommissionStage.report, 'File the report',
        'Mark it submitted once it is filed in court.', 'submit');
  }
}
