import 'package:flutter/foundation.dart';

class TitleSearch {
  final String id;
  final String userId;
  final String? firmId;
  final String? propertyName;
  final String district;
  final String taluk;
  final String village;
  final String surveyNumber;
  final String? oldSurveyNumber;
  final double? extent;
  final String extentUnit;
  final String? classification;
  final String? proposedSeller;
  final String? proposedBuyer;
  final double? proposedPrice;
  final String status; // draft, uploading, extracting, analyzing, completed, error
  final int? healthScore; // 0–100
  final int criticalCount;
  final int warningCount;
  final int passedCount;
  final int totalChecks;
  final String? advocateOpinion;
  final DateTime? opinionDate;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TitleSearch({
    required this.id,
    required this.userId,
    this.firmId,
    this.propertyName,
    required this.district,
    required this.taluk,
    required this.village,
    required this.surveyNumber,
    this.oldSurveyNumber,
    this.extent,
    this.extentUnit = 'acres',
    this.classification,
    this.proposedSeller,
    this.proposedBuyer,
    this.proposedPrice,
    this.status = 'draft',
    this.healthScore,
    this.criticalCount = 0,
    this.warningCount = 0,
    this.passedCount = 0,
    this.totalChecks = 0,
    this.advocateOpinion,
    this.opinionDate,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TitleSearch.fromJson(Map<String, dynamic> json) {
    return TitleSearch(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firmId: json['firm_id'] as String?,
      propertyName: json['property_name'] as String?,
      district: json['district'] as String? ?? '',
      taluk: json['taluk'] as String? ?? '',
      village: json['village'] as String? ?? '',
      surveyNumber: json['survey_number'] as String? ?? '',
      oldSurveyNumber: json['old_survey_number'] as String?,
      extent: json['extent'] != null ? (json['extent'] as num).toDouble() : null,
      extentUnit: json['extent_unit'] as String? ?? 'acres',
      classification: json['classification'] as String?,
      proposedSeller: json['proposed_seller'] as String?,
      proposedBuyer: json['proposed_buyer'] as String?,
      proposedPrice: json['proposed_price'] != null ? (json['proposed_price'] as num).toDouble() : null,
      status: json['status'] as String? ?? 'draft',
      healthScore: json['health_score'] as int?,
      criticalCount: json['critical_count'] as int? ?? 0,
      warningCount: json['warning_count'] as int? ?? 0,
      passedCount: json['passed_count'] as int? ?? 0,
      totalChecks: json['total_checks'] as int? ?? 0,
      advocateOpinion: json['advocate_opinion'] as String?,
      opinionDate: json['opinion_date'] != null ? DateTime.tryParse(json['opinion_date'] as String) : null,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'property_name': propertyName,
      'district': district,
      'taluk': taluk,
      'village': village,
      'survey_number': surveyNumber,
      'old_survey_number': oldSurveyNumber,
      'extent': extent,
      'extent_unit': extentUnit,
      'classification': classification,
      'proposed_seller': proposedSeller,
      'proposed_buyer': proposedBuyer,
      'proposed_price': proposedPrice,
      'status': status,
      'advocate_opinion': advocateOpinion,
    };
  }

  String get displayName =>
      (propertyName != null && propertyName!.trim().isNotEmpty)
          ? propertyName!
          : 'Sy. No. $surveyNumber, $village';

  bool get isCompleted => status == 'completed';
  bool get hasIssues => (criticalCount > 0 || warningCount > 0);
}

class TitleDocument {
  final String id;
  final String searchId;
  final String userId;
  final String documentType;
  final String? documentLabel;
  final String filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int? pageCount;
  final String? rawText;
  final Map<String, dynamic>? extractedData;
  final double? extractionConfidence;
  final String extractionStatus;
  final String? extractionError;
  final int? chainPosition;
  final DateTime createdAt;

  const TitleDocument({
    required this.id,
    required this.searchId,
    required this.userId,
    required this.documentType,
    this.documentLabel,
    required this.filePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.pageCount,
    this.rawText,
    this.extractedData,
    this.extractionConfidence,
    this.extractionStatus = 'pending',
    this.extractionError,
    this.chainPosition,
    required this.createdAt,
  });

  factory TitleDocument.fromJson(Map<String, dynamic> json) {
    return TitleDocument(
      id: json['id'] as String,
      searchId: json['search_id'] as String,
      userId: json['user_id'] as String,
      documentType: json['document_type'] as String? ?? 'other',
      documentLabel: json['document_label'] as String?,
      filePath: json['file_path'] as String? ?? '',
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      pageCount: json['page_count'] as int?,
      rawText: json['raw_text'] as String?,
      extractedData: json['extracted_data'] as Map<String, dynamic>?,
      extractionConfidence: json['extraction_confidence'] != null
          ? (json['extraction_confidence'] as num).toDouble()
          : null,
      extractionStatus: json['extraction_status'] as String? ?? 'pending',
      extractionError: json['extraction_error'] as String?,
      chainPosition: json['chain_position'] as int?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get humanReadableType => switch (documentType) {
    'sale_deed' => 'Current Sale Deed',
    'parent_deed' => 'Parent Deed',
    'grandparent_deed' => 'Grandparent Deed',
    'encumbrance_certificate' => 'Encumbrance Certificate (EC)',
    'patta' => 'Patta / Chitta',
    'chitta' => 'Chitta Extract',
    'legal_heir_certificate' => 'Legal Heir Certificate',
    'partition_deed' => 'Partition Deed',
    'will' => 'Registered Will',
    'gift_deed' => 'Gift Deed',
    'fmb_sketch' => 'FMB Sketch',
    'death_certificate' => 'Death Certificate',
    'power_of_attorney' => 'Power of Attorney',
    _ => 'Property Document',
  };
}

class TitleFinding {
  final String id;
  final String searchId;
  final String checkCode;
  final String checkName;
  final String category; // chain, identity, red_flag, completeness
  final String severity; // critical, warning, passed, info
  final String status; // open, acknowledged, resolved, false_positive
  final String description;
  final Map<String, dynamic>? details;
  final String? recommendation;
  final String? legalReference;
  final List<String> sourceDocIds;
  final String? advocateNotes;
  final DateTime createdAt;

  const TitleFinding({
    required this.id,
    required this.searchId,
    required this.checkCode,
    required this.checkName,
    required this.category,
    required this.severity,
    this.status = 'open',
    required this.description,
    this.details,
    this.recommendation,
    this.legalReference,
    this.sourceDocIds = const [],
    this.advocateNotes,
    required this.createdAt,
  });

  factory TitleFinding.fromJson(Map<String, dynamic> json) {
    return TitleFinding(
      id: json['id'] as String,
      searchId: json['search_id'] as String,
      checkCode: json['check_code'] as String? ?? '',
      checkName: json['check_name'] as String? ?? '',
      category: json['category'] as String? ?? 'chain',
      severity: json['severity'] as String? ?? 'info',
      status: json['status'] as String? ?? 'open',
      description: json['description'] as String? ?? '',
      details: json['details'] as Map<String, dynamic>?,
      recommendation: json['recommendation'] as String?,
      legalReference: json['legal_reference'] as String?,
      sourceDocIds: (json['source_doc_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      advocateNotes: json['advocate_notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isCritical => severity == 'critical';
  bool get isWarning => severity == 'warning';
  bool get isPassed => severity == 'passed';
}

class TitleChainLink {
  final String id;
  final String searchId;
  final String? sourceDocId;
  final int linkOrder;
  final String transactionType;
  final DateTime? transactionDate;
  final String? documentNumber;
  final String? subRegistrarOffice;
  final Map<String, dynamic>? fromParty;
  final Map<String, dynamic>? toParty;
  final String? surveyNumber;
  final double? extent;
  final String? extentUnit;
  final String? classification;
  final double? consideration;
  final bool isVerified;
  final String? notes;
  final DateTime createdAt;

  const TitleChainLink({
    required this.id,
    required this.searchId,
    this.sourceDocId,
    required this.linkOrder,
    required this.transactionType,
    this.transactionDate,
    this.documentNumber,
    this.subRegistrarOffice,
    this.fromParty,
    this.toParty,
    this.surveyNumber,
    this.extent,
    this.extentUnit,
    this.classification,
    this.consideration,
    this.isVerified = false,
    this.notes,
    required this.createdAt,
  });

  factory TitleChainLink.fromJson(Map<String, dynamic> json) {
    return TitleChainLink(
      id: json['id'] as String,
      searchId: json['search_id'] as String,
      sourceDocId: json['source_doc_id'] as String?,
      linkOrder: json['link_order'] as int? ?? 1,
      transactionType: json['transaction_type'] as String? ?? 'sale',
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'] as String)
          : null,
      documentNumber: json['document_number'] as String?,
      subRegistrarOffice: json['sub_registrar_office'] as String?,
      fromParty: json['from_party'] as Map<String, dynamic>?,
      toParty: json['to_party'] as Map<String, dynamic>?,
      surveyNumber: json['survey_number'] as String?,
      extent: json['extent'] != null ? (json['extent'] as num).toDouble() : null,
      extentUnit: json['extent_unit'] as String?,
      classification: json['classification'] as String?,
      consideration: json['consideration'] != null ? (json['consideration'] as num).toDouble() : null,
      isVerified: json['is_verified'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get fromName => fromParty?['name'] as String? ?? 'Original Owner';
  String get toName => toParty?['name'] as String? ?? 'Buyer';
}
