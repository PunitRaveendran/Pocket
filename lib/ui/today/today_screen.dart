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
import '../sheets/overspend_sheet.dart';
import '../sheets/receipt_sheet.dart';
import '../sheets/spend_sheet.dart';
import '../widgets/allowance_meter.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/hairline.dart';
import '../widgets/primary_button.dart';
import '../widgets/transaction_row.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  String? _filter;
  LocalDate _selectedDate = LocalDate.today();

  bool get _isToday => _selectedDate == LocalDate.today();

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final async = ref.watch(ledgerProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (ledger) {
        final isWeekly = ledger.settings.pacingMode == PacingMode.weekly;
        final hide = ledger.settings.hideAmounts;

        final int remaining;
        final int allowancePaise;
        final double usedRatio;
        final String label;
        final String caption;
        final String? topCategoryName;
        final int topCategoryPaise;
        final PayCycle cycle;
        final List<Txn> dayTxns;
        final WeekBudget? weekBudget;

        if (isWeekly) {
          final weekView = buildCurrentWeek(ledger, date: _selectedDate);
          weekBudget = weekView.budget;
          dayTxns = weekView.txns;
          remaining = weekBudget.remaining;
          allowancePaise = weekBudget.allowancePaise;
          usedRatio = weekBudget.usedRatio;
          topCategoryName = weekView.topCategoryName;
          topCategoryPaise = weekView.topCategoryPaise;
          cycle = weekView.cycle;
          label = remaining < 0
              ? 'over this week'
              : remaining == 0
                  ? 'this week is even'
                  : 'left this week';
          caption = remaining < 0
              ? Copy.overBy(Money.formatPaise(remaining.abs(), hide: hide))
              : Copy.leftOf(
                  Money.formatPaise(remaining, hide: hide),
                  Money.formatPaise(allowancePaise, hide: hide),
                );
        } else {
          final view = buildToday(ledger, date: _selectedDate);
          weekBudget = null;
          dayTxns = view.txns;
          remaining = view.budget.remaining;
          allowancePaise = view.budget.allowancePaise;
          usedRatio = view.budget.usedRatio;
          topCategoryName = view.topCategoryName;
          topCategoryPaise = view.topCategoryPaise;
          cycle = view.cycle;
          label = remaining < 0
              ? Copy.overToday
              : remaining == 0
                  ? Copy.evenToday
                  : Copy.leftToday;
          caption = remaining < 0
              ? Copy.overBy(Money.formatPaise(remaining.abs(), hide: hide))
              : Copy.leftOf(
                  Money.formatPaise(remaining, hide: hide),
                  Money.formatPaise(allowancePaise, hide: hide),
                );
        }

        final figureColor = remaining < 0 ? t.over : t.ink;
        final figure = Money.formatPaise(remaining.abs(), hide: hide);

        // Filter transactions for this day or week
        final filtered = _filter == null
            ? dayTxns
            : dayTxns.where((x) => x.categoryId == _filter).toList();

        // Calculate category totals
        final catSpentMap = <String, int>{};
        var totalSpentToday = 0;
        for (final txn in dayTxns) {
          if (txn.direction == Direction.debit) {
            catSpentMap[txn.categoryId] = (catSpentMap[txn.categoryId] ?? 0) + txn.amountPaise;
            totalSpentToday += txn.amountPaise;
          } else {
            catSpentMap[txn.categoryId] = (catSpentMap[txn.categoryId] ?? 0) - txn.amountPaise;
            totalSpentToday -= txn.amountPaise;
          }
        }

        final dayNumberInCycle = _selectedDate.dateTime.difference(cycle.start.dateTime).inDays + 1;
        final daysRemainingInCycle = cycle.endInclusive.dateTime.difference(_selectedDate.dateTime).inDays + 1;
        final pacePaise = safeDailyPace(ledger, cycle, _selectedDate);
        final isCrunchMode = daysRemainingInCycle >= 3 && daysRemainingInCycle <= 14 && pacePaise > 0 && pacePaise < 4000;
        final piggyPaise = ledger.settings.leftoverPolicy == LeftoverPolicy.outingsPiggyBank
            ? outingsPiggyBank(ledger, cycle, _selectedDate)
            : 0;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Switcher (Daily / Weekly) and Date Navigation Bar
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.chevron_left, color: t.inkSoft, size: 24),
                          tooltip: isWeekly ? 'Previous week' : 'Previous day',
                          onPressed: () {
                            if (isWeekly && weekBudget != null) {
                              setState(() => _selectedDate = weekBudget!.startDate.addDays(-1));
                            } else {
                              setState(() => _selectedDate = _selectedDate.addDays(-1));
                            }
                          },
                        ),
                        const SizedBox(width: Space.x2),
                        Text(
                          isWeekly && weekBudget != null
                              ? (weekBudget.contains(LocalDate.today())
                                  ? 'This Week (${DateFormat('d MMM').format(weekBudget.startDate.dateTime)} – ${DateFormat('d MMM').format(weekBudget.endDate.dateTime)})'
                                  : 'Week ${weekBudget.weekNumber} (${DateFormat('d MMM').format(weekBudget.startDate.dateTime)} – ${DateFormat('d MMM').format(weekBudget.endDate.dateTime)})')
                              : (_isToday
                                  ? 'Today, ${DateFormat('d MMM').format(_selectedDate.dateTime)}'
                                  : DateFormat('EEE, d MMM').format(_selectedDate.dateTime)),
                          style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: Space.x2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.chevron_right,
                            color: (isWeekly ? weekBudget?.contains(LocalDate.today()) == true : _isToday) ? t.rule : t.inkSoft,
                            size: 24,
                          ),
                          tooltip: isWeekly ? 'Next week' : 'Next day',
                          onPressed: (isWeekly ? weekBudget?.contains(LocalDate.today()) == true : _isToday)
                              ? null
                              : () {
                                  if (isWeekly && weekBudget != null) {
                                    setState(() => _selectedDate = weekBudget!.endDate.addDays(1));
                                  } else {
                                    setState(() => _selectedDate = _selectedDate.addDays(1));
                                  }
                                },
                        ),
                        const Spacer(),
                        // Daily / Weekly toggle
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                            border: Border.all(color: t.rule),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => ref
                                    .read(ledgerProvider.notifier)
                                    .setPacingMode(PacingMode.daily),
                                borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: !isWeekly ? t.accentTint : Colors.transparent,
                                    borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                  ),
                                  child: Text(
                                    'Daily',
                                    style: TypeScale.caption(!isWeekly ? t.accent : t.inkSoft)
                                        .copyWith(
                                      fontWeight: !isWeekly ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => ref
                                    .read(ledgerProvider.notifier)
                                    .setPacingMode(PacingMode.weekly),
                                borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isWeekly ? t.accentTint : Colors.transparent,
                                    borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                  ),
                                  child: Text(
                                    'Weekly',
                                    style: TypeScale.caption(isWeekly ? t.accent : t.inkSoft)
                                        .copyWith(
                                      fontWeight: isWeekly ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x3),
                    Semantics(
                      label: '${Money.spokenRupees(remaining.abs())} $label',
                      child: Text(figure, style: TypeScale.figure(figureColor)),
                    ),
                    Text(label, style: TypeScale.body(t.inkSoft)),
                    const SizedBox(height: Space.x4),
                    AllowanceMeter(ratio: usedRatio, caption: caption),
                    if (remaining < 0 && topCategoryName != null) ...[
                      const SizedBox(height: Space.x2),
                      Text(
                        Copy.categoryTook(
                          topCategoryName,
                          Money.formatPaise(topCategoryPaise, hide: hide),
                        ),
                        style: TypeScale.caption(t.inkSoft),
                      ),
                    ],
                    // Overspend recovery action banner
                    if (remaining < 0) ...[
                      const SizedBox(height: Space.x4),
                      InkWell(
                        onTap: () => showOverspendSheet(
                          context,
                          overPaise: remaining.abs(),
                          date: _selectedDate,
                          dayTxns: dayTxns,
                        ),
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.over.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 20, color: t.over),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Overspent by ${Money.formatPaise(remaining.abs(), hide: hide)} · Manage',
                                      style: TypeScale.caption(t.over).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'Borrow from tomorrow or reclassify spend to Outings',
                                      style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: t.inkSoft),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.x4),
                    // Student cycle pace micro-banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.rule),
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        color: t.card,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 16, color: t.inkSoft),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isWeekly && weekBudget != null
                                  ? 'Week ${weekBudget.weekNumber} of ${weekBudget.totalWeeks} (${DateFormat('d MMM').format(weekBudget.startDate.dateTime)} – ${DateFormat('d MMM').format(weekBudget.endDate.dateTime)}) · Allowance: ₹${allowancePaise ~/ 100}/wk'
                                  : 'Day $dayNumberInCycle of ${cycle.lengthDays} · Allowance: ₹${allowancePaise ~/ 100}/day',
                              style: TypeScale.caption(t.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isCrunchMode) ...[
                      const SizedBox(height: Space.x3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(color: t.over.withValues(alpha: 0.6)),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.tips_and_updates_outlined, size: 18, color: t.over),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Month-End Crunch Mode: ₹${pacePaise ~/ 100}/day left for $daysRemainingInCycle days',
                                    style: TypeScale.caption(t.over).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Mess food & essential canteen meals only to finish the cycle safely.',
                                    style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (piggyPaise > 0) ...[
                      const SizedBox(height: Space.x3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(color: t.rule),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.savings_outlined, size: 16, color: t.accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Outings Piggy Bank: ₹${piggyPaise ~/ 100} saved from past unspent days',
                                style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (daysRemainingInCycle <= 3) ...[
                      const SizedBox(height: Space.x3),
                      InkWell(
                        onTap: () => showMonthEndReceipt(context, ledger),
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.rule),
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 16, color: t.inkSoft),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cycle wrapping up · Tap for Month-End Paper Receipt',
                                  style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 16, color: t.inkSoft),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.x6),
                    PrimaryButton(
                      label: Copy.addSpend,
                      onPressed: () => showSpendSheet(
                        context,
                        initialCategoryId: _filter,
                        initialDate: _selectedDate,
                      ),
                    ),
                    const SizedBox(height: Space.x6),
                    // Categories horizontal tab bar with spent counters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          LedgerChip(
                            label: totalSpentToday > 0
                                ? 'All · ₹${totalSpentToday ~/ 100}'
                                : Copy.all,
                            selected: _filter == null,
                            onTap: () => setState(() => _filter = null),
                          ),
                          const SizedBox(width: Space.x2),
                          for (final c in ledger.categories) ...[
                            Builder(
                              builder: (context) {
                                final spent = catSpentMap[c.id] ?? 0;
                                final label = spent > 0
                                    ? '${c.name} · ₹${spent ~/ 100}'
                                    : c.name;
                                return LedgerChip(
                                  label: label,
                                  icon: categoryIcon(c.icon),
                                  selected: _filter == c.id,
                                  onTap: () => setState(() => _filter = c.id),
                                );
                              },
                            ),
                            const SizedBox(width: Space.x2),
                          ],
                          LedgerChip(
                            label: '+ Category',
                            selected: false,
                            onTap: () => _addCategory(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x4),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      _filter == null
                          ? Copy.nothingYet
                          : 'No expenses under ${_getCategoryName(ledger, _filter!)} today.',
                      style: TypeScale.body(t.inkSoft),
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Hairline(indent: Space.margin),
                itemBuilder: (context, i) {
                  final txn = filtered[i];
                  final cat = ledger.categoryById(txn.categoryId);
                  return TransactionRow(
                    txn: txn,
                    categoryName: cat?.name ?? Copy.misc,
                    categoryIconKey: cat?.icon ?? 'misc',
                    hideAmounts: hide,
                    onTap: () => showSpendSheet(
                      context,
                      editing: txn,
                      initialDate: _selectedDate,
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x12)),
          ],
        );
      },
    );
  }

  String _getCategoryName(Ledger ledger, String id) {
    return ledger.categoryById(id)?.name ?? id;
  }

  Future<void> _addCategory(BuildContext context) async {
    final t = TokenScope.of(context);
    final controller = TextEditingController();
    var selectedIcon = 'custom';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(Copy.addCategory, style: TypeScale.heading(t.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  hintText: Copy.categoryName,
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                ),
              ),
              const SizedBox(height: Space.x4),
              Text('Pick an icon', style: TypeScale.caption(t.inkSoft)),
              const SizedBox(height: Space.x2),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in availableCategoryIcons)
                    InkWell(
                      onTap: () => setDialogState(() => selectedIcon = item.$1),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedIcon == item.$1 ? t.accentTint : t.card,
                          border: Border.all(
                            color: selectedIcon == item.$1 ? t.accent : t.rule,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          item.$2,
                          size: 18,
                          color: selectedIcon == item.$1 ? t.accent : t.inkSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Copy.save, style: TypeScale.body(t.accent)),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      await ref.read(ledgerProvider.notifier).addCategory(
            controller.text.trim(),
            icon: selectedIcon,
          );
    }
  }
}
