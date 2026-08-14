class Ticket {
  final String id;
  final String studentPhone;
  final String rawMessage;
  final String? mediaUrl;
  final String parsedCategory;
  final String urgencyLevel; // 'Urgent', 'High', 'Routine'
  final String status; // 'Pending', 'Auto-Approved', 'Escalated', 'Resolved'
  final double calculatedAmount;
  final String? policyMatchReason;
  final DateTime createdAt;
  // ML & Deep Learning Metrics
  final double crisisSeverityIndex;
  final double dropoutRiskScore;
  final double? recommendedGrantAmount;
  final double? grantConfidenceScore;
  final double? anomalyScore;
  final String? thoughtProcess;
  final String? matchedPolicyName;
  final String? flagReason;
  final double sentimentNegativeScore;
  final double multiDepartmentInvolvement;
  final double policyAmbiguityScore;
  final String? fraudStatus;
  // Payout & Disbursement Info
  final String? payoutReference;
  final String? payoutMethod;
  final String? voucherCode;
  final String currency;

  Ticket({
    required this.id,
    required this.studentPhone,
    required this.rawMessage,
    this.mediaUrl,
    required this.parsedCategory,
    required this.urgencyLevel,
    required this.status,
    required this.calculatedAmount,
    this.policyMatchReason,
    required this.createdAt,
    this.crisisSeverityIndex = 0.0,
    this.dropoutRiskScore = 0.0,
    this.recommendedGrantAmount,
    this.grantConfidenceScore,
    this.anomalyScore,
    this.thoughtProcess,
    this.matchedPolicyName,
    this.flagReason,
    this.sentimentNegativeScore = 0.0,
    this.multiDepartmentInvolvement = 0.0,
    this.policyAmbiguityScore = 0.0,
    this.fraudStatus,
    this.payoutReference,
    this.payoutMethod,
    this.voucherCode,
    this.currency = 'INR',
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Ticket(
      id: json['id']?.toString() ?? '',
      studentPhone: json['student_phone']?.toString() ?? '',
      rawMessage: json['raw_message']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      parsedCategory: json['parsed_category']?.toString() ?? '',
      urgencyLevel: json['urgency_level']?.toString() ?? 'Routine',
      status: json['status']?.toString() ?? 'Pending',
      calculatedAmount: parseDouble(json['calculated_amount']),
      policyMatchReason: json['policy_match_reason']?.toString(),
      createdAt: json['created_at'] != null 
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      crisisSeverityIndex: parseDouble(json['crisis_severity_index']),
      dropoutRiskScore: parseDouble(json['dropout_risk_score']),
      recommendedGrantAmount: parseNullableDouble(json['recommended_grant_amount']),
      grantConfidenceScore: parseNullableDouble(json['grant_confidence_score']),
      anomalyScore: parseNullableDouble(json['anomaly_reconstruction_score'] ?? json['anomaly_score']),
      thoughtProcess: json['thought_process']?.toString(),
      matchedPolicyName: json['matched_policy_name']?.toString(),
      flagReason: json['flag_reason']?.toString(),
      sentimentNegativeScore: parseDouble(json['sentiment_negative_score']),
      multiDepartmentInvolvement: parseDouble(json['multi_department_involvement']),
      policyAmbiguityScore: parseDouble(json['policy_ambiguity_score']),
      fraudStatus: json['fraud_status']?.toString() ?? ((json['flag_reason'] != null || (parseNullableDouble(json['anomaly_reconstruction_score'] ?? json['anomaly_score']) ?? 0) > 0.65) ? 'FLAGGED' : 'CLEARED'),
      payoutReference: json['payout_reference']?.toString() ?? json['transaction_reference']?.toString() ?? json['voucher_code']?.toString(),
      payoutMethod: json['payout_method']?.toString() ?? json['disbursement_method']?.toString(),
      voucherCode: json['voucher_code']?.toString(),
      currency: json['currency']?.toString().isNotEmpty == true ? json['currency'].toString() : 'INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_phone': studentPhone,
      'raw_message': rawMessage,
      'media_url': mediaUrl,
      'parsed_category': parsedCategory,
      'urgency_level': urgencyLevel,
      'status': status,
      'calculated_amount': calculatedAmount,
      'policy_match_reason': policyMatchReason,
      'created_at': createdAt.toIso8601String(),
      'crisis_severity_index': crisisSeverityIndex,
      'dropout_risk_score': dropoutRiskScore,
      'recommended_grant_amount': recommendedGrantAmount,
      'grant_confidence_score': grantConfidenceScore,
      'anomaly_reconstruction_score': anomalyScore,
      'thought_process': thoughtProcess,
      'matched_policy_name': matchedPolicyName,
      'flag_reason': flagReason,
      'sentiment_negative_score': sentimentNegativeScore,
      'multi_department_involvement': multiDepartmentInvolvement,
      'policy_ambiguity_score': policyAmbiguityScore,
      'fraud_status': fraudStatus,
      'payout_reference': payoutReference,
      'payout_method': payoutMethod,
      'voucher_code': voucherCode,
      'currency': currency,
    };
  }
}
