class EmergencyHelpline {
  final String name;
  final String number;
  final String category;
  final String actionUrl;
  final String description;
  final String icon;

  const EmergencyHelpline({
    required this.name,
    required this.number,
    required this.category,
    required this.actionUrl,
    required this.description,
    this.icon = 'support_agent',
  });

  factory EmergencyHelpline.fromJson(Map<String, dynamic> json) {
    return EmergencyHelpline(
      name: json['name']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Crisis Helpline',
      actionUrl: json['actionUrl']?.toString() ?? 'tel:${json['number']}',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'support_agent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'category': category,
      'actionUrl': actionUrl,
      'description': description,
      'icon': icon,
    };
  }

  static const List<EmergencyHelpline> defaultHelplines = [
    EmergencyHelpline(
      name: "Tele-MANAS (Govt of India)",
      number: "14416",
      category: "Mental Health & Crisis Hotline",
      actionUrl: "tel:14416",
      description: "Toll-free 24/7 National Tele-Mental Health Programme (or 1800-891-4416).",
      icon: "support_agent",
    ),
    EmergencyHelpline(
      name: "Vandrevala Mental Health Helpline",
      number: "+91 9999 666 555",
      category: "24/7 Psychological First Aid",
      actionUrl: "tel:+919999666555",
      description: "Free, confidential 24/7 clinical counseling & de-escalation.",
      icon: "favorite",
    ),
    EmergencyHelpline(
      name: "988 Suicide & Crisis Lifeline",
      number: "988",
      category: "Immediate Emergency Lifeline",
      actionUrl: "tel:988",
      description: "24/7 confidential clinical support for acute distress or self-harm prevention.",
      icon: "crisis_alert",
    ),
    EmergencyHelpline(
      name: "MedAccess 24/7 Clinical Emergency Desk",
      number: "1800-MED-ACCESS",
      category: "Clinical Triage & Ambulance Dispatch",
      actionUrl: "tel:1800633222",
      description: "Institutional emergency medical escort, ER copay triage, and ambulance dispatch.",
      icon: "medical_services",
    ),
  ];
}
