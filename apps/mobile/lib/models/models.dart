import '../utils/safe_date.dart';
import 'enums.dart';
import '../components/chat/chat_message_data.dart';
export 'enums.dart';
export 'direct_message_models.dart';


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
    filingDate:
        parseDateOrNull(json['filing_date']),
    nextHearingDate:
        parseDateOrNull(json['next_hearing_date']),
    createdBy: json['created_by'] ?? '',
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
    clientName: json['clients'] != null ? json['clients']['name'] : null,
    state: json['state'],
    district: json['district'],
    cnrNumber: json['cnr_number'],
    firmId: json['firm_id'],
    assignedTo: json['assigned_to'],
    representationType:
        json['representation_type'] != null
            ? RepresentationType.fromString(json['representation_type'])
            : RepresentationType.petitioner,
    courtType:
        json['court_type'] != null
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'case_title': caseTitle,
    'case_number': caseNumber,
    'case_type': caseType,
    'court_name': courtName,
    'client_id': clientId,
    'status': status.name,
    'stage': stage.name,
    'filing_date': filingDate?.toIso8601String(),
    'next_hearing_date': nextHearingDate?.toIso8601String(),
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'state': state,
    'district': district,
    'cnr_number': cnrNumber,
    'firm_id': firmId,
    'assigned_to': assignedTo,
    'representation_type': representationType.name,
    'court_type': courtType.name,
    'opposing_party': opposingParty,
    'opposing_advocate': opposingAdvocate,
    'opposing_advocate_phone': opposingAdvocatePhone,
    'petitioner_advocate': petitionerAdvocate,
    'petitioner_advocate_phone': petitionerAdvocatePhone,
    if (clientName != null) 'clients': {'name': clientName},
  };
}

class ClientModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? state;
  final String? district;
  final String createdBy;
  final DateTime createdAt;
  final String? firmId;
  final int caseCount; // Joined count from cases table

  ClientModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.state,
    this.district,
    required this.createdBy,
    required this.createdAt,
    this.firmId,
    this.caseCount = 0,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'],
    phone: json['phone'],
    address: json['address'],
    state: json['state'],
    district: json['district'],
    createdBy: json['created_by'] ?? '',
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
    firmId: json['firm_id'],
    caseCount:
        json['case_count'] is int
            ? json['case_count']
            : (json['cases'] is List ? (json['cases'] as List).length : 0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'state': state,
    'district': district,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'firm_id': firmId,
  };

  /// Whether this client has any active cases
  bool get hasActiveCases => caseCount > 0;
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
    this.status = 'scheduled',
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
    hearingDate: parseDateOr(json['hearing_date'], DateTime.now()),
    stage: json['stage'],
    notes: json['notes'],
    nextAction: json['next_action'],
    createdBy: json['created_by'] ?? '',
    status: json['status'] ?? 'scheduled',
    purpose: json['purpose'],
    caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
    courtName: json['cases'] != null ? json['cases']['court_name'] : null,
    caseNumber: json['cases'] != null ? json['cases']['case_number'] : null,
    firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
    judgeName: json['judge_name'],
    nextDate:
        parseDateOrNull(json['next_date']),
    businessDone: json['business_done'],
  );

  bool isTeamCase(String userId) => firmId != null && firmId != userId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'case_id': caseId,
    'hearing_date': hearingDate.toIso8601String(),
    'stage': stage,
    'notes': notes,
    'next_action': nextAction,
    'created_by': createdBy,
    'status': status,
    'purpose': purpose,
    'judge_name': judgeName,
    'next_date': nextDate?.toIso8601String(),
    'business_done': businessDone,
    if (caseTitle != null || caseNumber != null || firmId != null)
      'cases': {
        'case_title': caseTitle,
        'case_number': caseNumber,
        'court_name': courtName,
        'firm_id': firmId,
      },
  };
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
    filingDate:
        parseDateOrNull(json['filing_date']),
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
    paidDate:
        parseDateOrNull(json['paid_date']),
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

  /// The court's case number (e.g. `DVC/13/2025`) — how advocates actually
  /// identify a case. Distinct from [caNumber], which is the certified-copy
  /// application number. Already joined by the query in FilingRepository.
  final String? caseNumber;
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
    this.status = 'box_drop',
    required this.createdBy,
    this.caseTitle,
    this.caseNumber,
    this.firmId,
    this.paidAmount,
    this.portalReceiptUrl,
  });

  factory CertifiedCopy.fromJson(Map<String, dynamic> json) => CertifiedCopy(
    id: json['id'] ?? '',
    caseId: json['case_id'] ?? '',
    caNumber: json['ca_number'],
    boxDropDate:
        parseDateOrNull(json['box_drop_date']),
    memoDate:
        parseDateOrNull(json['memo_date']),
    readyDate:
        parseDateOrNull(json['ready_date']),
    collectedDate:
        parseDateOrNull(json['collected_date']),
    status: json['status'] ?? 'box_drop',
    createdBy: json['created_by'] ?? '',
    caseTitle: json['cases'] != null ? json['cases']['case_title'] : null,
    caseNumber: json['cases'] != null ? json['cases']['case_number'] : null,
    firmId: json['cases'] != null ? json['cases']['firm_id'] : null,
    paidAmount:
        json['paid_amount'] != null
            ? (json['paid_amount'] as num).toDouble()
            : null,
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

  factory EvidenceChecklist.fromJson(Map<String, dynamic> json) =>
      EvidenceChecklist(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        itemType: json['item_type'] ?? 'pending',
        itemName: json['item_name'] ?? '',
        isCompleted: json['is_completed'] ?? false,
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
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
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
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
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
  );
}

class UserProfile {
  final String id;
  final String? fullName;
  final String subscriptionTier;
  final String userRole; // 'advocate' or 'citizen'
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEnd;
  final String? firmId;
  final String? email;
  final String? avatarUrl;

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
    this.userRole = 'advocate',
    this.trialEndsAt,
    this.currentPeriodEnd,
    this.firmId,
    this.email,
    this.avatarUrl,
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
    userRole: json['user_role'] ?? 'advocate',
    trialEndsAt:
        parseDateOrNull(json['trial_ends_at']),
    currentPeriodEnd:
        parseDateOrNull(json['current_period_end']),
    firmId: json['firm_id'],
    email: json['email'],
    avatarUrl: json['avatar_url'],
    mobileNumber: json['mobile_number'],
    registrationNumber: json['registration_number'],
    practiceState: json['practice_state'],
    practiceDistrict: json['practice_district'],
    officeAddress: json['office_address'],
    isPublicDirectoryEnabled: json['is_public_directory_enabled'] ?? true,
  );

  /// Feature gating: Based on subscription tier from the database.
  /// Respects trial periods and subscription expiration.
  ///
  /// Tier hierarchy: free < pro < business
  /// Access is granted if:
  ///   1. The user's tier matches or exceeds the required level, AND
  ///   2. The subscription has not expired (currentPeriodEnd is in the future), OR
  ///   3. The user is within an active trial period (trialEndsAt is in the future)

  /// Role-based access helpers
  bool get isAdvocate => userRole == 'advocate';
  bool get isCitizen => userRole == 'citizen';

  /// Whether the user's trial period is still active.
  bool get isTrialActive {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  /// Whether the user has an active paid subscription (not expired).
  bool get isSubscriptionActive {
    if (currentPeriodEnd == null) return false;
    return DateTime.now().isBefore(currentPeriodEnd!);
  }

  /// Pro-tier access: Grants access to AI chat, advanced tools, unlimited cases.
  /// True if user has 'pro' or 'business' tier with active subscription or trial.
  bool get isPro {
    if (subscriptionTier == 'pro' || subscriptionTier == 'business') {
      return isSubscriptionActive || isTrialActive;
    }
    // Free tier users can access Pro features only during trial
    return isTrialActive;
  }

  /// Business-tier access: Grants firm management, multi-advocate, API access.
  /// True if user has 'business' tier with active subscription or trial.
  bool get isBusiness {
    if (subscriptionTier == 'business') {
      return isSubscriptionActive || isTrialActive;
    }
    return false;
  }

  bool get isFirmOwner => firmId == null;

  // Data visibility: true if the user has joined someone else's firm
  bool get isFirmMember => firmId != null;

  /// Whether the user is on the free tier (no active subscription or trial).
  bool get isFree => !isPro && !isBusiness;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'subscription_tier': subscriptionTier,
    'user_role': userRole,
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'current_period_end': currentPeriodEnd?.toIso8601String(),
    'firm_id': firmId,
    'email': email,
    'avatar_url': avatarUrl,
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
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
    memberName: json['profiles'] != null ? json['profiles']['full_name'] : null,
    ownerName: json['profiles'] != null ? json['profiles']['full_name'] : null,
  );
}

/// A firm the current user has joined as an associate, with its senior and
/// accepted associates. Names only — see `get_my_senior_firms` on the server.
class SeniorFirm {
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final DateTime joinedAt;
  final List<TeamMate> teammates;

  const SeniorFirm({
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    required this.joinedAt,
    this.teammates = const [],
  });

  factory SeniorFirm.fromJson(Map<String, dynamic> json) => SeniorFirm(
    ownerId: json['owner_id'] ?? '',
    ownerName: json['owner_name'] ?? 'Senior Advocate',
    ownerAvatarUrl: json['owner_avatar_url'],
    joinedAt: parseDateOr(json['joined_at'], DateTime.now()),
    teammates: ((json['teammates'] as List?) ?? const [])
        .map((t) => TeamMate.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
}

class TeamMate {
  final String memberId;
  final String name;
  final String? avatarUrl;
  final bool isMe;

  const TeamMate({
    required this.memberId,
    required this.name,
    this.avatarUrl,
    this.isMe = false,
  });

  factory TeamMate.fromJson(Map<String, dynamic> json) => TeamMate(
    memberId: json['member_id'] ?? '',
    name: json['name'] ?? 'Associate',
    avatarUrl: json['avatar_url'],
    isMe: json['is_me'] == true,
  );
}

class CaseComment with ChatMessageData {
  final String id;
  final String? caseId;
  final String firmId;
  final String senderId;
  final String message;
  final bool isSystem;
  final DateTime createdAt;
  final String? senderName;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', 'document', 'file', 'video'
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSender;
  @override
  final DateTime? editedAt;

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
    this.replyToId,
    this.replyToMessage,
    this.replyToSender,
    this.editedAt,
  });

  factory CaseComment.fromJson(Map<String, dynamic> json) => CaseComment(
    id: json['id'] ?? '',
    caseId: json['case_id'],
    firmId: json['firm_id'] ?? '',
    senderId: json['sender_id'] ?? '',
    message: json['message'] ?? '',
    isSystem: json['is_system'] ?? false,
    createdAt: _parseUtc(json['created_at']),
    senderName:
        json['sender_name'] ??
        (json['profiles'] != null ? json['profiles']['full_name'] : null),
    attachmentUrl: json['attachment_url'],
    attachmentType: json['attachment_type'],
    replyToId: json['reply_to_id'],
    replyToMessage: json['reply_to_message'],
    replyToSender: json['reply_to_sender'],
    editedAt: json['edited_at'] != null ? parseDateOrNull(json['edited_at']) : null,
  );

  // hasAttachment, isImage, isVideo, hasReply are inherited from ChatMessageData

  static DateTime _parseUtc(dynamic value) {
    // Already fell back on a missing value; a malformed one now falls back
    // too, instead of throwing and failing the whole message query.
    final dt = parseDateOrNull(value) ?? DateTime.now();
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

  factory CaseCollaboration.fromJson(Map<String, dynamic> json) =>
      CaseCollaboration(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        collaboratorId: json['collaborator_id'],
        collaboratorEmail: json['collaborator_email'] ?? '',
        status: json['status'] ?? 'pending',
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
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
