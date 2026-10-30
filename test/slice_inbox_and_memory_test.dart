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
  });
}
