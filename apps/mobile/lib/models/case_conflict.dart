/// An existing case that clashes with one the user is about to create.
///
/// Two strengths, because the two situations deserve different answers:
///
///   * [isBlocking] — the same case number in the same court. Case numbers
///     repeat across courts (every district court has an OS/448/2022), so the
///     court is part of the identity. A match on both is the same case, and
///     the database rejects it outright.
///   * otherwise — the same title. "Amjath vs Aadil" is a plausible name for
///     two unrelated matters, so this only warrants a warning the user can
///     dismiss.
class CaseConflict {
  final String id;
  final String caseTitle;
  final String? caseNumber;
  final String? courtName;

  /// `'number'` or `'title'`, as returned by `find_conflicting_cases`.
  final String matchType;

  const CaseConflict({
    required this.id,
    required this.caseTitle,
    this.caseNumber,
    this.courtName,
    required this.matchType,
  });

  factory CaseConflict.fromJson(Map<String, dynamic> json) => CaseConflict(
    id: json['id'] as String,
    caseTitle: (json['case_title'] as String?) ?? 'Untitled case',
    caseNumber: json['case_number'] as String?,
    courtName: json['court_name'] as String?,
    matchType: (json['match_type'] as String?) ?? 'title',
  );

  bool get isBlocking => matchType == 'number';
}
