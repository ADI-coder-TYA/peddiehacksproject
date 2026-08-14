class ClinicalPolicy {
  final String id;
  final String title;
  final String category;
  final String content;
  final DateTime updatedAt;

  ClinicalPolicy({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.updatedAt,
  });

  factory ClinicalPolicy.fromJson(Map<String, dynamic> json) {
    return ClinicalPolicy(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      content: json['content'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
