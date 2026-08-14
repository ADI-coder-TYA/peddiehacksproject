class ClaimMessage {
  final String id;
  final String claimId;
  final String sender; // 'PATIENT' | 'COUNSELOR_AI' | 'CLINICAL_ADMIN'
  final String message;
  final bool isCrisisResponse;
  final List<dynamic>? suggestedResources;
  final DateTime createdAt;

  ClaimMessage({
    required this.id,
    required this.claimId,
    required this.sender,
    required this.message,
    this.isCrisisResponse = false,
    this.suggestedResources,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClaimMessage.fromJson(Map<String, dynamic> json) {
    return ClaimMessage(
      id: json['id']?.toString() ?? '',
      claimId: json['claim_id']?.toString() ?? json['claimId']?.toString() ?? '',
      sender: json['sender']?.toString() ?? 'PATIENT',
      message: json['message']?.toString() ?? '',
      isCrisisResponse: json['is_crisis_response'] == true || json['isCrisisResponse'] == true,
      suggestedResources: json['suggested_resources'] as List<dynamic>?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claim_id': claimId,
      'sender': sender,
      'message': message,
      'is_crisis_response': isCrisisResponse,
      'suggested_resources': suggestedResources,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
