import 'dart:convert';

import '../data/models.dart';
import '../data/repository.dart';
import 'dates.dart';

class BackupService {
  const BackupService._();

  static String generateBackupJson(Ledger ledger) {
    final s = ledger.settings;
    final data = {
      'pocket_version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': {
        'stipend_paise': s.stipendPaise,
        'cycle_start_day': s.cycleStartDay,
        'hide_amounts': s.hideAmounts,
        'onboarded': s.onboarded,
        'pacing_mode': s.pacingMode.name,
        'leftover_policy': s.leftoverPolicy.name,
        'biometric_enabled': s.biometricEnabled,
        'app_theme_mode': s.appThemeMode.name,
        'rollover_unspent': s.rolloverUnspent,
      },
      'categories': [
        for (final c in ledger.categories)
          {
            'id': c.id,
            'name': c.name,
            'icon': c.icon,
            'is_system': c.isSystem,
            'sort_order': c.sortOrder,
          }
      ],
      'fixed_deductions': [
        for (final d in s.fixedDeductions)
          {
            'id': d.id,
            'title': d.title,
            'amount_paise': d.amountPaise,
            'is_enabled': d.isEnabled,
          }
      ],
      'outings': [
        for (final o in ledger.outings)
          {
            'id': o.id,
            'title': o.title,
            'local_date': o.localDate.ymd,
            'note': o.note,
          }
      ],
      'transactions': [
        for (final t in ledger.transactions)
          {
            'id': t.id,
            'amount_paise': t.amountPaise,
            'direction': t.direction == Direction.credit ? 'credit' : 'debit',
            'occurred_at_ms': t.occurredAtMs,
            'local_date': t.localDate.ymd,
            'merchant': t.merchant,
            'category_id': t.categoryId,
            'bucket': t.bucket == Bucket.outing ? 'outing' : 'daily',
            'outing_id': t.outingId,
            'note': t.note,
          }
      ],
      'friend_splits': [
        for (final s in ledger.friendSplits)
          {
            'id': s.id,
            'friend_name': s.friendName,
            'amount_paise': s.amountPaise,
            'direction': s.direction == SplitDirection.youOwe ? 'you_owe' : 'you_are_owed',
            'occurred_at_ms': s.occurredAtMs,
            'local_date': s.localDate.ymd,
            'note': s.note,
            'is_settled': s.isSettled,
            'settled_at_ms': s.settledAtMs,
          }
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<bool> restoreFromJson(String jsonStr, PocketRepository repo) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return false;
      if (!decoded.containsKey('pocket_version')) return false;

      // 1. Pre-validate and construct Settings
      final sMap = decoded['settings'];
      if (sMap is! Map<String, dynamic>) return false;
      final rawStipend = sMap['stipend_paise'] as int? ?? 250000;
      final rawCycle = sMap['cycle_start_day'] as int? ?? 1;
      final settings = Settings(
        stipendPaise: rawStipend < 0 ? 0 : rawStipend,
        cycleStartDay: rawCycle.clamp(1, 31),
        hideAmounts: sMap['hide_amounts'] as bool? ?? false,
        onboarded: sMap['onboarded'] as bool? ?? true,
        pacingMode: sMap['pacing_mode'] == 'weekly' ? PacingMode.weekly : PacingMode.daily,
        leftoverPolicy: sMap['leftover_policy'] == 'outingsPiggyBank'
            ? LeftoverPolicy.outingsPiggyBank
            : LeftoverPolicy.dynamicDistribute,
        biometricEnabled: sMap['biometric_enabled'] as bool? ?? false,
        appThemeMode: sMap['app_theme_mode'] == 'dark'
            ? AppThemeMode.dark
            : (sMap['app_theme_mode'] == 'light' ? AppThemeMode.light : AppThemeMode.system),
        rolloverUnspent: sMap['rollover_unspent'] as bool? ?? true,
      );

      // 2. Pre-validate and construct Custom Categories
      final catList = decoded['categories'];
      final customCategories = <Category>[];
      if (catList is List) {
        var sortOrder = 4;
        for (final item in catList) {
          if (item is Map<String, dynamic>) {
            final isSys = item['is_system'] as bool? ?? false;
            if (!isSys) {
              final name = (item['name'] as String? ?? '').trim();
              if (name.isNotEmpty) {
                customCategories.add(
                  Category(
                    id: (item['id'] as String?) ?? 'cat_${customCategories.length}',
                    name: name,
                    icon: (item['icon'] as String?) ?? 'custom',
                    isSystem: false,
                    sortOrder: sortOrder++,
                  ),
                );
              }
            }
          }
        }
      }

      // 3. Pre-validate and construct Fixed Deductions
      final dedList = decoded['fixed_deductions'];
      final fixedDeductions = <FixedDeduction>[];
      if (dedList is List) {
        for (final item in dedList) {
          if (item is Map<String, dynamic>) {
            final title = (item['title'] as String? ?? '').trim();
            final amt = (item['amount_paise'] as int? ?? 0).clamp(0, 999999999);
            if (title.isNotEmpty) {
              fixedDeductions.add(
                FixedDeduction(
                  id: (item['id'] as String?) ?? 'fd_${fixedDeductions.length}',
                  title: title,
                  amountPaise: amt,
                  isEnabled: item['is_enabled'] as bool? ?? true,
                ),
              );
            }
          }
        }
      }

      // 4. Pre-validate and construct Outings
      final outingList = decoded['outings'];
      final outings = <Outing>[];
      if (outingList is List) {
        for (final item in outingList) {
          if (item is Map<String, dynamic>) {
            final date = LocalDate.tryParse(item['local_date'] as String?);
            if (date == null) return false; // Corrupted date -> abort safely
            outings.add(
              Outing(
                id: (item['id'] as String?) ?? 'out_${outings.length}',
                title: (item['title'] as String? ?? 'Outing').trim(),
                localDate: date,
                note: (item['note'] as String? ?? '').trim(),
              ),
            );
          }
        }
      }

      // 5. Pre-validate and construct Transactions
      final txnList = decoded['transactions'];
      final transactions = <Txn>[];
      if (txnList is List) {
        for (final item in txnList) {
          if (item is Map<String, dynamic>) {
            final date = LocalDate.tryParse(item['local_date'] as String?);
            if (date == null) return false; // Corrupted date -> abort safely
            final amt = (item['amount_paise'] as int? ?? 0).clamp(0, 999999999);
            final dir = item['direction'] == 'credit' ? Direction.credit : Direction.debit;
            final bucket = item['bucket'] == 'outing' ? Bucket.outing : Bucket.daily;
            transactions.add(
              Txn(
                id: (item['id'] as String?) ?? 'txn_${transactions.length}',
                amountPaise: amt,
                direction: dir,
                occurredAtMs: (item['occurred_at_ms'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
                localDate: date,
                merchant: (item['merchant'] as String? ?? 'Expense').trim(),
                categoryId: (item['category_id'] as String? ?? 'misc').trim(),
                bucket: bucket,
                outingId: item['outing_id'] as String?,
                note: (item['note'] as String? ?? '').trim(),
              ),
            );
          }
        }
      }

      // 6. Pre-validate and construct Friend Splits
      final splitList = decoded['friend_splits'];
      final friendSplits = <FriendSplit>[];
      if (splitList is List) {
        for (final item in splitList) {
          if (item is Map<String, dynamic>) {
            final date = LocalDate.tryParse(item['local_date'] as String?);
            if (date == null) return false;
            final amt = (item['amount_paise'] as int? ?? 0).clamp(0, 999999999);
            final dir = item['direction'] == 'you_owe' ? SplitDirection.youOwe : SplitDirection.youAreOwed;
            friendSplits.add(
              FriendSplit(
                id: (item['id'] as String?) ?? 'split_${friendSplits.length}',
                friendName: (item['friend_name'] as String? ?? 'Friend').trim(),
                amountPaise: amt,
                direction: dir,
                occurredAtMs: (item['occurred_at_ms'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
                localDate: date,
                note: (item['note'] as String? ?? '').trim(),
                isSettled: item['is_settled'] as bool? ?? false,
                settledAtMs: item['settled_at_ms'] as int?,
              ),
            );
          }
        }
      }

      // 7. Atomic Restore: All validations passed! Perform transactional wipe + restore
      return await repo.restoreSnapshot(
        settings: settings,
        customCategories: customCategories,
        fixedDeductions: fixedDeductions,
        outings: outings,
        transactions: transactions,
        friendSplits: friendSplits,
      );
    } catch (_) {
      return false;
    }
  }
}
