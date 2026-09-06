/// Bar Association Management System — Data Models
///
/// All models follow the existing CaseFlow pattern:
/// - `fromJson` factory constructor for Supabase deserialization
/// - `toJson` method for Supabase serialization
/// - Immutable fields with named constructor parameters
library;

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
    subscriptionExpiresAt: json['subscription_expires_at'] != null
        ? DateTime.parse(json['subscription_expires_at'])
        : null,
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
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
  });

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
    membershipType: json['membership_type'] ?? 'regular',
    status: json['status'] ?? 'active',
    joinedYear: json['joined_year'],
    feePaidUntil: json['fee_paid_until'],
    isCaseflowUser: json['is_caseflow_user'] ?? false,
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
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
      case 'election':
        return '🗳️ Election';
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
        publishedAt: DateTime.parse(
          json['published_at'] ?? DateTime.now().toIso8601String(),
        ),
        scheduledFor: json['scheduled_for'] != null
            ? DateTime.parse(json['scheduled_for'])
            : null,
        fcmSent: json['fcm_sent'] ?? false,
        readCount: json['read_count'] ?? 0,
        createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ),
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
    paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
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

class BarElection {
  final String id;
  final String associationId;
  final String title;
  final String? description;
  final DateTime nominationStart;
  final DateTime nominationEnd;
  final DateTime votingStart;
  final DateTime votingEnd;
  final String status;
  final bool resultsPublished;
  final DateTime createdAt;

  BarElection({
    required this.id,
    required this.associationId,
    required this.title,
    this.description,
    required this.nominationStart,
    required this.nominationEnd,
    required this.votingStart,
    required this.votingEnd,
    this.status = 'draft',
    this.resultsPublished = false,
    required this.createdAt,
  });

  bool get isVotingOpen {
    final now = DateTime.now();
    return status == 'voting' &&
        now.isAfter(votingStart) &&
        now.isBefore(votingEnd);
  }

  bool get isNominationOpen {
    final now = DateTime.now();
    return status == 'nominations' &&
        now.isAfter(nominationStart) &&
        now.isBefore(nominationEnd);
  }

  bool get isCompleted => status == 'completed';

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'nominations':
        return 'Nominations Open';
      case 'voting':
        return 'Voting Open';
      case 'completed':
        return resultsPublished ? 'Results Published' : 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  factory BarElection.fromJson(Map<String, dynamic> json) => BarElection(
    id: json['id'] ?? '',
    associationId: json['association_id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'],
    nominationStart: DateTime.parse(json['nomination_start']),
    nominationEnd: DateTime.parse(json['nomination_end']),
    votingStart: DateTime.parse(json['voting_start']),
    votingEnd: DateTime.parse(json['voting_end']),
    status: json['status'] ?? 'draft',
    resultsPublished: json['results_published'] ?? false,
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'association_id': associationId,
    'title': title,
    'description': description,
    'nomination_start': nominationStart.toIso8601String(),
    'nomination_end': nominationEnd.toIso8601String(),
    'voting_start': votingStart.toIso8601String(),
    'voting_end': votingEnd.toIso8601String(),
    'status': status,
    'results_published': resultsPublished,
  };
}

class BarElectionPost {
  final String id;
  final String electionId;
  final String postName;
  final int maxWinners;
  final DateTime createdAt;

  BarElectionPost({
    required this.id,
    required this.electionId,
    required this.postName,
    this.maxWinners = 1,
    required this.createdAt,
  });

  factory BarElectionPost.fromJson(Map<String, dynamic> json) =>
      BarElectionPost(
        id: json['id'] ?? '',
        electionId: json['election_id'] ?? '',
        postName: json['post_name'] ?? '',
        maxWinners: json['max_winners'] ?? 1,
        createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );

  Map<String, dynamic> toJson() => {
    'election_id': electionId,
    'post_name': postName,
    'max_winners': maxWinners,
  };
}

class BarNomination {
  final String id;
  final String postId;
  final String nomineeMemberId;
  final String? proposerMemberId;
  final String? seconderMemberId;
  final String status;
  final String? bio;
  final String? photoUrl;
  final DateTime createdAt;
  // Joined fields
  final String? nomineeName;
  final String? proposerName;
  final String? seconderName;
  final int? voteCount;

  BarNomination({
    required this.id,
    required this.postId,
    required this.nomineeMemberId,
    this.proposerMemberId,
    this.seconderMemberId,
    this.status = 'pending',
    this.bio,
    this.photoUrl,
    required this.createdAt,
    this.nomineeName,
    this.proposerName,
    this.seconderName,
    this.voteCount,
  });

  bool get isApproved => status == 'approved';

  factory BarNomination.fromJson(Map<String, dynamic> json) => BarNomination(
    id: json['id'] ?? '',
    postId: json['post_id'] ?? '',
    nomineeMemberId: json['nominee_member_id'] ?? '',
    proposerMemberId: json['proposer_member_id'],
    seconderMemberId: json['seconder_member_id'],
    status: json['status'] ?? 'pending',
    bio: json['bio'],
    photoUrl: json['photo_url'],
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
    nomineeName: json['nominee']?['name'],
    proposerName: json['proposer']?['name'],
    seconderName: json['seconder']?['name'],
    voteCount: json['vote_count'],
  );

  Map<String, dynamic> toJson() => {
    'post_id': postId,
    'nominee_member_id': nomineeMemberId,
    'proposer_member_id': proposerMemberId,
    'seconder_member_id': seconderMemberId,
    'status': status,
    'bio': bio,
    'photo_url': photoUrl,
  };
}

class BarVoterParticipation {
  final String id;
  final String electionId;
  final String memberId;
  final DateTime votedAt;
  final bool otpVerified;

  BarVoterParticipation({
    required this.id,
    required this.electionId,
    required this.memberId,
    required this.votedAt,
    this.otpVerified = false,
  });

  factory BarVoterParticipation.fromJson(Map<String, dynamic> json) =>
      BarVoterParticipation(
        id: json['id'] ?? '',
        electionId: json['election_id'] ?? '',
        memberId: json['member_id'] ?? '',
        votedAt: DateTime.parse(
          json['voted_at'] ?? DateTime.now().toIso8601String(),
        ),
        otpVerified: json['otp_verified'] ?? false,
      );
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
    eventDate: DateTime.parse(json['event_date']),
    startTime: json['start_time'],
    endTime: json['end_time'],
    location: json['location'],
    agenda: json['agenda'],
    category: json['category'] ?? 'meeting',
    createdBy: json['created_by'],
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
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
