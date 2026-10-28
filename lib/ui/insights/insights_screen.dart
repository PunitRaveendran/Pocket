import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../domain/budget.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/category_icon.dart';
import '../widgets/hairline.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TokenScope.of(context);
    final async = ref.watch(ledgerProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (ledger) {
        final today = LocalDate.today();
        final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
        final hide = ledger.settings.hideAmounts;
        final ordinary = ordinaryThisCycle(ledger, cycle);
        final extra = extraThisCycle(ledger, cycle);
        final stipend = ledger.settings.stipendPaise;
        final engine = const BudgetEngine();

        final daysElapsed = today.dateTime.difference(cycle.start.dateTime).inDays + 1;
        final daysRemaining = cycle.endInclusive.dateTime.difference(today.dateTime).inDays + 1;
        final remainingStipend = stipend - ordinary;
        final safeDailyPaise = (daysRemaining > 0 && remainingStipend > 0)
            ? remainingStipend ~/ daysRemaining
            : 0;

        // Last 7 days data
        final days = <_DayBar>[];
        for (var i = 6; i >= 0; i--) {
          final d = today.addDays(-i);
          final spent = ledger.transactions
              .where((x) => x.bucket == Bucket.daily && x.localDate == d && x.direction == Direction.debit)
              .fold<int>(0, (a, x) => a + x.amountPaise);
          final refunds = ledger.transactions
              .where((x) => x.bucket == Bucket.daily && x.localDate == d && x.direction == Direction.credit)
              .fold<int>(0, (a, x) => a + x.amountPaise);
          final allow = engine.allowanceFor(
            stipendPaise: stipend,
            cycle: cycle,
            day: d,
          );
          days.add(_DayBar(date: d, spent: (spent - refunds).clamp(0, 999999999), allowance: allow));
        }

        // Category breakdown
        final byCat = <String, int>{};
        var totalCatSpent = 0;
        for (final x in ledger.transactions) {
          if (x.bucket != Bucket.daily || !cycle.contains(x.localDate)) continue;
          if (x.direction == Direction.debit) {
            byCat[x.categoryId] = (byCat[x.categoryId] ?? 0) + x.amountPaise;
            totalCatSpent += x.amountPaise;
          } else {
            byCat[x.categoryId] = (byCat[x.categoryId] ?? 0) - x.amountPaise;
            totalCatSpent -= x.amountPaise;
          }
        }
        final catRows = byCat.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final maxBar = days.fold<int>(
          0,
          (m, d) => [m, d.spent, d.allowance].reduce((a, b) => a > b ? a : b),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, Space.x12),
          children: [
            Text('This cycle', style: TypeScale.title(t.ink)),
            const SizedBox(height: Space.x2),
            Text(
              'Day $daysElapsed of ${cycle.lengthDays} · $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x4),

            // Pacing Advice Card
            Container(
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.rule),
                borderRadius: BorderRadius.circular(Space.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed_outlined, size: 18, color: t.accent),
                      const SizedBox(width: 8),
                      Text('Safe Daily Pace', style: TypeScale.heading(t.ink)),
                    ],
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    remainingStipend > 0
                        ? 'You have ${Money.formatPaise(remainingStipend, hide: hide)} left in your monthly pool. You can safely spend up to ${Money.formatPaise(safeDailyPaise, hide: hide)}/day for the remaining $daysRemaining days.'
                        : 'You have reached your ordinary monthly allowance for this cycle.',
                    style: TypeScale.body(t.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x6),

            _Stat(label: 'Monthly stipend', value: Money.formatPaise(stipend, hide: hide)),
            _Stat(label: 'Spent on ordinary days', value: Money.formatPaise(ordinary, hide: hide)),
            _Stat(label: 'Spent on outings & trips', value: Money.formatPaise(extra, hide: hide)),
            const Hairline(),
            _Stat(
              label: 'Total left the pocket',
              value: Money.formatPaise(ordinary + extra, hide: hide),
            ),
            const SizedBox(height: Space.x3),
            Text(
              Copy.ordinaryVsExtra(
                Money.formatPaise(ordinary, hide: hide),
                Money.formatPaise(extra, hide: hide),
                Money.formatPaise(stipend, hide: hide),
              ),
              style: TypeScale.caption(t.inkSoft),
            ),

            const SizedBox(height: Space.x8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Last seven days', style: TypeScale.heading(t.ink)),
                Text(
                  'Allowance: ₹${stipend ~/ (cycle.lengthDays * 100)}/d',
                  style: TypeScale.caption(t.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Container(
              padding: const EdgeInsets.fromLTRB(Space.x3, Space.x4, Space.x3, Space.x3),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.rule),
                borderRadius: BorderRadius.circular(Space.cardRadius),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in days)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _Bar(
                                spent: d.spent,
                                allowance: d.allowance,
                                max: maxBar == 0 ? 1 : maxBar,
                                label: DateFormat('E').format(d.date.dateTime).substring(0, 1),
                                dateStr: DateFormat('d/M').format(d.date.dateTime),
                                hide: hide,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      Text('Under allowance', style: TypeScale.caption(t.inkSoft)),
                      const SizedBox(width: 16),
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: t.over, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 4),
                      Text('Over allowance', style: TypeScale.caption(t.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: Space.x8),
            Text('By category', style: TypeScale.heading(t.ink)),
            const SizedBox(height: Space.x3),
            if (catRows.isEmpty)
              Text('No ordinary spends recorded this cycle.', style: TypeScale.body(t.inkSoft))
            else
              Container(
                decoration: BoxDecoration(
                  color: t.card,
                  border: Border.all(color: t.rule),
                  borderRadius: BorderRadius.circular(Space.cardRadius),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < catRows.length; i++) ...[
                      if (i > 0) const Hairline(),
                      Builder(
                        builder: (context) {
                          final row = catRows[i];
                          final cat = ledger.categoryById(row.key);
                          final catName = cat?.name ?? row.key;
                          final iconKey = cat?.icon ?? 'custom';
                          final share = totalCatSpent > 0 ? (row.value / totalCatSpent) : 0.0;
                          final pct = (share * 100).round();

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(categoryIcon(iconKey), size: 16, color: t.inkSoft),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(catName, style: TypeScale.body(t.ink)),
                                    ),
                                    Text('$pct%', style: TypeScale.caption(t.inkSoft)),
                                    const SizedBox(width: 8),
                                    Text(
                                      Money.formatPaise(row.value, hide: hide),
                                      style: TypeScale.money(t.ink, size: 15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: share,
                                    minHeight: 4,
                                    backgroundColor: t.rule,
                                    valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayBar {
  _DayBar({required this.date, required this.spent, required this.allowance});
  final LocalDate date;
  final int spent;
  final int allowance;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TypeScale.body(t.inkSoft))),
          Text(value, style: TypeScale.money(t.ink, size: 16, height: 24 / 16)),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.spent,
    required this.allowance,
    required this.max,
    required this.label,
    required this.dateStr,
    required this.hide,
  });

  final int spent;
  final int allowance;
  final int max;
  final String label;
  final String dateStr;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    const h = 96.0;
    final spentH = max > 0 ? (spent / max) * h : 0.0;
    final over = spent > allowance;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (spent > 0)
          Text(
            hide ? '···' : '₹${spent ~/ 100}',
            style: TypeScale.caption(over ? t.over : t.inkSoft).copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          const SizedBox(height: 14),
        const SizedBox(height: 2),
        Container(
          height: spentH.clamp(spent > 0 ? 3.0 : 1.0, h),
          decoration: BoxDecoration(
            color: spent == 0
                ? t.rule
                : over
                    ? t.over
                    : t.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.w600)),
        Text(dateStr, style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 9)),
      ],
    );
  }
}
