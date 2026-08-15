class Ticket {
  final String id;
  final String studentPhone;
  final String rawMessage;
  final String? mediaUrl;
  final String parsedCategory;
  final String urgencyLevel; // 'Urgent', 'High', 'Routine'
  final String status; // 'Pending', 'Auto-Approved', 'Escalated', 'Resolved', 'Approved', 'Triage Active', 'Flagged'
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
  final String? matchedPolicyCap;
  final String? fundSourceName;
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
    this.matchedPolicyCap,
    this.fundSourceName,
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

    // Extract clinical notes / thought process
    String? thought = json['thought_process']?.toString() ??
        json['clinical_notes']?.toString() ??
        json['adjudication_notes']?.toString() ??
        json['policy_match_reason']?.toString();

    // Extract matched policy name and cap
    String? policyName = json['matched_policy_name']?.toString() ??
        json['policy_name']?.toString() ??
        json['policy_title']?.toString();
    String? policyCap = json['max_coverage_amount']?.toString();

    if (thought != null && thought.isNotEmpty) {
      if (policyName == null && thought.contains('Policy Cap:')) {
        final match = RegExp(r'Policy Cap:\s*([^\n\(\[]+)').firstMatch(thought);
        if (match != null) {
          policyName = match.group(1)?.trim();
        }
      }
      if (policyCap == null && thought.contains('Max Cap:')) {
        final match = RegExp(r'Max Cap:\s*([^\n\]]+)').firstMatch(thought);
        if (match != null) {
          policyCap = match.group(1)?.trim();
        }
      }
    }

    if (policyName == null && json['matched_policy_id'] != null) {
      final idStr = json['matched_policy_id'].toString();
      policyName = 'Institutional Policy #${idStr.length > 8 ? idStr.substring(0, 8) : idStr}';
    }

    final calculatedAmt = parseDouble(
      json['calculated_amount'] ??
      json['extracted_bill_amount'] ??
      json['requested_amount'] ??
      json['bill_amount'] ??
      json['amount'],
    );

    final recGrant = parseNullableDouble(
      json['recommended_grant_amount'] ??
      json['recommended_copay_amount'] ??
      json['approved_amount'],
    );

    // Institutional fund allocation source name
    String fundName = 'Institutional Healthcare Relief Reserve';
    if (json['clinical_category'] != null || json['parsed_category'] != null) {
      final cat = (json['clinical_category'] ?? json['parsed_category']).toString();
      if (cat.contains('Emergency') || cat.contains('Trauma')) {
        fundName = 'Trauma & Emergency Relief Endowment';
      } else if (cat.contains('Mental') || cat.contains('Crisis')) {
        fundName = 'Psychological Well-Being & Crisis Grant Fund';
      } else if (cat.contains('Prescription') || cat.contains('Pharmacy')) {
        fundName = 'Essential Pharmacy & Medication Reserve';
      }
    }

    // Format urgency level
    String urgency = json['urgency_level']?.toString() ?? json['esi_level']?.toString() ?? 'Routine';
    if (urgency.startsWith('ESI_1')) {
      urgency = 'Urgent';
    } else if (urgency.startsWith('ESI_2')) {
      urgency = 'High';
    } else if (urgency.startsWith('ESI_3')) {
      urgency = 'Routine';
    }

    return Ticket(
      id: json['id']?.toString() ?? '',
      studentPhone: json['student_phone']?.toString() ??
          json['patient_phone']?.toString() ??
          json['phone']?.toString() ??
          '',
      rawMessage: json['raw_message']?.toString() ??
          json['description']?.toString() ??
          json['symptoms']?.toString() ??
          json['notes']?.toString() ??
          '',
      mediaUrl: json['media_url']?.toString() ??
          json['receipt_url']?.toString() ??
          json['attachment_url']?.toString(),
      parsedCategory: json['parsed_category']?.toString() ??
          json['clinical_category']?.toString() ??
          'General Healthcare',
      urgencyLevel: urgency,
      status: json['status']?.toString() ?? 'Pending',
      calculatedAmount: calculatedAmt,
      policyMatchReason: json['policy_match_reason']?.toString() ?? thought,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      crisisSeverityIndex: parseDouble(json['crisis_severity_index']),
      dropoutRiskScore: parseDouble(json['dropout_risk_score'] ?? json['attrition_risk_score']),
      recommendedGrantAmount: recGrant,
      grantConfidenceScore: parseNullableDouble(
        json['grant_confidence_score'] ??
        (json['fraud_risk_score'] != null ? (1.0 - parseDouble(json['fraud_risk_score'])) : 0.96),
      ),
      anomalyScore: parseNullableDouble(
        json['anomaly_reconstruction_score'] ??
        json['anomaly_score'] ??
        json['fraud_risk_score'],
      ),
      thoughtProcess: thought,
      matchedPolicyName: policyName,
      matchedPolicyCap: policyCap,
      fundSourceName: fundName,
      flagReason: json['flag_reason']?.toString() ??
          (json['fraud_flags'] != null && json['fraud_flags'] != 'CLEAN_VERIFIED' ? json['fraud_flags'].toString() : null),
      sentimentNegativeScore: parseDouble(json['sentiment_negative_score']),
      multiDepartmentInvolvement: parseDouble(json['multi_department_involvement']),
      policyAmbiguityScore: parseDouble(json['policy_ambiguity_score']),
      fraudStatus: json['fraud_status']?.toString() ??
          ((json['flag_reason'] != null || (parseNullableDouble(json['anomaly_reconstruction_score'] ?? json['anomaly_score'] ?? json['fraud_risk_score']) ?? 0) > 0.65)
              ? 'FLAGGED'
              : 'CLEARED'),
      payoutReference: json['payout_reference']?.toString() ??
          json['transaction_reference']?.toString() ??
          json['voucher_code']?.toString(),
      payoutMethod: json['payout_method']?.toString() ??
          json['disbursement_method']?.toString(),
      voucherCode: json['voucher_code']?.toString(),
      currency: json['currency']?.toString().isNotEmpty == true ? json['currency'].toString() : 'INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_phone': studentPhone,
      'patient_phone': studentPhone,
      'raw_message': rawMessage,
      'description': rawMessage,
      'media_url': mediaUrl,
      'receipt_url': mediaUrl,
      'parsed_category': parsedCategory,
      'clinical_category': parsedCategory,
      'urgency_level': urgencyLevel,
      'status': status,
      'calculated_amount': calculatedAmount,
      'extracted_bill_amount': calculatedAmount,
      'policy_match_reason': policyMatchReason,
      'created_at': createdAt.toIso8601String(),
      'crisis_severity_index': crisisSeverityIndex,
      'dropout_risk_score': dropoutRiskScore,
      'recommended_grant_amount': recommendedGrantAmount,
      'recommended_copay_amount': recommendedGrantAmount,
      'grant_confidence_score': grantConfidenceScore,
      'anomaly_reconstruction_score': anomalyScore,
      'thought_process': thoughtProcess,
      'clinical_notes': thoughtProcess,
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
