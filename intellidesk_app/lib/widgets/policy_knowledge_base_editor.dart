import 'package:flutter/material.dart';
import '../models/clinical_policy.dart';
import '../widgets/clinical_widgets.dart';

class PolicyKnowledgeBaseEditor extends StatefulWidget {
  final List<ClinicalPolicy> policies;
  final void Function(ClinicalPolicy) onSave;

  const PolicyKnowledgeBaseEditor({
    super.key,
    required this.policies,
    required this.onSave,
  });

  @override
  State<PolicyKnowledgeBaseEditor> createState() => _PolicyKnowledgeBaseEditorState();
}

class _PolicyKnowledgeBaseEditorState extends State<PolicyKnowledgeBaseEditor> {
  ClinicalPolicy? _selected;
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Policy list
        SizedBox(
          width: 240,
          child: ListView.separated(
            itemCount: widget.policies.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = widget.policies[i];
              return ListTile(
                selected: _selected?.id == p.id,
                selectedTileColor: const Color(0xFF0D9488).withOpacity(0.08),
                leading: const Icon(Icons.policy_outlined, color: Color(0xFF0D9488)),
                title: Text(p.title, style: const TextStyle(fontSize: 13)),
                subtitle: Text(p.category, style: const TextStyle(fontSize: 11)),
                onTap: () {
                  setState(() {
                    _selected = p;
                    _ctrl.text = p.content;
                  });
                },
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        // Editor pane
        Expanded(
          child: _selected == null
              ? const Center(
                  child: Text('Select a policy to edit',
                      style: TextStyle(color: Colors.grey)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selected!.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Policy content...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClinicalButton(
                        label: 'Save Policy',
                        icon: Icons.save_outlined,
                        onPressed: () {
                          if (_selected != null) {
                            widget.onSave(ClinicalPolicy(
                              id: _selected!.id,
                              title: _selected!.title,
                              category: _selected!.category,
                              content: _ctrl.text,
                              updatedAt: DateTime.now(),
                            ));
                          }
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
