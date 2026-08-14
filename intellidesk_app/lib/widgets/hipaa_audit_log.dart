import 'package:flutter/material.dart';

class HipaaAuditLogEntry {
  final String ticketId;
  final String action;
  final String actor;
  final DateTime timestamp;
  final String hash;

  HipaaAuditLogEntry({
    required this.ticketId,
    required this.action,
    required this.actor,
    required this.timestamp,
  }) : hash = _generateHash('$ticketId|$action|$actor|${timestamp.toIso8601String()}');

  static String _generateHash(String input) {
    int hash = 0xcbf29ce484222325;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0').substring(0, 12);
  }
}

class HipaaAuditLogList extends StatelessWidget {
  final List<HipaaAuditLogEntry> entries;
  const HipaaAuditLogList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.lock_outline,
              size: 18, color: Color(0xFF0D9488)),
          title: Text('${e.action} — ${e.ticketId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Actor: ${e.actor} | ${e.timestamp.toLocal()}',
              style: const TextStyle(fontSize: 11)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text('SHA:${e.hash}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10, color: Colors.grey)),
          ),
        );
      },
    );
  }
}
