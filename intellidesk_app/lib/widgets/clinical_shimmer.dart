import 'package:flutter/material.dart';

/// Animated loading shimmer for clinical data placeholders
class ClinicalShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ClinicalShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<ClinicalShimmer> createState() => _ClinicalShimmerState();
}

class _ClinicalShimmerState extends State<ClinicalShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_anim.value - 0.3).clamp(0.0, 1.0),
                _anim.value.clamp(0.0, 1.0),
                (_anim.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFFE8F5F3),
                Color(0xFFB2DFDB),
                Color(0xFFE8F5F3),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Full card shimmer placeholder
class ClinicalCardShimmer extends StatelessWidget {
  const ClinicalCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClinicalShimmer(width: 36, height: 36, borderRadius: 18),
              SizedBox(width: 12),
              Expanded(child: ClinicalShimmer(height: 14)),
            ],
          ),
          SizedBox(height: 10),
          ClinicalShimmer(height: 12),
          SizedBox(height: 6),
          ClinicalShimmer(width: 120, height: 12),
        ],
      ),
    );
  }
}
