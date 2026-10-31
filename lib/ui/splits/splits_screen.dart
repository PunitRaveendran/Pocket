import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../sheets/bill_split_sheet.dart';
import '../sheets/split_sheet.dart';
import '../widgets/chips.dart';
import '../widgets/hairline.dart';

enum SplitFilter { all, owedToMe, iOwe, settled }

class SplitsScreen extends ConsumerStatefulWidget {
  const SplitsScreen({super.key});

  @override
  ConsumerState<SplitsScreen> createState() => _SplitsScreenState();
}

class _FriendGroup {
  final String friendName;
  final List<FriendSplit> splits;

  _FriendGroup({required this.friendName, required this.splits});

  int get netPaise {
    var net = 0;
    for (final s in splits) {
      if (s.isSettled) continue;
      if (s.direction == SplitDirection.youAreOwed) {
        net += s.amountPaise;
      } else {
        net -= s.amountPaise;
      }
    }
    return net;
  }

  int get totalSettledPaise {
    return splits
        .where((s) => s.isSettled)
        .fold(0, (sum, s) => sum + s.amountPaise);
  }

  int get activeCount => splits.where((s) => !s.isSettled).length;
}

class _SplitsScreenState extends ConsumerState<SplitsScreen> {
  SplitFilter _filter = SplitFilter.all;
  bool _groupByFriend = true;
  final Set<String> _expandedFriends = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final async = ref.watch(
      ledgerProvider.select(
        (a) => a.whenData((l) => (l.friendSplits, l.settings.hideAmounts)),
      ),
    );

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final (splits, hide) = data;

        var totalOwedToMe = 0;
        var totalIOwe = 0;
        for (final s in splits) {
          if (!s.isSettled) {
            if (s.direction == SplitDirection.youAreOwed) {
              totalOwedToMe += s.amountPaise;
            } else {
              totalIOwe += s.amountPaise;
            }
          }
        }
        final net = totalOwedToMe - totalIOwe;

        // Apply tab filter
        final filtered = splits.where((s) {
          switch (_filter) {
            case SplitFilter.all:
              return !s.isSettled;
            case SplitFilter.owedToMe:
              return !s.isSettled && s.direction == SplitDirection.youAreOwed;
            case SplitFilter.iOwe:
              return !s.isSettled && s.direction == SplitDirection.youOwe;
            case SplitFilter.settled:
              return s.isSettled;
          }
        }).toList();

        return Scaffold(
          backgroundColor: t.paper,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: t.accent,
            foregroundColor: t.paper,
            elevation: 2,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Split'),
            onPressed: () {
              HapticFeedback.lightImpact();
              _onAddSplitPressed(context);
            },
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, Space.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Net balance card
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
                                Icon(
                                  net >= 0 ? Icons.call_received : Icons.call_made,
                                  size: 18,
                                  color: net > 0 ? t.accent : t.inkSoft,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  net > 0
                                      ? 'Overall: You get back'
                                      : net < 0
                                          ? 'Overall: You owe'
                                          : 'All settled up',
                                  style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.calculate_outlined, color: t.inkSoft, size: 20),
                                  tooltip: 'Quick Group Split Calculator',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _openGroupCalculator(context);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.x2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Money.formatPaise(net.abs(), hide: hide),
                                style: TypeScale.figure(net > 0 ? t.accent : t.ink),
                              ),
                            ),
                            const SizedBox(height: Space.x3),
                            const Hairline(),
                            const SizedBox(height: Space.x3),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Owed to you', style: TypeScale.caption(t.inkSoft)),
                                      const SizedBox(height: 2),
                                      Text(
                                        Money.formatPaise(totalOwedToMe, hide: hide),
                                        style: TypeScale.heading(t.accent),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 32, color: t.rule),
                                const SizedBox(width: Space.x4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('You owe', style: TypeScale.caption(t.inkSoft)),
                                      const SizedBox(height: 2),
                                      Text(
                                        Money.formatPaise(totalIOwe, hide: hide),
                                        style: TypeScale.heading(t.ink),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.x4),

                      // Filter chips & View Toggle
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            LedgerChip(
                              label: _groupByFriend ? 'Grouped by Friend' : 'All Items',
                              selected: _groupByFriend,
                              onTap: () => setState(() => _groupByFriend = !_groupByFriend),
                            ),
                            const SizedBox(width: Space.x2),
                            LedgerChip(
                              label: 'Active (${splits.where((s) => !s.isSettled).length})',
                              selected: _filter == SplitFilter.all,
                              onTap: () => setState(() => _filter = SplitFilter.all),
                            ),
                            const SizedBox(width: Space.x2),
                            LedgerChip(
                              label: 'They Owe Me',
                              selected: _filter == SplitFilter.owedToMe,
                              onTap: () => setState(() => _filter = SplitFilter.owedToMe),
                            ),
                            const SizedBox(width: Space.x2),
                            LedgerChip(
                              label: 'I Owe',
                              selected: _filter == SplitFilter.iOwe,
                              onTap: () => setState(() => _filter = SplitFilter.iOwe),
                            ),
                            const SizedBox(width: Space.x2),
                            LedgerChip(
                              label: 'Settled (${splits.where((s) => s.isSettled).length})',
                              selected: _filter == SplitFilter.settled,
                              onTap: () => setState(() => _filter = SplitFilter.settled),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Split items list
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.margin),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 40, color: t.inkSoft),
                          const SizedBox(height: Space.x3),
                          Text(
                            _filter == SplitFilter.settled
                                ? 'No settled splits yet.'
                                : 'No splits here right now.',
                            style: TypeScale.body(t.inkSoft),
                          ),
                          const SizedBox(height: Space.x2),
                          Text(
                            'Hostel snacks, canteen tabs, and bills with friends stay organized here.',
                            textAlign: TextAlign.center,
                            style: TypeScale.caption(t.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_groupByFriend)
                Builder(
                  builder: (context) {
                    final groups = _computeGroups(filtered);
                    return SliverList.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        return _buildGroupedFriendCard(context, t, groups[index], hide);
                      },
                    );
                  },
                )
              else
                SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Hairline(indent: Space.margin),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isOwed = item.direction == SplitDirection.youAreOwed;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: item.isSettled
                            ? t.rule
                            : isOwed
                                ? t.accentTint
                                : t.card,
                        child: Text(
                          item.friendName.isNotEmpty ? item.friendName[0].toUpperCase() : '?',
                          style: TypeScale.body(
                            item.isSettled
                                ? t.inkSoft
                                : isOwed
                                    ? t.accent
                                    : t.ink,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.friendName,
                              style: TypeScale.body(t.ink).copyWith(
                                decoration: item.isSettled ? TextDecoration.lineThrough : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            Money.formatPaise(item.amountPaise, hide: hide),
                            style: TypeScale.money(
                              item.isSettled
                                  ? t.inkSoft
                                  : isOwed
                                      ? t.accent
                                      : t.ink,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                item.isSettled
                                    ? 'Settled'
                                    : isOwed
                                        ? 'Owes you'
                                        : 'You owe',
                                style: TypeScale.caption(
                                  item.isSettled
                                      ? t.inkSoft
                                      : isOwed
                                          ? t.accent
                                          : t.inkSoft,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 6),
                              Text('·', style: TypeScale.caption(t.inkSoft)),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('d MMM').format(item.localDate.dateTime),
                                style: TypeScale.caption(t.inkSoft),
                              ),
                              if (item.note.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('·', style: TypeScale.caption(t.inkSoft)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.note,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypeScale.caption(t.inkSoft),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!item.isSettled) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  side: BorderSide(color: t.accent),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(Space.controlRadius),
                                  ),
                                ),
                                onPressed: () => _confirmSettle(context, item),
                                child: Text('Settle Up', style: TypeScale.caption(t.accent)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: t.inkSoft),
                        color: t.card,
                        onSelected: (val) {
                          if (val == 'edit') {
                            showSplitSheet(context, editing: item);
                          } else if (val == 'delete') {
                            _confirmDelete(context, item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit', style: TypeScale.body(t.ink)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TypeScale.body(t.over)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  List<_FriendGroup> _computeGroups(List<FriendSplit> items) {
    final Map<String, ({String displayName, List<FriendSplit> splits})> groupedMap = {};
    for (final s in items) {
      final normKey = s.friendName.trim().toLowerCase();
      if (normKey.isEmpty) continue;
      if (!groupedMap.containsKey(normKey)) {
        groupedMap[normKey] = (displayName: s.friendName.trim(), splits: [s]);
      } else {
        groupedMap[normKey]!.splits.add(s);
      }
    }
    return groupedMap.values
        .map((e) => _FriendGroup(friendName: e.displayName, splits: e.splits))
        .toList();
  }

  Widget _buildGroupedFriendCard(
    BuildContext context,
    PaperTokens t,
    _FriendGroup group,
    bool hide,
  ) {
    final isExpanded = _expandedFriends.contains(group.friendName);
    final isSettledTab = _filter == SplitFilter.settled;
    final isOwed = group.netPaise > 0;
    final isOwing = group.netPaise < 0;
    final displayAmount = isSettledTab ? group.totalSettledPaise : group.netPaise.abs();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: 4),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.rule),
        borderRadius: BorderRadius.circular(Space.cardRadius),
      ),
      child: Column(
        children: [
          // Friend Card Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedFriends.remove(group.friendName);
                } else {
                  _expandedFriends.add(group.friendName);
                }
              });
            },
            borderRadius: BorderRadius.circular(Space.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isSettledTab
                        ? t.rule
                        : isOwed
                            ? t.accentTint
                            : t.paper,
                    child: Text(
                      group.friendName.isNotEmpty ? group.friendName[0].toUpperCase() : '?',
                      style: TypeScale.body(
                        isSettledTab
                            ? t.inkSoft
                            : isOwed
                                ? t.accent
                                : t.ink,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.friendName,
                          style: TypeScale.body(t.ink).copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: isSettledTab ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.splits.length > 1
                              ? '${group.splits.length} splits · ${group.activeCount} active'
                              : (group.splits.first.note.isNotEmpty
                                  ? group.splits.first.note
                                  : (isSettledTab ? 'Settled' : (isOwed ? 'Owes you' : 'You owe'))),
                          style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Money.formatPaise(displayAmount, hide: hide),
                        style: TypeScale.money(
                          isSettledTab
                              ? t.inkSoft
                              : isOwed
                                  ? t.accent
                                  : t.ink,
                          size: 16,
                        ),
                      ),
                      Text(
                        isSettledTab
                            ? 'Settled'
                            : isOwed
                                ? 'Owes you'
                                : isOwing
                                    ? 'You owe'
                                    : 'Balanced',
                        style: TypeScale.caption(
                          isSettledTab
                              ? t.inkSoft
                              : isOwed
                                  ? t.accent
                                  : t.inkSoft,
                        ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: t.inkSoft,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // If not expanded and has 1 split, show quick Settle Up row
          if (!isExpanded && group.activeCount == 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      side: BorderSide(color: t.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                    onPressed: () => _confirmSettle(
                      context,
                      group.splits.firstWhere((s) => !s.isSettled),
                    ),
                    child: Text('Settle Up', style: TypeScale.caption(t.accent)),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: t.inkSoft),
                    color: t.card,
                    onSelected: (val) {
                      final split = group.splits.first;
                      if (val == 'edit') {
                        showSplitSheet(context, editing: split);
                      } else if (val == 'delete') {
                        _confirmDelete(context, split);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: TypeScale.body(t.ink)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TypeScale.body(t.over)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // If not expanded and has > 1 active splits, show quick "Settle All" row
          if (!isExpanded && group.activeCount > 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      side: BorderSide(color: t.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                    icon: const Icon(Icons.done_all, size: 14),
                    onPressed: () => _confirmSettleMultiple(
                      context,
                      group.friendName,
                      group.splits.where((s) => !s.isSettled).toList(),
                    ),
                    label: Text(
                      'Settle All (${Money.formatPaise(group.netPaise.abs(), hide: hide)})',
                      style: TypeScale.caption(t.accent),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () => setState(() => _expandedFriends.add(group.friendName)),
                    child: Text('View Details', style: TypeScale.caption(t.inkSoft)),
                  ),
                ],
              ),
            ),
          ],

          // Expanded splits breakdown
          if (isExpanded) ...[
            const Hairline(),
            for (final split in group.splits) ...[
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: Icon(
                  split.direction == SplitDirection.youAreOwed
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 16,
                  color: split.isSettled
                      ? t.inkSoft
                      : (split.direction == SplitDirection.youAreOwed ? t.accent : t.ink),
                ),
                title: Text(
                  split.note.isNotEmpty ? split.note : 'Split',
                  style: TypeScale.caption(t.ink).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: split.isSettled ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('d MMM').format(split.localDate.dateTime)} · ${split.isSettled ? "Settled" : (split.direction == SplitDirection.youAreOwed ? "Owes you" : "You owe")}',
                  style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.formatPaise(split.amountPaise, hide: hide),
                        style: TypeScale.caption(
                          split.isSettled
                              ? t.inkSoft
                              : (split.direction == SplitDirection.youAreOwed ? t.accent : t.ink),
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!split.isSettled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          side: BorderSide(color: t.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                          ),
                        ),
                        onPressed: () => _confirmSettle(context, split),
                        child: Text('Settle Up', style: TypeScale.caption(t.accent).copyWith(fontSize: 11)),
                      ),
                    ],
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 16, color: t.inkSoft),
                      color: t.card,
                      onSelected: (val) {
                        if (val == 'edit') {
                          showSplitSheet(context, editing: split);
                        } else if (val == 'delete') {
                          _confirmDelete(context, split);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit', style: TypeScale.body(t.ink)),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TypeScale.body(t.over)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Hairline(indent: 14),
            ],
            if (group.activeCount > 1) ...[
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: t.accent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                    icon: const Icon(Icons.done_all, size: 16),
                    onPressed: () => _confirmSettleMultiple(
                      context,
                      group.friendName,
                      group.splits.where((s) => !s.isSettled).toList(),
                    ),
                    label: Text(
                      'Settle All with ${group.friendName} (${Money.formatPaise(group.netPaise.abs(), hide: hide)})',
                      style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSettleMultiple(
    BuildContext context,
    String friendName,
    List<FriendSplit> activeSplits,
  ) async {
    final t = TokenScope.of(context);
    final totalPaise = activeSplits.fold(0, (sum, s) => sum + s.amountPaise);
    var creditToToday = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Settle all with $friendName?', style: TypeScale.heading(t.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark ${activeSplits.length} splits totaling ${Money.formatPaise(totalPaise)} as settled.',
                style: TypeScale.body(t.ink),
              ),
              const SizedBox(height: Space.x4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: creditToToday,
                activeColor: t.accent,
                title: Text(
                  'Also add to today’s spending allowance',
                  style: TypeScale.caption(t.ink),
                ),
                subtitle: Text(
                  'Leave unchecked to clear the splits without inflating your daily balance.',
                  style: TypeScale.caption(t.inkSoft),
                ),
                onChanged: (v) => setDlgState(() => creditToToday = v ?? false),
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
              child: Text('Confirm Settle All', style: TypeScale.body(t.accent)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      for (final s in activeSplits) {
        await ref.read(ledgerProvider.notifier).settleFriendSplit(
              s.id,
              creditDaily: creditToToday,
            );
      }
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _confirmSettle(BuildContext context, FriendSplit split) async {
    final t = TokenScope.of(context);
    final isOwed = split.direction == SplitDirection.youAreOwed;
    var creditToToday = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Settle with ${split.friendName}?', style: TypeScale.heading(t.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark ${Money.formatPaise(split.amountPaise)} as paid and settled.',
                style: TypeScale.body(t.ink),
              ),
              if (isOwed) ...[
                const SizedBox(height: Space.x4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: creditToToday,
                  activeColor: t.accent,
                  title: Text(
                    'Also add to today’s spending allowance',
                    style: TypeScale.caption(t.ink),
                  ),
                  subtitle: Text(
                    'Leave unchecked to clear the split without inflating your daily balance.',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  onChanged: (v) => setDlgState(() => creditToToday = v ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirm Settle', style: TypeScale.body(t.accent)),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await ref.read(ledgerProvider.notifier).settleFriendSplit(
            split.id,
            creditDaily: creditToToday,
          );
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _confirmDelete(BuildContext context, FriendSplit split) async {
    final t = TokenScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Split?', style: TypeScale.heading(t.ink)),
        content: Text(
          'Remove this split with ${split.friendName} for ${Money.formatPaise(split.amountPaise)}?',
          style: TypeScale.body(t.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(ledgerProvider.notifier).deleteFriendSplit(split.id);
    }
  }

  Future<void> _openGroupCalculator(BuildContext context) async {
    await showBillSplitSheet(context, totalAmountPaise: 0, allowEditTotal: true);
  }

  void _onAddSplitPressed(BuildContext context) {
    final t = TokenScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: Space.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: t.rule, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: Space.x4),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.accentTint,
                  child: Icon(Icons.call_split_rounded, color: t.accent),
                ),
                title: Text('Split a Bill with Friends', style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text('e.g. ₹100 bill: your share goes to Today, rest goes to Splits', style: TypeScale.caption(t.inkSoft)),
                onTap: () {
                  Navigator.pop(ctx);
                  showBillSplitSheet(context, totalAmountPaise: 0, allowEditTotal: true);
                },
              ),
              const Hairline(indent: 56),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.card,
                  child: Icon(Icons.handshake_outlined, color: t.ink),
                ),
                title: Text('Direct Friend IOU', style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text('Directly track money you lent or borrowed 1-on-1', style: TypeScale.caption(t.inkSoft)),
                onTap: () {
                  Navigator.pop(ctx);
                  showSplitSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
