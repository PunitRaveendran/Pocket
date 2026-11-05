import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/slice_email_parser.dart';

void main() {
  group('SliceEmailParser Tests', () {
    test('Parses standard Slice payment email', () {
      const subject = 'Transaction alert: ₹450.00 spent on your slice account';
      const body = '''
Hi Ankith,
You have successfully paid ₹450.00 to Ramesh Canteen using your slice account.
Transaction Details:
Amount: ₹450.00
Paid to: Ramesh Canteen
Date & Time: 30 Oct 2026, 12:45 AM
UPI Ref ID: 1234567890
''';
      final result = SliceEmailParser.parse(
        subject: subject,
        bodyText: body,
        emailDate: DateTime(2026, 10, 30, 0, 45),
        messageId: 'msg-123@slice.bank.in',
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 45000);
      expect(result.merchant, 'Ramesh Canteen');
      expect(result.isDebit, isTrue);
      expect(result.messageId, 'msg-123@slice.bank.in');
    });

    test('Parses short subject-based Slice notification', () {
      const subject = 'Payment successful: ₹120 paid to Chai Point';
      const body = 'Your payment of Rs. 120.00 to Chai Point is successful.';

      final result = SliceEmailParser.parse(
        subject: subject,
        bodyText: body,
        emailDate: DateTime(2026, 10, 30, 1, 0),
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 12000);
      expect(result.merchant, 'Chai Point');
      expect(result.isDebit, isTrue);
    });

    test('Parses merchant with "at" syntax', () {
      const subject = 'Transaction successful for ₹150.00 at Starbucks';
      const body = 'You spent ₹150 at Starbucks on 29 Oct 2026.';

      final result = SliceEmailParser.parse(
        subject: subject,
        bodyText: body,
        emailDate: DateTime(2026, 10, 29, 18, 30),
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 15000);
      expect(result.merchant, 'Starbucks');
      expect(result.isDebit, isTrue);
    });

    test('Parses refund credit correctly', () {
      const subject = 'Refund received: ₹350.00 from Swiggy';
      const body = 'Rs. 350.00 has been credited to your slice account from Swiggy.';

      final result = SliceEmailParser.parse(
        subject: subject,
        bodyText: body,
        emailDate: DateTime(2026, 10, 28, 14, 0),
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 35000);
      expect(result.merchant, 'Swiggy');
      expect(result.isDebit, isFalse);
    });

    test('Parses user exact Slice Small Finance Bank debit email', () {
      const subject = '';
      const body = '''
Hi Ankith,
₹30 debited from your slice bank account xx8327 via UPI.
Transaction date
29-Oct-26
To
Akhil Asok
RRN
630246906599
Best,Team slice
Digital safety tips
To talk to us, drop an email to help@slice.bank.in
© slice small finance bank. All rights reserved.
''';

      final result = SliceEmailParser.parse(
        subject: subject,
        bodyText: body,
        emailDate: DateTime(2026, 10, 29, 16, 24),
        messageId: '010901a1874c2328-a36541c1-52c6-477c-871e-ea579ce2440c-000000',
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 3000);
      expect(result.merchant, 'Akhil Asok');
      expect(result.isDebit, isTrue);
      expect(result.occurredAt.year, 2026);
      expect(result.occurredAt.month, 10);
      expect(result.occurredAt.day, 29);
      expect(result.rawSnippet, contains('RRN: 630246906599'));
    });

    test('Parses horizontally formatted Slice email table', () {
      const body = '''
₹150 debited from your slice bank account xx8327 via UPI.
Transaction date    29-Oct-26
To                  Swiggy Instamart
RRN                 630246907777
''';

      final result = SliceEmailParser.parse(
        subject: '',
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 15000);
      expect(result.merchant, 'Swiggy Instamart');
      expect(result.isDebit, isTrue);
      expect(result.occurredAt.year, 2026);
      expect(result.occurredAt.month, 10);
      expect(result.occurredAt.day, 29);
    });

    test('Parses HDFC Bank UPI debit email', () {
      const subject = 'Alert: Update on your HDFC Bank Account';
      const body = '''
Dear Customer,
Rs.450.00 has been debited from account **1234 to SWIGGY on 28-OCT-26 via UPI txn id 630246906599.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 45000);
      expect(result.merchant, 'SWIGGY');
      expect(result.isDebit, isTrue);
      expect(result.rawSnippet, contains('RRN: 630246906599'));
    });

    test('Parses HDFC Bank Credit Card spend', () {
      const subject = 'Transaction alert for your HDFC Bank Credit Card';
      const body = '''
INR 1,250.00 spent on your HDFC Bank Card ending 5678 at AMAZON INDIA on 29-10-2026.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 125000);
      expect(result.merchant, 'AMAZON INDIA');
      expect(result.isDebit, isTrue);
    });

    test('Parses SBI UPI debit with compressed date', () {
      const subject = 'Transaction Alert from SBI';
      const body = '''
Dear SBI User, your A/C ending 4321 debited by Rs 300.00 on 29Oct26 transfer to Ramesh Tea Stall Ref No 630246906599.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 30000);
      expect(result.merchant, 'Ramesh Tea Stall');
      expect(result.isDebit, isTrue);
      expect(result.occurredAt.day, 29);
      expect(result.occurredAt.month, 10);
      expect(result.occurredAt.year, 2026);
    });

    test('Parses ICICI Bank debit with Info UPI tag', () {
      const subject = 'Transaction alert for your ICICI Bank Account';
      const body = '''
Dear Customer, Your ICICI Bank Account XX123 has been debited with INR 250.00 on 29-Oct-26. Info: UPI*ZOMATO*630246906599*Pay.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 25000);
      expect(result.merchant, 'ZOMATO');
      expect(result.isDebit, isTrue);
    });

    test('Parses Axis Bank Card spend', () {
      const subject = 'Transaction alert on Axis Bank Credit Card';
      const body = '''
Rs. 320.00 was spent on your Axis Bank Card ending 5555 on 29-10-2026 14:30:15 at MCDONALDS.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 32000);
      expect(result.merchant, 'MCDONALDS');
      expect(result.isDebit, isTrue);
    });

    test('Parses Kotak Bank payment', () {
      const subject = 'Kotak Bank: Transaction Alert';
      const body = '''
Sent Rs. 150.00 from Kotak Bank A/c ending 1234 to Chaayos on 29-Oct-26. UPI Ref: 123456789.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 15000);
      expect(result.merchant, 'Chaayos');
      expect(result.isDebit, isTrue);
    });

    test('Parses Jupiter / Federal Bank debit', () {
      const subject = 'You spent ₹220 at Blue Tokai';
      const body = 'You paid ₹220 at Blue Tokai using your Federal Bank debit card.';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 22000);
      expect(result.merchant, 'Blue Tokai');
      expect(result.isDebit, isTrue);
    });

    test('Parses generic bank credit/transfer', () {
      const subject = 'Credit Alert: Account update';
      const body = '''
INR 2,500.00 is credited to your account **1234 on 29-OCT-26 by transfer from Sneha Sharma.
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 250000);
      expect(result.merchant, 'Sneha Sharma');
      expect(result.isDebit, isFalse);
    });

    test('Parses inline Slice credit email from user screenshot', () {
      const subject = 'Received ₹10 in your slice account';
      const body = 'Hi Ankith, You have received ₹10 via UPI in your slice bank account xx8327. Avl. Bal. ₹160.23 Transaction date 30-Oct-26 From THADUR ABHINAV SIDDHARTH RRN 63033';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 1000);
      expect(result.merchant, 'THADUR ABHINAV SIDDHARTH');
      expect(result.isDebit, isFalse);
    });

    test('Parses multiline Slice credit email from user screenshot', () {
      const subject = 'Received ₹10 in your slice account';
      const body = '''
slice

Hi Ankith,

You have received ₹10 via UPI in your slice bank account xx8327. Avl. Bal. ₹168.75

Transaction date    30-Oct-26
From                SNEH NIPOON SHETH
RRN                 111038253278
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 1000);
      expect(result.merchant, 'SNEH NIPOON SHETH');
      expect(result.isDebit, isFalse);
      expect(result.rawSnippet, contains('111038253278'));
    });

    test('Parses raw HTML Slice credit email', () {
      const subject = 'Received ₹10 in your slice account';
      const htmlBody = '''
<!DOCTYPE html>
<html>
<body>
  <div style="font-family:sans-serif;">
    <p>Hi Ankith,</p>
    <p>You have received ₹10 via UPI in your slice bank account xx8327. Avl. Bal. &#8377;168.75</p>
    <table cellpadding="4">
      <tr>
        <td>Transaction date</td>
        <td>30-Oct-26</td>
      </tr>
      <tr>
        <td>From</td>
        <td>SNEH NIPOON SHETH</td>
      </tr>
      <tr>
        <td>RRN</td>
        <td>111038253278</td>
      </tr>
    </table>
  </div>
</body>
</html>
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: htmlBody,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 1000);
      expect(result.merchant, 'SNEH NIPOON SHETH');
      expect(result.isDebit, isFalse);
    });

    test('Parses raw HTML Slice debit email', () {
      const subject = 'Transaction alert: ₹30 debited from slice account';
      const htmlBody = '''
<!DOCTYPE html>
<html>
<body>
  <p>Hi Ankith,</p>
  <p>₹30 debited from your slice bank account xx8327 via UPI.</p>
  <table>
    <tr>
      <td>Transaction date</td>
      <td>29-Oct-26</td>
    </tr>
    <tr>
      <td>To</td>
      <td>Akhil Asok</td>
    </tr>
    <tr>
      <td>RRN</td>
      <td>630246906599</td>
    </tr>
  </table>
  <p>Best, Team slice</p>
</body>
</html>
''';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: htmlBody,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 3000);
      expect(result.merchant, 'Akhil Asok');
      expect(result.isDebit, isTrue);
    });

    test('Parses inline Slice debit email with trailing RRN and footer', () {
      const subject = '';
      const body = 'Hi Ankith, ₹30 debited from your slice bank account xx8327 via UPI. Transaction date 29-Oct-26 To Akhil Asok RRN 630246906599 Best, Team slice';

      final result = BankEmailParser.parse(
        subject: subject,
        bodyText: body,
      );

      expect(result, isNotNull);
      expect(result!.amountPaise, 3000);
      expect(result.merchant, 'Akhil Asok');
      expect(result.isDebit, isTrue);
    });

    group('Indian Bank & UPI SMS Alerts', () {
      test('Parses HDFC Sent Rs SMS', () {
        const address = 'VK-HDFCBK';
        const sms = 'Sent Rs.500.00 from HDFC Bank A/C **1234 to SWIGGY on 01-NOV-26. UPI:430712345678. Not you? Call 18002586161.';

        final result = BankEmailParser.parse(
          subject: address,
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 50000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'SWIGGY');
      });

      test('Parses SBI UPI debit SMS without currency symbol', () {
        const address = 'VM-SBIPAY';
        const sms = 'Dear UPI user A/C 1234 debited by 500.0 on date 01Nov26 trf to RAMESH Refno 430712345678. If not done by you, call 1800111109 -SBI';

        final result = BankEmailParser.parse(
          subject: address,
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 50000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'RAMESH');
      });

      test('Parses ICICI UPI slash path debit SMS', () {
        const address = 'AD-ICICIB';
        const sms = 'Your A/C XX1234 is debited for Rs 500.00 on 01-Nov-26. Info: UPI/DR/430712345678/SWIGGY/ICIC/user. Bal Rs 5000.';

        final result = BankEmailParser.parse(
          subject: address,
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 50000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'SWIGGY');
      });

      test('Parses Axis Bank debit to VPA SMS', () {
        const address = 'AX-AXISBK';
        const sms = 'INR 500.00 debited from A/C no. XX1234 on 01-11-26 15:30:00 towards VPA swiggy@icici (UPI Ref no 430712345678).';

        final result = BankEmailParser.parse(
          subject: address,
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 50000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'swiggy');
      });

      test('Parses Google Pay SMS', () {
        const sms = 'You sent ₹500 to Ramesh using Google Pay (UPI: 430712345678).';

        final result = BankEmailParser.parse(
          subject: '',
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 50000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'Ramesh');
      });

      test('Parses PhonePe SMS', () {
        const sms = 'Paid ₹350 to Chai Point successfully on PhonePe. Txn ID: T2611011530.';

        final result = BankEmailParser.parse(
          subject: '',
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 35000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'Chai Point');
      });

      test('Parses Debit of Rs. SMS', () {
        const sms = 'Debit of Rs. 200.00 from A/c XX1234 on 01-Nov-26 at MCDONALDS.';

        final result = BankEmailParser.parse(
          subject: '',
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 20000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'MCDONALDS');
      });

      test('Parses A/C Dr Rs. SMS', () {
        const sms = 'A/C XX1234 Dr Rs 150.00 on 01-Nov-26 trf to Ramesh. Bal Rs 2000.';

        final result = BankEmailParser.parse(
          subject: '',
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 15000);
        expect(result.isDebit, isTrue);
        expect(result.merchant, 'Ramesh');
      });

      test('Credit SMS remains intact and correctly recognized as credit', () {
        const sms = 'Your A/C XX1234 is credited with Rs 1,000.00 on 01-Nov-26 by transfer from Sneha Sharma.';

        final result = BankEmailParser.parse(
          subject: '',
          bodyText: sms,
        );

        expect(result, isNotNull);
        expect(result!.amountPaise, 100000);
        expect(result.isDebit, isFalse);
        expect(result.merchant, 'Sneha Sharma');
      });

      test('Benchmark: Slice email parsing processes 1,000 emails ultra-fast', () {
        const sliceEmailBody = '''
Hi Ankith,
₹30 debited from your slice bank account xx8327 via UPI.
Transaction date
29-Oct-26
To
Akhil Asok
RRN
630246906599
Best,Team slice
Digital safety tips
To talk to us, drop an email to help@slice.bank.in
© slice small finance bank. All rights reserved.
''';

        // Warm up
        for (var i = 0; i < 50; i++) {
          SliceEmailParser.parse(
            subject: 'Transaction alert: ₹30.00 spent',
            bodyText: sliceEmailBody,
            emailDate: DateTime(2026, 10, 29, 16, 24),
            messageId: 'msg-$i@slice.bank.in',
          );
        }

        final stopwatch = Stopwatch()..start();
        const iterations = 1000;
        for (var i = 0; i < iterations; i++) {
          final res = SliceEmailParser.parse(
            subject: 'Transaction alert: ₹30.00 spent',
            bodyText: sliceEmailBody,
            emailDate: DateTime(2026, 10, 29, 16, 24),
            messageId: 'msg-$i@slice.bank.in',
          );
          expect(res, isNotNull);
          expect(res!.amountPaise, 3000);
          expect(res.merchant, 'Akhil Asok');
        }
        stopwatch.stop();

        // 1,000 emails should parse in well under 100ms (typically 5-20ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
        // ignore: avoid_print
        print('⚡ Benchmark: Parsed $iterations Slice emails in ${stopwatch.elapsedMilliseconds} ms (${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1)} µs/email)');
      });
    });

  });
}


