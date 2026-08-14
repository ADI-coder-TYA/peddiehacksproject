import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/claims_provider.dart';
import '../../widgets/clinical_widgets.dart';

class ClaimsHistoryScreen extends StatelessWidget {
  const ClaimsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final claims = context.watch<ClaimsProvider>().claims;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Claims History'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: claims.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 60, color: Color(0xFF0D9488)),
                  SizedBox(height: 12),
                  Text('No claims submitted yet',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: claims.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final claim = claims[i];
                return GlassClinicCard(
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined,
                          color: Color(0xFF0D9488)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(claim.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('\$${claim.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(claim.status,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            const Color(0xFF0D9488).withOpacity(0.1),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
