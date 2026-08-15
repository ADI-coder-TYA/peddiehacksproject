import 'package:flutter/material.dart';
import '../models/ticket.dart';
import 'glass_card.dart';

class TicketCard extends StatefulWidget {
  final Ticket ticket;
  final VoidCallback? onTapOverride;

  const TicketCard({super.key, required this.ticket, this.onTapOverride});

  @override
  State<TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<TicketCard> {
  bool _isHovered = false;

  Color _getCrisisColor(double severity) {
    if (severity > 0.75) return const Color(0xFFEE4D9F);
    if (severity > 0.45) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Color _getCardBackgroundColor(double severity) {
    if (severity > 0.75) return const Color(0xFFEE4D9F).withValues(alpha: 0.06);
    if (severity > 0.45) return const Color(0xFFF59E0B).withValues(alpha: 0.06);
    return Colors.white.withValues(alpha: 0.8);
  }

  bool _isAnomalyOrFraud(String? reason, String status) {
    if (status == 'Flagged') return true;
    if (reason == null) return false;
    final upper = reason.toUpperCase();
    return upper.contains('ANOMALY') ||
        upper.contains('FRAUD') ||
        upper.contains('DUPLICATE') ||
        upper.contains('VELOCITY') ||
        upper.contains('GAMING');
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final bool hasAnomaly = _isAnomalyOrFraud(ticket.flagReason, ticket.status);
    final Color severityColor = _getCrisisColor(ticket.crisisSeverityIndex);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: GlassCard(
            borderRadius: 20,
            padding: EdgeInsets.zero,
            backgroundColor: _getCardBackgroundColor(ticket.crisisSeverityIndex),
            border: Border.all(
              color: _isHovered
                  ? severityColor.withValues(alpha: 0.5)
                  : (hasAnomaly
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.9)),
              width: _isHovered ? 1.8 : 1.2,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTapOverride ??
                  () {
                    Scaffold.of(context).openEndDrawer();
                  },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Anomaly / Fraud Sentinel Banner
                  if (hasAnomaly)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFFCA5A5), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 12),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'FRAUD SENTINEL: ${ticket.flagReason ?? "Quarantined for manual review"}',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [severityColor, const Color(0xFF8B5CF6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.white,
                                      child: Icon(Icons.person, size: 16, color: Color(0xFF1F1B2C)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ticket.studentPhone.isNotEmpty ? ticket.studentPhone : 'Patient #${ticket.id.substring(0, ticket.id.length > 8 ? 8 : ticket.id.length)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F1B2C),
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ID #${ticket.id.substring(0, ticket.id.length > 8 ? 8 : ticket.id.length)} • ${ticket.urgencyLevel}',
                                          style: TextStyle(
                                            color: const Color(0xFF1F1B2C).withValues(alpha: 0.5),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (ticket.status == 'Approved' || ticket.status == 'Resolved')
                                    ? const Color(0xFFD1FAE5)
                                    : (ticket.status == 'Escalated' || ticket.status == 'Flagged'
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFEFF6FF)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (ticket.status == 'Approved' || ticket.status == 'Resolved')
                                      ? const Color(0xFF6EE7B7)
                                      : (ticket.status == 'Escalated' || ticket.status == 'Flagged'
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFBFDBFE)),
                                ),
                              ),
                              child: Text(
                                ticket.status,
                                style: TextStyle(
                                  color: (ticket.status == 'Approved' || ticket.status == 'Resolved')
                                      ? const Color(0xFF047857)
                                      : (ticket.status == 'Escalated' || ticket.status == 'Flagged'
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFF1D4ED8)),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Category Pill
                        if (ticket.parsedCategory.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1B2C).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_hospital_outlined, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    ticket.parsedCategory,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Text(
                          ticket.rawMessage.isNotEmpty ? ticket.rawMessage : 'No additional symptoms reported.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1F1B2C).withValues(alpha: 0.85),
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        
                        // Financial Copay Breakdown in Card
                        if (ticket.calculatedAmount > 0 || (ticket.recommendedGrantAmount ?? 0) > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bill: ₹${ticket.calculatedAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F1B2C).withValues(alpha: 0.65),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.verified, size: 12, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Copay: ₹${(ticket.recommendedGrantAmount ?? ticket.calculatedAmount).toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Crisis Severity Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Severity ',
                                    style: TextStyle(
                                      color: severityColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    (ticket.crisisSeverityIndex * 100).toStringAsFixed(0),
                                    style: TextStyle(
                                      color: severityColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Matched Policy Badge
                            if (ticket.matchedPolicyName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.policy_outlined, size: 12, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text(
                                      ticket.matchedPolicyName!.length > 18
                                          ? '${ticket.matchedPolicyName!.substring(0, 18)}...'
                                          : ticket.matchedPolicyName!,
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Disbursement Rail Badge
                            if (ticket.status == 'Approved' || ticket.status == 'Resolved')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt, size: 14, color: Color(0xFF059669)),
                                    const SizedBox(width: 4),
                                    Text(
                                      ticket.payoutMethod?.replaceAll('RAZORPAY_', '') ?? 'Disbursed',
                                      style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
