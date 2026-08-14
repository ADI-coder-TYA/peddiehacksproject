import 'package:flutter/material.dart';

class VoiceDistressRecorder extends StatefulWidget {
  final void Function(String transcription) onTranscribed;
  const VoiceDistressRecorder({super.key, required this.onTranscribed});

  @override
  State<VoiceDistressRecorder> createState() => _VoiceDistressRecorderState();
}

class _VoiceDistressRecorderState extends State<VoiceDistressRecorder>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _recording = !_recording);
    if (!_recording) {
      // Simulate Whisper transcription
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onTranscribed('I need emergency help with a hospital bill');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _recording
                  ? const Color(0xFFEF4444).withOpacity(0.1 + _pulse.value * 0.2)
                  : const Color(0xFF0D9488).withOpacity(0.1),
              border: Border.all(
                color: _recording ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                width: 2,
              ),
            ),
            child: child,
          ),
          child: IconButton(
            onPressed: _toggle,
            icon: Icon(
              _recording ? Icons.stop : Icons.mic,
              size: 32,
              color: _recording ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _recording ? 'Recording... tap to stop' : 'Tap mic to describe emergency',
          style: TextStyle(
            color: _recording ? const Color(0xFFEF4444) : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
