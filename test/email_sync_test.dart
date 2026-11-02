import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/slice_email_sync.dart';
import 'package:pocket/data/database.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/data/repository.dart';

void main() {
  group('Bank Email Parser & Sync Tests', () {
    test('BankEmailSyncService validates empty email or app password', () async {
      const service = BankEmailSyncService();
      final resEmptyEmail = await service.sync(
        email: '',
        appPassword: 'abcd efgh ijkl mnop',
        isAlreadyProcessed: (_) async => false,
      );
      expect(resEmptyEmail.success, isFalse);
      expect(resEmptyEmail.errorMessage, contains('empty'));

      final resEmptyPass = await service.sync(
        email: 'user@gmail.com',
        appPassword: '   ',
        isAlreadyProcessed: (_) async => false,
      );
      expect(resEmptyPass.success, isFalse);
      expect(resEmptyPass.errorMessage, contains('empty'));
    });

    test('Parses HDFC Bank UPI and card debit emails cleanly', () {
      final hdfcUpi = BankEmailParser.parse(
        subject: 'Alert: Update on your HDFC Bank Account',
        bodyText:
            'Dear Customer, Rs. 450.00 has been debited from account **1234 to VPA swiggy@icici (UPI Ref No 1234567890) on 02-11-2026. Avail Bal: Rs 15,200.00',
        messageId: 'hdfc-upi-1',
      );
      expect(hdfcUpi, isNotNull);
      expect(hdfcUpi!.amountPaise, 45000);
      expect(hdfcUpi.merchant, 'swiggy');
      expect(hdfcUpi.isDebit, isTrue);

      final hdfcCard = BankEmailParser.parse(
        subject: 'Transaction alert for your HDFC Bank Credit Card',
        bodyText:
            'You have done a transaction of INR 899.00 on your Credit Card ending 9876 at ZOMATO on 02-11-2026 at 20:15:30. Avail Limit: INR 75,000.00.',
        messageId: 'hdfc-card-1',
      );
      expect(hdfcCard, isNotNull);
      expect(hdfcCard!.amountPaise, 89900);
      expect(hdfcCard.merchant, 'ZOMATO');
      expect(hdfcCard.isDebit, isTrue);
    });

    test('Parses ICICI Bank debit alert emails cleanly', () {
      final icici = BankEmailParser.parse(
        subject: 'Transaction alert for your ICICI Bank Account',
        bodyText:
            'Dear Customer, your Acct ending in 4092 is debited with INR 240.00 on 02-Nov-26 at BLUETOKAI. Info: UPI/BLUETOKAI/98712. Avail Bal: INR 8,450.00.',
        messageId: 'icici-1',
      );
      expect(icici, isNotNull);
      expect(icici!.amountPaise, 24000);
      expect(icici.merchant, 'BLUETOKAI');
      expect(icici.isDebit, isTrue);
    });

    test('Parses SBI UPI debit alert emails cleanly', () {
      final sbi = BankEmailParser.parse(
        subject: 'SBI Alert: Account Debited',
        bodyText:
            'Dear SBI UPI User, A/C 9876 has been debited by 320.00 on 02Nov26 trf to Amazon India Ref No 654321098. Bal: Rs 12,000.',
        messageId: 'sbi-1',
      );
      expect(sbi, isNotNull);
      expect(sbi!.amountPaise, 32000);
      expect(sbi.merchant, 'Amazon India');
      expect(sbi.isDebit, isTrue);
    });

    test('Parses Slice Small Finance Bank debit email cleanly', () {
      final slice = BankEmailParser.parse(
        subject: 'Payment to Zepto was successful',
        bodyText:
            'Paid ₹380.00 to Zepto via slice UPI on 02-Nov-2026 12:45 PM. UPI Ref: 987654321. Team slice',
        messageId: 'slice-1',
      );
      expect(slice, isNotNull);
      expect(slice!.amountPaise, 38000);
      expect(slice.merchant, 'Zepto');
      expect(slice.isDebit, isTrue);
    });

    test('Parses Axis Bank, Kotak, and IndusInd alert emails cleanly', () {
      final axis = BankEmailParser.parse(
        subject: 'Transaction alert on Axis Bank Credit Card',
        bodyText:
            'INR 550.00 spent on Axis Bank Card ending 1234 at Chaayos on 02-11-2026 14:10. Avail Bal: INR 45,000',
        messageId: 'axis-1',
      );
      expect(axis, isNotNull);
      expect(axis!.amountPaise, 55000);
      expect(axis.merchant, 'Chaayos');

      final kotak = BankEmailParser.parse(
        subject: 'Kotak Bank Transaction Alert',
        bodyText:
            'Rs. 199.00 debited from Kotak A/C towards payment to Netflix on 02-Nov-2026. Avail Bal: Rs 22,000.',
        messageId: 'kotak-1',
      );
      expect(kotak, isNotNull);
      expect(kotak!.amountPaise, 19900);
      expect(kotak.merchant, 'Netflix');

      final indusind = BankEmailParser.parse(
        subject: 'IndusInd Bank Alert',
        bodyText:
            'Your A/c ending 5678 is debited for INR 420.00 at BookMyShow on 02-Nov-2026. Info: UPI/BMS.',
        messageId: 'indusind-1',
      );
      expect(indusind, isNotNull);
      expect(indusind!.amountPaise, 42000);
      expect(indusind.merchant, 'BookMyShow');

      final canara = BankEmailParser.parse(
        subject: 'Canara Bank Debit Notification',
        bodyText:
            'Your A/C XXXXX1234 debited by INR 150.00 on 02-11-2026 for UPI/654321/SWIGGY. Avail Bal INR 5,230.00.',
        messageId: 'canara-1',
      );
      expect(canara, isNotNull);
      expect(canara!.amountPaise, 15000);
      expect(canara.merchant, 'SWIGGY');

      final pnb = BankEmailParser.parse(
        subject: 'PNB Transaction Alert',
        bodyText:
            'Dear Customer, Your A/C 9876 is debited for Rs 420.00 on 02-11-2026 by UPI to OLA CABS. Bal Rs 3,400.00.',
        messageId: 'pnb-1',
      );
      expect(pnb, isNotNull);
      expect(pnb!.amountPaise, 42000);
      expect(pnb.merchant, 'OLA CABS');

      final jupiter = BankEmailParser.parse(
        subject: 'Transaction Alert',
        bodyText:
            'You spent Rs. 210.00 at Starbucks using your Federal Bank Debit Card ending 4321 on 02-11-2026.',
        messageId: 'jupiter-1',
      );
      expect(jupiter, isNotNull);
      expect(jupiter!.amountPaise, 21000);
      expect(jupiter.merchant, 'Starbucks');
    });

    test('Parses bank refund / credit email correctly', () {
      final refund = BankEmailParser.parse(
        subject: 'Refund received from Swiggy',
        bodyText:
            'Dear Customer, INR 350.00 has been credited to your A/c 1234 on 02-Nov-2026 as refund from Swiggy. Avail Bal: INR 12,450.00.',
        messageId: 'refund-1',
      );
      expect(refund, isNotNull);
      expect(refund!.amountPaise, 35000);
      expect(refund.merchant, 'Swiggy');
      expect(refund.isDebit, isFalse);
    });

    test('Parses rich HTML bank transaction email', () {
      const htmlEmail = '''
<!DOCTYPE html>
<html>
  <body>
    <div>
      <p>Dear Customer,</p>
      <p>You have done a transaction on your HDFC Bank Card.</p>
      <table>
        <tr><td>Amount:</td><td>INR 1,250.00</td></tr>
        <tr><td>Merchant:</td><td>BLINKIT</td></tr>
        <tr><td>Date:</td><td>02-11-2026</td></tr>
      </table>
      <p>Avail Limit: INR 85,000.00</p>
    </div>
  </body>
</html>
''';
      final parsed = BankEmailParser.parse(
        subject: 'Transaction alert on your HDFC Bank Card',
        bodyText: htmlEmail,
        messageId: 'html-1',
      );
      expect(parsed, isNotNull);
      expect(parsed!.amountPaise, 125000);
      expect(parsed.merchant, 'BLINKIT');
      expect(parsed.isDebit, isTrue);
    });

    test('Validates BankPresets contains all major banks and valid senders', () {
      final presets = BankPresets.all;
      expect(presets.length, greaterThanOrEqualTo(8));
      final names = presets.map((b) => b.displayName).toList();
      expect(names, containsAll(['Slice', 'HDFC', 'SBI', 'ICICI', 'Axis', 'Kotak', 'Jupiter/Fi', 'IndusInd']));

      final allSenders = BankPresets.allSenders;
      expect(allSenders, isNotEmpty);
      expect(allSenders.any((s) => s.contains('hdfcbank')), isTrue);
      expect(allSenders.any((s) => s.contains('sbi')), isTrue);
      expect(allSenders.any((s) => s.contains('icici')), isTrue);
      expect(allSenders.any((s) => s.contains('slice')), isTrue);
    });

    test('End-to-end repository inbox insertion and approval flow for parsed emails', () async {
      final repo = PocketRepository(PocketDatabase.instance, inMemory: true);

      final emails = [
        BankEmailParser.parse(
          subject: 'Payment to Swiggy was successful',
          bodyText: 'Paid ₹350.00 to Swiggy on 02-Nov-2026. Ref: 12345',
          messageId: 'email-msg-001',
        )!,
        BankEmailParser.parse(
          subject: 'Payment to Starbucks was successful',
          bodyText: 'Paid ₹299.00 to Starbucks on 02-Nov-2026. Ref: 67890',
          messageId: 'email-msg-002',
        )!,
      ];

      final pendingList = emails.map((e) {
        return PendingTransaction(
          id: '',
          amountPaise: e.amountPaise,
          direction: e.isDebit ? Direction.debit : Direction.credit,
          occurredAtMs: e.occurredAt.millisecondsSinceEpoch,
          localDate: e.localDate,
          merchant: e.merchant,
          rawSource: 'slice_email',
          messageId: e.messageId,
          status: InboxStatus.pending,
        );
      }).toList();

      final added = await repo.addPendingTransactions(pendingList);
      expect(added.length, 2);

      // Verify pending inbox
      final ledger1 = await repo.load();
      expect(ledger1.pendingInbox.length, 2);
      expect(ledger1.pendingInbox.any((p) => p.merchant == 'Swiggy'), isTrue);
      expect(ledger1.pendingInbox.any((p) => p.merchant == 'Starbucks'), isTrue);

      // Test duplicate prevention via isEmailMessageProcessed
      final already1 = await repo.isEmailMessageProcessed('email-msg-001');
      expect(already1, isTrue);

      // Approve Starbucks as Food
      final toApprove = ledger1.pendingInbox.firstWhere((p) => p.merchant == 'Starbucks');
      final approvedTxn = await repo.approvePendingTransaction(
        toApprove,
        categoryId: 'food',
        bucket: Bucket.daily,
      );
      expect(approvedTxn.amountPaise, 29900);
      expect(approvedTxn.merchant, 'Starbucks');

      // Verify pending inbox decremented
      final ledger2 = await repo.load();
      expect(ledger2.pendingInbox.length, 1);
      expect(ledger2.pendingInbox.first.merchant, 'Swiggy');

      // Verify approved txn added to transactions
      expect(ledger2.transactions.any((t) => t.merchant == 'Starbucks' && t.amountPaise == 29900), isTrue);

      // Verify merchant memory recorded Starbucks -> food
      final memorized = await repo.getMerchantCategory('Starbucks');
      expect(memorized, 'food');
    });

    test('Slice-only active bank configuration resolves strictly to Slice senders', () {
      const sliceOnlySettings = Settings(
        stipendPaise: 250000,
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
        emailSyncActiveBanks: ['slice'],
      );

      final senders = sliceOnlySettings.resolvedEmailSenders;
      expect(senders.length, 2);
      expect(senders, contains('noreply@slice.bank.in'));
      expect(senders, contains('alerts@sliceit.com'));
      // Must NOT contain other bank senders like HDFC or SBI
      expect(senders.any((s) => s.contains('hdfc')), isFalse);
      expect(senders.any((s) => s.contains('sbi')), isFalse);
    });

    test('Multiple active banks configuration resolves combined senders', () {
      const multiBankSettings = Settings(
        stipendPaise: 250000,
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
        emailSyncActiveBanks: ['slice', 'hdfc'],
      );

      final senders = multiBankSettings.resolvedEmailSenders;
      expect(senders.length, 4);
      expect(senders, contains('noreply@slice.bank.in'));
      expect(senders, contains('alerts@hdfcbank.net'));
      expect(senders.any((s) => s.contains('icici')), isFalse);
    });

    test('buildImapSearchCriteria generates correct standard IMAP query', () {
      // 1 sender
      final singleQuery = BankEmailSyncService.buildImapSearchCriteria(
        ['noreply@slice.bank.in'],
        '01-Nov-2026',
      );
      expect(singleQuery, 'FROM "noreply@slice.bank.in" SINCE 01-Nov-2026');

      // 2 senders (Slice UPI + Slice card alerts)
      final sliceQuery = BankEmailSyncService.buildImapSearchCriteria(
        ['noreply@slice.bank.in', 'alerts@sliceit.com'],
        '01-Nov-2026',
      );
      expect(sliceQuery, 'OR FROM "noreply@slice.bank.in" FROM "alerts@sliceit.com" SINCE 01-Nov-2026');
    });
  });
}
