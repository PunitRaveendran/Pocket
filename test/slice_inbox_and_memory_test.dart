import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/data/database.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/data/repository.dart';

void main() {
  group('Slice Inbox & Merchant Memory Tests', () {
    late PocketRepository repo;

    setUp(() {
      repo = PocketRepository(PocketDatabase.instance, inMemory: true);
    });

    test('Add pending transactions and prevent duplicates by messageId', () async {
      final item1 = PendingTransaction(
        id: 'p-1',
        amountPaise: 45000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'Ramesh Canteen',
        rawSource: 'slice_email',
        messageId: 'msg-101@slice.bank.in',
      );

      final inserted1 = await repo.addPendingTransactions([item1]);
      expect(inserted1.length, 1);
      expect(inserted1.first.merchant, 'Ramesh Canteen');

      // Duplicate messageId should be skipped
      final itemDuplicate = PendingTransaction(
        id: 'p-2',
        amountPaise: 45000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'Ramesh Canteen',
        rawSource: 'slice_email',
        messageId: 'msg-101@slice.bank.in',
      );

      final inserted2 = await repo.addPendingTransactions([itemDuplicate]);
      expect(inserted2.length, 0);

      final ledger = await repo.load();
      expect(ledger.pendingInbox.length, 1);
      expect(ledger.pendingInbox.first.messageId, 'msg-101@slice.bank.in');
    });

    test('Approving pending transaction creates real Txn and memorizes merchant category', () async {
      final item = PendingTransaction(
        id: 'p-approve-test',
        amountPaise: 24000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'Campus Juice Bar',
        rawSource: 'slice_email',
        messageId: 'msg-202@slice.bank.in',
      );

      await repo.addPendingTransactions([item]);

      // Approve as 'snacks'
      final txn = await repo.approvePendingTransaction(
        item,
        categoryId: 'snacks',
        bucket: Bucket.daily,
      );

      expect(txn.merchant, 'Campus Juice Bar');
      expect(txn.amountPaise, 24000);
      expect(txn.categoryId, 'snacks');

      // Verify pending inbox is now empty
      final ledgerAfter = await repo.load();
      expect(ledgerAfter.pendingInbox.any((p) => p.id == 'p-approve-test'), isFalse);

      // Verify merchant memory remembered 'campus juice bar' -> 'snacks'
      final rememberedCategory = await repo.getMerchantCategory('Campus Juice Bar');
      expect(rememberedCategory, 'snacks');

      // Now add a second transaction from the same merchant (without suggested category)
      final repeatItem = PendingTransaction(
        id: 'p-repeat',
        amountPaise: 12000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'Campus Juice Bar',
        rawSource: 'slice_email',
        messageId: 'msg-203@slice.bank.in',
      );

      final insertedRepeat = await repo.addPendingTransactions([repeatItem]);
      expect(insertedRepeat.first.suggestedCategoryId, 'snacks');
    });

    test('Dismissing pending transaction removes it from pending list', () async {
      final item = PendingTransaction(
        id: 'p-dismiss-test',
        amountPaise: 50000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'ATM Withdrawal',
        rawSource: 'slice_email',
        messageId: 'msg-303@slice.bank.in',
      );

      await repo.addPendingTransactions([item]);
      var ledger = await repo.load();
      expect(ledger.pendingInbox.any((p) => p.id == 'p-dismiss-test'), isTrue);

      await repo.dismissPendingTransaction('p-dismiss-test');
      ledger = await repo.load();
      expect(ledger.pendingInbox.any((p) => p.id == 'p-dismiss-test'), isFalse);
    });

    test('Auto-sync validation checks credentials and enabled flags', () async {
      final s = const Settings(
        stipendPaise: 250000,
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
        emailSyncEnabled: false,
        emailSyncAddress: '',
        emailSyncAppPassword: '',
      );
      await repo.saveSettings(s);
      final loaded = await repo.load();
      expect(loaded.settings.emailSyncEnabled, isFalse);
      expect(loaded.settings.emailSyncAddress, isEmpty);
    });

    test('Merchant alias memory stores and resolves friendly names for senders and shops', () async {
      // Save alias for a shop
      await repo.saveMerchantAlias('RAMESH CANTEEN PVT LTD', 'Ramesh Canteen');
      final alias = await repo.getMerchantAlias('RAMESH CANTEEN PVT LTD');
      expect(alias, 'Ramesh Canteen');

      // Substring lookup works
      final subAlias = await repo.getMerchantAlias('ramesh canteen');
      expect(subAlias, 'Ramesh Canteen');

      // Adding pending transaction with raw name automatically resolves to friendly alias
      final item = PendingTransaction(
        id: 'p-alias-1',
        amountPaise: 15000,
        direction: Direction.debit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'RAMESH CANTEEN PVT LTD',
        rawSource: 'slice_email',
        messageId: 'msg-alias-1@slice.bank.in',
      );
      final inserted = await repo.addPendingTransactions([item]);
      expect(inserted.first.merchant, 'Ramesh Canteen');

      // Approving with a renamed merchant saves alias automatically
      final personItem = PendingTransaction(
        id: 'p-alias-2',
        amountPaise: 35000,
        direction: Direction.credit,
        occurredAtMs: DateTime.now().millisecondsSinceEpoch,
        localDate: LocalDate.today(),
        merchant: 'SNEH NIPOON SHETH',
        rawSource: 'slice_email',
        messageId: 'msg-alias-2@slice.bank.in',
      );
      await repo.addPendingTransactions([personItem]);
      await repo.approvePendingTransaction(
        personItem,
        categoryId: 'income',
        bucket: Bucket.daily,
        merchant: 'Sneh',
      );

      final personAlias = await repo.getMerchantAlias('SNEH NIPOON SHETH');
      expect(personAlias, 'Sneh');
    });

    test('Ledger.resolveMerchantName resolves aliases and heuristics for friends', () {
      final ledger = Ledger(
        settings: const Settings(stipendPaise: 100000, cycleStartDay: 1, hideAmounts: false, onboarded: true),
        categories: const [],
        transactions: const [],
        outings: const [],
        savedFriends: const ['Sneh', 'Rahul', 'Surya'],
        merchantAliases: const {
          'ramesh canteen pvt ltd': 'Ramesh Canteen',
          'swiggy instamart': 'Instamart',
        },
      );

      // 1. Exact alias
      expect(ledger.resolveMerchantName('ramesh canteen pvt ltd'), 'Ramesh Canteen');

      // 2. Substring alias
      expect(ledger.resolveMerchantName('SWIGGY INSTAMART HYD'), 'Instamart');

      // 3. Friend heuristic from saved friends (e.g. Sneh)
      expect(ledger.resolveMerchantName('SNEH NIPOON SHETH'), 'Sneh');
      expect(ledger.resolveMerchantName('RAHUL SHARMA UPI'), 'Rahul');

      // 4. Unknown merchant stays intact
      expect(ledger.resolveMerchantName('UNKNOWN COFFEE SHOP'), 'UNKNOWN COFFEE SHOP');
    });
  });
}
