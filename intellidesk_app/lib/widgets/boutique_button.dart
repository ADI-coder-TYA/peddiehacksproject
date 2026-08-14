import 'package:flutter/material.dart';

class BoutiqueButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;
  final String? tooltip;

  const BoutiqueButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.95,
    this.tooltip,
  });

  @override
  State<BoutiqueButton> createState() => _BoutiqueButtonState();
}

class _BoutiqueButtonState extends State<BoutiqueButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _scale = widget.scaleFactor);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _scale = 1.0);
    widget.onPressed!();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    Widget buttonWidget = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: isDisabled ? 1.0 : _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDisabled ? 0.5 : 1.0,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: buttonWidget,
      );
    }
    return buttonWidget;
  }
}

