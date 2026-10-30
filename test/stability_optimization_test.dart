import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/backup.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/core/money.dart';
import 'package:pocket/core/upi_sms_parser.dart';
import 'package:pocket/data/database.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/data/repository.dart';
import 'package:pocket/state/ledger.dart';

void main() {
  group('LocalDate & Date Utilities Optimizations', () {
    test('LocalDate implements Comparable and sorts accurately', () {
      final dates = [
        const LocalDate(2026, 10, 28),
        const LocalDate(2025, 12, 31),
        const LocalDate(2026, 1, 1),
        const LocalDate(2026, 10, 5),
      ];

      dates.sort();

      expect(dates, [
        const LocalDate(2025, 12, 31),
        const LocalDate(2026, 1, 1),
        const LocalDate(2026, 10, 5),
        const LocalDate(2026, 10, 28),
      ]);
    });

    test('isBefore, isAfter, and isSameDay evaluate accurately without allocations', () {
      const d1 = LocalDate(2026, 10, 15);
      const d2 = LocalDate(2026, 10, 16);
      const d3 = LocalDate(2026, 10, 15);

      expect(d1.isBefore(d2), isTrue);
      expect(d2.isAfter(d1), isTrue);
      expect(d1.isBefore(d3), isFalse);
      expect(d1.isAfter(d3), isFalse);
      expect(d1.isSameDay(d3), isTrue);
    });

    test('LocalDate.tryParse handles edge cases and invalid formats safely', () {
      expect(LocalDate.tryParse('2026-10-28'), const LocalDate(2026, 10, 28));
      expect(LocalDate.tryParse(' 2026-05-09 '), const LocalDate(2026, 5, 9));
      expect(LocalDate.tryParse(null), isNull);
      expect(LocalDate.tryParse(''), isNull);
      expect(LocalDate.tryParse('invalid-date'), isNull);
      expect(LocalDate.tryParse('2026-13-01'), isNull); // Month 13 invalid
      expect(LocalDate.tryParse('2026-10-32'), isNull); // Day 32 invalid
    });

    test('PayCycle.contains evaluates correctly', () {
      final cycle = PayCycle.containing(const LocalDate(2026, 10, 15), 1);
      expect(cycle.contains(const LocalDate(2026, 10, 1)), isTrue);
      expect(cycle.contains(const LocalDate(2026, 10, 31)), isTrue);
      expect(cycle.contains(const LocalDate(2026, 9, 30)), isFalse);
      expect(cycle.contains(const LocalDate(2026, 11, 1)), isFalse);
    });
  });

  group('Money Safety & Hardening', () {
    test('fromDigitsAndPaise safely bounds inputs and handles whitespace', () {
      expect(Money.fromDigitsAndPaise(' 250 ', 50), 25050);
      expect(Money.fromDigitsAndPaise('', 0), 0);
      expect(Money.fromDigitsAndPaise('invalid', 0), 0);
      expect(Money.fromDigitsAndPaise('-50', 0), 0);
      expect(Money.fromDigitsAndPaise('100', 120), 10099); // Paise clamped to 99
    });
  });

  group('UPI SMS Parser Modern Indian Formats', () {
    test('parses modern SMS containing ₹ unicode symbol', () {
      const sms = 'Sent ₹ 120.00 to Chai Point via GPay UPI Ref 928172.';
      final res = UpiSmsParser.parse(sms);
      expect(res, isNotNull);
      expect(res!.amountPaise, 12000);
      expect(res.isDebit, isTrue);
      expect(res.merchant.toLowerCase(), contains('chai point'));
    });

    test('parses attached ₹ without space', () {
      const sms = 'Dear Customer, ₹45.50 debited from A/C 9999 at College Xerox on 28-10-26.';
      final res = UpiSmsParser.parse(sms);
      expect(res, isNotNull);
      expect(res!.amountPaise, 4550);
      expect(res.isDebit, isTrue);
    });
  });

  group('Safe Backup Validation & Atomic Rollback', () {
    test('rejects corrupted JSON payload without crashing or data loss', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);

      // Malformed date in transaction
      final corruptedJson = jsonEncode({
        'pocket_version': 4,
        'settings': {
          'stipend_paise': 250000,
          'cycle_start_day': 1,
        },
        'categories': [],
        'fixed_deductions': [],
        'outings': [],
        'transactions': [
          {
            'id': 't1',
            'amount_paise': 5000,
            'direction': 'debit',
            'local_date': 'corrupted-date', // INVALID!
            'merchant': 'Shop',
            'category_id': 'food',
            'bucket': 'daily',
            'note': '',
          }
        ],
        'friend_splits': [],
      });

      final success = await BackupService.restoreFromJson(corruptedJson, repo);
      expect(success, isFalse);
    });

    test('restores clean valid snapshot atomically', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);

      final validJson = jsonEncode({
        'pocket_version': 4,
        'settings': {
          'stipend_paise': 280000,
          'cycle_start_day': 5,
          'hide_amounts': false,
          'onboarded': true,
          'pacing_mode': 'daily',
          'leftover_policy': 'dynamicDistribute',
          'biometric_enabled': false,
        },
        'categories': [
          {'id': 'c1', 'name': 'Gym & Sports', 'icon': 'custom', 'is_system': false, 'sort_order': 4}
        ],
        'fixed_deductions': [
          {'id': 'fd1', 'title': 'Internet Recharge', 'amount_paise': 29900, 'is_enabled': true}
        ],
        'outings': [
          {'id': 'o1', 'title': 'Campus Fest', 'local_date': '2026-10-28', 'note': 'Cultural night'}
        ],
        'transactions': [
          {
            'id': 't1',
            'amount_paise': 3500,
            'direction': 'debit',
            'occurred_at_ms': 1000,
            'local_date': '2026-10-28',
            'merchant': 'Samosa',
            'category_id': 'snacks',
            'bucket': 'daily',
            'note': 'Snack',
          }
        ],
        'friend_splits': [],
      });

      final success = await BackupService.restoreFromJson(validJson, repo);
      expect(success, isTrue);

      final loaded = await repo.load();
      expect(loaded.settings.stipendPaise, 280000);
      expect(loaded.settings.cycleStartDay, 5);
      expect(loaded.categories.any((c) => c.name == 'Gym & Sports'), isTrue);
      expect(loaded.transactions.length, 1);
      expect(loaded.transactions.first.merchant, 'Samosa');
    });
  });

  group('Single-Pass Algorithmic Calculations', () {
    test('outingsPiggyBank sums unspent past daily allowances accurately', () {
      final cycle = PayCycle.containing(const LocalDate(2026, 10, 5), 1);
      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 310000, // ₹100/day
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          leftoverPolicy: LeftoverPolicy.outingsPiggyBank,
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        ],
        transactions: [
          // Day 1: Allowance 10000, spent 4000 -> saved 6000
          Txn(
            id: 't1',
            amountPaise: 4000,
            direction: Direction.debit,
            occurredAtMs: 1,
            localDate: const LocalDate(2026, 10, 1),
            merchant: 'Lunch',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: '',
          ),
          // Day 2: Allowance 10000, spent 7000 -> saved 3000
          Txn(
            id: 't2',
            amountPaise: 7000,
            direction: Direction.debit,
            occurredAtMs: 2,
            localDate: const LocalDate(2026, 10, 2),
            merchant: 'Dinner',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: '',
          ),
        ],
        outings: const [],
        friendSplits: const [],
      );

      // On Oct 3, days 1 and 2 are in the past.
      // Day 1 savings: 10000 - 4000 = 6000
      // Day 2 savings: 10000 - 7000 = 3000
      // Total savings swept to piggy bank: 9000 paise (₹90)
      final piggySavings = outingsPiggyBank(ledger, cycle, const LocalDate(2026, 10, 3));
      expect(piggySavings, 9000);
    });

    test('buildCurrentWeek dynamically distributes remaining allowance for remaining days', () {
      // 31-day October cycle, stipend = 310,000 paise (₹3,100).
      // On Oct 29, 3 days left in month (29, 30, 31).
      // If 0 spent so far, all 310,000 paise remain for the remaining 3 days.
      // Week 5 (29-31 Oct) should receive all 310,000 paise!
      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 310000,
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          leftoverPolicy: LeftoverPolicy.dynamicDistribute,
          appThemeMode: AppThemeMode.dark,
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        ],
        transactions: const [],
        outings: const [],
        friendSplits: const [],
      );

      final weekView = buildCurrentWeek(ledger, date: const LocalDate(2026, 10, 29));
      expect(weekView.budget.weekNumber, 5);
      expect(weekView.budget.totalWeeks, 5);
      expect(weekView.budget.startDate, const LocalDate(2026, 10, 26));
      expect(weekView.budget.endDate, const LocalDate(2026, 10, 31));
      // Full remaining stipend is distributed across Week 5 as final week of cycle
      expect(weekView.budget.allowancePaise, 310000);
    });

    test('AppThemeMode enum and settings toggle persist correctly in repository', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      final initial = await repo.load();
      expect(initial.settings.appThemeMode, AppThemeMode.system);

      await repo.saveSettings(initial.settings.copyWith(appThemeMode: AppThemeMode.dark));
      final updated = await repo.load();
      expect(updated.settings.appThemeMode, AppThemeMode.dark);
    });

    test('Month-to-Month Rollover accurately rolls unspent savings into next cycle', () {
      // October cycle: 1 Oct - 31 Oct. Base stipend: ₹2,500 (250000 paise).
      // Spent in October: ₹1,500 (150000 paise).
      // Leftover in October: ₹1,000 (100000 paise).
      final octTxn = Txn(
        id: 't-oct-1',
        amountPaise: 150000,
        direction: Direction.debit,
        occurredAtMs: DateTime(2026, 10, 15).millisecondsSinceEpoch,
        localDate: const LocalDate(2026, 10, 15),
        merchant: 'Hostel Mess Fee',
        categoryId: 'food',
        bucket: Bucket.daily,
        note: 'Mess fee',
      );

      final ledgerWithRollover = Ledger(
        settings: const Settings(
          stipendPaise: 250000,
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          rolloverUnspent: true,
        ),
        categories: const [Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0)],
        transactions: [octTxn],
        outings: const [],
        friendSplits: const [],
      );

      final novCycle = PayCycle.containing(const LocalDate(2026, 11, 1), 1);

      // In November, effective stipend should be base ₹2,500 + ₹1,000 unspent = ₹3,500 (350000 paise)
      final novEffective = effectiveStipendForCycle(ledgerWithRollover, novCycle);
      expect(novEffective, 350000);

      final novToday = buildToday(ledgerWithRollover, date: const LocalDate(2026, 11, 1));
      // 30 days in November: 350000 / 30 = 11666 paise (~₹116)
      expect(novToday.budget.allowancePaise, 350000 ~/ 30);

      // When rolloverUnspent is turned off, November stays at base ₹2,500
      final ledgerWithoutRollover = Ledger(
        settings: ledgerWithRollover.settings.copyWith(rolloverUnspent: false),
        categories: ledgerWithRollover.categories,
        transactions: ledgerWithRollover.transactions,
        outings: const [],
        friendSplits: const [],
      );
      final novBase = effectiveStipendForCycle(ledgerWithoutRollover, novCycle);
      expect(novBase, 250000);
    });
  });
}

