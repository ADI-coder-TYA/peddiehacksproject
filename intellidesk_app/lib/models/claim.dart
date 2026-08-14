class Claim {
  final String id;
  final String institutionId;
  final String? patientId;
  final String? patientPhone;
  final String description;
  final String clinicalCategory;
  final String esiLevel;
  final double crisisSeverityIndex;
  final bool isLifeSafetyAlert;
  final String? receiptUrl;
  final String? receiptImageHash;
  final double? extractedBillAmount;
  final String currency;
  final double? recommendedCopayAmount;
  final double? approvedAmount;
  final double? fraudRiskScore;
  final String? fraudFlags;
  final String status;
  final String? clinicalNotes;
  final String? payoutReference;
  final String? payoutMethod;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Claim({
    required this.id,
    this.institutionId = 'default',
    this.patientId,
    this.patientPhone,
    required this.description,
    required this.clinicalCategory,
    this.esiLevel = 'ROUTINE',
    this.crisisSeverityIndex = 0.0,
    this.isLifeSafetyAlert = false,
    this.receiptUrl,
    this.receiptImageHash,
    this.extractedBillAmount,
    this.currency = 'INR',
    this.recommendedCopayAmount,
    this.approvedAmount,
    this.fraudRiskScore,
    this.fraudFlags,
    this.status = 'Submitted',
    this.clinicalNotes,
    this.payoutReference,
    this.payoutMethod,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id']?.toString() ?? '',
      institutionId: json['institution_id']?.toString() ?? json['institutionId']?.toString() ?? 'default',
      patientId: json['patient_id']?.toString() ?? json['patientId']?.toString(),
      patientPhone: json['patient_phone']?.toString() ?? json['patientPhone']?.toString() ?? json['student_phone']?.toString(),
      description: json['description']?.toString() ?? json['raw_message']?.toString() ?? '',
      clinicalCategory: json['clinical_category']?.toString() ?? json['clinicalCategory']?.toString() ?? json['parsed_category']?.toString() ?? 'Medical Emergency',
      esiLevel: json['esi_level']?.toString() ?? json['esiLevel']?.toString() ?? 'ROUTINE',
      crisisSeverityIndex: (json['crisis_severity_index'] ?? json['crisisSeverityIndex'] ?? 0.0).toDouble(),
      isLifeSafetyAlert: json['is_life_safety_alert'] == true || json['isLifeSafetyAlert'] == true,
      receiptUrl: json['receipt_url']?.toString() ?? json['receiptUrl']?.toString() ?? json['media_url']?.toString(),
      receiptImageHash: json['receipt_image_hash']?.toString() ?? json['receiptImageHash']?.toString(),
      extractedBillAmount: json['extracted_bill_amount'] != null ? (json['extracted_bill_amount']).toDouble() : (json['extracted_amount'] != null ? (json['extracted_amount']).toDouble() : null),
      currency: json['currency']?.toString() ?? 'INR',
      recommendedCopayAmount: json['recommended_copay_amount'] != null ? (json['recommended_copay_amount']).toDouble() : (json['recommended_grant_amount'] != null ? (json['recommended_grant_amount']).toDouble() : null),
      approvedAmount: json['approved_amount'] != null ? (json['approved_amount']).toDouble() : (json['calculated_amount'] != null ? (json['calculated_amount']).toDouble() : null),
      fraudRiskScore: json['fraud_risk_score'] != null ? (json['fraud_risk_score']).toDouble() : (json['anomaly_score'] != null ? (json['anomaly_score']).toDouble() : null),
      fraudFlags: json['fraud_flags']?.toString() ?? json['fraudFlags']?.toString() ?? json['flag_reason']?.toString(),
      status: json['status']?.toString() ?? 'Submitted',
      clinicalNotes: json['clinical_notes']?.toString() ?? json['clinicalNotes']?.toString(),
      payoutReference: json['payout_reference']?.toString() ?? json['payoutReference']?.toString(),
      payoutMethod: json['payout_method']?.toString() ?? json['payoutMethod']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution_id': institutionId,
      'patient_id': patientId,
      'patient_phone': patientPhone,
      'description': description,
      'clinical_category': clinicalCategory,
      'esi_level': esiLevel,
      'crisis_severity_index': crisisSeverityIndex,
      'is_life_safety_alert': isLifeSafetyAlert,
      'receipt_url': receiptUrl,
      'receipt_image_hash': receiptImageHash,
      'extracted_bill_amount': extractedBillAmount,
      'currency': currency,
      'recommended_copay_amount': recommendedCopayAmount,
      'approved_amount': approvedAmount,
      'fraud_risk_score': fraudRiskScore,
      'fraud_flags': fraudFlags,
      'status': status,
      'clinical_notes': clinicalNotes,
      'payout_reference': payoutReference,
      'payout_method': payoutMethod,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
