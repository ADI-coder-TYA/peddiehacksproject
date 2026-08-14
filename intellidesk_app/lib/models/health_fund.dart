class HealthFund {
  final String id;
  final String institutionId;
  final String name;
  final String category;
  final double totalAllocated;
  final double totalDisbursed;
  final String currency;

  HealthFund({
    required this.id,
    this.institutionId = 'default',
    required this.name,
    required this.category,
    required this.totalAllocated,
    this.totalDisbursed = 0.0,
    this.currency = 'INR',
  });

  double get remainingBalance => (totalAllocated - totalDisbursed).clamp(0.0, totalAllocated);
  double get utilizationPercentage => totalAllocated > 0 ? ((totalDisbursed / totalAllocated) * 100).clamp(0.0, 100.0) : 0.0;

  factory HealthFund.fromJson(Map<String, dynamic> json) {
    return HealthFund(
      id: json['id']?.toString() ?? '',
      institutionId: json['institution_id']?.toString() ?? json['institutionId']?.toString() ?? 'default',
      name: json['name']?.toString() ?? json['fund_name']?.toString() ?? 'Emergency Copay Fund',
      category: json['category']?.toString() ?? 'Medical Emergency',
      totalAllocated: (json['total_allocated'] ?? json['total_budget'] ?? 0.0).toDouble(),
      totalDisbursed: (json['total_disbursed'] ?? json['allocated_amount'] ?? 0.0).toDouble(),
      currency: json['currency']?.toString() ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution_id': institutionId,
      'name': name,
      'category': category,
      'total_allocated': totalAllocated,
      'total_disbursed': totalDisbursed,
      'currency': currency,
    };
  }
}
