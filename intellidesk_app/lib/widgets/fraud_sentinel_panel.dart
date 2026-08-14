import 'package:flutter/material.dart';
import '../widgets/clinical_widgets.dart';

class FraudRiskBadge extends StatelessWidget {
  final double riskScore; // 0.0 - 1.0

  const FraudRiskBadge({super.key, required this.riskScore});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (riskScore >= 0.75) {
      color = const Color(0xFFEF4444);
      label = '🚨 HIGH FRAUD RISK';
    } else if (riskScore >= 0.4) {
      color = const Color(0xFFF97316);
      label = '⚠️ MEDIUM RISK';
    } else {
      color = const Color(0xFF0D9488);
      label = '✅ LOW RISK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Text('${(riskScore * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class FraudSentinelPanel extends StatelessWidget {
  final List<Map<String, dynamic>> quarantinedClaims;

  const FraudSentinelPanel({super.key, required this.quarantinedClaims});

  @override
  Widget build(BuildContext context) {
    return GlassClinicCard(
      borderColor: const Color(0xFFEF4444).withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              const Text('Fraud Sentinel — Quarantine Queue',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: Color(0xFFEF4444))),
              const Spacer(),
              Chip(
                label: Text('${quarantinedClaims.length} flagged',
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: const Color(0xFFEF4444),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...quarantinedClaims.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.block, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(c['id'] as String? ?? '',
                          style: const TextStyle(fontSize: 12,
                              fontFamily: 'monospace')),
                    ),
                    FraudRiskBadge(
                        riskScore: (c['riskScore'] as num?)?.toDouble() ?? 0.8),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
