
import 'package:flutter/material.dart';

class BoutiqueBackground extends StatelessWidget {
  final Widget child;

  const BoutiqueBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lowest layer: Solid soft off-white
        Container(
          color: const Color(0xFFF5F5F7),
        ),
        // Active Screen Content
        child,
      ],
    );
  }
}
