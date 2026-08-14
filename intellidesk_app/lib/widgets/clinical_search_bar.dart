import 'package:flutter/material.dart';

class ClinicalSearchBar extends StatefulWidget {
  final String hint;
  final void Function(String) onSearch;
  final List<String> filters;
  final void Function(String)? onFilterSelected;

  const ClinicalSearchBar({
    super.key,
    this.hint = 'Search claims, tickets, policies...',
    required this.onSearch,
    this.filters = const [],
    this.onFilterSelected,
  });

  @override
  State<ClinicalSearchBar> createState() => _ClinicalSearchBarState();
}

class _ClinicalSearchBarState extends State<ClinicalSearchBar> {
  final _ctrl = TextEditingController();
  String? _activeFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: TextField(
            controller: _ctrl,
            onChanged: widget.onSearch,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF0D9488)),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        widget.onSearch('');
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: widget.onSearch,
          ),
        ),
        if (widget.filters.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.filters.map((f) {
                final active = _activeFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    selected: active,
                    selectedColor: const Color(0xFF0D9488).withOpacity(0.15),
                    checkmarkColor: const Color(0xFF0D9488),
                    onSelected: (_) {
                      setState(() => _activeFilter = active ? null : f);
                      if (widget.onFilterSelected != null) {
                        widget.onFilterSelected!(active ? '' : f);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
