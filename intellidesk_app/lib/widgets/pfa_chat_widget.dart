import 'package:flutter/material.dart';
import '../../widgets/clinical_widgets.dart';

class PfaQuickPrompt {
  final String label;
  final String prompt;
  final IconData icon;
  const PfaQuickPrompt(this.label, this.prompt, this.icon);
}

class PfaChatWidget extends StatefulWidget {
  const PfaChatWidget({super.key});

  @override
  State<PfaChatWidget> createState() => _PfaChatWidgetState();
}

class _PfaChatWidgetState extends State<PfaChatWidget> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _ctrl = TextEditingController();

  static const _prompts = [
    PfaQuickPrompt('Panic Attack', 'I am having a panic attack right now', Icons.psychology_outlined),
    PfaQuickPrompt('Copay Help', 'I need help with emergency hospital copay', Icons.receipt_long_outlined),
    PfaQuickPrompt('Crisis Line', 'Connect me to a crisis counselor', Icons.phone_outlined),
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _ctrl.clear();
      // Simulate PFA response
      _messages.add({
        'role': 'ai',
        'text': 'I hear you. You are safe. Let\'s work through this together. Please tell me more.',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Quick prompts
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _prompts.map((p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Icon(p.icon, size: 14, color: const Color(0xFF0D9488)),
                label: Text(p.label, style: const TextStyle(fontSize: 12)),
                onPressed: () => _send(p.prompt),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Messages
        Expanded(
          child: ListView.builder(
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF0D9488) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isUser ? null : Border.all(color: const Color(0xFF0D9488).withOpacity(0.2)),
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: 'Describe your situation...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _send(_ctrl.text),
              icon: const Icon(Icons.send, color: Color(0xFF0D9488)),
            ),
          ],
        ),
      ],
    );
  }
}
