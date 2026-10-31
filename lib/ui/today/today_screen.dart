import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../sheets/spend_sheet.dart';
import '../widgets/allowance_meter.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/hairline.dart';
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
    final async = ref.watch(
      ledgerProvider.select(
        (a) => a.whenData((l) => (l.settings, l.categories, l.transactions)),
      ),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final (settings, categories, transactions) = data;
        final ledger = Ledger(
          settings: settings,
          categories: categories,
          transactions: transactions,
          outings: const [],
        );
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

        final daysRemainingInCycle = cycle.endInclusive.dateTime.difference(_selectedDate.dateTime).inDays + 1;
        final pacePaise = safeDailyPace(ledger, cycle, _selectedDate);
        final isCrunchMode = daysRemainingInCycle >= 3 && daysRemainingInCycle <= 14 && pacePaise > 0 && pacePaise < 4000;
        final piggyPaise = ledger.settings.leftoverPolicy == LeftoverPolicy.outingsPiggyBank
            ? outingsPiggyBank(ledger, cycle, _selectedDate)
            : 0;

        return RefreshIndicator(
          color: t.accent,
          backgroundColor: t.card,
          onRefresh: () async {
            if (ledger.settings.emailSyncEnabled &&
                ledger.settings.emailSyncAddress.trim().isNotEmpty &&
                ledger.settings.emailSyncAppPassword.trim().isNotEmpty) {
              await ref.read(ledgerProvider.notifier).syncSliceEmails(force: true);
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x2, Space.margin, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Switcher (D / W) and Date Navigation Bar
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.chevron_left, color: t.inkSoft, size: 24),
                          tooltip: isWeekly ? 'Previous week' : 'Previous day',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (isWeekly && weekBudget != null) {
                              setState(() => _selectedDate = weekBudget!.startDate.addDays(-1));
                            } else {
                              setState(() => _selectedDate = _selectedDate.addDays(-1));
                            }
                          },
                        ),
                        const SizedBox(width: Space.x1),
                        Expanded(
                          child: Text(
                            isWeekly && weekBudget != null
                                ? (weekBudget.contains(LocalDate.today())
                                    ? 'This Week (${DateFormat('d MMM').format(weekBudget.startDate.dateTime)} – ${DateFormat('d MMM').format(weekBudget.endDate.dateTime)})'
                                    : 'Week ${weekBudget.weekNumber} (${DateFormat('d MMM').format(weekBudget.startDate.dateTime)} – ${DateFormat('d MMM').format(weekBudget.endDate.dateTime)})')
                                : (_isToday
                                    ? 'Today, ${DateFormat('d MMM').format(_selectedDate.dateTime)}'
                                    : DateFormat('EEE, d MMM').format(_selectedDate.dateTime)),
                            style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Space.x1),
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
                                  HapticFeedback.selectionClick();
                                  if (isWeekly && weekBudget != null) {
                                    setState(() => _selectedDate = weekBudget!.endDate.addDays(1));
                                  } else {
                                    setState(() => _selectedDate = _selectedDate.addDays(1));
                                  }
                                },
                        ),
                        const SizedBox(width: Space.x2),
                        // D / W compact toggle
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
                              Tooltip(
                                message: 'Daily',
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(ledgerProvider.notifier)
                                        .setPacingMode(PacingMode.daily);
                                  },
                                  borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: !isWeekly ? t.accentTint : Colors.transparent,
                                      borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                    ),
                                    child: Text(
                                      'D',
                                      style: TypeScale.caption(!isWeekly ? t.accent : t.inkSoft)
                                          .copyWith(
                                        fontWeight: !isWeekly ? FontWeight.w800 : FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: 'Weekly',
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(ledgerProvider.notifier)
                                        .setPacingMode(PacingMode.weekly);
                                  },
                                  borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isWeekly ? t.accentTint : Colors.transparent,
                                      borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                                    ),
                                    child: Text(
                                      'W',
                                      style: TypeScale.caption(isWeekly ? t.accent : t.inkSoft)
                                          .copyWith(
                                        fontWeight: isWeekly ? FontWeight.w800 : FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x2),
                    // Balance & Compact Side Add Spend Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                label: '${Money.spokenRupees(remaining.abs())} $label',
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(figure, style: TypeScale.figure(figureColor)),
                                ),
                              ),
                              Text(
                                label,
                                style: TypeScale.body(t.inkSoft),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.x3),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.accent,
                            foregroundColor: t.paper,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            minimumSize: const Size(0, 38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Space.controlRadius),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              Copy.addSpend,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            showSpendSheet(
                              context,
                              initialCategoryId: _filter,
                              initialDate: _selectedDate,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.x3),
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
                                      'Reclassify spend to Outings to protect daily allowance',
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
                    if (isCrunchMode) ...[
                      const SizedBox(height: Space.x2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      const SizedBox(height: Space.x2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                    const SizedBox(height: Space.x4),
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
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _filter = null);
                            },
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
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _filter = c.id);
                                  },
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
                    const SizedBox(height: Space.x3),
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
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final txn = filtered[i];
                    final cat = ledger.categoryById(txn.categoryId);
                    final catName = cat?.name ?? Copy.misc;
                    return Dismissible(
                      key: Key('txn-dismissible-${txn.id}'),
                      direction: DismissDirection.horizontal,
                      dismissThresholds: const {
                        DismissDirection.startToEnd: 0.25,
                        DismissDirection.endToStart: 0.35,
                      },
                      background: Container(
                        color: t.accentTint,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: t.accent, size: 20),
                            const SizedBox(width: Space.x2),
                            Text(
                              'Re-categorize',
                              style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        color: t.overTint,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Delete',
                              style: TypeScale.caption(t.over).copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: Space.x2),
                            Icon(Icons.delete_outline_rounded, color: t.over, size: 20),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          HapticFeedback.lightImpact();
                          _showQuickCategoryPicker(t, txn, catName);
                          return false;
                        } else if (direction == DismissDirection.endToStart) {
                          return true;
                        }
                        return false;
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                          HapticFeedback.mediumImpact();
                          ref.read(ledgerProvider.notifier).deleteTxn(txn.id);

                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(Space.margin),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Space.controlRadius),
                                side: BorderSide(color: t.rule),
                              ),
                              backgroundColor: t.card,
                              elevation: 4,
                              content: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: t.inkSoft),
                                  const SizedBox(width: Space.x2),
                                  Expanded(
                                    child: Text(
                                      'Deleted ${txn.merchant.isNotEmpty ? txn.merchant : catName} (₹${txn.amountPaise ~/ 100})',
                                      style: TypeScale.body(t.ink).copyWith(fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: t.accent,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(ledgerProvider.notifier).restoreTxn(txn);
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: Material(
                        color: t.paper,
                        child: Column(
                          children: [
                            TransactionRow(
                              txn: txn,
                              categoryName: catName,
                              categoryIconKey: cat?.icon ?? 'misc',
                              hideAmounts: hide,
                              onTap: () => showSpendSheet(
                                context,
                                editing: txn,
                                initialDate: _selectedDate,
                              ),
                            ),
                            if (i < filtered.length - 1)
                              const Hairline(indent: Space.margin)
                            else
                              const SizedBox(height: 1),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.x12)),
          ],
        ),
      );
    },
    );
  }

  Future<void> _showQuickCategoryPicker(PaperTokens t, Txn txn, String currentCategoryName) async {
    final ledger = ref.read(ledgerProvider).valueOrNull;
    if (ledger == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Space.cardRadius)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.margin, Space.x3, Space.margin, Space.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.rule,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: Space.x3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Re-categorize',
                            style: TypeScale.title(t.ink).copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${txn.merchant.isNotEmpty ? txn.merchant : currentCategoryName} · ₹${txn.amountPaise ~/ 100}',
                            style: TypeScale.caption(t.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: t.inkSoft),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final cat in ledger.categories)
                      InkWell(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          Navigator.of(sheetContext).pop();
                          if (cat.id == txn.categoryId) return;

                          final updated = txn.copyWith(categoryId: cat.id);
                          await ref.read(ledgerProvider.notifier).updateTxn(updated);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(Space.margin),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Space.controlRadius),
                                  side: BorderSide(color: t.rule),
                                ),
                                backgroundColor: t.card,
                                duration: const Duration(seconds: 3),
                                content: Row(
                                  children: [
                                    Icon(categoryIcon(cat.icon), size: 18, color: t.accent),
                                    const SizedBox(width: Space.x2),
                                    Expanded(
                                      child: Text(
                                        'Moved to ${cat.name}',
                                        style: TypeScale.body(t.ink).copyWith(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                        },
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cat.id == txn.categoryId ? t.accentTint : t.card,
                            border: Border.all(
                              color: cat.id == txn.categoryId ? t.accent : t.rule,
                              width: cat.id == txn.categoryId ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryIcon(cat.icon),
                                size: 16,
                                color: cat.id == txn.categoryId ? t.accent : t.inkSoft,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cat.name,
                                style: TypeScale.caption(
                                  cat.id == txn.categoryId ? t.accent : t.ink,
                                ).copyWith(
                                  fontWeight: cat.id == txn.categoryId ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
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

