import 'package:flutter/material.dart';

class CopayGrantBadge extends StatelessWidget {
  final double amount;
  final String currency;
  final bool isDisbursed;

  const CopayGrantBadge({
    super.key,
    required this.amount,
    this.currency = 'USD',
    this.isDisbursed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisbursed ? const Color(0xFF0D9488) : const Color(0xFF0284C7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isDisbursed ? Icons.check_circle : Icons.pending,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color),
          ),
          const SizedBox(width: 6),
          Text(
            isDisbursed ? 'DISBURSED' : 'PENDING',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
