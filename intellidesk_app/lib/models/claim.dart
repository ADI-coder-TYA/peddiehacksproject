class Claim {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final String status;
  final DateTime submittedAt;

  Claim({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.status,
    required this.submittedAt,
  });
}
