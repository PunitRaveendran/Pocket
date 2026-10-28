import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/core/dates.dart';
import 'package:pocket/core/money.dart';
import 'package:pocket/data/models.dart';
import 'package:pocket/domain/budget.dart';
import 'package:pocket/state/ledger.dart';

void main() {
  test('indian grouping', () {
    expect(Money.groupRupees(1), '1');
    expect(Money.groupRupees(999), '999');
    expect(Money.groupRupees(1000), '1,000');
    expect(Money.groupRupees(125000), '1,25,000');
    expect(Money.groupRupees(1234567), '12,34,567');
  });

  test('paise formatting never uses floats', () {
    expect(Money.formatPaise(250000), '₹2,500');
    expect(Money.formatPaise(161250), '₹1,612.50');
    expect(Money.fromDigitsAndPaise('2500', 0), 250000);
  });

  test('daily allowance splits stipend with leftover on last day', () {
    final day = const LocalDate(2026, 10, 1);
    final cycle = PayCycle.containing(day, 1);
    expect(cycle.lengthDays, 31);
    const engine = BudgetEngine();
    const stipend = 250000;
    final daily = stipend ~/ 31;
    final leftover = stipend % 31;
    expect(
      engine.allowanceFor(stipendPaise: stipend, cycle: cycle, day: const LocalDate(2026, 10, 1)),
      daily,
    );
    expect(
      engine.allowanceFor(stipendPaise: stipend, cycle: cycle, day: const LocalDate(2026, 10, 31)),
      daily + leftover,
    );
  });

  test('overspend is negative remaining', () {
    final day = const LocalDate(2026, 10, 5);
    final cycle = PayCycle.containing(day, 1);
    final budget = const BudgetEngine().day(
      stipendPaise: 310000,
      cycle: cycle,
      date: day,
      spentPaise: 15000,
      refundsPaise: 0,
    );
    expect(budget.allowancePaise, 10000);
    expect(budget.remaining, -5000);
    expect(budget.isOver, isTrue);
  });

  test('refund / split received reduces net spent and restores remaining allowance', () {
    final day = const LocalDate(2026, 10, 10);
    final cycle = PayCycle.containing(day, 1);
    final budget = const BudgetEngine().day(
      stipendPaise: 250000, // ~8064 paise/day
      cycle: cycle,
      date: day,
      spentPaise: 5000, // 50 Rs spent on lunch
      refundsPaise: 2000, // 20 Rs received back via UPI split
    );
    expect(budget.netSpent, 3000);
    expect(budget.remaining, budget.allowancePaise - 3000);
    expect(budget.isOver, isFalse);
  });

  test('ordinary and outing expenses stay in separate buckets', () {
    final cycle = PayCycle.containing(const LocalDate(2026, 10, 15), 1);
    final ledger = Ledger(
      settings: const Settings(
        stipendPaise: 250000,
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
      ),
      categories: const [
        Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
        Category(id: 'misc', name: 'Misc', icon: 'misc', isSystem: true, sortOrder: 1),
      ],
      transactions: [
        // Daily ordinary spend
        Txn(
          id: '1',
          amountPaise: 6000,
          direction: Direction.debit,
          occurredAtMs: 1000,
          localDate: const LocalDate(2026, 10, 15),
          merchant: 'Canteen',
          categoryId: 'food',
          bucket: Bucket.daily,
          note: '',
        ),
        // Outing extra spend
        Txn(
          id: '2',
          amountPaise: 45000,
          direction: Direction.debit,
          occurredAtMs: 2000,
          localDate: const LocalDate(2026, 10, 15),
          merchant: 'Weekend Trek Bus',
          categoryId: 'misc',
          bucket: Bucket.outing,
          outingId: 'outing-1',
          note: '',
        ),
      ],
      outings: const [
        Outing(
          id: 'outing-1',
          title: 'Weekend Trek',
          localDate: LocalDate(2026, 10, 15),
          note: '',
        ),
      ],
    );

    expect(ordinaryThisCycle(ledger, cycle), 6000);
    expect(extraThisCycle(ledger, cycle), 45000);

    final todayView = buildToday(ledger, date: const LocalDate(2026, 10, 15));
    // The daily view should only reflect ordinary transactions (6000), not the outing (45000)
    expect(todayView.budget.spentPaise, 6000);
  });

  test('pay cycle clamps 31st to end-of-month properly across different months', () {
    // Oct has 31 days. Start day 31.
    final cycleOct = PayCycle.containing(const LocalDate(2026, 10, 31), 31);
    expect(cycleOct.start, const LocalDate(2026, 10, 31));
    // Next month is Nov, which has 30 days -> next cycle starts Nov 30 -> Oct cycle ends Nov 29.
    expect(cycleOct.endInclusive, const LocalDate(2026, 11, 29));

    // Mid-month cycle: 15th
    final cycleMid = PayCycle.containing(const LocalDate(2026, 10, 20), 15);
    expect(cycleMid.start, const LocalDate(2026, 10, 15));
    expect(cycleMid.endInclusive, const LocalDate(2026, 11, 14));
  });

  test('weekly budget sums daily slices accurately across cycle', () {
    final ledger = Ledger(
      settings: const Settings(
        stipendPaise: 310000, // 3,100 Rs = 100 Rs/day on 31-day month
        cycleStartDay: 1,
        hideAmounts: false,
        onboarded: true,
        pacingMode: PacingMode.weekly,
      ),
      categories: const [
        Category(id: 'food', name: 'Food', icon: 'food', isSystem: true, sortOrder: 0),
      ],
      transactions: [
        Txn(
          id: '1',
          amountPaise: 15000, // 150 Rs
          direction: Direction.debit,
          occurredAtMs: 1000,
          localDate: const LocalDate(2026, 10, 3),
          merchant: 'Lunch',
          categoryId: 'food',
          bucket: Bucket.daily,
          note: '',
        ),
      ],
      outings: const [],
    );

    final weekView = buildCurrentWeek(ledger, date: const LocalDate(2026, 10, 3));
    // Week 1 of Oct has 7 days (Oct 1 to Oct 7) = 70000 paise allowance (₹700)
    expect(weekView.budget.weekNumber, 1);
    expect(weekView.budget.allowancePaise, 70000);
    expect(weekView.budget.spentPaise, 15000);
    expect(weekView.budget.remaining, 55000);
    expect(weekView.budget.isOver, isFalse);
  });

  test('friend split net balances calculate correctly for owed and owing', () {
    final ledger = Ledger(
      settings: Settings.defaults,
      categories: const [],
      transactions: const [],
      outings: const [],
      friendSplits: [
        // Rahul owes me ₹120 (active)
        const FriendSplit(
          id: '1',
          friendName: 'Rahul',
          amountPaise: 12000,
          direction: SplitDirection.youAreOwed,
          occurredAtMs: 1000,
          localDate: LocalDate(2026, 10, 1),
        ),
        // I owe Sneha ₹50 (active)
        const FriendSplit(
          id: '2',
          friendName: 'Sneha',
          amountPaise: 5000,
          direction: SplitDirection.youOwe,
          occurredAtMs: 2000,
          localDate: LocalDate(2026, 10, 2),
        ),
        // Aman already settled ₹80 (settled, should not affect active balance)
        const FriendSplit(
          id: '3',
          friendName: 'Aman',
          amountPaise: 8000,
          direction: SplitDirection.youAreOwed,
          occurredAtMs: 3000,
          localDate: LocalDate(2026, 10, 2),
          isSettled: true,
        ),
      ],
    );

    expect(ledger.totalOwedToMePaise, 12000); // Only Rahul
    expect(ledger.totalIOwePaise, 5000); // Sneha
    expect(ledger.netFriendBalancePaise, 7000); // Overall get back ₹70
  });
}
