import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/dates.dart';
import '../core/keystore_service.dart';
import '../core/money.dart';
import 'database.dart';
import 'models.dart';

const _uuid = Uuid();

class PocketRepository {
  PocketRepository(this._db, {this.inMemory = false});
  final PocketDatabase _db;
  final bool inMemory;

  bool get _isInMemory => kIsWeb || inMemory;

  static const systemCategories = [
    Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
    Category(id: 'snacks', name: 'Snacks', icon: 'snacks', isSystem: true, sortOrder: 1),
    Category(id: 'study', name: 'Study', icon: 'study', isSystem: true, sortOrder: 2),
    Category(id: 'misc', name: 'Misc', icon: 'misc', isSystem: true, sortOrder: 3),
    Category(id: 'income', name: 'Top-Up', icon: 'savings', isSystem: true, sortOrder: 4),
  ];

  // In-memory backing for web browser preview
  static Settings _webSettings = const Settings(
    stipendPaise: 250000,
    cycleStartDay: 1,
    hideAmounts: false,
    onboarded: true,
    pacingMode: PacingMode.daily,
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
  static final List<FriendSplit> _webSplits = [
    FriendSplit(
      id: 's-1',
      friendName: 'Rahul',
      amountPaise: 12000,
      direction: SplitDirection.youAreOwed,
      occurredAtMs: DateTime.now().subtract(const Duration(hours: 4)).millisecondsSinceEpoch,
      localDate: LocalDate.today(),
      note: 'Biryani split at canteen',
      isSettled: false,
    ),
    FriendSplit(
      id: 's-2',
      friendName: 'Sneha',
      amountPaise: 5000,
      direction: SplitDirection.youOwe,
      occurredAtMs: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      localDate: LocalDate.today(),
      note: 'Xerox & lab manual',
      isSettled: false,
    ),
  ];
  static final List<FixedDeduction> _webDeductions = [
    const FixedDeduction(
      id: 'fd-1',
      title: 'College Bus Pass',
      amountPaise: 40000,
      isEnabled: true,
    ),
    const FixedDeduction(
      id: 'fd-2',
      title: 'Mobile Data Recharge',
      amountPaise: 29900,
      isEnabled: true,
    ),
  ];

  static final List<PendingTransaction> _webPendingInbox = [];
  static final Map<String, String> _webMerchantMemory = {};

  Future<Ledger> load() async {
    if (_isInMemory) {
      return Ledger(
        settings: _webSettings.copyWith(fixedDeductions: List.of(_webDeductions)),
        categories: List.of(_webCategories),
        transactions: List.of(_webTxns),
        outings: List.of(_webOutings),
        friendSplits: List.of(_webSplits),
        pendingInbox: List.of(_webPendingInbox.where((p) => p.status == InboxStatus.pending)),
      );
    }

    final db = await _db.db;
    await _ensureSeed(db);

    final results = await Future.wait([
      db.query(
        'fixed_deductions',
        where: 'deleted_at IS NULL',
        orderBy: 'title ASC',
      ),
      db.query('settings'),
      db.query('categories', orderBy: 'sort_order ASC'),
      db.query(
        'outings',
        where: 'deleted_at IS NULL',
        orderBy: 'local_date DESC, title ASC',
      ),
      db.query(
        'txns',
        where: 'deleted_at IS NULL',
        orderBy: 'occurred_at DESC',
      ),
      db.query(
        'friend_splits',
        where: 'deleted_at IS NULL',
        orderBy: 'occurred_at DESC',
      ),
      db.query(
        'pending_inbox',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'occurred_at DESC',
      ),
    ]);

    final dedRows = results[0];
    final settingRows = results[1];
    final catRows = results[2];
    final outingRows = results[3];
    final txnRows = results[4];
    final splitRows = results[5];
    final inboxRows = results[6];

    final deductions = dedRows.map(_deductionFromRow).toList();
    final map = {for (final r in settingRows) r['key'] as String: r['value'] as String};

    String appPassword = '';
    final encPassword = map['email_sync_app_password_enc'];
    if (encPassword != null && encPassword.isNotEmpty) {
      appPassword = await KeystoreService.instance.decrypt(encPassword);
    } else if (map['email_sync_app_password'] != null) {
      appPassword = map['email_sync_app_password']!;
    }

    final settings = Settings(
      stipendPaise: int.parse(map['stipend_paise'] ?? '${Settings.defaults.stipendPaise}'),
      cycleStartDay: int.parse(map['cycle_start_day'] ?? '${Settings.defaults.cycleStartDay}'),
      hideAmounts: map['hide_amounts'] == '1',
      onboarded: map['onboarded'] == '1',
      pacingMode: map['pacing_mode'] == 'weekly' ? PacingMode.weekly : PacingMode.daily,
      leftoverPolicy: map['leftover_policy'] == 'outingsPiggyBank'
          ? LeftoverPolicy.outingsPiggyBank
          : LeftoverPolicy.dynamicDistribute,
      biometricEnabled: map['biometric_enabled'] == '1',
      fixedDeductions: deductions,
      appThemeMode: map['app_theme_mode'] == 'dark'
          ? AppThemeMode.dark
          : (map['app_theme_mode'] == 'light' ? AppThemeMode.light : AppThemeMode.system),
      rolloverUnspent: map['rollover_unspent'] != '0',
      emailSyncAddress: map['email_sync_address'] ?? '',
      emailSyncAppPassword: appPassword,
      emailSyncSender: map['email_sync_sender'] ?? 'noreply@slice.bank.in',
      emailSyncEnabled: map['email_sync_enabled'] == '1',
      emailSyncLastSyncedMs: int.tryParse(map['email_sync_last_synced_ms'] ?? ''),
    );

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

    final txns = txnRows.map(_txnFromRow).toList();
    final splits = splitRows.map(_splitFromRow).toList();
    final inbox = inboxRows.map(_pendingFromRow).toList();

    return Ledger(
      settings: settings,
      categories: categories,
      transactions: txns,
      outings: outings,
      friendSplits: splits,
      pendingInbox: inbox,
    );
  }

  Future<void> saveSettings(Settings s) async {
    if (_isInMemory) {
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
    await put('pacing_mode', s.pacingMode.name);
    await put('leftover_policy', s.leftoverPolicy.name);
    await put('biometric_enabled', s.biometricEnabled ? '1' : '0');
    await put('app_theme_mode', s.appThemeMode.name);
    await put('rollover_unspent', s.rolloverUnspent ? '1' : '0');
    await put('email_sync_address', s.emailSyncAddress);
    if (s.emailSyncAppPassword.isNotEmpty) {
      final encrypted = await KeystoreService.instance.encrypt(s.emailSyncAppPassword);
      await put('email_sync_app_password_enc', encrypted);
      await db.delete('settings', where: 'key = ?', whereArgs: ['email_sync_app_password']);
    } else {
      await put('email_sync_app_password_enc', '');
      await db.delete('settings', where: 'key = ?', whereArgs: ['email_sync_app_password']);
    }
    await put('email_sync_sender', s.emailSyncSender);
    await put('email_sync_enabled', s.emailSyncEnabled ? '1' : '0');
    if (s.emailSyncLastSyncedMs != null) {
      await put('email_sync_last_synced_ms', '${s.emailSyncLastSyncedMs}');
    }
  }

  Future<void> addCategory(String name, {String icon = 'custom'}) async {
    final cat = Category(
      id: _uuid.v4(),
      name: name.trim(),
      icon: icon,
      isSystem: false,
      sortOrder: _webCategories.length,
    );

    if (_isInMemory) {
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
    if (_isInMemory) {
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

    if (_isInMemory) {
      _webTxns.insert(0, txn);
      return txn;
    }

    final db = await _db.db;
    await db.insert('txns', _txnToRow(txn));
    return txn;
  }

  Future<void> updateTxn(Txn txn) async {
    if (_isInMemory) {
      final index = _webTxns.indexWhere((t) => t.id == txn.id);
      if (index != -1) _webTxns[index] = txn;
      return;
    }

    final db = await _db.db;
    await db.update('txns', _txnToRow(txn), where: 'id = ?', whereArgs: [txn.id]);
  }

  Future<void> softDeleteTxn(String id) async {
    if (_isInMemory) {
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

  Future<void> restoreTxn(Txn txn) async {
    if (_isInMemory) {
      if (!_webTxns.any((t) => t.id == txn.id)) {
        _webTxns.insert(0, txn);
      }
      return;
    }

    final db = await _db.db;
    await db.update(
      'txns',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [txn.id],
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

    if (_isInMemory) {
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
    if (_isInMemory) {
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
    if (_isInMemory) {
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

  Future<Outing> addOutingWithSpend({
    required String title,
    required int amountPaise,
    required LocalDate date,
    String itemTitle = '',
    String note = '',
    String? existingOutingId,
  }) async {
    if (_isInMemory) {
      final outingId = existingOutingId ?? (await addOuting(title: title, localDate: date, note: note)).id;
      await addTxn(
        amountPaise: amountPaise,
        direction: Direction.debit,
        localDate: date,
        merchant: itemTitle.isNotEmpty ? itemTitle : title,
        categoryId: 'misc',
        bucket: Bucket.outing,
        outingId: outingId,
        note: note,
      );
      return _webOutings.firstWhere((o) => o.id == outingId);
    }

    final db = await _db.db;
    return await db.transaction((txn) async {
      final String outingId;
      Outing outing;
      if (existingOutingId != null) {
        outingId = existingOutingId;
        final rows = await txn.query('outings', where: 'id = ?', whereArgs: [outingId]);
        outing = rows.isNotEmpty
            ? Outing(
                id: rows.first['id'] as String,
                title: rows.first['title'] as String,
                localDate: LocalDate.parse(rows.first['local_date'] as String),
                note: rows.first['note'] as String,
              )
            : Outing(id: outingId, title: title.trim(), localDate: date, note: note.trim());
      } else {
        outing = Outing(id: _uuid.v4(), title: title.trim(), localDate: date, note: note.trim());
        await txn.insert('outings', {
          'id': outing.id,
          'title': outing.title,
          'local_date': outing.localDate.ymd,
          'note': outing.note,
        });
        outingId = outing.id;
      }

      final txnObj = Txn(
        id: _uuid.v4(),
        amountPaise: amountPaise,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: date,
        merchant: itemTitle.isNotEmpty ? itemTitle.trim() : title.trim(),
        categoryId: 'misc',
        bucket: Bucket.outing,
        outingId: outingId,
        note: note.trim(),
      );
      await txn.insert('txns', _txnToRow(txnObj));
      return outing;
    });
  }

  Future<void> borrowFromTomorrow({
    required int amountPaise,
    required LocalDate today,
  }) async {
    final tomorrow = today.addDays(1);
    final now = DateTime.now().millisecondsSinceEpoch;
    final creditTxn = Txn(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      direction: Direction.credit,
      occurredAtMs: now,
      localDate: today,
      merchant: "Borrowed from tomorrow's allowance",
      categoryId: 'misc',
      bucket: Bucket.daily,
      note: 'Overspend recovery',
    );
    final debitTxn = Txn(
      id: _uuid.v4(),
      amountPaise: amountPaise,
      direction: Direction.debit,
      occurredAtMs: now + 1,
      localDate: tomorrow,
      merchant: 'Carried forward from yesterday',
      categoryId: 'misc',
      bucket: Bucket.daily,
      note: 'Overspend recovery',
    );

    if (_isInMemory) {
      _webTxns.insert(0, creditTxn);
      _webTxns.insert(0, debitTxn);
      return;
    }

    final db = await _db.db;
    await db.transaction((txn) async {
      await txn.insert('txns', _txnToRow(creditTxn));
      await txn.insert('txns', _txnToRow(debitTxn));
    });
  }

  Future<void> reclassifyTxnAsOuting(Txn txn, {String outingTitle = 'Overspend Splurge'}) async {
    final outing = Outing(
      id: _uuid.v4(),
      title: outingTitle.trim(),
      localDate: txn.localDate,
      note: 'Reclassified from daily (${txn.merchant})',
    );
    final updatedTxn = Txn(
      id: txn.id,
      amountPaise: txn.amountPaise,
      direction: txn.direction,
      occurredAtMs: txn.occurredAtMs,
      localDate: txn.localDate,
      merchant: txn.merchant,
      categoryId: txn.categoryId,
      bucket: Bucket.outing,
      outingId: outing.id,
      note: txn.note,
    );

    if (_isInMemory) {
      _webOutings.insert(0, outing);
      final idx = _webTxns.indexWhere((t) => t.id == txn.id);
      if (idx != -1) _webTxns[idx] = updatedTxn;
      return;
    }

    final db = await _db.db;
    await db.transaction((txnDb) async {
      await txnDb.insert('outings', {
        'id': outing.id,
        'title': outing.title,
        'local_date': outing.localDate.ymd,
        'note': outing.note,
      });
      await txnDb.update('txns', _txnToRow(updatedTxn), where: 'id = ?', whereArgs: [txn.id]);
    });
  }

  Future<FriendSplit> addFriendSplit({
    required String friendName,
    required int amountPaise,
    required SplitDirection direction,
    required LocalDate localDate,
    String note = '',
    DateTime? occurredAt,
    bool deductFromDaily = false,
  }) async {
    final now = (occurredAt ?? DateTime.now()).millisecondsSinceEpoch;
    final split = FriendSplit(
      id: _uuid.v4(),
      friendName: friendName.trim(),
      amountPaise: amountPaise,
      direction: direction,
      occurredAtMs: now,
      localDate: localDate,
      note: note.trim(),
      isSettled: false,
    );

    Txn? dailyTxn;
    if (deductFromDaily && direction == SplitDirection.youAreOwed) {
      dailyTxn = Txn(
        id: _uuid.v4(),
        amountPaise: amountPaise,
        direction: Direction.debit,
        occurredAtMs: now,
        localDate: localDate,
        merchant: 'Lent to ${friendName.trim()}',
        categoryId: 'misc',
        bucket: Bucket.daily,
        note: note.isNotEmpty ? 'Split: $note' : 'Lent to ${friendName.trim()}',
      );
    }

    if (_isInMemory) {
      _webSplits.insert(0, split);
      if (dailyTxn != null) _webTxns.insert(0, dailyTxn);
      return split;
    }

    final db = await _db.db;
    if (dailyTxn != null) {
      await db.transaction((txn) async {
        await txn.insert('friend_splits', _splitToRow(split));
        await txn.insert('txns', _txnToRow(dailyTxn!));
      });
    } else {
      await db.insert('friend_splits', _splitToRow(split));
    }
    return split;
  }

  Future<void> updateFriendSplit(FriendSplit split) async {
    if (_isInMemory) {
      final idx = _webSplits.indexWhere((s) => s.id == split.id);
      if (idx != -1) _webSplits[idx] = split;
      return;
    }

    final db = await _db.db;
    await db.update('friend_splits', _splitToRow(split), where: 'id = ?', whereArgs: [split.id]);
  }

  Future<void> settleFriendSplit(String id, {bool creditDaily = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isInMemory) {
      final idx = _webSplits.indexWhere((s) => s.id == id);
      if (idx != -1) {
        final old = _webSplits[idx];
        _webSplits[idx] = old.copyWith(isSettled: true, settledAtMs: now);
        if (creditDaily && old.direction == SplitDirection.youAreOwed) {
          await addTxn(
            amountPaise: old.amountPaise,
            direction: Direction.credit,
            localDate: LocalDate.today(),
            merchant: '${old.friendName} settled split',
            categoryId: 'misc',
            bucket: Bucket.daily,
            note: 'Settled split: ${old.note.isNotEmpty ? old.note : old.friendName}',
          );
        }
      }
      return;
    }

    final db = await _db.db;
    await db.transaction((txn) async {
      final rows = await txn.query('friend_splits', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final split = _splitFromRow(rows.first);
        await txn.update(
          'friend_splits',
          {'is_settled': 1, 'settled_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
        if (creditDaily && split.direction == SplitDirection.youAreOwed) {
          final creditTxn = Txn(
            id: _uuid.v4(),
            amountPaise: split.amountPaise,
            direction: Direction.credit,
            occurredAtMs: now,
            localDate: LocalDate.today(),
            merchant: '${split.friendName} settled split',
            categoryId: 'misc',
            bucket: Bucket.daily,
            note: 'Settled split: ${split.note.isNotEmpty ? split.note : split.friendName}',
          );
          await txn.insert('txns', _txnToRow(creditTxn));
        }
      }
    });
  }

  Future<void> softDeleteFriendSplit(String id) async {
    if (_isInMemory) {
      _webSplits.removeWhere((s) => s.id == id);
      return;
    }

    final db = await _db.db;
    await db.update(
      'friend_splits',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> splitBill({
    required int totalAmountPaise,
    required int mySharePaise,
    required List<({String friendName, int amountPaise})> friends,
    required LocalDate date,
    required String categoryId,
    required String merchant,
    String note = '',
    String? pendingInboxId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Txn? userTxn;
    if (mySharePaise > 0) {
      userTxn = Txn(
        id: _uuid.v4(),
        amountPaise: mySharePaise,
        direction: Direction.debit,
        occurredAtMs: now,
        localDate: date,
        merchant: merchant.isNotEmpty ? merchant : 'Bill Split',
        categoryId: categoryId.isNotEmpty ? categoryId : 'food',
        bucket: Bucket.daily,
        note: note.isNotEmpty
            ? '$note (My share of ${Money.formatPaise(totalAmountPaise)})'
            : 'My share of ${Money.formatPaise(totalAmountPaise)}',
      );
    }

    final newSplits = <FriendSplit>[];
    for (var i = 0; i < friends.length; i++) {
      final f = friends[i];
      if (f.amountPaise <= 0 || f.friendName.trim().isEmpty) continue;
      newSplits.add(
        FriendSplit(
          id: _uuid.v4(),
          friendName: f.friendName.trim(),
          amountPaise: f.amountPaise,
          direction: SplitDirection.youAreOwed,
          occurredAtMs: now + i + 1,
          localDate: date,
          note: merchant.isNotEmpty ? '$merchant split' : (note.isNotEmpty ? note : 'Bill split'),
          isSettled: false,
        ),
      );
    }

    if (_isInMemory) {
      if (userTxn != null) _webTxns.insert(0, userTxn);
      for (final s in newSplits) {
        _webSplits.insert(0, s);
      }
      if (pendingInboxId != null) {
        final idx = _webPendingInbox.indexWhere((p) => p.id == pendingInboxId);
        if (idx != -1) {
          _webPendingInbox[idx] = _webPendingInbox[idx].copyWith(status: InboxStatus.approved);
        }
      }
      if (merchant.isNotEmpty && categoryId.isNotEmpty) {
        await recordMerchantCategory(merchant, categoryId);
      }
      return;
    }

    final db = await _db.db;
    await db.transaction((txn) async {
      if (userTxn != null) {
        await txn.insert('txns', _txnToRow(userTxn));
      }
      for (final s in newSplits) {
        await txn.insert('friend_splits', _splitToRow(s));
      }
      if (pendingInboxId != null) {
        await txn.update(
          'pending_inbox',
          {'status': 'approved'},
          where: 'id = ?',
          whereArgs: [pendingInboxId],
        );
      }
    });

    if (merchant.isNotEmpty && categoryId.isNotEmpty) {
      await recordMerchantCategory(merchant, categoryId);
    }
  }

  Future<void> wipe() async {
    if (_isInMemory) {
      _webSettings = Settings.defaults;
      _webCategories
        ..clear()
        ..addAll(systemCategories);
      _webOutings.clear();
      _webTxns.clear();
      _webSplits.clear();
      _webDeductions.clear();
      return;
    }
    await _db.wipe();
  }

  /// Compacts and defragments database pages and re-optimizes query planner statistics.
  Future<void> optimizeDatabase() async {
    if (_isInMemory) return;
    await _db.optimize();
  }

  /// Checks the on-disk storage size of the local database files in bytes.
  Future<int> getStorageSizeBytes() async {
    if (_isInMemory) return 0;
    return await _db.getDatabaseSizeBytes();
  }

  /// Permanently removes soft-deleted records older than [olderThanDays] and vacuums the database.
  Future<int> purgeDeletedRecords({int olderThanDays = 30}) async {
    if (_isInMemory) {
      return 0;
    }
    return await _db.purgeDeletedRecords(olderThanDays: olderThanDays);
  }

  /// Verifies the SQLite database integrity.
  Future<String> checkIntegrity() async {
    if (_isInMemory) return 'ok';
    return await _db.checkIntegrity();
  }

  /// Atomically restores a full backup snapshot within a single SQLite transaction.
  /// If any error occurs during restoration, all changes are automatically rolled back.
  Future<bool> restoreSnapshot({
    required Settings settings,
    required List<Category> customCategories,
    required List<FixedDeduction> fixedDeductions,
    required List<Outing> outings,
    required List<Txn> transactions,
    required List<FriendSplit> friendSplits,
  }) async {
    if (_isInMemory) {
      _webSettings = settings;
      _webCategories
        ..clear()
        ..addAll(systemCategories)
        ..addAll(customCategories);
      _webDeductions
        ..clear()
        ..addAll(fixedDeductions);
      _webOutings
        ..clear()
        ..addAll(outings);
      _webTxns
        ..clear()
        ..addAll(transactions);
      _webSplits
        ..clear()
        ..addAll(friendSplits);
      return true;
    }

    final db = await _db.db;
    try {
      await db.transaction((txn) async {
        // 1. Wipe existing tables cleanly
        await txn.delete('fixed_deductions');
        await txn.delete('friend_splits');
        await txn.delete('txns');
        await txn.delete('outings');
        await txn.delete('categories');
        await txn.delete('settings');

        // 2. Re-seed system categories
        for (final c in systemCategories) {
          await txn.insert('categories', {
            'id': c.id,
            'name': c.name,
            'icon': c.icon,
            'is_system': 1,
            'sort_order': c.sortOrder,
          });
        }

        // 3. Re-insert settings
        Future<void> put(String k, String v) =>
            txn.insert('settings', {'key': k, 'value': v}, conflictAlgorithm: ConflictAlgorithm.replace);
        await put('stipend_paise', '${settings.stipendPaise}');
        await put('cycle_start_day', '${settings.cycleStartDay}');
        await put('hide_amounts', settings.hideAmounts ? '1' : '0');
        await put('onboarded', settings.onboarded ? '1' : '0');
        await put('pacing_mode', settings.pacingMode.name);
        await put('leftover_policy', settings.leftoverPolicy.name);
        await put('biometric_enabled', settings.biometricEnabled ? '1' : '0');
        await put('app_theme_mode', settings.appThemeMode.name);

        // 4. Re-insert custom categories
        for (final c in customCategories) {
          await txn.insert('categories', {
            'id': c.id,
            'name': c.name,
            'icon': c.icon,
            'is_system': 0,
            'sort_order': c.sortOrder,
          });
        }

        // 5. Batch insert fixed deductions
        for (final d in fixedDeductions) {
          await txn.insert('fixed_deductions', _deductionToRow(d));
        }

        // 6. Batch insert outings
        for (final o in outings) {
          await txn.insert('outings', {
            'id': o.id,
            'title': o.title,
            'local_date': o.localDate.ymd,
            'note': o.note,
          });
        }

        // 7. Batch insert transactions
        for (final t in transactions) {
          await txn.insert('txns', _txnToRow(t));
        }

        // 8. Batch insert friend splits
        for (final s in friendSplits) {
          await txn.insert('friend_splits', _splitToRow(s));
        }
      });

      await _db.optimize();
      return true;
    } catch (_) {
      return false;
    }
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

  FriendSplit _splitFromRow(Map<String, Object?> r) {
    return FriendSplit(
      id: r['id'] as String,
      friendName: r['friend_name'] as String,
      amountPaise: r['amount_paise'] as int,
      direction: r['direction'] == 'you_owe' ? SplitDirection.youOwe : SplitDirection.youAreOwed,
      occurredAtMs: r['occurred_at'] as int,
      localDate: LocalDate.parse(r['local_date'] as String),
      note: r['note'] as String,
      isSettled: (r['is_settled'] as int) == 1,
      settledAtMs: r['settled_at'] as int?,
    );
  }

  Future<FixedDeduction> addFixedDeduction({
    required String title,
    required int amountPaise,
    bool isEnabled = true,
  }) async {
    final d = FixedDeduction(
      id: _uuid.v4(),
      title: title.trim(),
      amountPaise: amountPaise,
      isEnabled: isEnabled,
    );

    if (_isInMemory) {
      _webDeductions.add(d);
      return d;
    }

    final db = await _db.db;
    await db.insert('fixed_deductions', _deductionToRow(d));
    return d;
  }

  Future<void> updateFixedDeduction(FixedDeduction d) async {
    if (_isInMemory) {
      final idx = _webDeductions.indexWhere((x) => x.id == d.id);
      if (idx != -1) _webDeductions[idx] = d;
      return;
    }

    final db = await _db.db;
    await db.update('fixed_deductions', _deductionToRow(d), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteFixedDeduction(String id) async {
    if (_isInMemory) {
      _webDeductions.removeWhere((x) => x.id == id);
      return;
    }

    final db = await _db.db;
    await db.update(
      'fixed_deductions',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  FixedDeduction _deductionFromRow(Map<String, Object?> r) {
    return FixedDeduction(
      id: r['id'] as String,
      title: r['title'] as String,
      amountPaise: r['amount_paise'] as int,
      isEnabled: (r['is_enabled'] as int) == 1,
    );
  }

  Map<String, Object?> _deductionToRow(FixedDeduction d) => {
        'id': d.id,
        'title': d.title,
        'amount_paise': d.amountPaise,
        'is_enabled': d.isEnabled ? 1 : 0,
      };

  Map<String, Object?> _splitToRow(FriendSplit s) => {
        'id': s.id,
        'friend_name': s.friendName,
        'amount_paise': s.amountPaise,
        'direction': s.direction == SplitDirection.youOwe ? 'you_owe' : 'you_are_owed',
        'occurred_at': s.occurredAtMs,
        'local_date': s.localDate.ymd,
        'note': s.note,
        'is_settled': s.isSettled ? 1 : 0,
        'settled_at': s.settledAtMs,
      };

  Future<bool> isEmailMessageProcessed(String messageId) async {
    if (messageId.isEmpty) return false;
    if (_isInMemory) {
      return _webPendingInbox.any((p) => p.messageId == messageId);
    }
    final db = await _db.db;
    final res = await db.query(
      'pending_inbox',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<String?> getMerchantCategory(String merchant) async {
    final clean = merchant.trim().toLowerCase();
    if (clean.isEmpty) return null;
    if (_isInMemory) {
      return _webMerchantMemory[clean];
    }
    final db = await _db.db;
    final res = await db.query(
      'merchant_memory',
      columns: ['category_id'],
      where: 'merchant_clean = ?',
      whereArgs: [clean],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['category_id'] as String?;
    }
    return null;
  }

  Future<void> recordMerchantCategory(String merchant, String categoryId) async {
    final clean = merchant.trim().toLowerCase();
    if (clean.isEmpty || categoryId.isEmpty) return;
    if (_isInMemory) {
      _webMerchantMemory[clean] = categoryId;
      return;
    }
    final db = await _db.db;
    await db.insert(
      'merchant_memory',
      {
        'merchant_clean': clean,
        'category_id': categoryId,
        'last_used_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingTransaction>> addPendingTransactions(List<PendingTransaction> txns) async {
    final inserted = <PendingTransaction>[];
    for (final t in txns) {
      if (t.messageId != null && await isEmailMessageProcessed(t.messageId!)) {
        continue;
      }
      var suggested = t.suggestedCategoryId;
      if (suggested == null || suggested.isEmpty) {
        suggested = await getMerchantCategory(t.merchant);
      }
      final toAdd = t.copyWith(
        id: t.id.isEmpty ? _uuid.v4() : t.id,
        suggestedCategoryId: suggested,
      );

      if (_isInMemory) {
        _webPendingInbox.add(toAdd);
        inserted.add(toAdd);
        continue;
      }

      final db = await _db.db;
      await db.insert('pending_inbox', _pendingToRow(toAdd), conflictAlgorithm: ConflictAlgorithm.ignore);
      inserted.add(toAdd);
    }
    return inserted;
  }

  Future<Txn> approvePendingTransaction(
    PendingTransaction pending, {
    required String categoryId,
    Bucket bucket = Bucket.daily,
    String? outingId,
    String? note,
    String? merchant,
  }) async {
    final effectiveMerchant = (merchant != null && merchant.trim().isNotEmpty)
        ? merchant.trim()
        : pending.merchant;

    final txn = await addTxn(
      direction: pending.direction,
      amountPaise: pending.amountPaise,
      localDate: pending.localDate,
      merchant: effectiveMerchant,
      categoryId: categoryId,
      bucket: bucket,
      outingId: outingId,
      note: note ?? (pending.rawSource.isNotEmpty ? 'Slice Auto-Sync' : ''),
    );

    await recordMerchantCategory(pending.merchant, categoryId);

    if (_isInMemory) {
      final idx = _webPendingInbox.indexWhere((p) => p.id == pending.id);
      if (idx != -1) {
        _webPendingInbox[idx] = _webPendingInbox[idx].copyWith(status: InboxStatus.approved);
      }
      return txn;
    }

    final db = await _db.db;
    await db.update(
      'pending_inbox',
      {'status': 'approved'},
      where: 'id = ?',
      whereArgs: [pending.id],
    );
    return txn;
  }

  Future<void> dismissPendingTransaction(String id) async {
    if (_isInMemory) {
      final idx = _webPendingInbox.indexWhere((p) => p.id == id);
      if (idx != -1) {
        _webPendingInbox[idx] = _webPendingInbox[idx].copyWith(status: InboxStatus.dismissed);
      }
      return;
    }

    final db = await _db.db;
    await db.update(
      'pending_inbox',
      {'status': 'dismissed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearPendingInbox() async {
    if (_isInMemory) {
      _webPendingInbox.removeWhere((p) => p.status == InboxStatus.pending);
      return;
    }

    final db = await _db.db;
    await db.delete(
      'pending_inbox',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
  }

  PendingTransaction _pendingFromRow(Map<String, Object?> r) {
    return PendingTransaction(
      id: r['id'] as String,
      amountPaise: r['amount_paise'] as int,
      direction: r['direction'] == 'credit' ? Direction.credit : Direction.debit,
      occurredAtMs: r['occurred_at'] as int,
      localDate: LocalDate.parse(r['local_date'] as String),
      merchant: r['merchant'] as String,
      suggestedCategoryId: r['suggested_category_id'] as String?,
      rawSource: r['raw_source'] as String,
      messageId: r['message_id'] as String?,
      status: r['status'] == 'approved'
          ? InboxStatus.approved
          : (r['status'] == 'dismissed' ? InboxStatus.dismissed : InboxStatus.pending),
    );
  }

  Map<String, Object?> _pendingToRow(PendingTransaction p) => {
        'id': p.id,
        'amount_paise': p.amountPaise,
        'direction': p.direction == Direction.credit ? 'credit' : 'debit',
        'occurred_at': p.occurredAtMs,
        'local_date': p.localDate.ymd,
        'merchant': p.merchant,
        'suggested_category_id': p.suggestedCategoryId,
        'raw_source': p.rawSource,
        'message_id': p.messageId,
        'status': p.status.name,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };
}

