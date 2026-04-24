class Caveat {
  final String id;
  final String userId;
  final String courtName;
  final String? caseType;
  final String caveatorName;
  final String opponentName;
  final String? subjectMatter;
  final String? caveatNumber;
  final DateTime filingDate;
  final DateTime expiryDate;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Caveat({
    required this.id,
    required this.userId,
    required this.courtName,
    this.caseType,
    required this.caveatorName,
    required this.opponentName,
    this.subjectMatter,
    this.caveatNumber,
    required this.filingDate,
    required this.expiryDate,
    this.status = 'active',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Caveat.fromJson(Map<String, dynamic> json) {
    return Caveat(
      id: json['id'],
      userId: json['user_id'],
      courtName: json['court_name'],
      caseType: json['case_type'],
      caveatorName: json['caveator_name'],
      opponentName: json['opponent_name'],
      subjectMatter: json['subject_matter'],
      caveatNumber: json['caveat_number'],
      filingDate: DateTime.parse(json['filing_date']),
      expiryDate: DateTime.parse(json['expiry_date']),
      status: json['status'] ?? 'active',
      notes: json['notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'court_name': courtName,
      'case_type': caseType,
      'caveator_name': caveatorName,
      'opponent_name': opponentName,
      'subject_matter': subjectMatter,
      'caveat_number': caveatNumber,
      'filing_date': filingDate.toIso8601String().split('T')[0],
      'expiry_date': expiryDate.toIso8601String().split('T')[0],
      'status': status,
      'notes': notes,
    };
  }

  /// Calculates the number of days remaining until expiry.
  /// If the caveat is already expired, returns a negative number.
  int get daysRemaining {
    final now = DateTime.now();
    // Neutralize time to compare dates only
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  bool get isExpired => daysRemaining < 0;
}
