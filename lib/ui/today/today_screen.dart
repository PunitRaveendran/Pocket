import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
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
        final view = buildToday(ledger, date: _selectedDate);
        final hide = ledger.settings.hideAmounts;
        final remaining = view.budget.remaining;
        final figureColor = remaining < 0 ? t.over : t.ink;
        final figure = Money.formatPaise(remaining.abs(), hide: hide);
        final label = remaining < 0
            ? Copy.overToday
            : remaining == 0
                ? Copy.evenToday
                : Copy.leftToday;
        final caption = remaining < 0
            ? Copy.overBy(Money.formatPaise(remaining.abs(), hide: hide))
            : Copy.leftOf(
                Money.formatPaise(remaining, hide: hide),
                Money.formatPaise(view.budget.allowancePaise, hide: hide),
              );

        // Filter transactions for this day
        final dayTxns = view.txns;
        final filtered = _filter == null
            ? dayTxns
            : dayTxns.where((x) => x.categoryId == _filter).toList();

        // Calculate category totals for today
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

        final cycle = view.cycle;
        final dayNumberInCycle = _selectedDate.dateTime.difference(cycle.start.dateTime).inDays + 1;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Navigation Bar
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.chevron_left, color: t.inkSoft, size: 24),
                          tooltip: 'Previous day',
                          onPressed: () {
                            setState(() => _selectedDate = _selectedDate.addDays(-1));
                          },
                        ),
                        const SizedBox(width: Space.x2),
                        Text(
                          _isToday
                              ? 'Today, ${DateFormat('d MMM').format(_selectedDate.dateTime)}'
                              : DateFormat('EEE, d MMM').format(_selectedDate.dateTime),
                          style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: Space.x2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.chevron_right,
                            color: _isToday ? t.rule : t.inkSoft,
                            size: 24,
                          ),
                          tooltip: 'Next day',
                          onPressed: _isToday
                              ? null
                              : () {
                                  setState(() => _selectedDate = _selectedDate.addDays(1));
                                },
                        ),
                        const Spacer(),
                        if (!_isToday)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => setState(() => _selectedDate = LocalDate.today()),
                            child: Text('Jump to Today', style: TypeScale.caption(t.accent)),
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
                    AllowanceMeter(ratio: view.budget.usedRatio, caption: caption),
                    if (view.budget.isOver && view.topCategoryName != null) ...[
                      const SizedBox(height: Space.x2),
                      Text(
                        Copy.categoryTook(
                          view.topCategoryName!,
                          Money.formatPaise(view.topCategoryPaise, hide: hide),
                        ),
                        style: TypeScale.caption(t.inkSoft),
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
                              'Day $dayNumberInCycle of ${cycle.lengthDays} · Allowance: ₹${view.budget.allowancePaise ~/ 100}/day',
                              style: TypeScale.caption(t.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
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
