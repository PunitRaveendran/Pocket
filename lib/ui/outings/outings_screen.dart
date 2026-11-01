import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../sheets/outing_sheet.dart';
import '../widgets/hairline.dart';
import '../widgets/primary_button.dart';

enum OutingsFilter { thisMonth, allTime }

class OutingsScreen extends ConsumerStatefulWidget {
  const OutingsScreen({super.key});

  @override
  ConsumerState<OutingsScreen> createState() => _OutingsScreenState();
}

class _OutingsScreenState extends ConsumerState<OutingsScreen> {
  OutingsFilter _filter = OutingsFilter.thisMonth;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final async = ref.watch(
      ledgerProvider.select(
        (a) => a.whenData((l) => (l.settings, l.outings, l.transactions)),
      ),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final (settings, outings, transactions) = data;
        final ledger = Ledger(
          settings: settings,
          categories: const [],
          transactions: transactions,
          outings: outings,
        );
        final today = LocalDate.today();
        final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
        final extraCycle = extraThisCycle(ledger, cycle);
        final hide = ledger.settings.hideAmounts;
        final allGroups = _allGroups(ledger);

        final currentCycleGroups = allGroups.where((g) {
          return cycle.contains(g.date) || g.txns.any((t) => cycle.contains(t.localDate));
        }).toList();

        final pastCycleGroups = allGroups.where((g) => !currentCycleGroups.contains(g)).toList();

        final totalAllTime = allGroups.fold<int>(0, (sum, g) => sum + g.total);
        final displayAmount = _filter == OutingsFilter.thisMonth ? extraCycle : totalAllTime;
        final displayLabel = _filter == OutingsFilter.thisMonth ? Copy.extraThisMonth : 'total in all outings';

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, Space.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trips and nights out sit here. They are tracked separately so they don’t reduce your daily food allowance.',
                      style: TypeScale.body(t.inkSoft),
                    ),
                    const SizedBox(height: Space.x6),
                    Semantics(
                      label: '${Money.spokenRupees(displayAmount)} $displayLabel',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Money.formatPaise(displayAmount, hide: hide),
                          style: TypeScale.figure(t.ink),
                        ),
                      ),
                    ),
                    Text(displayLabel, style: TypeScale.body(t.inkSoft)),
                    if (allGroups.isNotEmpty) ...[
                      const SizedBox(height: Space.x4),
                      Row(
                        children: [
                          ChoiceChip(
                            selected: _filter == OutingsFilter.thisMonth,
                            onSelected: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _filter = OutingsFilter.thisMonth);
                            },
                            label: Text('This Month (${Money.formatPaise(extraCycle, hide: hide)})'),
                            selectedColor: t.accent.withValues(alpha: 0.15),
                            labelStyle: TypeScale.caption(
                              _filter == OutingsFilter.thisMonth ? t.accent : t.inkSoft,
                            ),
                            backgroundColor: t.card,
                            side: BorderSide(
                              color: _filter == OutingsFilter.thisMonth ? t.accent : t.rule,
                            ),
                          ),
                          const SizedBox(width: Space.x2),
                          ChoiceChip(
                            selected: _filter == OutingsFilter.allTime,
                            onSelected: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _filter = OutingsFilter.allTime);
                            },
                            label: Text('All Outings (${allGroups.length})'),
                            selectedColor: t.accent.withValues(alpha: 0.15),
                            labelStyle: TypeScale.caption(
                              _filter == OutingsFilter.allTime ? t.accent : t.inkSoft,
                            ),
                            backgroundColor: t.card,
                            side: BorderSide(
                              color: _filter == OutingsFilter.allTime ? t.accent : t.rule,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Space.x6),
                    PrimaryButton(
                      label: Copy.addOuting,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        showOutingSheet(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (allGroups.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: Space.x6),
                  child: Container(
                    padding: const EdgeInsets.all(Space.x4),
                    decoration: BoxDecoration(
                      border: Border.all(color: t.rule),
                      borderRadius: BorderRadius.circular(Space.cardRadius),
                      color: t.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No extra spends yet', style: TypeScale.heading(t.ink)),
                        const SizedBox(height: Space.x2),
                        Text(
                          'Planning a movie, weekend trip, or concert? Log it here to keep your day-to-day food & study allowance unaffected.',
                          style: TypeScale.body(t.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filter == OutingsFilter.thisMonth) ...[
              if (currentCycleGroups.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = currentCycleGroups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.x4),
                          child: _OutingCard(group: g, hideAmounts: hide),
                        );
                      },
                      childCount: currentCycleGroups.length,
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.margin, 0, Space.margin, Space.x4),
                    child: Container(
                      padding: const EdgeInsets.all(Space.x3),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        border: Border.all(color: t.rule),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: t.inkSoft),
                          const SizedBox(width: Space.x2),
                          Expanded(
                            child: Text(
                              'No extra spends recorded this month. Previous outings are shown below.',
                              style: TypeScale.caption(t.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (pastCycleGroups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.margin, Space.x2, Space.margin, Space.x3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Past Trips & Outings', style: TypeScale.heading(t.ink)),
                        Text(
                          '${pastCycleGroups.length} ${pastCycleGroups.length == 1 ? 'trip' : 'trips'}',
                          style: TypeScale.caption(t.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = pastCycleGroups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.x4),
                          child: _OutingCard(group: g, hideAmounts: hide),
                        );
                      },
                      childCount: pastCycleGroups.length,
                    ),
                  ),
                ),
              ],
            ] else ...[
              if (currentCycleGroups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.margin, Space.x2, Space.margin, Space.x3),
                    child: Text('This Month', style: TypeScale.heading(t.ink)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = currentCycleGroups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.x4),
                          child: _OutingCard(group: g, hideAmounts: hide),
                        );
                      },
                      childCount: currentCycleGroups.length,
                    ),
                  ),
                ),
              ],
              if (pastCycleGroups.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.margin, Space.x2, Space.margin, Space.x3),
                    child: Text('Past Trips & Outings', style: TypeScale.heading(t.ink)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = pastCycleGroups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.x4),
                          child: _OutingCard(group: g, hideAmounts: hide),
                        );
                      },
                      childCount: pastCycleGroups.length,
                    ),
                  ),
                ),
              ],
            ],
            const SliverToBoxAdapter(child: SizedBox(height: Space.x12)),
          ],
        );
      },
    );
  }
}

class _OutingCard extends ConsumerWidget {
  const _OutingCard({required this.group, required this.hideAmounts});

  final _Group group;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TokenScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(Space.cardRadius),
        border: Border.all(color: t.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title, style: TypeScale.heading(t.ink)),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('d MMM yyyy').format(group.date.dateTime)} · ${group.txns.length} ${group.txns.length == 1 ? 'item' : 'items'}',
                        style: TypeScale.caption(t.inkSoft),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.formatPaise(group.total, hide: hideAmounts),
                  style: TypeScale.money(t.ink, size: 17, height: 24 / 17).copyWith(fontWeight: FontWeight.w600),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: t.inkSoft),
                  padding: EdgeInsets.zero,
                  color: t.card,
                  onSelected: (val) {
                    if (val == 'edit') {
                      _editOutingTitle(context, ref);
                    } else if (val == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Rename trip', style: TypeScale.body(t.ink)),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete trip', style: TypeScale.body(t.over)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Hairline(),
          for (final txn in group.txns)
            Dismissible(
              key: ValueKey(txn.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => ref.read(ledgerProvider.notifier).deleteTxn(txn.id),
              background: Container(
                color: t.overTint,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: Space.x4),
                child: Icon(Icons.delete_outline, color: t.over, size: 20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.note.isNotEmpty ? txn.note : txn.merchant,
                            style: TypeScale.body(t.ink),
                          ),
                          if (txn.note.isNotEmpty && txn.merchant.isNotEmpty && txn.merchant != txn.note)
                            Text(txn.merchant, style: TypeScale.caption(t.inkSoft)),
                        ],
                      ),
                    ),
                    Text(
                      Money.formatPaise(txn.amountPaise, hide: hideAmounts),
                      style: TypeScale.money(t.inkSoft, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showOutingSheet(
                  context,
                  existingOutingId: group.id,
                  title: group.title,
                ),
                icon: Icon(Icons.add, size: 16, color: t.accent),
                label: Text('Add spend to this outing', style: TypeScale.caption(t.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOutingTitle(BuildContext context, WidgetRef ref) async {
    final t = TokenScope.of(context);
    final controller = TextEditingController(text: group.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename outing', style: TypeScale.heading(t.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TypeScale.body(t.ink),
          cursorColor: t.accent,
          decoration: InputDecoration(
            hintText: 'Outing title',
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(Copy.save, style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      await ref.read(ledgerProvider.notifier).updateOuting(
            Outing(id: group.id, title: newTitle, localDate: group.date, note: ''),
          );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = TokenScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${group.title}"?', style: TypeScale.heading(t.ink)),
        content: Text(
          'This will remove the outing and its ${group.txns.length} logged expenses.',
          style: TypeScale.body(t.inkSoft),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Copy.remove, style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(ledgerProvider.notifier).deleteOuting(group.id);
    }
  }
}

class _Group {
  _Group({required this.id, required this.title, required this.date, required this.txns});
  final String id;
  final String title;
  final LocalDate date;
  final List<Txn> txns;
  int get total => txns.fold(0, (a, t) => a + t.amountPaise);
}

List<_Group> _allGroups(Ledger ledger) {
  final result = <_Group>[];
  for (final o in ledger.outings) {
    final txns = ledger.transactions
        .where((t) => t.bucket == Bucket.outing && t.outingId == o.id)
        .toList();
    if (txns.isEmpty) continue;
    result.add(_Group(id: o.id, title: o.title, date: o.localDate, txns: txns));
  }
  result.sort((a, b) => b.date.ymd.compareTo(a.date.ymd));
  return result;
}
