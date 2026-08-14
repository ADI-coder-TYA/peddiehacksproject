import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StressTestModal extends StatefulWidget {
  const StressTestModal({super.key});

  @override
  State<StressTestModal> createState() => _StressTestModalState();
}

class _StressTestModalState extends State<StressTestModal> {
  int _selectedCount = 10;
  bool _isRunning = false;
  Map<String, dynamic>? _benchmarkReport;

  Future<void> _runStressTest() async {
    setState(() {
      _isRunning = true;
      _benchmarkReport = null;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Trigger simulation backend benchmark run
      final response = await ApiService().runCrisisStressTest(scenarioCount: _selectedCount);
      final report = response['benchmarkReport'] as Map<String, dynamic>?;

      setState(() {
        _benchmarkReport = report;
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('⚡ Simulation completed! Avg latency: ${report?['avgProcessingTimeMs']}ms / ticket'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Simulation error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  Widget _buildBenchmarkCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 520;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Clinical Crisis SLA Stress-Tester & Simulator',
                              style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 16, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 20),

                const Text(
                  'Select synthetic clinical emergency batch size to benchmark local intake throughput, ESI triage inference speed, and Fraud Sentinel quarantines.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Batch Count Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 20].map((count) {
                    final isSelected = _selectedCount == count;
                    return FilterChip(
                      label: Text('$count Clinical Cases'),
                      selected: isSelected,
                      onSelected: _isRunning ? null : (_) => setState(() => _selectedCount = count),
                      selectedColor: const Color(0xFF0D9488),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Progress Indicator during active simulation
                if (_isRunning) ...[
                  const LinearProgressIndicator(color: Color(0xFF0D9488), backgroundColor: Color(0xFF1E293B)),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '⚡ Simulating $_selectedCount clinical emergency claims through MedAccess pipeline...',
                      style: const TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Benchmark Results Cards
                if (_benchmarkReport != null) ...[
                  const Text(
                    '📊 REAL-TIME SLA BENCHMARK RESULTS',
                    style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: isMobile ? 1 : 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: isMobile ? 3.0 : 2.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBenchmarkCard(
                        'Average Triage Speed',
                        '${_benchmarkReport!['avgProcessingTimeMs']} ms / ticket',
                        Icons.speed,
                        const Color(0xFF10B981),
                      ),
                      _buildBenchmarkCard(
                        'Policy Match Accuracy',
                        '${_benchmarkReport!['policyMatchAccuracy']}%',
                        Icons.verified,
                        const Color(0xFF3B82F6),
                      ),
                      _buildBenchmarkCard(
                        'Fraud Quarantines',
                        '${_benchmarkReport!['fraudFlaggedCount']} Flagged',
                        Icons.shield,
                        const Color(0xFFEF4444),
                      ),
                      _buildBenchmarkCard(
                        'Auto-Allocated Relief',
                        '\$${(_benchmarkReport!['totalDisbursedRecommended'] as num).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        Icons.payments,
                        const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Run Simulation Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runStressTest,
                    icon: const Icon(Icons.flash_on, color: Colors.white, size: 18),
                    label: Text(_isRunning ? 'Running Stress-Test...' : '⚡ Execute Crisis Stress-Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
