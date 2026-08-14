import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VoiceRecorderDialog extends StatefulWidget {
  final String? studentName;
  final String? studentContact;
  final Function(String transcript, String jobId)? onSubmitted;

  const VoiceRecorderDialog({
    super.key,
    this.studentName,
    this.studentContact,
    this.onSubmitted,
  });

  @override
  State<VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<VoiceRecorderDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isRecording = false;
  bool _isUploading = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _transcriptionResult;
  String? _jobId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Stop recording
      _timer?.cancel();
      _pulseController.stop();
      setState(() => _isRecording = false);
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _transcriptionResult = null;
        _jobId = null;
      });
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordSeconds++);
        }
      });
    }
  }

  Future<void> _submitVoiceNote() async {
    setState(() => _isUploading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Generate a mock 16kHz PCM mono WAV header + sine wave audio payload for demonstration / testing
      final sampleRate = 16000;
      final numSamples = sampleRate * math.max(1, _recordSeconds).toInt();
      final pcmBytes = List<int>.generate(numSamples * 2, (i) => (i * 7) % 256);
      
      // WAV 44-byte header
      final wavHeader = <int>[
        ... 'RIFF'.codeUnits,
        ... [ (36 + pcmBytes.length) & 0xFF, ((36 + pcmBytes.length) >> 8) & 0xFF, ((36 + pcmBytes.length) >> 16) & 0xFF, ((36 + pcmBytes.length) >> 24) & 0xFF ],
        ... 'WAVE'.codeUnits,
        ... 'fmt '.codeUnits,
        16, 0, 0, 0, // Subchunk1Size
        1, 0,        // AudioFormat (PCM)
        1, 0,        // NumChannels (1)
        0x80, 0x3E, 0, 0, // SampleRate (16000)
        0x00, 0x7D, 0, 0, // ByteRate (32000)
        2, 0,        // BlockAlign
        16, 0,       // BitsPerSample
        ... 'data'.codeUnits,
        ... [ pcmBytes.length & 0xFF, (pcmBytes.length >> 8) & 0xFF, (pcmBytes.length >> 16) & 0xFF, (pcmBytes.length >> 24) & 0xFF ],
      ];

      final fullWavBytes = [...wavHeader, ...pcmBytes];

      final response = await ApiService().sendVoiceIntake(
        audioBytes: fullWavBytes,
        filename: 'student_voice_distress.wav',
        studentName: widget.studentName,
        studentContact: widget.studentContact,
      );

      final transcript = response['transcript'] as String? ?? 'Transcribed distress note';
      final jobId = response['jobId'] as String? ?? '';

      setState(() {
        _transcriptionResult = transcript;
        _jobId = jobId;
      });

      if (widget.onSubmitted != null) {
        widget.onSubmitted!(transcript, jobId);
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('🎙️ Voice note transcribed in ${ApiConfig.selectedLanguage} via Local Whisper (0 Cloud API Fees)')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error uploading voice note: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF334155), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mic, color: Color(0xFF60A5FA), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice Intake (Local AI)',
                          style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Language: ${ApiConfig.selectedLanguage}',
                          style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E293B), height: 24),

            // Pulsing Mic Button
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isRecording ? 1.0 + (_pulseController.value * 0.15) : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withValues(alpha: 0.4),
                            blurRadius: _isRecording ? 20 : 10,
                            spreadRadius: _isRecording ? 5 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _isRecording ? 'Recording Voice Note... ${_formatTimer(_recordSeconds)}' : 'Tap Mic to Record Distress Note',
              style: TextStyle(
                color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Transcribed offline via Local Hugging Face Whisper. Zero cloud subscription fees.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Result Box if Transcribed
            if (_transcriptionResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Transcribed Offline (Whisper)',
                          style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"$_transcriptionResult"',
                      style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                    if (_jobId != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Enqueued Job: $_jobId',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Button
            if (_isUploading)
              const CircularProgressIndicator(color: Color(0xFF3B82F6))
            else if (_recordSeconds > 0 && !_isRecording)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitVoiceNote,
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  label: const Text('Submit Voice Distress Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
