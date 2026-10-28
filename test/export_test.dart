import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/core/export.dart';
import 'package:pocket/data/models.dart';

void main() {
  test('CSV export generates correct headers and escapes commas', () {
    final ledger = Ledger(
      settings: const Settings(
        stipendPaise: 250000,
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
      ),
      categories: const [
        Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        Category(id: 'snacks', name: 'Snacks', icon: 'snacks', isSystem: true, sortOrder: 1),
      ],
      transactions: [
        Txn(
          id: '1',
          amountPaise: 4500,
          direction: Direction.debit,
          occurredAtMs: DateTime(2026, 10, 28, 13, 30).millisecondsSinceEpoch,
          localDate: const LocalDate(2026, 10, 28),
          merchant: 'Canteen, North Block',
          categoryId: 'food',
          bucket: Bucket.daily,
          note: 'Thali lunch',
        ),
        Txn(
          id: '2',
          amountPaise: 2000,
          direction: Direction.credit,
          occurredAtMs: DateTime(2026, 10, 28, 14, 0).millisecondsSinceEpoch,
          localDate: const LocalDate(2026, 10, 28),
          merchant: 'Rahul',
          categoryId: 'food',
          bucket: Bucket.daily,
          note: 'Split share',
        ),
      ],
      outings: const [],
    );

    final csv = LedgerExport.toCsv(ledger);
    expect(csv.contains('Date,Time,Bucket,Category,Type,Title/Merchant,Note,Amount (Rupees),Outing'), isTrue);
    expect(csv.contains('2026-10-28'), isTrue);
    expect(csv.contains('"Canteen, North Block"'), isTrue);
    expect(csv.contains('Credit/Refund'), isTrue);
    expect(csv.contains('45.00'), isTrue);
    expect(csv.contains('20.00'), isTrue);
  });
}
