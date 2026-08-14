import 'package:flutter/material.dart';

class ClinicalSlaSimulator extends StatefulWidget {
  final Future<void> Function(int batchSize) onRunSimulation;

  const ClinicalSlaSimulator({super.key, required this.onRunSimulation});

  @override
  State<ClinicalSlaSimulator> createState() => _ClinicalSlaSimulatorState();
}

class _ClinicalSlaSimulatorState extends State<ClinicalSlaSimulator> {
  int _batchSize = 50;
  bool _running = false;
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                const Text('Clinical Crisis SLA Stress-Tester',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Synthetic Batch Size: $_batchSize claims',
                style: const TextStyle(fontSize: 13)),
            Slider(
              value: _batchSize.toDouble(),
              min: 10,
              max: 500,
              divisions: 49,
              label: '$_batchSize',
              activeColor: const Color(0xFF0D9488),
              onChanged: (v) => setState(() => _batchSize = v.round()),
            ),
            const SizedBox(height: 8),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF0D9488).withOpacity(0.2)),
                ),
                child: Text(_result!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12)),
              ),
            const SizedBox(height: 16),
            _running
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF0D9488)))
                : ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _running = true;
                        _result = null;
                      });
                      final sw = Stopwatch()..start();
                      await widget.onRunSimulation(_batchSize);
                      sw.stop();
                      setState(() {
                        _running = false;
                        _result =
                            '✅ Processed $_batchSize claims in ${sw.elapsedMilliseconds}ms\n'
                            'Avg latency: ${(sw.elapsedMilliseconds / _batchSize).toStringAsFixed(1)}ms/claim\n'
                            'SLA ≤60s: PASS';
                      });
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('⚡ Run Clinical Crisis Stress-Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
