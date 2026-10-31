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
import 'package:pocket/ui/shell.dart';
import 'package:pocket/ui/splits/splits_screen.dart';
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
        friendSplits: [
          FriendSplit(
            id: 's1',
            friendName: 'Rahul',
            amountPaise: 12000,
            direction: SplitDirection.youAreOwed,
            occurredAtMs: 1000,
            localDate: LocalDate.today(),
            note: 'Biryani split',
          ),
          FriendSplit(
            id: 's2',
            friendName: 'Sneha',
            amountPaise: 5000,
            direction: SplitDirection.youOwe,
            occurredAtMs: 2000,
            localDate: LocalDate.today(),
            note: 'Lab xerox',
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
  Ledger _initial;

  @override
  Future<Ledger> build() async => _initial;

  @override
  Future<void> deleteTxn(String id) async {
    final current = state.valueOrNull ?? _initial;
    _initial = current.copyWith(
      transactions: current.transactions.where((t) => t.id != id).toList(),
    );
    state = AsyncData(_initial);
  }

  @override
  Future<void> updateTxn(Txn txn) async {
    final current = state.valueOrNull ?? _initial;
    _initial = current.copyWith(
      transactions: current.transactions.map((t) => t.id == txn.id ? txn : t).toList(),
    );
    state = AsyncData(_initial);
  }

  @override
  Future<void> restoreTxn(Txn txn) async {
    final current = state.valueOrNull ?? _initial;
    if (!current.transactions.any((t) => t.id == txn.id)) {
      _initial = current.copyWith(
        transactions: [txn, ...current.transactions],
      );
      state = AsyncData(_initial);
    }
  }
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

  testWidgets('TodayScreen swipe right opens quick re-categorize sheet and re-categorizes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const TodayScreen()));
    await tester.pumpAndSettle();

    // Swipe right on 'Canteen Thali'
    await tester.drag(find.text('Canteen Thali'), const Offset(300, 0));
    await tester.pumpAndSettle();

    // Quick category bottom sheet appears
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('Re-categorize')),
      findsOneWidget,
    );
    expect(find.text('Canteen Thali · ₹40'), findsOneWidget);

    // Tap 'Snacks' category in sheet
    final snacksOption = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Snacks'),
    );
    expect(snacksOption, findsOneWidget);
    await tester.tap(snacksOption);
    await tester.pumpAndSettle();

    // Feedback toast is shown
    expect(find.text('Moved to Snacks'), findsOneWidget);
  });

  testWidgets('TodayScreen swipe left deletes transaction with UNDO option', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const TodayScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Canteen Thali'), findsOneWidget);

    // Swipe left to dismiss and delete
    await tester.drag(find.text('Canteen Thali'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Canteen Thali is deleted from view
    expect(find.text('Canteen Thali'), findsNothing);
    expect(find.text('UNDO'), findsOneWidget);

    // Tap UNDO
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    // Transaction is restored
    expect(find.text('Canteen Thali'), findsOneWidget);
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
    expect(find.text('Visual Analytics'), findsOneWidget);
    expect(find.text('7-Day Bars'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
  });

  testWidgets('SplitsScreen renders friend balances, tabs, and settle actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const SplitsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Overall: You get back'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Sneha'), findsOneWidget);
    expect(find.text('Settle Up'), findsWidgets);
  });

  testWidgets('AppShell renders pending Slice transactions badge in AppBar and opens review sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final sample = Ledger(
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
      transactions: const [],
      outings: const [],
      pendingInbox: [
        PendingTransaction(
          id: 'p-1',
          amountPaise: 24000,
          direction: Direction.debit,
          occurredAtMs: DateTime.now().millisecondsSinceEpoch,
          localDate: LocalDate.today(),
          merchant: 'Ramesh Canteen',
          rawSource: 'slice_email',
          messageId: 'slice-msg-1',
        ),
      ],
    );

    await tester.pumpWidget(_wrap(const AppShell(), ledger: sample));
    await tester.pumpAndSettle();

    // Verify presence of Slice inbox pill in AppBar
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('1 new'), findsOneWidget);

    // Tap the inbox pill to open the review sheet
    await tester.tap(find.byIcon(Icons.inbox_outlined));
    await tester.pumpAndSettle();

    // Verify sheet content
    expect(find.text('Slice Transactions'), findsOneWidget);
    expect(find.text('What was this for?'), findsOneWidget);
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Split with friends'), findsOneWidget);
  });

  testWidgets('AppShell renders all 4 tabs including restored Splits tab and navigates correctly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const AppShell()));
    await tester.pumpAndSettle();

    // Verify all 4 bottom navigation tabs are present
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Splits'), findsWidgets);
    expect(find.text('Outings'), findsWidgets);
    expect(find.text('Insights'), findsWidgets);

    // Tap on Splits tab
    await tester.tap(find.text('Splits'));
    await tester.pumpAndSettle();

    // Verify Splits screen content is now shown
    expect(find.text('Overall: You get back'), findsOneWidget);
    expect(find.text('Add Split'), findsOneWidget);
  });
}

