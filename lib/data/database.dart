import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PocketDatabase {
  PocketDatabase._();
  static final PocketDatabase instance = PocketDatabase._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'pocket.db');
    _db = await openDatabase(
      path,
      version: 3,
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

        await db.execute('''
          CREATE TABLE fixed_deductions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            deleted_at INTEGER
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
      },
    );
    return _db!;
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
  }
}
