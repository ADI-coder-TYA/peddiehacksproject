import 'package:flutter/material.dart';
import '../widgets/clinical_widgets.dart';

class EsiDistributionCard extends StatelessWidget {
  final Map<String, int> esiCounts; // e.g. {'ESI-1': 3, 'ESI-2': 12, 'ESI-3': 45}
  final double copayBurnRate; // 0.0 - 1.0

  const EsiDistributionCard({
    super.key,
    required this.esiCounts,
    required this.copayBurnRate,
  });

  @override
  Widget build(BuildContext context) {
    final total = esiCounts.values.fold(0, (a, b) => a + b);
    return GlassClinicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ESI Distribution',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          ...esiCounts.entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final color = e.key.contains('1')
                ? const Color(0xFFEF4444)
                : e.key.contains('2')
                    ? const Color(0xFFF97316)
                    : const Color(0xFF0D9488);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withOpacity(0.1),
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          const Text('Copay Pool Burn Rate',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: copayBurnRate,
              backgroundColor: Colors.grey.shade200,
              color: copayBurnRate > 0.85
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0D9488),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(copayBurnRate * 100).toStringAsFixed(1)}% of pool utilised',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
