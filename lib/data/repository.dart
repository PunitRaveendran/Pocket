import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import 'database.dart';
import 'models.dart';

const _uuid = Uuid();

class PocketRepository {
  PocketRepository(this._db);
  final PocketDatabase _db;

  static const systemCategories = [
    Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
    Category(id: 'snacks', name: 'Snacks', icon: 'snacks', isSystem: true, sortOrder: 1),
    Category(id: 'study', name: 'Study', icon: 'study', isSystem: true, sortOrder: 2),
    Category(id: 'misc', name: 'Misc', icon: 'misc', isSystem: true, sortOrder: 3),
  ];

  // In-memory backing for web browser preview
  static Settings _webSettings = const Settings(
    stipendPaise: 250000,
    cycleStartDay: 1,
    hideAmounts: false,
    onboarded: true,
  );
  static final List<Category> _webCategories = List.of(systemCategories);
  static final List<Outing> _webOutings = [
    Outing(
      id: 'o-sample',
      title: 'Weekend Trek to Nandi Hills',
      localDate: LocalDate.today(),
      note: 'Trip with batchmates',
    ),
  ];
  static final List<Txn> _webTxns = [
    Txn(
      id: 't-1',
      amountPaise: 4000,
      direction: Direction.debit,
      occurredAtMs: DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      localDate: LocalDate.today(),
      merchant: 'Canteen Thali',
      categoryId: 'food',
      bucket: Bucket.daily,
      note: 'Lunch',
    ),
    Txn(
      id: 't-2',
      amountPaise: 1500,
      direction: Direction.debit,
      occurredAtMs: DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
      localDate: LocalDate.today(),
      merchant: 'Chai & Samosa',
      categoryId: 'snacks',
      bucket: Bucket.daily,
      note: 'Evening snack',
    ),
    Txn(
      id: 't-3',
      amountPaise: 35000,
      direction: Direction.debit,
      occurredAtMs: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      localDate: LocalDate.today(),
      merchant: 'Trek Bus Fare',
      categoryId: 'misc',
      bucket: Bucket.outing,
      outingId: 'o-sample',
      note: 'Bus booking',
    ),
  ];

  Future<Ledger> load() async {
    if (kIsWeb) {
      return Ledger(
        settings: _webSettings,
        categories: List.of(_webCategories),
        transactions: List.of(_webTxns),
        outings: List.of(_webOutings),
      );
    }

    final db = await _db.db;
    await _ensureSeed(db);

    final settingRows = await db.query('settings');
    final map = {for (final r in settingRows) r['key'] as String: r['value'] as String};
    final settings = Settings(
      stipendPaise: int.parse(map['stipend_paise'] ?? '${Settings.defaults.stipendPaise}'),
      cycleStartDay: int.parse(map['cycle_start_day'] ?? '${Settings.defaults.cycleStartDay}'),
      hideAmounts: map['hide_amounts'] == '1',
      onboarded: map['onboarded'] == '1',
    );

    final catRows = await db.query('categories', orderBy: 'sort_order ASC');
    final categories = catRows
        .map(
          (r) => Category(
            id: r['id'] as String,
            name: r['name'] as String,
            icon: r['icon'] as String,
            isSystem: (r['is_system'] as int) == 1,
            sortOrder: r['sort_order'] as int,
          ),
        )
        .toList();

    final outingRows = await db.query(
      'outings',
      where: 'deleted_at IS NULL',
      orderBy: 'local_date DESC, title ASC',
    );
    final outings = outingRows
        .map(
          (r) => Outing(
            id: r['id'] as String,
            title: r['title'] as String,
            localDate: LocalDate.parse(r['local_date'] as String),
            note: r['note'] as String,
          ),
        )
        .toList();

    final txnRows = await db.query(
      'txns',
      where: 'deleted_at IS NULL',
      orderBy: 'occurred_at DESC',
    );
    final txns = txnRows.map(_txnFromRow).toList();

    return Ledger(
      settings: settings,
      categories: categories,
      transactions: txns,
      outings: outings,
    );
  }

  Future<void> saveSettings(Settings s) async {
    if (kIsWeb) {
      _webSettings = s;
      return;
    }

    final db = await _db.db;
    Future<void> put(String k, String v) =>
        db.insert('settings', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);
    await put('stipend_paise', '${s.stipendPaise}');
    await put('cycle_start_day', '${s.cycleStartDay}');
    await put('hide_amounts', s.hideAmounts ? '1' : '0');
    await put('onboarded', s.onboarded ? '1' : '0');
  }

  Future<void> addCategory(String name, {String icon = 'custom'}) async {
    final cat = Category(
      id: _uuid.v4(),
      name: name.trim(),
      icon: icon,
      isSystem: false,
      sortOrder: _webCategories.length,
    );

    if (kIsWeb) {
      _webCategories.add(cat);
      return;
    }

    final db = await _db.db;
    final max = Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(sort_order) FROM categories'),
        ) ??
        0;
    await db.insert('categories', {
      'id': cat.id,
      'name': cat.name,
      'icon': cat.icon,
      'is_system': 0,
      'sort_order': max + 1,
    });
  }

  Future<void> deleteCategory(String id) async {
    if (kIsWeb) {
      for (var i = 0; i < _webTxns.length; i++) {
        if (_webTxns[i].categoryId == id) {
          final old = _webTxns[i];
          _webTxns[i] = Txn(
            id: old.id,
            amountPaise: old.amountPaise,
            direction: old.direction,
            occurredAtMs: old.occurredAtMs,
            localDate: old.localDate,
            merchant: old.merchant,
            categoryId: 'misc',
            bucket: old.bucket,
            outingId: old.outingId,
            note: old.note,
          );
        }
      }
      _webCategories.removeWhere((c) => c.id == id && !c.isSystem);
      return;
    }

    final db = await _db.db;
    await db.transaction((txn) async {
      await txn.update(
        'txns',
        {'category_id': 'misc'},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ? AND is_system = 0', whereArgs: [id]);
    });
  }

  Future<Txn> addTxn({
    required int amountPaise,
    required Direction direction,
    required LocalDate localDate,
    required String merchant,
    required String categoryId,
    required Bucket bucket,
    String? outingId,
    String note = '',
    DateTime? occurredAt,
  }) async {
    final txn = Txn(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      direction: direction,
      occurredAtMs: (occurredAt ?? DateTime.now()).millisecondsSinceEpoch,
      localDate: localDate,
      merchant: merchant.trim(),
      categoryId: categoryId,
      bucket: bucket,
      outingId: outingId,
      note: note.trim(),
    );

    if (kIsWeb) {
      _webTxns.insert(0, txn);
      return txn;
    }

    final db = await _db.db;
    await db.insert('txns', _txnToRow(txn));
    return txn;
  }

  Future<void> updateTxn(Txn txn) async {
    if (kIsWeb) {
      final index = _webTxns.indexWhere((t) => t.id == txn.id);
      if (index != -1) _webTxns[index] = txn;
      return;
    }

    final db = await _db.db;
    await db.update('txns', _txnToRow(txn), where: 'id = ?', whereArgs: [txn.id]);
  }

  Future<void> softDeleteTxn(String id) async {
    if (kIsWeb) {
      _webTxns.removeWhere((t) => t.id == id);
      return;
    }

    final db = await _db.db;
    await db.update(
      'txns',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Outing> addOuting({
    required String title,
    required LocalDate localDate,
    String note = '',
  }) async {
    final outing = Outing(
      id: _uuid.v4(),
      title: title.trim(),
      localDate: localDate,
      note: note.trim(),
    );

    if (kIsWeb) {
      _webOutings.insert(0, outing);
      return outing;
    }

    final db = await _db.db;
    await db.insert('outings', {
      'id': outing.id,
      'title': outing.title,
      'local_date': outing.localDate.ymd,
      'note': outing.note,
    });
    return outing;
  }

  Future<void> softDeleteOuting(String id) async {
    if (kIsWeb) {
      _webOutings.removeWhere((o) => o.id == id);
      _webTxns.removeWhere((t) => t.outingId == id);
      return;
    }

    final db = await _db.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update('outings', {'deleted_at': now}, where: 'id = ?', whereArgs: [id]);
      await txn.update('txns', {'deleted_at': now}, where: 'outing_id = ?', whereArgs: [id]);
    });
  }

  Future<void> updateOuting(Outing outing) async {
    if (kIsWeb) {
      final index = _webOutings.indexWhere((o) => o.id == outing.id);
      if (index != -1) _webOutings[index] = outing;
      return;
    }

    final db = await _db.db;
    await db.update(
      'outings',
      {
        'title': outing.title.trim(),
        'local_date': outing.localDate.ymd,
        'note': outing.note.trim(),
      },
      where: 'id = ?',
      whereArgs: [outing.id],
    );
  }

  Future<void> wipe() async {
    if (kIsWeb) {
      _webSettings = Settings.defaults;
      _webCategories
        ..clear()
        ..addAll(systemCategories);
      _webOutings.clear();
      _webTxns.clear();
      return;
    }
    await _db.wipe();
  }

  Future<void> _ensureSeed(dynamic db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
    if (count == 0) {
      for (final c in systemCategories) {
        await db.insert('categories', {
          'id': c.id,
          'name': c.name,
          'icon': c.icon,
          'is_system': 1,
          'sort_order': c.sortOrder,
        });
      }
    }
  }

  Txn _txnFromRow(Map<String, Object?> r) {
    return Txn(
      id: r['id'] as String,
      amountPaise: r['amount_paise'] as int,
      direction: r['direction'] == 'credit' ? Direction.credit : Direction.debit,
      occurredAtMs: r['occurred_at'] as int,
      localDate: LocalDate.parse(r['local_date'] as String),
      merchant: r['merchant'] as String,
      categoryId: r['category_id'] as String,
      bucket: r['bucket'] == 'outing' ? Bucket.outing : Bucket.daily,
      outingId: r['outing_id'] as String?,
      note: r['note'] as String,
    );
  }

  Map<String, Object?> _txnToRow(Txn t) => {
        'id': t.id,
        'amount_paise': t.amountPaise,
        'direction': t.direction == Direction.credit ? 'credit' : 'debit',
        'occurred_at': t.occurredAtMs,
        'local_date': t.localDate.ymd,
        'merchant': t.merchant,
        'category_id': t.categoryId,
        'bucket': t.bucket == Bucket.outing ? 'outing' : 'daily',
        'outing_id': t.outingId,
        'note': t.note,
      };
}
