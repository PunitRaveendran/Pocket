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
  });
}
