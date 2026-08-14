import 'package:flutter/material.dart';

class ClinicalCategorySelector extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelected;

  static const categories = [
    'Medical Emergency & Inpatient Care',
    'Prescription & Pharmacy Copay',
    'Mental Health & Crisis Intervention',
    'Diagnostic, Lab & Imaging Relief',
    'Physical Therapy & Dental Crisis',
    'General Health & Basic Welfare',
  ];

  static const icons = [
    Icons.local_hospital_outlined,
    Icons.medication_outlined,
    Icons.psychology_outlined,
    Icons.biotech_outlined,
    Icons.healing_outlined,
    Icons.health_and_safety_outlined,
  ];

  const ClinicalCategorySelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Claim Category',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(categories.length, (i) {
            final cat = categories[i];
            final isSelected = selected == cat;
            return GestureDetector(
              onTap: () => onSelected(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0D9488)
                      : const Color(0xFF0D9488).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D9488)
                        : const Color(0xFF0D9488).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icons[i],
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : const Color(0xFF0D9488),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
