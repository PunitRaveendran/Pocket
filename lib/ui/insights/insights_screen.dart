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
import '../widgets/chips.dart';
import '../widgets/hairline.dart';

enum GraphMode { daily, weekly, burnRate, category }

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  GraphMode _selectedGraph = GraphMode.daily;

  @override
  Widget build(BuildContext context) {
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

        // Weekly trend data
        final weeks = cycle.calendarWeeks();
        final weekBars = <_WeekBar>[];
        for (final w in weeks) {
          final wStart = w.start;
          final wEnd = w.end;

          var wAllowance = 0;
          for (var d = wStart; !d.dateTime.isAfter(wEnd.dateTime); d = d.addDays(1)) {
            wAllowance += engine.allowanceFor(
              stipendPaise: stipend,
              cycle: cycle,
              day: d,
            );
          }

          final wSpent = ledger.transactions.where((t) {
            if (t.bucket != Bucket.daily) return false;
            final dt = t.localDate.dateTime;
            return !dt.isBefore(wStart.dateTime) && !dt.isAfter(wEnd.dateTime);
          }).fold<int>(0, (sum, t) => sum + t.signedPaise);

          weekBars.add(_WeekBar(
            weekNumber: w.weekNumber,
            label: 'W${w.weekNumber}',
            dateRange: '${DateFormat('d/M').format(wStart.dateTime)}–${DateFormat('d/M').format(wEnd.dateTime)}',
            spent: wSpent.clamp(0, 999999999),
            allowance: wAllowance,
          ));
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

        // Burn-rate calculations
        final idealPacePaise = cycle.lengthDays > 0
            ? (stipend * daysElapsed) ~/ cycle.lengthDays
            : 0;
        final paceDifference = idealPacePaise - ordinary;
        final isAheadOfPace = paceDifference >= 0;

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

            // Multi-Graph Interactive Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Visual Analytics', style: TypeScale.heading(t.ink)),
                Text('Select View', style: TypeScale.caption(t.inkSoft)),
              ],
            ),
            const SizedBox(height: Space.x3),

            // Segmented Graph Mode Selector Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  LedgerChip(
                    label: '7-Day Bars',
                    selected: _selectedGraph == GraphMode.daily,
                    onTap: () => setState(() => _selectedGraph = GraphMode.daily),
                  ),
                  const SizedBox(width: Space.x2),
                  LedgerChip(
                    label: 'Weekly Trend',
                    selected: _selectedGraph == GraphMode.weekly,
                    onTap: () => setState(() => _selectedGraph = GraphMode.weekly),
                  ),
                  const SizedBox(width: Space.x2),
                  LedgerChip(
                    label: 'Burn-Rate Pace',
                    selected: _selectedGraph == GraphMode.burnRate,
                    onTap: () => setState(() => _selectedGraph = GraphMode.burnRate),
                  ),
                  const SizedBox(width: Space.x2),
                  LedgerChip(
                    label: 'Categories',
                    selected: _selectedGraph == GraphMode.category,
                    onTap: () => setState(() => _selectedGraph = GraphMode.category),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x4),

            // Graph Display Container
            _buildGraphContent(
              t: t,
              mode: _selectedGraph,
              days: days,
              weekBars: weekBars,
              catRows: catRows,
              totalCatSpent: totalCatSpent,
              ledger: ledger,
              hide: hide,
              daysElapsed: daysElapsed,
              totalDays: cycle.lengthDays,
              stipend: stipend,
              ordinary: ordinary,
              idealPace: idealPacePaise,
              paceDifference: paceDifference,
              isAhead: isAheadOfPace,
            ),

            const SizedBox(height: Space.x8),

            // Category summary always available at bottom
            if (_selectedGraph != GraphMode.category) ...[
              Text('By category', style: TypeScale.heading(t.ink)),
              const SizedBox(height: Space.x3),
              if (catRows.isEmpty)
                Text('No ordinary spends recorded this cycle.', style: TypeScale.body(t.inkSoft))
              else
                _buildCategoryList(t, catRows, totalCatSpent, ledger, hide),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGraphContent({
    required PaperTokens t,
    required GraphMode mode,
    required List<_DayBar> days,
    required List<_WeekBar> weekBars,
    required List<MapEntry<String, int>> catRows,
    required int totalCatSpent,
    required Ledger ledger,
    required bool hide,
    required int daysElapsed,
    required int totalDays,
    required int stipend,
    required int ordinary,
    required int idealPace,
    required int paceDifference,
    required bool isAhead,
  }) {
    switch (mode) {
      case GraphMode.daily:
        final maxBar = days.fold<int>(
          0,
          (m, d) => [m, d.spent, d.allowance].reduce((a, b) => a > b ? a : b),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(Space.x3, Space.x4, Space.x3, Space.x3),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.rule),
            borderRadius: BorderRadius.circular(Space.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Daily Spend vs Allowance (Past 7 Days)', style: TypeScale.caption(t.inkSoft)),
              const SizedBox(height: Space.x3),
              SizedBox(
                height: 146,
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Within budget', style: TypeScale.caption(t.inkSoft)),
                  const SizedBox(width: 16),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.over, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Over allowance', style: TypeScale.caption(t.inkSoft)),
                ],
              ),
            ],
          ),
        );

      case GraphMode.weekly:
        final maxWeekBar = weekBars.fold<int>(
          0,
          (m, w) => [m, w.spent, w.allowance].reduce((a, b) => a > b ? a : b),
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(Space.x3, Space.x4, Space.x3, Space.x3),
          decoration: BoxDecoration(
            color: t.card,
            border: Border.all(color: t.rule),
            borderRadius: BorderRadius.circular(Space.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Weekly Spend Comparison Across Month', style: TypeScale.caption(t.inkSoft)),
              const SizedBox(height: Space.x3),
              SizedBox(
                height: 146,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final w in weekBars)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _Bar(
                            spent: w.spent,
                            allowance: w.allowance,
                            max: maxWeekBar == 0 ? 1 : maxWeekBar,
                            label: w.label,
                            dateStr: w.dateRange,
                            hide: hide,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Within week budget', style: TypeScale.caption(t.inkSoft)),
                  const SizedBox(width: 16),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.over, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text('Over week budget', style: TypeScale.caption(t.inkSoft)),
                ],
              ),
            ],
          ),
        );

      case GraphMode.burnRate:
        final spentPct = stipend > 0 ? (ordinary / stipend).clamp(0.0, 1.0) : 0.0;
        final timePct = totalDays > 0 ? (daysElapsed / totalDays).clamp(0.0, 1.0) : 0.0;

        return Container(
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
                  Icon(
                    isAhead ? Icons.trending_up : Icons.trending_down,
                    size: 20,
                    color: isAhead ? t.accent : t.over,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAhead
                        ? 'Ahead of Pace · ${Money.formatPaise(paceDifference.abs(), hide: hide)} Surplus'
                        : 'Behind Pace · ${Money.formatPaise(paceDifference.abs(), hide: hide)} Ahead of Burn',
                    style: TypeScale.heading(isAhead ? t.accent : t.over),
                  ),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(
                isAhead
                    ? 'At day $daysElapsed of $totalDays, you have spent less than the ideal linear benchmark. Great pace!'
                    : 'Spending is running slightly higher than linear pace. Slow down daily spends to end the month even.',
                style: TypeScale.body(t.inkSoft),
              ),
              const SizedBox(height: Space.x6),

              // Burn Progress Visualizer
              Text('Monthly Allowance Consumed', style: TypeScale.caption(t.inkSoft)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Actual: ${(spentPct * 100).round()}% (${Money.formatPaise(ordinary, hide: hide)})',
                    style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Target: ${(timePct * 100).round()}%',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: t.rule,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: spentPct,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: spentPct > timePct ? t.over : t.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Day 1', style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 10)),
                  Text('Day $daysElapsed (Today)', style: TypeScale.caption(t.accent).copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                  Text('Day $totalDays', style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 10)),
                ],
              ),
            ],
          ),
        );

      case GraphMode.category:
        if (catRows.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(color: t.card, border: Border.all(color: t.rule)),
            child: Text('No ordinary spends recorded yet.', style: TypeScale.body(t.inkSoft)),
          );
        }
        return _buildCategoryList(t, catRows, totalCatSpent, ledger, hide);
    }
  }

  Widget _buildCategoryList(
    PaperTokens t,
    List<MapEntry<String, int>> catRows,
    int totalCatSpent,
    Ledger ledger,
    bool hide,
  ) {
    return Container(
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
    );
  }
}

class _DayBar {
  _DayBar({required this.date, required this.spent, required this.allowance});
  final LocalDate date;
  final int spent;
  final int allowance;
}

class _WeekBar {
  _WeekBar({
    required this.weekNumber,
    required this.label,
    required this.dateRange,
    required this.spent,
    required this.allowance,
  });
  final int weekNumber;
  final String label;
  final String dateRange;
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
    const maxBarH = 80.0;
    final spentH = max > 0 ? (spent / max) * maxBarH : 0.0;
    final over = spent > allowance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upper Bar Area: fixed height so all bars sit on the exact same baseline
        SizedBox(
          height: maxBarH + 20, // 20px headroom for amount text
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (spent > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    hide ? '···' : '₹${spent ~/ 100}',
                    style: TypeScale.caption(over ? t.over : t.inkSoft)
                        .copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Container(
                height: spent > 0 ? spentH.clamp(3.0, maxBarH) : 0.0,
                decoration: BoxDecoration(
                  color: over ? t.over : t.accent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ],
          ),
        ),
        // Continuous horizontal baseline across all days
        Container(
          height: 1.5,
          color: t.rule,
        ),
        const SizedBox(height: 6),
        // Day & Date labels pinned at exact same vertical position
        Text(
          label,
          textAlign: TextAlign.center,
          style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          dateStr,
          textAlign: TextAlign.center,
          style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 9),
        ),
      ],
    );
  }
}
