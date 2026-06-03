/// Models for eCourt-style Case Dossier sections:
/// Acts & Sections, Interlocutory Applications, Interim Orders

class CaseAct {
  final String id;
  final String caseId;
  final String actName;
  final String? sectionNumber;
  final String createdBy;
  final DateTime createdAt;

  CaseAct({
    required this.id,
    required this.caseId,
    required this.actName,
    this.sectionNumber,
    required this.createdBy,
    required this.createdAt,
  });

  factory CaseAct.fromJson(Map<String, dynamic> json) => CaseAct(
    id: json['id'] ?? '',
    caseId: json['case_id'] ?? '',
    actName: json['act_name'] ?? '',
    sectionNumber: json['section_number'],
    createdBy: json['created_by'] ?? '',
    createdAt: DateTime.parse(
      json['created_at'] ?? DateTime.now().toIso8601String(),
    ),
  );
}

class CaseIAApplication {
  final String id;
  final String caseId;
  final String iaNumber;
  final String? classification;
  final String? party;
  final DateTime? filingDate;
  final DateTime? nextDate;
  final String iaStatus;
  final String createdBy;
  final DateTime createdAt;

  CaseIAApplication({
    required this.id,
    required this.caseId,
    required this.iaNumber,
    this.classification,
    this.party,
    this.filingDate,
    this.nextDate,
    this.iaStatus = 'pending',
    required this.createdBy,
    required this.createdAt,
  });

  factory CaseIAApplication.fromJson(Map<String, dynamic> json) =>
      CaseIAApplication(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        iaNumber: json['ia_number'] ?? '',
        classification: json['classification'],
        party: json['party'],
        filingDate:
            json['filing_date'] != null
                ? DateTime.parse(json['filing_date'])
                : null,
        nextDate:
            json['next_date'] != null
                ? DateTime.parse(json['next_date'])
                : null,
        iaStatus: json['ia_status'] ?? 'pending',
        createdBy: json['created_by'] ?? '',
        createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
}

class CaseInterimOrder {
  final String id;
  final String caseId;
  final int? orderNumber;
  final DateTime orderDate;
  final String orderType;
  final String? orderSummary;
  final String? documentUrl;
  final String createdBy;
  final DateTime createdAt;

  CaseInterimOrder({
    required this.id,
    required this.caseId,
    this.orderNumber,
    required this.orderDate,
    this.orderType = 'deposition',
    this.orderSummary,
    this.documentUrl,
    required this.createdBy,
    required this.createdAt,
  });

  factory CaseInterimOrder.fromJson(Map<String, dynamic> json) =>
      CaseInterimOrder(
        id: json['id'] ?? '',
        caseId: json['case_id'] ?? '',
        orderNumber: json['order_number'],
        orderDate: DateTime.parse(
          json['order_date'] ?? DateTime.now().toIso8601String(),
        ),
        orderType: json['order_type'] ?? 'deposition',
        orderSummary: json['order_summary'],
        documentUrl: json['document_url'],
        createdBy: json['created_by'] ?? '',
        createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );
}
