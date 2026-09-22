/// Bar Association Management System — Data Models
///
/// All models follow the existing CaseFlow pattern:
/// - `fromJson` factory constructor for Supabase deserialization
/// - `toJson` method for Supabase serialization
/// - Immutable fields with named constructor parameters
library;

import '../utils/safe_date.dart';

class BarAssociation {
  final String id;
  final String name;
  final String district;
  final String court;
  final String? address;
  final String? logoUrl;
  final double annualFee;
  final String inviteCode;
  final String subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  final DateTime createdAt;
  final int? memberCount;

  BarAssociation({
    required this.id,
    required this.name,
    required this.district,
    required this.court,
    this.address,
    this.logoUrl,
    this.annualFee = 500.0,
    required this.inviteCode,
    this.subscriptionPlan = 'starter',
    this.subscriptionExpiresAt,
    required this.createdAt,
    this.memberCount,
  });

  factory BarAssociation.fromJson(Map<String, dynamic> json) => BarAssociation(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    district: json['district'] ?? '',
    court: json['court'] ?? '',
    address: json['address'],
    logoUrl: json['logo_url'],
    annualFee: (json['annual_fee'] ?? 500.0).toDouble(),
    inviteCode: json['invite_code'] ?? '',
    subscriptionPlan: json['subscription_plan'] ?? 'starter',
    subscriptionExpiresAt: parseDateOrNull(json['subscription_expires_at']),
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
    memberCount: json['member_count'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'district': district,
    'court': court,
    'address': address,
    'logo_url': logoUrl,
    'annual_fee': annualFee,
    'invite_code': inviteCode,
    'subscription_plan': subscriptionPlan,
  };
}

class BarMember {
  final String id;
  final String associationId;
  final String? userId;
  final String name;
  final String? enrollmentNumber;
  final String mobile;
  final String? email;
  final String? photoUrl;
  final String membershipType;
  final String status;
  final int? joinedYear;
  final int? feePaidUntil;
  final bool isCaseflowUser;
  final DateTime createdAt;

  /// When the membership lapses. A lapsed membership is why a welfare claim
  /// gets refused, so this is the date the app counts down to.
  final DateTime? membershipExpiresOn;
  final String? enrolmentDateIso;
  final String welfareFundStatus;
  final String? welfareFundNumber;
  final String? idCardNumber;
  final DateTime? idCardValidUntil;
  final String memberClass;
  final String? bloodGroup;

  BarMember({
    required this.id,
    required this.associationId,
    this.userId,
    required this.name,
    this.enrollmentNumber,
    required this.mobile,
    this.email,
    this.photoUrl,
    this.membershipType = 'regular',
    this.status = 'active',
    this.joinedYear,
    this.feePaidUntil,
    this.isCaseflowUser = false,
    required this.createdAt,
    this.membershipExpiresOn,
    this.enrolmentDateIso,
    this.welfareFundStatus = 'unknown',
    this.welfareFundNumber,
    this.idCardNumber,
    this.idCardValidUntil,
    this.memberClass = 'advocate',
    this.bloodGroup,
  });

  /// Days until the membership lapses; negative once it has. Null when the
  /// association has not recorded an expiry.
  int? get daysUntilExpiry {
    final expiry = membershipExpiresOn;
    if (expiry == null) return null;
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(expiry.year, expiry.month, expiry.day);
    return b.difference(a).inDays;
  }

  bool get hasLapsed => (daysUntilExpiry ?? 1) < 0;

  /// Inside the window where renewing still protects a welfare claim.
  bool get isLapsingSoon {
    final d = daysUntilExpiry;
    return d != null && d >= 0 && d <= 30;
  }

  bool get isClerk => memberClass == 'clerk';

  bool get hasValidIdCard {
    final until = idCardValidUntil;
    return idCardNumber != null &&
        until != null &&
        until.isAfter(DateTime.now());
  }

  String get welfareFundLabel {
    switch (welfareFundStatus) {
      case 'active':
        return 'Active';
      case 'arrears':
        return 'In arrears';
      case 'not_enrolled':
        return 'Not enrolled';
      case 'retired':
        return 'Retired';
      case 'claimed':
        return 'Claimed';
      default:
        return 'Not recorded';
    }
  }

  bool get isFeePaidForCurrentYear {
    final currentYear = DateTime.now().year;
    return feePaidUntil != null && feePaidUntil! >= currentYear;
  }

  String get membershipTypeLabel {
    switch (membershipType) {
      case 'regular':
        return 'Regular';
      case 'life':
        return 'Life Member';
      case 'honorary':
        return 'Honorary';
      case 'student':
        return 'Student';
      default:
        return membershipType;
    }
  }

  factory BarMember.fromJson(Map<String, dynamic> json) => BarMember(
    id: json['id'] ?? '',
    associationId: json['association_id'] ?? '',
    userId: json['user_id'],
    name: json['name'] ?? '',
    enrollmentNumber: json['enrollment_number'],
    mobile: json['mobile'] ?? '',
    email: json['email'],
    photoUrl: json['photo_url'],
    membershipExpiresOn: json['membership_expires_on'] != null
        ? DateTime.parse(json['membership_expires_on'])
        : null,
    enrolmentDateIso: json['enrolment_date'],
    welfareFundStatus: json['welfare_fund_status'] ?? 'unknown',
    welfareFundNumber: json['welfare_fund_number'],
    idCardNumber: json['id_card_number'],
    idCardValidUntil: json['id_card_valid_until'] != null
        ? DateTime.parse(json['id_card_valid_until'])
        : null,
    memberClass: json['member_class'] ?? 'advocate',
    bloodGroup: json['blood_group'],
    membershipType: json['membership_type'] ?? 'regular',
    status: json['status'] ?? 'active',
    joinedYear: json['joined_year'],
    feePaidUntil: json['fee_paid_until'],
    isCaseflowUser: json['is_caseflow_user'] ?? false,
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
  );

  Map<String, dynamic> toJson() => {
    'association_id': associationId,
    'user_id': userId,
    'name': name,
    'enrollment_number': enrollmentNumber,
    'mobile': mobile,
    'email': email,
    'photo_url': photoUrl,
    'membership_type': membershipType,
    'status': status,
    'joined_year': joinedYear,
    'fee_paid_until': feePaidUntil,
    'is_caseflow_user': isCaseflowUser,
  };
}

class BarNotice {
  final String id;
  final String associationId;
  final String title;
  final String body;
  final String category;
  final bool isPinned;
  final String? publishedBy;
  final DateTime publishedAt;
  final DateTime? scheduledFor;
  final bool fcmSent;
  final int readCount;
  final DateTime createdAt;
  final bool isRead;

  BarNotice({
    required this.id,
    required this.associationId,
    required this.title,
    required this.body,
    this.category = 'general',
    this.isPinned = false,
    this.publishedBy,
    required this.publishedAt,
    this.scheduledFor,
    this.fcmSent = false,
    this.readCount = 0,
    required this.createdAt,
    this.isRead = false,
  });

  String get categoryLabel {
    switch (category) {
      case 'general':
        return 'General';
      case 'urgent':
        return '🔴 Urgent';
      case 'event':
        return '📅 Event';
      case 'holiday':
        return '🏖️ Holiday';
      default:
        return category;
    }
  }

  factory BarNotice.fromJson(Map<String, dynamic> json, {bool isRead = false}) =>
      BarNotice(
        id: json['id'] ?? '',
        associationId: json['association_id'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        category: json['category'] ?? 'general',
        isPinned: json['is_pinned'] ?? false,
        publishedBy: json['published_by'],
        publishedAt: parseDateOr(json['published_at'], DateTime.now()),
        scheduledFor: parseDateOrNull(json['scheduled_for']),
        fcmSent: json['fcm_sent'] ?? false,
        readCount: json['read_count'] ?? 0,
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
        isRead: isRead,
      );

  Map<String, dynamic> toJson() => {
    'association_id': associationId,
    'title': title,
    'body': body,
    'category': category,
    'is_pinned': isPinned,
    'published_by': publishedBy,
    'scheduled_for': scheduledFor?.toIso8601String(),
  };
}

class BarFeePayment {
  final String id;
  final String associationId;
  final String memberId;
  final double amount;
  final int feeYear;
  final String paymentMethod;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String status;
  final String? receiptNumber;
  final DateTime? paidAt;
  final DateTime createdAt;

  BarFeePayment({
    required this.id,
    required this.associationId,
    required this.memberId,
    required this.amount,
    required this.feeYear,
    this.paymentMethod = 'razorpay',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.status = 'pending',
    this.receiptNumber,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status == 'paid';

  factory BarFeePayment.fromJson(Map<String, dynamic> json) => BarFeePayment(
    id: json['id'] ?? '',
    associationId: json['association_id'] ?? '',
    memberId: json['member_id'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    feeYear: json['fee_year'] ?? DateTime.now().year,
    paymentMethod: json['payment_method'] ?? 'razorpay',
    razorpayOrderId: json['razorpay_order_id'],
    razorpayPaymentId: json['razorpay_payment_id'],
    status: json['status'] ?? 'pending',
    receiptNumber: json['receipt_number'],
    paidAt: parseDateOrNull(json['paid_at']),
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
  );

  Map<String, dynamic> toJson() => {
    'association_id': associationId,
    'member_id': memberId,
    'amount': amount,
    'fee_year': feeYear,
    'payment_method': paymentMethod,
    'razorpay_order_id': razorpayOrderId,
    'razorpay_payment_id': razorpayPaymentId,
    'status': status,
    'receipt_number': receiptNumber,
    'paid_at': paidAt?.toIso8601String(),
  };
}

/// A death announced by the association.
///
/// Separate from a notice: the shape is fixed, the association keeps it as a
/// record, and by convention the bar does not take up work that day — so the
/// meeting time matters as much as the fact.
class BarCondolence {
  final String id;
  final String associationId;
  final String? memberId;
  final String deceasedName;
  final String? enrolmentNumber;
  final DateTime dateOfDeath;
  final int? age;
  final String? message;
  final DateTime? meetingAt;
  final String? meetingVenue;
  final bool noWorkResolution;
  final DateTime publishedAt;

  BarCondolence({
    required this.id,
    required this.associationId,
    this.memberId,
    required this.deceasedName,
    this.enrolmentNumber,
    required this.dateOfDeath,
    this.age,
    this.message,
    this.meetingAt,
    this.meetingVenue,
    required this.noWorkResolution,
    required this.publishedAt,
  });

  factory BarCondolence.fromJson(Map<String, dynamic> json) => BarCondolence(
    id: json['id'] ?? '',
    associationId: json['association_id'] ?? '',
    memberId: json['member_id'],
    deceasedName: json['deceased_name'] ?? '',
    enrolmentNumber: json['enrolment_number'],
    dateOfDeath: DateTime.parse(json['date_of_death']),
    age: json['age'],
    message: json['message'],
    meetingAt: json['meeting_at'] != null
        ? DateTime.parse(json['meeting_at']).toLocal()
        : null,
    meetingVenue: json['meeting_venue'],
    noWorkResolution: json['no_work_resolution'] ?? false,
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at']).toLocal()
        : DateTime.now(),
  );

  /// Today's condolences are the ones that change whether an advocate goes
  /// to court, so the UI leads with them.
  bool get isToday {
    final now = DateTime.now();
    return dateOfDeath.year == now.year &&
        dateOfDeath.month == now.month &&
        dateOfDeath.day == now.day;
  }
}

class BarEvent {
  final String id;
  final String associationId;
  final String title;
  final String? description;
  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? agenda;
  final String category;
  final String? createdBy;
  final DateTime createdAt;

  BarEvent({
    required this.id,
    required this.associationId,
    required this.title,
    this.description,
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.location,
    this.agenda,
    this.category = 'meeting',
    this.createdBy,
    required this.createdAt,
  });

  String get categoryLabel {
    switch (category) {
      case 'meeting':
        return '📋 Meeting';
      case 'holiday':
        return '🏖️ Court Holiday';
      case 'lecture':
        return '🎓 Lecture';
      case 'sports':
        return '🏏 Sports';
      case 'annual':
        return '🎉 Annual Event';
      default:
        return category;
    }
  }

  factory BarEvent.fromJson(Map<String, dynamic> json) => BarEvent(
    id: json['id'] ?? '',
    associationId: json['association_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    eventDate: parseDateOr(json['event_date'], DateTime.now()),
    startTime: json['start_time'],
    endTime: json['end_time'],
    location: json['location'],
    agenda: json['agenda'],
    category: json['category'] ?? 'meeting',
    createdBy: json['created_by'],
    createdAt: parseDateOr(json['created_at'], DateTime.now()),
  );

  Map<String, dynamic> toJson() => {
    'association_id': associationId,
    'title': title,
    'description': description,
    'event_date': eventDate.toIso8601String().split('T')[0],
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
    'agenda': agenda,
    'category': category,
    'created_by': createdBy,
  };
}
