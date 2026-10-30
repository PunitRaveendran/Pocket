import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PocketDatabase {
  PocketDatabase._();
  static final PocketDatabase instance = PocketDatabase._();

  Database? _db;
  String? _dbPath;

  Future<String> get dbPath async {
    if (_dbPath != null) return _dbPath!;
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = p.join(dir.path, 'pocket.db');
    return _dbPath!;
  }

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    final path = await dbPath;
    _db = await openDatabase(
      path,
      version: 5,
      onConfigure: (db) async {
        try {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.execute('PRAGMA journal_mode = WAL;');
          await db.execute('PRAGMA synchronous = NORMAL;');
          await db.execute('PRAGMA temp_store = MEMORY;');
        } catch (_) {
          // Fallback gracefully on environments with restricted SQLite configs
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT NOT NULL,
            is_system INTEGER NOT NULL,
            sort_order INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE outings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            local_date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            deleted_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE txns (
            id TEXT PRIMARY KEY,
            amount_paise INTEGER NOT NULL,
            direction TEXT NOT NULL,
            occurred_at INTEGER NOT NULL,
            local_date TEXT NOT NULL,
            merchant TEXT NOT NULL,
            category_id TEXT NOT NULL,
            bucket TEXT NOT NULL,
            outing_id TEXT,
            note TEXT NOT NULL DEFAULT '',
            deleted_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_txns_date ON txns(local_date)');
        await db.execute('CREATE INDEX idx_txns_outing ON txns(outing_id)');
        await db.execute('CREATE INDEX idx_txns_composite ON txns(deleted_at, bucket, local_date)');

        await db.execute('''
          CREATE TABLE friend_splits (
            id TEXT PRIMARY KEY,
            friend_name TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            direction TEXT NOT NULL,
            occurred_at INTEGER NOT NULL,
            local_date TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            is_settled INTEGER NOT NULL DEFAULT 0,
            settled_at INTEGER,
            deleted_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_splits_date ON friend_splits(local_date)');
        await db.execute('CREATE INDEX idx_splits_friend ON friend_splits(friend_name)');
        await db.execute('CREATE INDEX idx_splits_composite ON friend_splits(deleted_at, is_settled, friend_name)');

        await db.execute('''
          CREATE TABLE fixed_deductions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            deleted_at INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_outings_composite ON outings(deleted_at, local_date)');

        await db.execute('''
          CREATE TABLE pending_inbox (
            id TEXT PRIMARY KEY,
            amount_paise INTEGER NOT NULL,
            direction TEXT NOT NULL,
            occurred_at INTEGER NOT NULL,
            local_date TEXT NOT NULL,
            merchant TEXT NOT NULL,
            suggested_category_id TEXT,
            raw_source TEXT NOT NULL,
            message_id TEXT UNIQUE,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_inbox_status ON pending_inbox(status)');

        await db.execute('''
          CREATE TABLE merchant_memory (
            merchant_clean TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            last_used_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE friend_splits (
              id TEXT PRIMARY KEY,
              friend_name TEXT NOT NULL,
              amount_paise INTEGER NOT NULL,
              direction TEXT NOT NULL,
              occurred_at INTEGER NOT NULL,
              local_date TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              is_settled INTEGER NOT NULL DEFAULT 0,
              settled_at INTEGER,
              deleted_at INTEGER
            )
          ''');
          await db.execute('CREATE INDEX idx_splits_date ON friend_splits(local_date)');
          await db.execute('CREATE INDEX idx_splits_friend ON friend_splits(friend_name)');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE fixed_deductions (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              amount_paise INTEGER NOT NULL,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              deleted_at INTEGER
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_txns_composite ON txns(deleted_at, bucket, local_date)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_splits_composite ON friend_splits(deleted_at, is_settled, friend_name)');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_outings_composite ON outings(deleted_at, local_date)');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_inbox (
              id TEXT PRIMARY KEY,
              amount_paise INTEGER NOT NULL,
              direction TEXT NOT NULL,
              occurred_at INTEGER NOT NULL,
              local_date TEXT NOT NULL,
              merchant TEXT NOT NULL,
              suggested_category_id TEXT,
              raw_source TEXT NOT NULL,
              message_id TEXT UNIQUE,
              status TEXT NOT NULL DEFAULT 'pending',
              created_at INTEGER NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_inbox_status ON pending_inbox(status)');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS merchant_memory (
              merchant_clean TEXT PRIMARY KEY,
              category_id TEXT NOT NULL,
              last_used_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
    return _db!;
  }

  /// Compacts and defragments database pages and re-optimizes query planner statistics.
  Future<void> optimize() async {
    final database = await db;
    try {
      await database.execute('PRAGMA optimize;');
      await database.execute('VACUUM;');
    } catch (_) {}
  }

  /// Runs SQLite PRAGMA integrity_check and returns status string ('ok').
  Future<String> checkIntegrity() async {
    final database = await db;
    try {
      final rows = await database.rawQuery('PRAGMA integrity_check(1);');
      if (rows.isNotEmpty && rows.first.values.isNotEmpty) {
        return '${rows.first.values.first}';
      }
      return 'ok';
    } catch (e) {
      return 'error: $e';
    }
  }

  /// Computes the total on-disk storage footprint of the SQLite database (including WAL & SHM files).
  Future<int> getDatabaseSizeBytes() async {
    try {
      final mainPath = await dbPath;
      var total = 0;
      for (final ext in ['', '-wal', '-shm']) {
        final f = File('$mainPath$ext');
        if (await f.exists()) {
          total += await f.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Permanently removes soft-deleted records older than [olderThanDays] and vacuums the database.
  Future<int> purgeDeletedRecords({int olderThanDays = 30}) async {
    final database = await db;
    final cutoffMs = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;

    var deletedCount = 0;
    await database.transaction((txn) async {
      deletedCount += await txn.delete('txns', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoffMs]);
      deletedCount += await txn.delete('friend_splits', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoffMs]);
      deletedCount += await txn.delete('outings', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoffMs]);
      deletedCount += await txn.delete('fixed_deductions', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoffMs]);
    });

    if (deletedCount > 0) {
      await optimize();
    }
    return deletedCount;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> wipe() async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete('fixed_deductions');
      await txn.delete('friend_splits');
      await txn.delete('txns');
      await txn.delete('outings');
      await txn.delete('categories');
      await txn.delete('settings');
    });
    await optimize();
  }
}
