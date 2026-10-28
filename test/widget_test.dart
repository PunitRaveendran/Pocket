import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/core/money.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/state/ledger.dart';
import 'package:pocket/theme/app_theme.dart';
import 'package:pocket/theme/tokens.dart';
import 'package:pocket/ui/insights/insights_screen.dart';
import 'package:pocket/ui/outings/outings_screen.dart';
import 'package:pocket/ui/today/today_screen.dart';
import 'package:pocket/ui/widgets/allowance_meter.dart';
import 'package:pocket/ui/widgets/amount_pad.dart';

Widget _wrap(Widget child, {Ledger? ledger}) {
  final sampleLedger = ledger ??
      Ledger(
        settings: const Settings(
          stipendPaise: 250000,
          cycleStartDay: 1,
          hideAmounts: false,
          onboarded: true,
        ),
        categories: const [
          Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
          Category(id: 'snacks', name: 'Snacks', icon: 'snacks', isSystem: true, sortOrder: 1),
          Category(id: 'study', name: 'Study', icon: 'study', isSystem: true, sortOrder: 2),
          Category(id: 'misc', name: 'Misc', icon: 'misc', isSystem: true, sortOrder: 3),
        ],
        transactions: [
          Txn(
            id: 't1',
            amountPaise: 4000,
            direction: Direction.debit,
            occurredAtMs: DateTime.now().millisecondsSinceEpoch,
            localDate: LocalDate.today(),
            merchant: 'Canteen Thali',
            categoryId: 'food',
            bucket: Bucket.daily,
            note: 'Lunch',
          ),
          Txn(
            id: 't2',
            amountPaise: 1500,
            direction: Direction.debit,
            occurredAtMs: DateTime.now().millisecondsSinceEpoch,
            localDate: LocalDate.today(),
            merchant: 'Chai & Samosa',
            categoryId: 'snacks',
            bucket: Bucket.daily,
            note: 'Evening snack',
          ),
          Txn(
            id: 't3',
            amountPaise: 45000,
            direction: Direction.debit,
            occurredAtMs: DateTime.now().millisecondsSinceEpoch,
            localDate: LocalDate.today(),
            merchant: 'Trek Bus Fare',
            categoryId: 'misc',
            bucket: Bucket.outing,
            outingId: 'o1',
            note: 'Bus booking',
          ),
        ],
        outings: [
          Outing(
            id: 'o1',
            title: 'Nandi Hills Trek',
            localDate: LocalDate.today(),
            note: 'Weekend with batchmates',
          ),
        ],
      );

  return ProviderScope(
    overrides: [
      ledgerProvider.overrideWith(() => _MockLedgerNotifier(sampleLedger)),
    ],
    child: TokenScope(
      tokens: PaperTokens.light,
      child: MaterialApp(
        theme: PocketTheme.of(Brightness.light),
        home: Scaffold(body: child),
      ),
    ),
  );
}

class _MockLedgerNotifier extends LedgerNotifier {
  _MockLedgerNotifier(this._initial);
  final Ledger _initial;

  @override
  Future<Ledger> build() async => _initial;
}

void main() {
  test('spoken rupees', () {
    expect(Money.spokenRupees(161200), 'rupees one thousand six hundred twelve');
  });

  testWidgets('AllowanceMeter renders with under/over ratios without error', (tester) async {
    await tester.pumpWidget(
      TokenScope(
        tokens: PaperTokens.light,
        child: const MaterialApp(
          home: Scaffold(
            body: AllowanceMeter(ratio: 0.5, caption: '₹40 of ₹80 left'),
          ),
        ),
      ),
    );
    expect(find.text('₹40 of ₹80 left'), findsOneWidget);
  });

  testWidgets('AmountPad quick add buttons work correctly', (tester) async {
    var current = const AmountValue(rupeeDigits: '20', paise: 0);

    await tester.pumpWidget(
      TokenScope(
        tokens: PaperTokens.light,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AmountPad(
                  value: current,
                  onChanged: (val) => setState(() => current = val),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap +₹50
    await tester.tap(find.text('+₹50'));
    await tester.pump();
    expect(current.rupeeDigits, '70');

    // Tap +₹10
    await tester.tap(find.text('+₹10'));
    await tester.pump();
    expect(current.rupeeDigits, '80');
  });

  testWidgets('TodayScreen renders allowance, category tabs, and transaction rows', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const TodayScreen()));
    await tester.pumpAndSettle();

    // Verify presence of category tabs
    expect(find.text('All · ₹55'), findsOneWidget);
    expect(find.text('Food · ₹40'), findsOneWidget);
    expect(find.text('Snacks · ₹15'), findsOneWidget);
    expect(find.text('Study'), findsOneWidget);
    expect(find.text('Misc'), findsOneWidget);

    // Verify transactions are listed
    expect(find.text('Canteen Thali'), findsOneWidget);
    expect(find.text('Chai & Samosa'), findsOneWidget);
    // Outing transaction should NOT be on Today screen
    expect(find.text('Trek Bus Fare'), findsNothing);
  });

  testWidgets('OutingsScreen renders outings card with extra total and items', (tester) async {
    await tester.pumpWidget(_wrap(const OutingsScreen()));
    await tester.pumpAndSettle();

    // Verify outing title and extra spend
    expect(find.text('Nandi Hills Trek'), findsOneWidget);
    expect(find.text('Trek Bus Fare'), findsOneWidget);
    expect(find.text('₹450'), findsWidgets);
  });

  testWidgets('InsightsScreen renders pacing card, chart, and category proportions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const InsightsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Safe Daily Pace'), findsOneWidget);
    expect(find.text('Last seven days'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
  });
}
