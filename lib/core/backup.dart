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
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!map.containsKey('pocket_version')) return false;

      // Wipe current data
      await repo.wipe();

      // Restore settings
      final sMap = map['settings'] as Map<String, dynamic>? ?? {};
      final settings = Settings(
        stipendPaise: sMap['stipend_paise'] as int? ?? 250000,
        cycleStartDay: sMap['cycle_start_day'] as int? ?? 1,
        hideAmounts: sMap['hide_amounts'] as bool? ?? false,
        onboarded: sMap['onboarded'] as bool? ?? true,
        pacingMode: sMap['pacing_mode'] == 'weekly' ? PacingMode.weekly : PacingMode.daily,
        leftoverPolicy: sMap['leftover_policy'] == 'outingsPiggyBank'
            ? LeftoverPolicy.outingsPiggyBank
            : LeftoverPolicy.dynamicDistribute,
        biometricEnabled: sMap['biometric_enabled'] as bool? ?? false,
      );
      await repo.saveSettings(settings);

      // Restore custom categories
      final catList = (map['categories'] as List<dynamic>? ?? []);
      for (final c in catList) {
        final isSystem = c['is_system'] as bool? ?? false;
        if (!isSystem) {
          await repo.addCategory(
            c['name'] as String? ?? 'Custom',
            icon: c['icon'] as String? ?? 'custom',
          );
        }
      }

      // Restore fixed deductions
      final dedList = (map['fixed_deductions'] as List<dynamic>? ?? []);
      for (final d in dedList) {
        await repo.addFixedDeduction(
          title: d['title'] as String? ?? 'Fixed cost',
          amountPaise: d['amount_paise'] as int? ?? 0,
          isEnabled: d['is_enabled'] as bool? ?? true,
        );
      }

      // Restore outings
      final outingList = (map['outings'] as List<dynamic>? ?? []);
      final outingIdMap = <String, String>{};
      for (final o in outingList) {
        final oldId = o['id'] as String;
        final created = await repo.addOuting(
          title: o['title'] as String? ?? 'Outing',
          localDate: LocalDate.parse(o['local_date'] as String),
          note: o['note'] as String? ?? '',
        );
        outingIdMap[oldId] = created.id;
      }

      // Restore transactions
      final txnList = (map['transactions'] as List<dynamic>? ?? []);
      for (final t in txnList) {
        final rawOutingId = t['outing_id'] as String?;
        await repo.addTxn(
          amountPaise: t['amount_paise'] as int? ?? 0,
          direction: t['direction'] == 'credit' ? Direction.credit : Direction.debit,
          localDate: LocalDate.parse(t['local_date'] as String),
          merchant: t['merchant'] as String? ?? 'Expense',
          categoryId: t['category_id'] as String? ?? 'misc',
          bucket: t['bucket'] == 'outing' ? Bucket.outing : Bucket.daily,
          outingId: rawOutingId != null ? (outingIdMap[rawOutingId] ?? rawOutingId) : null,
          note: t['note'] as String? ?? '',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(t['occurred_at_ms'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        );
      }

      // Restore friend splits
      final splitList = (map['friend_splits'] as List<dynamic>? ?? []);
      for (final s in splitList) {
        final created = await repo.addFriendSplit(
          friendName: s['friend_name'] as String? ?? 'Friend',
          amountPaise: s['amount_paise'] as int? ?? 0,
          direction: s['direction'] == 'you_owe' ? SplitDirection.youOwe : SplitDirection.youAreOwed,
          localDate: LocalDate.parse(s['local_date'] as String),
          note: s['note'] as String? ?? '',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(s['occurred_at_ms'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        );
        if (s['is_settled'] == true) {
          await repo.settleFriendSplit(created.id, creditDaily: false);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
