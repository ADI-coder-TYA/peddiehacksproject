import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OfflineSyncManager extends ChangeNotifier {
  Database? _db;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'medaccess_offline.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_claims (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> queueClaim(String id, String payload) async {
    await _db?.insert('pending_claims', {
      'id': id,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getPendingClaims() async {
    return await _db?.query('pending_claims') ?? [];
  }

  Future<void> removeClaim(String id) async {
    await _db?.delete('pending_claims', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }
}
