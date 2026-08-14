import 'package:flutter/material.dart';

class ClinicalNotificationBanner extends StatelessWidget {
  final String message;
  final String esiLevel;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String actionLabel;

  const ClinicalNotificationBanner({
    super.key,
    required this.message,
    required this.esiLevel,
    this.onDismiss,
    this.onAction,
    this.actionLabel = 'View',
  });

  Color get _esiColor {
    if (esiLevel.contains('1')) return const Color(0xFFEF4444);
    if (esiLevel.contains('2')) return const Color(0xFFF97316);
    return const Color(0xFF0D9488);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _esiColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _esiColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: _esiColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(esiLevel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _esiColor,
                        letterSpacing: 0.5)),
                Text(message,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel,
                  style: TextStyle(color: _esiColor, fontWeight: FontWeight.w600)),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
