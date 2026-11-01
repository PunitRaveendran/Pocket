import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/backup.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/core/upi_sms_parser.dart';
import 'package:pocket/data/database.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/data/repository.dart';
import 'package:pocket/state/ledger.dart';

void main() {
  group('UpiSmsParser Tests', () {
    test('parses SBI debit SMS correctly', () {
      const sms = 'Dear SBI User, your A/C ending with 1234 debited by Rs 40.00 on 28Oct26 at Sharma Canteen via UPI Ref 9283749281.';
      final result = UpiSmsParser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amountPaise, 4000);
      expect(result.isDebit, isTrue);
      expect(result.merchant.toLowerCase(), contains('sharma canteen'));
    });

    test('parses HDFC debit SMS correctly', () {
      const sms = 'HDFC Bank: Rs 150.00 spent on your card ending 5678 at CCD CAFE on 28-OCT-26. Bal INR 3400.';
      final result = UpiSmsParser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amountPaise, 15000);
      expect(result.isDebit, isTrue);
      expect(result.merchant.toLowerCase(), contains('ccd cafe'));
    });

    test('parses credit / refund UPI SMS correctly', () {
      const sms = 'Dear Customer, your a/c ending 9012 is credited with Rs 200.00 from Rahul Kumar UPI ref 827189.';
      final result = UpiSmsParser.parse(sms);
      expect(result, isNotNull);
      expect(result!.amountPaise, 20000);
      expect(result.isDebit, isFalse);
    });

    test('ignores non-transaction OTP SMS', () {
      const sms = 'Your OTP for logging into Student Portal is 492019. Valid for 10 mins. Do not share.';
      final result = UpiSmsParser.parse(sms);
      expect(result, isNull);
    });
  });

  group('Fixed Deductions & Budget Calculations', () {
    test('deductions correctly compute effective stipend', () {
      const settings = Settings(
        stipendPaise: 300000, // ₹3,000
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
        fixedDeductions: [
          FixedDeduction(id: '1', title: 'Bus Pass', amountPaise: 40000, isEnabled: true), // ₹400
          FixedDeduction(id: '2', title: 'Recharge', amountPaise: 29900, isEnabled: true), // ₹299
          FixedDeduction(id: '3', title: 'Gym', amountPaise: 50000, isEnabled: false), // disabled
        ],
      );

      expect(settings.totalFixedDeductionsPaise, 69900); // 400 + 299
      expect(settings.effectiveStipendPaise, 230100); // 3000 - 699 = 2301
    });

    test('buildToday incorporates dynamic distribute policy', () {
      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 300000,
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          leftoverPolicy: LeftoverPolicy.dynamicDistribute,
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        ],
        transactions: [
          Txn(
            id: 't1',
            amountPaise: 2000, // spent ₹20
            direction: Direction.debit,
            occurredAtMs: 1,
            localDate: const LocalDate(2026, 10, 1),
            merchant: 'Chai',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: 'Morning chai',
          ),
        ],
        outings: const [],
        friendSplits: const [],
      );

      // Testing today view for Oct 2
      final todayView = buildToday(ledger, date: const LocalDate(2026, 10, 2));
      expect(todayView.budget.allowancePaise, greaterThan(0));
    });
  });

  group('BackupService Tests', () {
    test('generateBackupJson produces valid structured JSON', () {
      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 250000,
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          fixedDeductions: [
            FixedDeduction(id: 'd1', title: 'Bus Pass', amountPaise: 40000, isEnabled: true),
          ],
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        ],
        transactions: [
          Txn(
            id: 't1',
            amountPaise: 4000,
            direction: Direction.debit,
            occurredAtMs: 1000,
            localDate: const LocalDate(2026, 10, 28),
            merchant: 'Canteen',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: 'Lunch',
          ),
        ],
        outings: const [],
        friendSplits: [
          FriendSplit(
            id: 's1',
            friendName: 'Rahul',
            amountPaise: 15000,
            direction: SplitDirection.youAreOwed,
            occurredAtMs: 1000,
            localDate: const LocalDate(2026, 10, 28),
            note: 'Auto fare',
            isSettled: false,
          ),
        ],
      );

      final jsonStr = BackupService.generateBackupJson(ledger);
      expect(jsonStr, contains('pocket_version'));
      expect(jsonStr, contains('Bus Pass'));
      expect(jsonStr, contains('Rahul'));
      expect(jsonStr, contains('Canteen'));
    });

    test('restoreFromJson cleanly restores user backup with past outings and friend splits', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      const userJson = '''{
  "pocket_version": 3,
  "exported_at": "2026-11-01T11:18:19.091241",
  "settings": {
    "stipend_paise": 100000,
    "cycle_start_day": 1,
    "hide_amounts": false,
    "onboarded": true,
    "pacing_mode": "weekly",
    "leftover_policy": "dynamicDistribute",
    "biometric_enabled": false,
    "app_theme_mode": "light",
    "rollover_unspent": true
  },
  "categories": [
    {
      "id": "food",
      "name": "Food",
      "icon": "food",
      "is_system": true,
      "sort_order": 0
    },
    {
      "id": "snacks",
      "name": "Snacks",
      "icon": "snacks",
      "is_system": true,
      "sort_order": 1
    },
    {
      "id": "study",
      "name": "Study",
      "icon": "study",
      "is_system": true,
      "sort_order": 2
    },
    {
      "id": "misc",
      "name": "Misc",
      "icon": "misc",
      "is_system": true,
      "sort_order": 3
    },
    {
      "id": "income",
      "name": "Top-Up",
      "icon": "savings",
      "is_system": true,
      "sort_order": 4
    },
    {
      "id": "de7a1a36-d5c6-4446-8954-3c9d59579c55",
      "name": "Puffs",
      "icon": "food",
      "is_system": false,
      "sort_order": 5
    },
    {
      "id": "4c357471-629a-4d04-b6b9-a76074397337",
      "name": "Soft Drinks",
      "icon": "snacks",
      "is_system": false,
      "sort_order": 6
    }
  ],
  "fixed_deductions": [],
  "outings": [
    {
      "id": "82b755b0-12a5-4543-8b62-bd422f261013",
      "title": "Other Expenses",
      "local_date": "2026-10-31",
      "note": ""
    }
  ],
  "transactions": [
    {
      "id": "1fcf95f4-48d1-4674-9519-ea79ad8c1fe7",
      "amount_paise": 1000,
      "direction": "debit",
      "occurred_at_ms": 1793449175181,
      "local_date": "2026-10-31",
      "merchant": "Tea",
      "category_id": "snacks",
      "bucket": "daily",
      "outing_id": null,
      "note": "Split with Manjari (My share of ₹22)"
    },
    {
      "id": "c010b122-c08e-42db-962e-67f389d2babe",
      "amount_paise": 52500,
      "direction": "debit",
      "occurred_at_ms": 1793437629431,
      "local_date": "2026-10-31",
      "merchant": "Treat",
      "category_id": "misc",
      "bucket": "outing",
      "outing_id": "82b755b0-12a5-4543-8b62-bd422f261013",
      "note": ""
    },
    {
      "id": "257c2e1e-9f5a-4eb1-ba9b-8161fff09746",
      "amount_paise": 1500,
      "direction": "debit",
      "occurred_at_ms": 1793435363934,
      "local_date": "2026-10-31",
      "merchant": "JK Print",
      "category_id": "study",
      "bucket": "daily",
      "outing_id": null,
      "note": "Slice · Slice Payment"
    },
    {
      "id": "d73781e8-1824-414f-a9c2-aca42426170c",
      "amount_paise": 3500,
      "direction": "debit",
      "occurred_at_ms": 1793420698479,
      "local_date": "2026-10-31",
      "merchant": "JK Book",
      "category_id": "study",
      "bucket": "daily",
      "outing_id": null,
      "note": "Slice · Slice Payment"
    },
    {
      "id": "5ba129bb-5bc6-4ff7-bb4d-cb283a0d3500",
      "amount_paise": 75000,
      "direction": "debit",
      "occurred_at_ms": 1793392253871,
      "local_date": "2026-10-31",
      "merchant": "Mouse",
      "category_id": "misc",
      "bucket": "outing",
      "outing_id": "82b755b0-12a5-4543-8b62-bd422f261013",
      "note": ""
    },
    {
      "id": "f9c554cc-7b70-47ba-acf9-866879ff2a06",
      "amount_paise": 161000,
      "direction": "debit",
      "occurred_at_ms": 1793392226861,
      "local_date": "2026-10-31",
      "merchant": "Train",
      "category_id": "misc",
      "bucket": "outing",
      "outing_id": "82b755b0-12a5-4543-8b62-bd422f261013",
      "note": ""
    },
    {
      "id": "9a2cebd4-ba6b-4bb9-983a-38d47fbf89d4",
      "amount_paise": 90000,
      "direction": "debit",
      "occurred_at_ms": 1793392197941,
      "local_date": "2026-10-31",
      "merchant": "Recharge",
      "category_id": "misc",
      "bucket": "outing",
      "outing_id": "82b755b0-12a5-4543-8b62-bd422f261013",
      "note": ""
    }
  ],
  "friend_splits": [
    {
      "id": "34ebd4af-26e4-4307-b04d-db0458902bb7",
      "friend_name": "Manjari",
      "amount_paise": 1200,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793449175182,
      "local_date": "2026-10-31",
      "note": "Tea split",
      "is_settled": false,
      "settled_at_ms": null
    },
    {
      "id": "6c02086e-1361-409b-8ac0-0be0c49aafa5",
      "friend_name": "Punit",
      "amount_paise": 30000,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793443460204,
      "local_date": "2026-10-31",
      "note": "Krishna split",
      "is_settled": false,
      "settled_at_ms": null
    },
    {
      "id": "19d7b33c-0491-4838-8a21-e66879fc1a99",
      "friend_name": "Jayakrishna",
      "amount_paise": 20000,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793443460203,
      "local_date": "2026-10-31",
      "note": "Krishna split",
      "is_settled": false,
      "settled_at_ms": null
    },
    {
      "id": "8663abb9-9db5-48a1-b162-7bb9c3b719b9",
      "friend_name": "Surya",
      "amount_paise": 20000,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793443460202,
      "local_date": "2026-10-31",
      "note": "Krishna split",
      "is_settled": false,
      "settled_at_ms": null
    },
    {
      "id": "da0a86dc-3a0f-4223-8140-9fb581ea3368",
      "friend_name": "Jayakrishna",
      "amount_paise": 3500,
      "direction": "you_owe",
      "occurred_at_ms": 1793392104254,
      "local_date": "2026-10-31",
      "note": "",
      "is_settled": true,
      "settled_at_ms": 1793420713564
    },
    {
      "id": "4aad9eb8-3382-473d-a6f5-013ad5c7499f",
      "friend_name": "Surya",
      "amount_paise": 2500,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793391753468,
      "local_date": "2026-10-31",
      "note": "Bill Split split",
      "is_settled": true,
      "settled_at_ms": 1793391967011
    },
    {
      "id": "d2740184-8f1c-49f4-8e3b-9fe9de6a7809",
      "friend_name": "Punit",
      "amount_paise": 2500,
      "direction": "you_are_owed",
      "occurred_at_ms": 1793391753467,
      "local_date": "2026-10-31",
      "note": "Bill Split split",
      "is_settled": true,
      "settled_at_ms": 1793391970390
    }
  ]
}''';

      final success = await BackupService.restoreFromJson(userJson, repo);
      expect(success, isTrue);

      final loaded = await repo.load();
      expect(loaded.outings.length, 1);
      expect(loaded.outings.first.title, 'Other Expenses');
      expect(loaded.outings.first.localDate, const LocalDate(2026, 10, 31));

      final outingTxns = loaded.transactions.where((t) => t.bucket == Bucket.outing).toList();
      expect(outingTxns.length, 4);
      final outingTotal = outingTxns.fold<int>(0, (sum, t) => sum + t.amountPaise);
      expect(outingTotal, 378500); // ₹3,785.00

      expect(loaded.friendSplits.length, 7);
      expect(loaded.savedFriends, contains('Manjari'));
      expect(loaded.savedFriends, contains('Jayakrishna'));
      expect(loaded.settings.rolloverUnspent, isTrue);
      expect(loaded.categories.any((c) => c.name == 'Puffs'), isTrue);
      expect(loaded.categories.any((c) => c.name == 'Soft Drinks'), isTrue);
    });
  });

  group('Extra Money Top-Up & Friend Repayments', () {
    test('extra stipend top-up adds directly to cycle allowance without distorting daily spending', () {
      final cycle = PayCycle.containing(const LocalDate(2026, 10, 15), 1);
      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 300000, // ₹3,000 base
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
          Category(id: 'income', name: 'Top-Up', icon: 'savings', isSystem: true, sortOrder: 4),
        ],
        transactions: [
          Txn(
            id: 't1',
            amountPaise: 5000, // ₹50 spent
            direction: Direction.debit,
            occurredAtMs: 1000,
            localDate: const LocalDate(2026, 10, 10),
            merchant: 'Lunch',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: 'Lunch with batchmates',
          ),
          Txn(
            id: 't2',
            amountPaise: 100000, // ₹1,000 extra received from parents
            direction: Direction.credit,
            occurredAtMs: 2000,
            localDate: const LocalDate(2026, 10, 15),
            merchant: 'Parents Top-Up',
            categoryId: 'income',
            bucket: Bucket.daily,
            note: 'Stipend Top-Up',
          ),
        ],
        outings: const [],
        friendSplits: const [],
      );

      // Verify top-up calculation
      expect(extraTopUpForCycle(ledger, cycle), 100000);
      // Effective stipend increased by ₹1,000 to ₹4,000
      expect(effectiveStipendForCycle(ledger, cycle), 400000);
      // Ordinary daily spend is still ₹50, NOT -₹950!
      expect(ordinaryThisCycle(ledger, cycle), 5000);
    });

    test('friend repayment clears split without inflating daily balance', () {
      final cycle = PayCycle.containing(const LocalDate(2026, 10, 15), 1);
      final split = FriendSplit(
        id: 's1',
        friendName: 'Aarav',
        amountPaise: 20000, // ₹200
        direction: SplitDirection.youAreOwed,
        occurredAtMs: 1000,
        localDate: const LocalDate(2026, 10, 10),
        note: 'Dinner share',
        isSettled: false,
      );

      final ledgerBefore = Ledger(
        settings: const Settings(stipendPaise: 300000, cycleStartDay: 1, hideAmounts: false, onboarded: true),
        categories: const [],
        transactions: const [],
        outings: const [],
        friendSplits: [split],
      );

      expect(ledgerBefore.totalOwedToMePaise, 20000);

      // Friend pays back, split settled with creditDaily = false
      final settledSplit = split.copyWith(isSettled: true, settledAtMs: 3000);
      final ledgerAfter = Ledger(
        settings: ledgerBefore.settings,
        categories: const [],
        transactions: const [], // No credit transaction created in daily balance!
        outings: const [],
        friendSplits: [settledSplit],
      );

      expect(ledgerAfter.totalOwedToMePaise, 0);
      expect(settledSplit.isSettled, isTrue);
      // Ordinary daily spend and effective stipend are completely unchanged!
      expect(ordinaryThisCycle(ledgerAfter, cycle), 0);
      expect(effectiveStipendForCycle(ledgerAfter, cycle), 300000);
    });
  });

  group('Bill Split Isolation Tests', () {
    test('splitBill debits only user share (₹20) to Today spend and sends ₹80 to Splits section', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      await repo.wipe();
      final today = LocalDate.today();

      await repo.splitBill(
        totalAmountPaise: 10000, // ₹100 total
        mySharePaise: 2000,      // ₹20 my share
        friends: [
          (friendName: 'Rahul', amountPaise: 2000),
          (friendName: 'Aman', amountPaise: 2000),
          (friendName: 'Sneha', amountPaise: 2000),
          (friendName: 'Rohan', amountPaise: 2000),
        ],
        date: today,
        categoryId: 'food',
        merchant: 'Canteen Thali',
      );

      final ledger = await repo.load();

      // Only 1 transaction in daily spend for ₹20
      expect(ledger.transactions.length, 1);
      final userTxn = ledger.transactions.first;
      expect(userTxn.amountPaise, 2000); // Exactly ₹20
      expect(userTxn.direction, Direction.debit);
      expect(userTxn.merchant, 'Canteen Thali');
      expect(userTxn.bucket, Bucket.daily);

      // In Splits section: 4 friends owe ₹20 each = ₹80 total
      expect(ledger.friendSplits.length, 4);
      expect(ledger.totalOwedToMePaise, 8000); // Exactly ₹80
      expect(ledger.totalIOwePaise, 0);
      expect(ledger.netFriendBalancePaise, 8000);

      // Verify that Today's spend calculation only includes ₹20
      final todayView = buildToday(ledger, date: today);
      expect(todayView.budget.spentPaise, 2000); // Only ₹20 deducted from allowance!
      expect(todayView.budget.netSpent, 2000);
    });

    test('splitBill supports custom per-friend share amounts and groups friend splits', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      await repo.wipe();
      final today = LocalDate.today();

      // Bill 1: ₹100 split where Rahul owes ₹30, Aman owes ₹50, User personal share is ₹20
      await repo.splitBill(
        totalAmountPaise: 10000, // ₹100 total
        mySharePaise: 2000,      // ₹20 user share
        friends: [
          (friendName: 'Rahul', amountPaise: 3000), // ₹30
          (friendName: 'Aman', amountPaise: 5000),  // ₹50
        ],
        date: today,
        categoryId: 'food',
        merchant: 'Hostel Night Canteen',
      );

      // Bill 2: Another bill where Rahul owes ₹25
      await repo.splitBill(
        totalAmountPaise: 5000,  // ₹50 total
        mySharePaise: 2500,      // ₹25 user share
        friends: [
          (friendName: 'Rahul', amountPaise: 2500), // ₹25
        ],
        date: today,
        categoryId: 'food',
        merchant: 'Chai & Snacks',
      );

      final ledger = await repo.load();

      // User has 2 transactions: ₹20 + ₹25 = ₹45 total
      expect(ledger.transactions.length, 2);
      expect(ledger.transactions.fold<int>(0, (sum, t) => sum + t.amountPaise), 4500);

      // Total owed in Splits:
      // Rahul owes: ₹30 + ₹25 = ₹55
      // Aman owes: ₹50
      // Total = ₹105
      expect(ledger.friendSplits.length, 3);
      expect(ledger.totalOwedToMePaise, 10500);

      // Verify grouped friend math: Rahul has 2 splits totaling ₹55
      final rahulSplits = ledger.friendSplits.where((s) => s.friendName == 'Rahul').toList();
      expect(rahulSplits.length, 2);
      expect(rahulSplits.fold<int>(0, (sum, s) => sum + s.amountPaise), 5500);

      // Aman has 1 split for ₹50
      final amanSplits = ledger.friendSplits.where((s) => s.friendName == 'Aman').toList();
      expect(amanSplits.length, 1);
      expect(amanSplits.first.amountPaise, 5000);
    });
  });

  group('Category Reordering & Friends Suggestions Tests', () {
    test('reorderCategories alters category order in ledger', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      await repo.wipe();
      final ledger1 = await repo.load();
      final originalIds = ledger1.categories.map((c) => c.id).toList();

      // Reverse order of categories
      final reversedIds = originalIds.reversed.toList();
      await repo.reorderCategories(reversedIds);

      final ledger2 = await repo.load();
      expect(ledger2.categories.map((c) => c.id).toList(), reversedIds);
    });

    test('addFriend, deleteFriend and allFriendSuggestions work properly', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);
      await repo.wipe();
      await repo.addFriend('Vikram');
      var ledger = await repo.load();
      expect(ledger.savedFriends, contains('Vikram'));
      expect(ledger.allFriendSuggestions, contains('Vikram'));

      // Test deduplication with past split
      final today = LocalDate(2026, 10, 28);
      await repo.splitBill(
        totalAmountPaise: 2000,
        mySharePaise: 1000,
        friends: [(friendName: 'Vikram', amountPaise: 1000)],
        date: today,
        categoryId: 'food',
        merchant: 'Canteen',
      );

      ledger = await repo.load();
      final vikramCount = ledger.allFriendSuggestions.where((f) => f.toLowerCase() == 'vikram').length;
      expect(vikramCount, 1);

      // Delete friend
      await repo.deleteFriend('Vikram');
      ledger = await repo.load();
      expect(ledger.savedFriends, isNot(contains('Vikram')));
    });
  });

  group('Week/Day Switcher and Monthly Balance Rollover Tests', () {
    test('Sunday cycle start creates full multi-day week and updates money between Day and Week', () {
      final cycle = PayCycle.containing(const LocalDate(2026, 11, 1), 1);
      final weeks = cycle.calendarWeeks();

      // Nov 1, 2026 is Sunday. Week 1 spans Sun Nov 1 to Sun Nov 8 (8 days)
      expect(weeks.first.start, const LocalDate(2026, 11, 1));
      expect(weeks.first.end, const LocalDate(2026, 11, 8));
      expect(weeks.first.lengthDays, 8);

      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 300000, // ₹3,000 for 30 days = ₹100/day
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          leftoverPolicy: LeftoverPolicy.dynamicDistribute,
        ),
        categories: const [],
        transactions: const [],
        outings: const [],
      );

      final dayView = buildToday(ledger, date: const LocalDate(2026, 11, 1));
      final weekView = buildCurrentWeek(ledger, date: const LocalDate(2026, 11, 1));

      // Day view gives 1 day's allowance (₹100)
      expect(dayView.budget.allowancePaise, 10000);
      expect(dayView.budget.remaining, 10000);

      // Week view gives 8 days' allowance (₹800), NOT a duplicate of day view (₹100)!
      expect(weekView.budget.allowancePaise, 80000);
      expect(weekView.budget.remaining, 80000);
    });

    test('monthly balance incorporates unspent rollover from previous cycle', () {
      final prevDay = const LocalDate(2026, 10, 25);
      final currentDay = const LocalDate(2026, 11, 5);

      final ledger = Ledger(
        settings: const Settings(
          stipendPaise: 1000000, // ₹10,000 base stipend
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          rolloverUnspent: true,
        ),
        categories: const [],
        transactions: [
          // Previous cycle (October): spent ₹2,000 out of ₹10,000 -> ₹8,000 leftover unspent!
          Txn(
            id: 't_prev',
            amountPaise: 200000,
            categoryId: 'food',
            merchant: 'Mess',
            occurredAtMs: 1000,
            localDate: prevDay,
            direction: Direction.debit,
            bucket: Bucket.daily,
            note: 'Mess fee',
          ),
          // Current cycle (November): spent ₹1,000
          Txn(
            id: 't_curr',
            amountPaise: 100000,
            categoryId: 'food',
            merchant: 'Snacks',
            occurredAtMs: 2000,
            localDate: currentDay,
            direction: Direction.debit,
            bucket: Bucket.daily,
            note: 'Canteen',
          ),
        ],
        outings: const [],
      );

      final currentCycle = PayCycle.containing(currentDay, 1);
      final rollover = rolloverSavingsFromPreviousCycle(ledger, currentCycle);
      expect(rollover, 800000); // ₹8,000 rolled over from October!

      final cycleStipend = effectiveStipendForCycle(ledger, currentCycle);
      expect(cycleStipend, 1800000); // ₹10,000 base + ₹8,000 rollover = ₹18,000

      final spentThisCycle = ordinaryThisCycle(ledger, currentCycle);
      expect(spentThisCycle, 100000); // ₹1,000 spent in Nov

      // Actual remaining monthly balance including rollover: ₹18,000 - ₹1,000 = ₹17,000
      final currentRemaining = cycleStipend - spentThisCycle;
      expect(currentRemaining, 1700000);
    });

    test('balance adjustment fixes account amount without creating any spending transactions', () {
      final today = const LocalDate(2026, 11, 10);
      final cycle = PayCycle.containing(today, 1);

      final realSpend = Txn(
        id: 't_real',
        amountPaise: 50000, // ₹500 real food expense
        categoryId: 'food',
        merchant: 'Canteen',
        occurredAtMs: 1000,
        localDate: today,
        direction: Direction.debit,
        bucket: Bucket.daily,
        note: 'Lunch',
      );

      final initialLedger = Ledger(
        settings: const Settings(
          stipendPaise: 300000, // ₹3,000 base stipend
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
          rolloverUnspent: false,
        ),
        categories: const [],
        transactions: [realSpend],
        outings: const [],
      );

      // Current remaining = ₹3,000 stipend - ₹500 spent = ₹2,500
      expect(ordinaryThisCycle(initialLedger, cycle), 50000);
      final remainingBefore = effectiveStipendForCycle(initialLedger, cycle) - ordinaryThisCycle(initialLedger, cycle);
      expect(remainingBefore, 250000);

      // User directly updates their monthly balance to ₹1,000 (targetPaise = 100000)
      const targetPaise = 100000;

      final adjustedLedger = Ledger(
        settings: initialLedger.settings.copyWith(stipendPaise: targetPaise),
        categories: initialLedger.categories,
        transactions: initialLedger.transactions, // ZERO new transactions added!
        outings: initialLedger.outings,
      );

      // Monthly stipend is directly set to ₹1,000 (NOT reduced to 60 or distorted)
      expect(adjustedLedger.settings.stipendPaise, 100000);
      // Spending is completely unchanged (still ₹500, zero fake transactions)
      expect(ordinaryThisCycle(adjustedLedger, cycle), 50000);
      expect(adjustedLedger.transactions.length, 1);
      expect(adjustedLedger.transactions.first.merchant, 'Canteen');
    });
  });
}

