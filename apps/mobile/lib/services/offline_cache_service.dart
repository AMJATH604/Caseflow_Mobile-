import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Offline-first cache layer using SQLite.
///
/// Caches cases, hearings, clients, and dashboard data locally so the app
/// functions without internet. Data is synced from Supabase whenever
/// a network connection is available.
///
/// **Strategy: Cache-then-Network**
/// 1. Return cached data immediately for instant UI
/// 2. Fetch fresh data from Supabase in the background
/// 3. Update cache and notify listeners
class OfflineCacheService {
  static Database? _db;
  static const int _dbVersion = 1;
  static const String _dbName = 'caseflow_cache.db';

  // ─── Database Initialization ───────────────────────────

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    // Cases cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_cases (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Hearings cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_hearings (
        id TEXT PRIMARY KEY,
        case_id TEXT,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Clients cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_clients (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Dashboard stats cache
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_stats (
        key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Generic key-value cache for misc data
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_kv (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        ttl_seconds INTEGER DEFAULT 300,
        updated_at TEXT NOT NULL
      )
    ''');

    debugPrint('OfflineCache: SQLite tables created');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  // ─── Network Check ─────────────────────────────────────

  /// Check if the device has an active internet connection.
  static Future<bool> get isOnline async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Stream of connectivity changes.
  static Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
      (results) => !results.contains(ConnectivityResult.none),
    );
  }

  // ─── Cases Cache ───────────────────────────────────────

  /// Cache a list of cases.
  static Future<void> cacheCases(List<Map<String, dynamic>> cases) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final c in cases) {
      batch.insert(
        'cached_cases',
        {
          'id': c['id'],
          'data': jsonEncode(c),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('OfflineCache: Cached ${cases.length} cases');
  }

  /// Get cached cases.
  static Future<List<Map<String, dynamic>>> getCachedCases() async {
    try {
      final db = await database;
      final results = await db.query('cached_cases', orderBy: 'updated_at DESC');
      return results.map((row) {
        return jsonDecode(row['data'] as String) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint('OfflineCache: Error reading cached cases: $e');
      return [];
    }
  }

  // ─── Hearings Cache ────────────────────────────────────

  /// Cache a list of hearings.
  static Future<void> cacheHearings(List<Map<String, dynamic>> hearings) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final h in hearings) {
      batch.insert(
        'cached_hearings',
        {
          'id': h['id'],
          'case_id': h['case_id'],
          'data': jsonEncode(h),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('OfflineCache: Cached ${hearings.length} hearings');
  }

  /// Get cached hearings, optionally filtered by case ID.
  static Future<List<Map<String, dynamic>>> getCachedHearings({String? caseId}) async {
    try {
      final db = await database;
      final results = caseId != null
          ? await db.query('cached_hearings', where: 'case_id = ?', whereArgs: [caseId], orderBy: 'updated_at DESC')
          : await db.query('cached_hearings', orderBy: 'updated_at DESC');
      return results.map((row) {
        return jsonDecode(row['data'] as String) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint('OfflineCache: Error reading cached hearings: $e');
      return [];
    }
  }

  // ─── Clients Cache ─────────────────────────────────────

  /// Cache a list of clients.
  static Future<void> cacheClients(List<Map<String, dynamic>> clients) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final c in clients) {
      batch.insert(
        'cached_clients',
        {
          'id': c['id'],
          'data': jsonEncode(c),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('OfflineCache: Cached ${clients.length} clients');
  }

  /// Get cached clients.
  static Future<List<Map<String, dynamic>>> getCachedClients() async {
    try {
      final db = await database;
      final results = await db.query('cached_clients', orderBy: 'updated_at DESC');
      return results.map((row) {
        return jsonDecode(row['data'] as String) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint('OfflineCache: Error reading cached clients: $e');
      return [];
    }
  }

  // ─── Dashboard Stats Cache ─────────────────────────────

  /// Cache dashboard stats.
  static Future<void> cacheDashboardStats(Map<String, dynamic> stats) async {
    final db = await database;
    // Remove non-serializable data (like Hearing objects)
    final serializable = Map<String, dynamic>.from(stats);
    serializable.remove('todayHearings'); // These are Hearing objects, not raw maps

    await db.insert(
      'cached_stats',
      {
        'key': 'dashboard',
        'data': jsonEncode(serializable),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached dashboard stats.
  static Future<Map<String, dynamic>?> getCachedDashboardStats() async {
    try {
      final db = await database;
      final results = await db.query('cached_stats', where: 'key = ?', whereArgs: ['dashboard']);
      if (results.isEmpty) return null;
      return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('OfflineCache: Error reading cached stats: $e');
      return null;
    }
  }

  // ─── Generic Key-Value Cache ───────────────────────────

  /// Set a cached value with optional TTL (default 5 minutes).
  static Future<void> set(String key, dynamic value, {int ttlSeconds = 300}) async {
    final db = await database;
    await db.insert(
      'cached_kv',
      {
        'key': key,
        'value': jsonEncode(value),
        'ttl_seconds': ttlSeconds,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a cached value, returns null if expired or missing.
  static Future<dynamic> get(String key) async {
    try {
      final db = await database;
      final results = await db.query('cached_kv', where: 'key = ?', whereArgs: [key]);
      if (results.isEmpty) return null;

      final row = results.first;
      final updatedAt = DateTime.parse(row['updated_at'] as String);
      final ttl = row['ttl_seconds'] as int;

      // Check TTL expiry
      if (DateTime.now().difference(updatedAt).inSeconds > ttl) {
        await db.delete('cached_kv', where: 'key = ?', whereArgs: [key]);
        return null;
      }

      return jsonDecode(row['value'] as String);
    } catch (e) {
      return null;
    }
  }

  // ─── Cache Invalidation ────────────────────────────────

  /// Clear all cached data (e.g., on logout).
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('cached_cases');
    await db.delete('cached_hearings');
    await db.delete('cached_clients');
    await db.delete('cached_stats');
    await db.delete('cached_kv');
    debugPrint('OfflineCache: All caches cleared');
  }

  /// Clear specific entity cache.
  static Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }
}
