import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/ticket_provider.dart';
import '../models/ticket.dart';
import 'config/api_config.dart';
import 'utils/currency_formatter.dart';
import 'widgets/glass_card.dart';
import 'widgets/approval_desk_dialog.dart';
import 'widgets/stress_test_modal.dart';

// ============================================================================
// Data Models
// ============================================================================
class CrisisIncident {
  final String ticketId;
  final String studentName;
  final String contactPhone;
  final String location;
  final String crisisType;
  final DateTime reportedAt;
  final String aiSummary;
  final double crisisSeverityIndex;
  final Ticket ticket;

  CrisisIncident({
    required this.ticketId,
    required this.studentName,
    required this.contactPhone,
    required this.location,
    required this.crisisType,
    required this.reportedAt,
    required this.aiSummary,
    required this.crisisSeverityIndex,
    required this.ticket,
  });
}

// ============================================================================
// Main War Room Screen Structure
// ============================================================================
class EmergencyWarRoomScreen extends StatefulWidget {
  const EmergencyWarRoomScreen({super.key});

  @override
  State<EmergencyWarRoomScreen> createState() => _EmergencyWarRoomScreenState();
}

class _EmergencyWarRoomScreenState extends State<EmergencyWarRoomScreen> {
  void _handleIncidentResolved(String ticketId, String actionNote) async {
    final provider = Provider.of<TicketProvider>(context, listen: false);
    try {
      await provider.approveTicket(ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving ticket: $e')),
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incident logged: $actionNote')),
      );
    }
  }

  CrisisIncident _mapTicketToIncident(Ticket t) {
    return CrisisIncident(
      ticketId: t.id,
      studentName: 'Student (${t.studentPhone})', 
      contactPhone: t.studentPhone,
      location: 'Unknown Location', 
      crisisType: t.parsedCategory,
      reportedAt: t.createdAt,
      aiSummary: t.thoughtProcess ?? t.rawMessage,
      crisisSeverityIndex: t.crisisSeverityIndex,
      ticket: t,
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<TicketProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.tickets.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          final activeTickets = provider.tickets.where((t) => 
            t.status != 'Resolved' && t.status != 'Denied' && 
            (t.status.toLowerCase() == 'escalated' || t.crisisSeverityIndex >= 0.7)
          ).toList();

          final activeIncidents = activeTickets.map(_mapTicketToIncident).toList();
          final totalDisbursed = provider.tickets.where((t) => t.status == 'Auto-Approved' || t.status == 'Approved' || t.status == 'Copay Grant Disbursed')
              .fold<double>(0.0, (acc, t) => acc + t.calculatedAmount);
          final quarantinedCount = provider.tickets.where((t) => t.fraudStatus == 'FLAGGED' || t.status == 'Quarantined').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monitor_heart, color: Color(0xFFEF4444), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MedAccess Clinical Triage & Emergency Copay War Room',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Real-time clinical distress monitoring, ESI Level 1-3 triage & emergency copay relief',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Top War Room Actions Bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const StressTestModal(),
                          );
                        },
                        icon: const Icon(Icons.bolt, size: 16, color: Colors.white),
                        label: const Text('⚡ Run Clinical Crisis Stress-Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('${ApiConfig.baseUrl}/reports/audit-pdf');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF0D9488)),
                        label: const Text('📑 Export Health Audit PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (activeTickets.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (_) => ApprovalDeskDialog(ticket: activeTickets.first),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No pending clinical claims to disburse.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.credit_card, size: 16, color: Colors.white),
                        label: const Text('💳 Disburse Copay Relief', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4 Metric Cards
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Copay Funds Disbursed',
                          CurrencyFormatter.format(totalDisbursed),
                          Icons.payments_outlined,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          'Active Medical Emergencies',
                          '${activeIncidents.length}',
                          Icons.emergency,
                          const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          'Avg Triage Latency (ESI)',
                          '42s',
                          Icons.speed,
                          const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          'Fraud Quarantined Claims',
                          '$quarantinedCount',
                          Icons.security,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),

                CriticalCrisisHeader(criticalCount: activeIncidents.length),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: activeIncidents.length,
                  itemBuilder: (context, index) {
                    return EmergencyIncidentCard(
                      incident: activeIncidents[index],
                      onResolved: _handleIncidentResolved,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 1. High-Priority Alert Banner & Sound Handler (CriticalCrisisHeader)
// ============================================================================
class CriticalCrisisHeader extends StatefulWidget {
  final int criticalCount;
  const CriticalCrisisHeader({super.key, required this.criticalCount});

  @override
  State<CriticalCrisisHeader> createState() => _CriticalCrisisHeaderState();
}

class _CriticalCrisisHeaderState extends State<CriticalCrisisHeader> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<Color?> _colorAnimation;
  bool _muted = false; 

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFFFF0F0),
      end: const Color(0xFFFFE0E0),
    ).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.criticalCount == 0 || _muted) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          borderRadius: 24.0,
          backgroundColor: _colorAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'CRITICAL INCIDENTS DETECTED',
                      style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.criticalCount} active emergencies require immediate dispatch intervention.',
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _muted = true);
                  },
                  icon: const Icon(Icons.volume_off, color: Color(0xFFC62828), size: 18),
                  label: const Text('Mute Alarm', style: TextStyle(color: Color(0xFFC62828))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFC62828)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// 2. Incident Command Grid (EmergencyIncidentCard)
// ============================================================================
class EmergencyIncidentCard extends StatefulWidget {
  final CrisisIncident incident;
  final Function(String ticketId, String actionNote) onResolved;

  const EmergencyIncidentCard({super.key, required this.incident, required this.onResolved});

  @override
  State<EmergencyIncidentCard> createState() => _EmergencyIncidentCardState();
}

class _EmergencyIncidentCardState extends State<EmergencyIncidentCard> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.incident.reportedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.incident.reportedAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}m ${twoDigits(d.inSeconds.remainder(60))}s";
  }

  @override
  Widget build(BuildContext context) {
    final bool isCriticalTime = _elapsed.inMinutes >= 5;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 24),
      backgroundColor: const Color(0xFFFFF0F0).withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Badges & Timer
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFD4D4)),
                  ),
                  child: Text(
                    widget.incident.crisisType,
                    style: const TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                  ),
                ),
                if (widget.incident.ticket.calculatedAmount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, color: Color(0xFF059669), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Requested: \$${widget.incident.ticket.calculatedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCriticalTime ? Colors.white : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isCriticalTime ? const Color(0xFFFFD4D4) : Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, color: isCriticalTime ? const Color(0xFFC62828) : Colors.orange.shade800, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Pending Intervention: ${_formatElapsed(_elapsed)}',
                        style: TextStyle(color: isCriticalTime ? const Color(0xFFC62828) : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Middle Row: Details
            Column(
              children: [
                // Identity & Location block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDetailRow(Icons.person, widget.incident.studentName, titleColor: const Color(0xFF1F1B2C))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDetailRow(Icons.phone, widget.incident.contactPhone, titleColor: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDetailRow(Icons.location_on, widget.incident.location, titleColor: const Color(0xFF1F1B2C))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDetailRow(Icons.tag, 'Ticket ID: ${widget.incident.ticketId}', titleColor: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // AI Summary Block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smart_toy, color: Colors.purple, size: 18),
                              const SizedBox(width: 8),
                              const Text('AI Intake Extraction', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'CSI: ${widget.incident.crisisSeverityIndex.toStringAsFixed(2)}', 
                              style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.incident.aiSummary,
                        style: const TextStyle(color: Colors.black87, height: 1.5, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Divider(color: Colors.black12),
            ),
            
            // Dispatch Actions
            SafetyDispatchActionPanel(
              incident: widget.incident,
              onResolved: (note) => widget.onResolved(widget.incident.ticketId, note),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {Color? titleColor, double fontSize = 14}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: titleColor ?? Colors.black87, fontSize: fontSize, fontWeight: titleColor != null ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 3. Rapid Dispatch Action Panel (SafetyDispatchActionPanel)
// ============================================================================
class SafetyDispatchActionPanel extends StatefulWidget {
  final CrisisIncident incident;
  final Function(String actionNote) onResolved;

  const SafetyDispatchActionPanel({super.key, required this.incident, required this.onResolved});

  @override
  State<SafetyDispatchActionPanel> createState() => _SafetyDispatchActionPanelState();
}

class _SafetyDispatchActionPanelState extends State<SafetyDispatchActionPanel> {
  final TextEditingController _noteController = TextEditingController();

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  void _showResolutionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text('Log Dispatch Action', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Dispatched campus police to dorm, notified counseling on-call.',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                if (_noteController.text.trim().isEmpty) return;
                Navigator.pop(context);
                widget.onResolved(_noteController.text);
              },
              child: const Text('Mark as Handled', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openDisbursementDesk() {
    showDialog(
      context: context,
      builder: (ctx) => ApprovalDeskDialog(
        ticket: widget.incident.ticket,
        onDisbursed: (method, amount, ref) {
          final formatted = CurrencyFormatter.format(amount, currency: widget.incident.ticket.currency);
          widget.onResolved('Disbursed $formatted via $method (Ref: $ref)');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.incident.ticket;
    final hasAmount = t.calculatedAmount > 0;
    final amountLabel = hasAmount
        ? CurrencyFormatter.format(t.calculatedAmount, currency: t.currency)
        : (t.recommendedGrantAmount != null
            ? CurrencyFormatter.format(t.recommendedGrantAmount, currency: t.currency)
            : 'Relief');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Issue Voucher / Razorpay Payout Modal Trigger
        ElevatedButton.icon(
          onPressed: _openDisbursementDesk,
          icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
          label: Text(
            'Issue Bypass Voucher & Payout ($amountLabel)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
        ),
        const SizedBox(height: 12),
        
        // Call Police
        ElevatedButton.icon(
          onPressed: () => _launchUrl('tel:911'),
          icon: const Icon(Icons.local_police_outlined),
          label: const Text('Call Campus Police'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F1B2C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        // Notify Counseling
        ElevatedButton.icon(
          onPressed: () => _launchUrl('mailto:counseling-oncall@university.edu?subject=CRITICAL INCIDENT: ${widget.incident.ticketId}'),
          icon: const Icon(Icons.health_and_safety_outlined),
          label: const Text('Notify Counseling'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        // Resolve Audit Logger
        ElevatedButton.icon(
          onPressed: _showResolutionDialog,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Handled by Human Team'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
