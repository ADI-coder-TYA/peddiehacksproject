import 'package:flutter/material.dart';
import '../widgets/clinical_widgets.dart';

class CopayAdjudicationModal extends StatefulWidget {
  final String ticketId;
  final double requestedAmount;
  final void Function(double approvedAmount, String note) onDisburse;

  const CopayAdjudicationModal({
    super.key,
    required this.ticketId,
    required this.requestedAmount,
    required this.onDisburse,
  });

  @override
  State<CopayAdjudicationModal> createState() => _CopayAdjudicationModalState();
}

class _CopayAdjudicationModalState extends State<CopayAdjudicationModal> {
  late double _approvedAmount;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _approvedAmount = widget.requestedAmount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFF0D9488)),
          const SizedBox(width: 8),
          const Text('Disburse Copay Relief'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ticket: ${widget.ticketId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Text('Requested: \$${widget.requestedAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('Approved Amount: \$${_approvedAmount.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700)),
          Slider(
            value: _approvedAmount,
            min: 0,
            max: widget.requestedAmount * 1.2,
            divisions: 100,
            activeColor: const Color(0xFF0D9488),
            onChanged: (v) => setState(() => _approvedAmount = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Adjudication Note (optional)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ClinicalButton(
          label: '💳 Disburse Relief',
          onPressed: () {
            widget.onDisburse(_approvedAmount, _noteCtrl.text);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
