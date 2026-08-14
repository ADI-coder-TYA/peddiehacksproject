import 'package:flutter/material.dart';

enum TriageStage {
  submitted,
  triageActive,
  claimVerified,
  copayDisbursed,
}

extension TriageStageExt on TriageStage {
  String get label {
    switch (this) {
      case TriageStage.submitted:
        return 'Claim Submitted';
      case TriageStage.triageActive:
        return 'Clinical Triage Active';
      case TriageStage.claimVerified:
        return 'Claim Verified';
      case TriageStage.copayDisbursed:
        return 'Copay Grant Disbursed';
    }
  }

  IconData get icon {
    switch (this) {
      case TriageStage.submitted:
        return Icons.upload_file_outlined;
      case TriageStage.triageActive:
        return Icons.monitor_heart_outlined;
      case TriageStage.claimVerified:
        return Icons.verified_outlined;
      case TriageStage.copayDisbursed:
        return Icons.payments_outlined;
    }
  }
}

class EsiProgressTracker extends StatelessWidget {
  final TriageStage currentStage;

  const EsiProgressTracker({super.key, required this.currentStage});

  @override
  Widget build(BuildContext context) {
    final stages = TriageStage.values;
    return Column(
      children: stages.map((stage) {
        final isDone = stage.index <= currentStage.index;
        final isCurrent = stage == currentStage;
        return Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF0D9488) : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(stage.icon,
                  size: 18,
                  color: isDone ? Colors.white : Colors.grey.shade400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                stage.label,
                style: TextStyle(
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isDone ? const Color(0xFF0D9488) : Colors.grey,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
