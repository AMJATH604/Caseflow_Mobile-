import 'enums.dart';
export 'enums.dart';

class CaseModel {
  final String id;
  final String caseTitle;
  final String? caseNumber;
  final String? caseType;
  final String? courtName;
  final String clientId;
  final CaseStatus status;
  final CaseStage stage;
  final DateTime? filingDate;
  final DateTime? nextHearingDate;
  final String createdBy;
  final DateTime createdAt;
  final String? clientName;
  final String? state;
  final String? district;
  final String? cnrNumber;
  final String? firmId;
  final String? assignedTo;
  final RepresentationType representationType;
  final CourtType courtType;
  final String? opposingParty;
  final String? opposingAdvocate;
  final String? opposingAdvocatePhone;
  final String? petitionerAdvocate;
  final String? petitionerAdvocatePhone;

  CaseModel({
    required this.id,
    required this.caseTitle,
    this.caseNumber,
    this.caseType,
    this.courtName,
    required this.clientId,
    this.status = CaseStatus.active,
    this.stage = CaseStage.filing,
    this.filingDate,
    this.nextHearingDate,
    required this.createdBy,
    required this.createdAt,
    this.clientName,
    this.state,
    this.district,
    this.cnrNumber,
    this.firmId,
    this.assignedTo,
    this.representationType = RepresentationType.petitioner,
    this.courtType = CourtType.trial,
    this.opposingParty,
    this.opposingAdvocate,
    this.opposingAdvocatePhone,
    this.petitionerAdvocate,
    this.petitionerAdvocatePhone,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) => CaseModel(
        id: json['id'] ?? '',
        caseTitle: json['case_title'] ?? '',
        caseNumber: json['case_number'],
        caseType: json['case_type'],
        courtName: json['court_name'],
        clientId: json['client_id'] ?? '',
        status: CaseStatus.fromString(json['status'] ?? 'active'),
        stage: CaseStage.fromString(json['stage'] ?? 'filing'),
        filingDate: json['filing_date'] != null ? DateTime.parse(json['filing_date']) : null,
        nextHearingDate: json['next_hearing_date'] != null ? DateTime.parse(json['next_hearing_date']) : null,
        createdBy: json['created_by'] ?? '',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
        clientName: json['clients'] != null ? json['clients']['name'] : null,
        state: json['state'],
        district: json['district'],
        cnrNumber: json['cnr_number'],
        firmId: json['firm_id'],
        assignedTo: json['assigned_to'],
        representationType: json['representation_type'] != null 
            ? RepresentationType.fromString(json['representation_type'])
            : RepresentationType.petitioner,
        courtType: json['court_type'] != null
            ? CourtType.fromString(json['court_type'])
            : CourtType.trial,
        opposingParty: json['opposing_party'],
        opposingAdvocate: json['opposing_advocate'],
        opposingAdvocatePhone: json['opposing_advocate_phone'],
        petitionerAdvocate: json['petitioner_advocate'],
        petitionerAdvocatePhone: json['petitioner_advocate_phone'],
      );

  bool isTeamCase(String userId) {
    // If firmId exists and it's NOT the user's ID, it's a team case
    return firmId != null && firmId != userId;
  }
}

class ClientModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String createdBy;
  final String createdAt;

  ClientModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    required this.createdBy,
    required this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'],
        phone: json['phone'],
        address: json['address'],
        createdBy: json['created_by'] ?? '',
        createdAt: json['created_at'] ?? '',
      );
}

class Hearing {
  final String id;
  final String caseId;
  final DateTime hearingDate;
  final String? stage;
  final String? notes;
  final String? nextAction;
  final String createdBy;
  final String status;
  final String? purpose;
  final String? caseTitle;
  final String? courtName;
  final String? caseNumber;
  final String? firmId;
  final String? judgeName;
  final DateTime? nextDate;
  final String? businessDone;

  Hearing({
    required this.id,
    required this.caseId,
    required this.hearingDate,
    this.stage,
    this.notes,
    this.nextAction,
    required this.createdBy,
    this.status = "scheduled",
    this.purpose,
    this.caseTitle,
    this.courtName,
    this.caseNumber,
    this.firmId,
    this.judgeName,
    this.nextDate,
    this.businessDone,
  });

  factory Hearing.fromJson(Map<String, dynamic> json) => Hearing(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        hearingDate: DateTime.parse(json['hearing_date'] ?? DateTime.now().toIso8601String()),
        stage: json['stage'],
        notes: json['notes'],
        nextAction: json['next_action'],
        createdBy: json['created_by'] ?? '',
        status: json['status'] ?? "scheduled",
        purpose: json['purpose'],
        caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
        courtName: json['cases'] != null ? json['cases']['court_name'] : null,
        caseNumber: json['cases'] != null ? json['cases']['case_number'] : null,
        firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
        judgeName: json['judge_name'],
        nextDate: json['next_date'] != null ? DateTime.parse(json['next_date']) : null,
        businessDone: json['business_done'],
      );

  bool isTeamCase(String userId) => firmId != null && firmId != userId;
}

class EFilingRecord {
  final String id;
  final String caseId;
  final String documentType;
  final FilingStatus status;
  final DateTime? filingDate;
  final String createdBy;
  final String? caseTitle;
  final String? defectNotes;
  final String? firmId;

  EFilingRecord({
    required this.id,
    required this.caseId,
    required this.documentType,
    required this.status,
    this.filingDate,
    required this.createdBy,
    this.caseTitle,
    this.defectNotes,
    this.firmId,
  });

  factory EFilingRecord.fromJson(Map<String, dynamic> json) => EFilingRecord(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        documentType: json['document_type'] ?? '',
        status: FilingStatus.fromString(json['status'] ?? 'drafting'),
        filingDate: json['filing_date'] != null ? DateTime.parse(json['filing_date']) : null,
        createdBy: json['created_by'] ?? '',
        caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
        defectNotes: json['defect_notes'],
        firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
      );

  bool isTeamCase(String userId) => firmId != null && firmId != userId;
}

class Payment {
  final String id;
  final String caseId;
  final double totalFee;
  final double paidAmount;
  final double balanceAmount;
  final DateTime? paidDate;
  final String? paymentMode;
  final String createdBy;
  final String? caseTitle;
  final String? firmId;
  final String? notes;
  final String transactionType; // 'revenue' or 'expense'

  Payment({
    required this.id,
    required this.caseId,
    required this.totalFee,
    required this.paidAmount,
    required this.balanceAmount,
    this.paidDate,
    this.paymentMode,
    required this.createdBy,
    this.caseTitle,
    this.firmId,
    this.notes,
    this.transactionType = 'revenue',
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        totalFee: (json['total_fee'] ?? 0).toDouble(),
        paidAmount: (json['paid_amount'] ?? 0).toDouble(),
        balanceAmount: (json['balance_amount'] ?? 0).toDouble(),
        paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date']) : null,
        paymentMode: json['payment_mode'],
        createdBy: json['created_by'] ?? '',
        caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
        firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
        notes: json['notes'],
        transactionType: json['transaction_type'] ?? 'revenue',
      );

  bool isTeamCase(String userId) => firmId != null && firmId != userId;
}

class CertifiedCopy {
  final String id;
  final String caseId;
  final String? caNumber;
  final DateTime? boxDropDate;
  final DateTime? memoDate;
  final DateTime? readyDate;
  final DateTime? collectedDate;
  final String status;
  final String createdBy;
  final String? caseTitle;
  final String? firmId;
  final double? paidAmount;
  final String? portalReceiptUrl;

  CertifiedCopy({
    required this.id,
    required this.caseId,
    this.caNumber,
    this.boxDropDate,
    this.memoDate,
    this.readyDate,
    this.collectedDate,
    this.status = "box_drop",
    required this.createdBy,
    this.caseTitle,
    this.firmId,
    this.paidAmount,
    this.portalReceiptUrl,
  });

  factory CertifiedCopy.fromJson(Map<String, dynamic> json) => CertifiedCopy(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        caNumber: json['ca_number'],
        boxDropDate: json['box_drop_date'] != null ? DateTime.parse(json['box_drop_date']) : null,
        memoDate: json['memo_date'] != null ? DateTime.parse(json['memo_date']) : null,
        readyDate: json['ready_date'] != null ? DateTime.parse(json['ready_date']) : null,
        collectedDate: json['collected_date'] != null ? DateTime.parse(json['collected_date']) : null,
        status: json['status'] ?? 'box_drop',
        createdBy: json['created_by'] ?? '',
        caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
        firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
        paidAmount: json['paid_amount'] != null ? (json['paid_amount'] as num).toDouble() : null,
        portalReceiptUrl: json['portal_receipt_url'],
      );

  bool isTeamCase(String userId) => firmId != null && firmId != userId;
}

class TaskModel {
  final String id;
  final String title;
  final bool isCompleted;
  final String createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        isCompleted: json['is_completed'] ?? false,
        createdAt: json['created_at'] ?? '',
      );
}

class EvidenceChecklist {
  final String id;
  final String caseId;
  final String itemType;
  final String itemName;
  final bool isCompleted;
  final DateTime createdAt;

  EvidenceChecklist({
    required this.id,
    required this.caseId,
    required this.itemType,
    required this.itemName,
    this.isCompleted = false,
    required this.createdAt,
  });

  factory EvidenceChecklist.fromJson(Map<String, dynamic> json) => EvidenceChecklist(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        itemType: json['item_type'] ?? 'pending',
        itemName: json['item_name'] ?? '',
        isCompleted: json['is_completed'] ?? false,
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}

class WitnessNote {
  final String id;
  final String caseId;
  final String witnessTag;
  final String witnessName;
  final String? notes;
  final DateTime createdAt;

  WitnessNote({
    required this.id,
    required this.caseId,
    required this.witnessTag,
    required this.witnessName,
    this.notes,
    required this.createdAt,
  });

  factory WitnessNote.fromJson(Map<String, dynamic> json) => WitnessNote(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        witnessTag: json['witness_tag'] ?? '',
        witnessName: json['witness_name'] ?? '',
        notes: json['notes'],
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}

class EvidencePhoto {
  final String id;
  final String caseId;
  final String photoUrl;
  final String? description;
  final List<String> tags;
  final DateTime createdAt;

  EvidencePhoto({
    required this.id,
    required this.caseId,
    required this.photoUrl,
    this.description,
    this.tags = const [],
    required this.createdAt,
  });

  factory EvidencePhoto.fromJson(Map<String, dynamic> json) => EvidencePhoto(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        photoUrl: json['file_url'] ?? json['photo_url'] ?? '',
        description: json['description'],
        tags: List<String>.from(json['tags'] ?? []),
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}

class UserProfile {
  final String id;
  final String? fullName;
  final String subscriptionTier;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String? firmId;
  final String? email;
  
  // New Professional Fields for Directory
  final String? mobileNumber;
  final String? registrationNumber;
  final String? practiceState;
  final String? practiceDistrict;
  final String? officeAddress;
  final bool isPublicDirectoryEnabled;

  UserProfile({
    required this.id,
    this.fullName,
    this.subscriptionTier = 'free',
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.firmId,
    this.email,
    this.mobileNumber,
    this.registrationNumber,
    this.practiceState,
    this.practiceDistrict,
    this.officeAddress,
    this.isPublicDirectoryEnabled = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? '',
        fullName: json['full_name'],
        subscriptionTier: json['subscription_tier'] ?? 'free',
        trialEndsAt: json['trial_ends_at'] != null ? DateTime.parse(json['trial_ends_at']) : null,
        currentPeriodEnd: json['current_period_end'] != null ? DateTime.parse(json['current_period_end']) : null,
        firmId: json['firm_id'],
        email: json['email'],
        mobileNumber: json['mobile_number'],
        registrationNumber: json['registration_number'],
        practiceState: json['practice_state'],
        practiceDistrict: json['practice_district'],
        officeAddress: json['office_address'],
        isPublicDirectoryEnabled: json['is_public_directory_enabled'] ?? true,
      );

  /// Feature gating: Based on subscription tier from the database.
  /// Respects trial periods and subscription expiration.
  bool get isPro => true; // Unlocked: Free for all mode enabled

  bool get isBusiness => true; // Unlocked: Free for all mode enabled

  bool get isFirmOwner => firmId == null;

  // Data visibility: true if the user has joined someone else's firm
  bool get isFirmMember => firmId != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'subscription_tier': subscriptionTier,
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'current_period_end': currentPeriodEnd?.toIso8601String(),
    'firm_id': firmId,
    'email': email,
    'mobile_number': mobileNumber,
    'registration_number': registrationNumber,
    'practice_state': practiceState,
    'practice_district': practiceDistrict,
    'office_address': officeAddress,
    'is_public_directory_enabled': isPublicDirectoryEnabled,
  };
}


class FirmMember {
  final String id;
  final String ownerId;
  final String memberEmail;
  final String? memberId;
  final String role;
  final String status;
  final DateTime createdAt;
  final String? memberName;
  final String? ownerName;

  FirmMember({
    required this.id,
    required this.ownerId,
    required this.memberEmail,
    this.memberId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.memberName,
    this.ownerName,
  });

  factory FirmMember.fromJson(Map<String, dynamic> json) => FirmMember(
        id: json['id'] ?? '',
        ownerId: json['owner_id'] ?? '',
        memberEmail: json['member_email'] ?? '',
        memberId: json['member_id'],
        role: json['role'] ?? 'member',
        status: json['status'] ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
        memberName: json['profiles'] != null ? json['profiles']['full_name'] : null,
        ownerName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      );
}

class CaseComment {
  final String id;
  final String? caseId;
  final String firmId;
  final String senderId;
  final String message;
  final bool isSystem;
  final DateTime createdAt;
  final String? senderName;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', 'document', 'file'

  CaseComment({
    required this.id,
    this.caseId,
    required this.firmId,
    required this.senderId,
    required this.message,
    this.isSystem = false,
    required this.createdAt,
    this.senderName,
    this.attachmentUrl,
    this.attachmentType,
  });

  factory CaseComment.fromJson(Map<String, dynamic> json) => CaseComment(
        id: json['id'] ?? '',
        caseId: json['case_id'],
        firmId: json['firm_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        message: json['message'] ?? '',
        isSystem: json['is_system'] ?? false,
        createdAt: _parseUtc(json['created_at']),
        senderName: json['sender_name'] ?? (json['profiles'] != null ? json['profiles']['full_name'] : null),
        attachmentUrl: json['attachment_url'],
        attachmentType: json['attachment_type'],
      );

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => attachmentType == 'image';

  static DateTime _parseUtc(dynamic value) {
    if (value == null) return DateTime.now().toUtc();
    final dt = DateTime.parse(value.toString());
    return dt.isUtc ? dt : dt.toUtc();
  }
}

class CaseCollaboration {
  final String id;
  final String caseId;
  final String? collaboratorId;
  final String collaboratorEmail;
  final String status;
  final DateTime createdAt;
  final String? caseTitle; // Joined from cases

  CaseCollaboration({
    required this.id,
    required this.caseId,
    this.collaboratorId,
    required this.collaboratorEmail,
    required this.status,
    required this.createdAt,
    this.caseTitle,
  });

  factory CaseCollaboration.fromJson(Map<String, dynamic> json) => CaseCollaboration(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        collaboratorId: json['collaborator_id'],
        collaboratorEmail: json['collaborator_email'] ?? '',
        status: json['status'] ?? 'pending',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
        caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
      );
}

extension DateTimeIST on DateTime {
  DateTime toIST() => toUtc().add(const Duration(hours: 5, minutes: 30));
}

class LegalTemplate {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String? pdfUrl;
  final String? docxUrl;

  LegalTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.pdfUrl,
    this.docxUrl,
  });

  factory LegalTemplate.fromJson(Map<String, dynamic> json) => LegalTemplate(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'],
        category: json['category'] ?? 'General',
        pdfUrl: json['pdf_url'] ?? json['file_url'],
        docxUrl: json['docx_url'],
      );
}
