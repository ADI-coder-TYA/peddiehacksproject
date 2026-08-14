import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../utils/currency_formatter.dart';
import 'glass_card.dart';
import 'boutique_button.dart';
import 'approval_desk_dialog.dart';

class TicketDetailDrawer extends StatelessWidget {
  final Ticket ticket;

  const TicketDetailDrawer({
    super.key,
    required this.ticket,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 440,
      backgroundColor: const Color(0xFFF4F1FB),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                border: Border(
                  bottom: BorderSide(color: const Color(0xFF1F1B2C).withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  BoutiqueButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1B2C).withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20, color: Color(0xFF1F1B2C)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ticket Adjudication',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F1B2C),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'ID #${ticket.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF1F1B2C).withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // Financial Comparison
                  if (ticket.parsedCategory == 'Financial')
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.attach_money, color: Color(0xFF10B981), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Financial Grant Assessment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1F1B2C),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Requested',
                                    style: TextStyle(fontSize: 12, color: const Color(0xFF1F1B2C).withValues(alpha: 0.5)),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(ticket.calculatedAmount, currency: ticket.currency, decimalDigits: 2),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'AI Recommended',
                                    style: TextStyle(fontSize: 12, color: const Color(0xFF1F1B2C).withValues(alpha: 0.5)),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(ticket.recommendedGrantAmount ?? ticket.calculatedAmount, currency: ticket.currency, decimalDigits: 2),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grant Confidence Score',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                              Text(
                                '${((ticket.grantConfidenceScore ?? 0.0) * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: ticket.grantConfidenceScore ?? 0.0,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: (ticket.grantConfidenceScore ?? 0.0) > 0.7
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Chain-of-Thought AI Reasoning Section
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 24,
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEE4D9F).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.psychology, color: Color(0xFFEE4D9F), size: 20),
                      ),
                      title: const Text(
                        'Chain-of-Thought Reasoning',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F1B2C)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF1F1B2C).withValues(alpha: 0.08)),
                                ),
                                child: Text(
                                  ticket.thoughtProcess ?? 'No reasoning provided.',
                                  style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (ticket.matchedPolicyName != null)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.policy, color: Color(0xFFEE4D9F)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                ticket.matchedPolicyName!,
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('AI Policy Verification Trace:',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
                                              const SizedBox(height: 8),
                                              Text(
                                                ticket.thoughtProcess ?? 'No detailed reasoning available.',
                                                style: const TextStyle(fontSize: 14, height: 1.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(dialogContext).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.open_in_new, size: 14, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Matched Policy: ${ticket.matchedPolicyName}',
                                            style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ML Risk Radar / Metrics Card
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.insights, color: Color(0xFF8B5CF6), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'ML Risk Radar & Severity',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F1B2C)),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(height: 1),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flight_takeoff, color: Color(0xFF7C3AED)),
                          title: const Text('Dropout Risk Score', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ticket.dropoutRiskScore.toStringAsFixed(2),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_fire_department, color: Color(0xFFEF4444)),
                          title: const Text('Crisis Severity Index', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ticket.crisisSeverityIndex.toStringAsFixed(2),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bug_report, color: Color(0xFFEC4899)),
                          title: const Text('Anomaly Score', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (ticket.anomalyScore ?? 0.0).toStringAsFixed(4),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDB2777)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F1B2C).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BoutiqueButton(
                    onPressed: () {
                      context.read<TicketProvider>().approveTicket(ticket.id);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F1B2C), Color(0xFF3B3355)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F1B2C).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Confirm AI Decision',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BoutiqueButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (ctx) => ApprovalDeskDialog(ticket: ticket),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFF1F1B2C), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note, color: Color(0xFF1F1B2C), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Override & Manual Approve',
                            style: TextStyle(color: Color(0xFF1F1B2C), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BoutiqueButton(
                    onPressed: () {
                      context.read<TicketProvider>().denyTicket(ticket.id, notes: 'Escalated to Dean');
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward, color: const Color(0xFFEE4D9F), size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Escalate to Dean',
                            style: TextStyle(color: Color(0xFFEE4D9F), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

