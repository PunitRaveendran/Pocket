import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/slice_email_parser.dart';

void main() {
  test('BankEmailParser cleanly parses SMS with Avail Bal', () {
    final parsed = BankEmailParser.parse(
      subject: 'VM-HDFCBK',
      bodyText: 'Your A/C ending 4567 debited by Rs. 350.00 on 02-Nov-2026 towards payment to Swiggy. Avail Bal: Rs 4,500.00',
      messageId: 'sms-1',
    );
    expect(parsed, isNotNull);
    expect(parsed!.amountPaise, equals(35000));
    expect(parsed.merchant, equals('Swiggy'));
    expect(parsed.isDebit, isTrue);
  });

  test('BankEmailParser cleanly parses SMS with Slice card', () {
    final parsed = BankEmailParser.parse(
      subject: 'VM-SLICE',
      bodyText: 'Spent Rs. 240.00 on your Slice card at Starbucks on 01-Nov-2026. Avail Bal: Rs 4500',
      messageId: 'sms-2',
    );
    expect(parsed, isNotNull);
    expect(parsed!.amountPaise, equals(24000));
    expect(parsed.merchant, equals('Starbucks'));
    expect(parsed.isDebit, isTrue);
  });
}
