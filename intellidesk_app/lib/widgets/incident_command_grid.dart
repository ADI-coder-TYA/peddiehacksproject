import 'package:flutter/material.dart';
import '../../widgets/clinical_widgets.dart';

class IncidentCommandGrid extends StatelessWidget {
  final List<Map<String, dynamic>> incidents;
  const IncidentCommandGrid({super.key, required this.incidents});

  Color _esiColor(String level) {
    if (level.contains('1')) return const Color(0xFFEF4444);
    if (level.contains('2')) return const Color(0xFFF97316);
    return const Color(0xFF0D9488);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: incidents.length,
      itemBuilder: (context, i) {
        final inc = incidents[i];
        final esi = inc['esi'] as String? ?? 'ESI-3';
        return GlassClinicCard(
          borderColor: _esiColor(esi).withOpacity(0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(inc['id'] as String? ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  EsiBadge(level: esi, color: _esiColor(esi)),
                ],
              ),
              const SizedBox(height: 8),
              Text(inc['category'] as String? ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const Spacer(),
              Text(inc['status'] as String? ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}
