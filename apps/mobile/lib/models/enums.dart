enum AppRole {
  admin,
  lawyer,
  staff;

  static AppRole fromString(String value) {
    return AppRole.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => AppRole.lawyer,
    );
  }
}

enum CaseStatus {
  active,
  closed,
  appeal,
  disposed,
  dismissed;

  String get label => name[0].toUpperCase() + name.substring(1);

  static CaseStatus fromString(String value) {
    return CaseStatus.values.firstWhere(
      (e) =>
          e.name == value.toLowerCase() ||
          e.label.toLowerCase() == value.toLowerCase(),
      orElse: () => CaseStatus.active,
    );
  }
}

enum CaseStage {
  filing,
  evidence,
  argument,
  judgment,
  disposed,
  dismissed;

  String get label {
    if (this == disposed) return 'Case Disposed';
    if (this == dismissed) return 'Case Dismissed';
    return name[0].toUpperCase() + name.substring(1);
  }

  static CaseStage fromString(String value) {
    final clean = value.toLowerCase().trim();
    return CaseStage.values.firstWhere(
      (e) => e.name == clean || e.label.toLowerCase() == clean,
      orElse: () => CaseStage.filing,
    );
  }
}

enum DocType {
  plaint,
  affidavit,
  vakalat,
  order,
  judgment;

  String get label {
    switch (this) {
      case DocType.plaint:
        return 'Plaint';
      case DocType.affidavit:
        return 'Affidavit';
      case DocType.vakalat:
        return 'Vakalat';
      case DocType.order:
        return 'Order';
      case DocType.judgment:
        return 'Judgment';
    }
  }

  static DocType fromString(String value) {
    final clean = value.toLowerCase().trim();
    return DocType.values.firstWhere(
      (e) => e.name == clean,
      orElse: () => DocType.plaint,
    );
  }
}

enum FilingStatus {
  drafting,
  review,
  signaturePending,
  filed,
  defect,
  accepted;

  String get label {
    switch (this) {
      case FilingStatus.signaturePending:
        return 'Signature Pending';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  static FilingStatus fromString(String value) {
    final clean = value.toLowerCase().replaceAll('_', '');
    return FilingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == clean || e.name == value,
      orElse: () => FilingStatus.drafting,
    );
  }
}

enum PaymentMode {
  cash,
  upi,
  bankTransfer,
  cheque,
  online;

  String get label {
    switch (this) {
      case PaymentMode.bankTransfer:
        return 'Bank Transfer';
      default:
        return name.toUpperCase();
    }
  }

  static PaymentMode fromString(String value) {
    final clean = value.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    return PaymentMode.values.firstWhere(
      (e) =>
          e.name.toLowerCase() == clean ||
          e.name == value.replaceAll(' ', '').replaceAll('_', ''),
      orElse: () => PaymentMode.cash,
    );
  }
}

enum CourtType {
  trial,
  higher;

  String get label => this == trial ? 'Trial Court' : 'High / Supreme Court';

  static CourtType fromString(String value) {
    return CourtType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CourtType.trial,
    );
  }
}

enum RepresentationType {
  petitioner,
  respondent;

  String getLabel(CourtType courtType) {
    if (courtType == CourtType.trial) {
      return this == petitioner ? 'Plaintiff' : 'Defendant';
    } else {
      return this == petitioner ? 'Petitioner' : 'Respondent';
    }
  }

  static RepresentationType fromString(String value) {
    return RepresentationType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RepresentationType.petitioner,
    );
  }
}
