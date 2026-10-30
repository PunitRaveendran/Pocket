import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'bill_split_sheet.dart';

Future<void> showPendingInboxSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const PendingInboxSheet(),
  );
}

class PendingInboxSheet extends ConsumerStatefulWidget {
  const PendingInboxSheet({super.key});

  @override
  ConsumerState<PendingInboxSheet> createState() => _PendingInboxSheetState();
}

class _PendingInboxSheetState extends ConsumerState<PendingInboxSheet> {
  final Map<String, String> _selectedCategories = {};
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final pendingItems = ledger?.pendingInbox ?? const [];
    final categories = ledger?.categories ?? const [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.rule,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mail_outline_rounded, size: 20, color: t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Slice Transactions',
                        style: TypeScale.title(t.ink).copyWith(fontSize: 18),
                      ),
                      Text(
                        pendingItems.isEmpty
                            ? 'All caught up'
                            : '${pendingItems.length} new transaction${pendingItems.length > 1 ? 's' : ''} to review',
                        style: TypeScale.caption(t.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (_isSyncing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  IconButton(
                    icon: Icon(Icons.sync_rounded, color: t.inkSoft),
                    tooltip: 'Sync now',
                    onPressed: _syncEmails,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: t.inkSoft),
                    tooltip: 'More options',
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'resync_clean',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Clear pending & re-sync'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'resync_clean') {
                        _resyncClean();
                      }
                    },
                  ),
                ],
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.inkSoft),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: pendingItems.isEmpty
                ? _buildEmptyState(t)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (ctx, i) {
                      final item = pendingItems[i];
                      return _buildTransactionCard(ctx, t, item, categories);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PaperTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.done_all_rounded, size: 40, color: t.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'All Slice transactions reviewed! 🎉',
              style: TypeScale.title(t.ink).copyWith(fontSize: 17),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New transaction emails from noreply@slice.bank.in will automatically appear here.',
              style: TypeScale.body(t.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _syncEmails,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check for new emails'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    PaperTokens t,
    PendingTransaction item,
    List<Category> categories,
  ) {
    // Current selected category for this card (defaults to suggestedCategoryId, or first available)
    final selectedCatId = _selectedCategories[item.id] ??
        item.suggestedCategoryId ??
        (categories.isNotEmpty ? categories.first.id : 'misc');

    final hasMemoryMatch = item.suggestedCategoryId != null &&
        item.suggestedCategoryId == selectedCatId;

    final dateFormatted = DateFormat('d MMM, h:mm a').format(item.occurredAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: BorderRadius.circular(Space.cardRadius),
        border: Border.all(color: t.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Merchant & Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.merchant,
                      style: TypeScale.title(t.ink).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          dateFormatted,
                          style: TypeScale.caption(t.inkSoft),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.accentTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Slice UPI',
                            style: TypeScale.caption(t.accent).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.direction == Direction.debit ? '-' : '+'}${Money.formatPaise(item.amountPaise)}',
                style: TypeScale.title(item.direction == Direction.debit ? t.ink : t.accent).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category assignment section
          Row(
            children: [
              Text(
                'What was this for?',
                style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
              ),
              if (hasMemoryMatch) ...[
                const SizedBox(width: 6),
                Icon(Icons.auto_awesome, size: 14, color: t.accent),
                const SizedBox(width: 2),
                Text(
                  'Auto-matched',
                  style: TypeScale.caption(t.accent).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: categories.map((cat) {
              final isSelected = cat.id == selectedCatId;
              return ChoiceChip(
                label: Text(cat.name),
                selected: isSelected,
                selectedColor: t.accentTint,
                backgroundColor: t.card,
                labelStyle: TypeScale.caption(isSelected ? t.accent : t.ink).copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? t.accent : t.rule,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategories[item.id] = cat.id;
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Decision Actions: "Just Me" vs "Split with Friends" vs "Dismiss"
          if (item.direction == Direction.credit)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => _approveTopUp(item),
                    icon: const Icon(Icons.savings_outlined, size: 16),
                    label: const Text('Add to Balance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () => _settleSplitFromInbox(item),
                    icon: Icon(Icons.people_outline_rounded, size: 16, color: t.accent),
                    label: Text('Settle Split', style: TextStyle(color: t.accent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.accent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: t.inkSoft),
                  tooltip: 'Dismiss without recording',
                  onPressed: () => _dismiss(item),
                ),
              ],
            )
          else
            Row(
              children: [
                // Just Me Button
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => _approveJustMe(item, selectedCatId),
                    icon: const Icon(Icons.person_rounded, size: 16),
                    label: const Text('Just me'),
                    style: FilledButton.styleFrom(
                      backgroundColor: t.ink,
                      foregroundColor: t.paper,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Split with Friends Button
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: () => _splitWithFriends(item, selectedCatId),
                    icon: Icon(Icons.people_alt_outlined, size: 16, color: t.accent),
                    label: Text('Split with friends', style: TextStyle(color: t.accent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.accent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Dismiss Icon Button
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: t.inkSoft),
                  tooltip: 'Dismiss without recording',
                  onPressed: () => _dismiss(item),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _approveTopUp(PendingTransaction item) async {
    try {
      await ref.read(ledgerProvider.notifier).approveInboxTransaction(
            item,
            categoryId: 'income',
            bucket: Bucket.daily,
            note: 'Stipend Top-Up via Slice',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${Money.formatPaise(item.amountPaise)} on top of monthly balance!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving top-up: $e')),
        );
      }
    }
  }

  Future<void> _settleSplitFromInbox(PendingTransaction item) async {
    final t = TokenScope.of(context);
    final ledger = ref.read(ledgerProvider).valueOrNull;
    final openSplits = (ledger?.friendSplits ?? [])
        .where((s) => !s.isSettled && s.direction == SplitDirection.youAreOwed)
        .toList();

    FriendSplit? chosenSplit;
    if (openSplits.isNotEmpty) {
      final match = openSplits.cast<FriendSplit?>().firstWhere(
            (s) => item.merchant.toLowerCase().contains(s!.friendName.toLowerCase()) ||
                s.friendName.toLowerCase().contains(item.merchant.toLowerCase()),
            orElse: () => null,
          );
      if (match != null) {
        chosenSplit = match;
      }
    }

    final selected = await showDialog<FriendSplit?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Settle Friend Split', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Received ${Money.formatPaise(item.amountPaise)} from ${item.merchant}.\nSelect which friend split to clear (won\'t be added to daily spending balance):',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x3),
            if (openSplits.isEmpty)
              Text('No open friend splits found.', style: TypeScale.body(t.inkSoft))
            else
              for (final s in openSplits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline, color: t.accent),
                  title: Text(s.friendName, style: TypeScale.body(t.ink)),
                  subtitle: Text(s.note.isNotEmpty ? s.note : 'Split share', style: TypeScale.caption(t.inkSoft)),
                  trailing: Text(Money.formatPaise(s.amountPaise), style: TypeScale.title(t.ink)),
                  onTap: () => Navigator.pop(ctx, s),
                ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          if (chosenSplit != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, chosenSplit),
              child: Text('Settle with ${chosenSplit.friendName}', style: TypeScale.body(t.accent)),
            ),
        ],
      ),
    );

    if (selected != null) {
      await ref.read(ledgerProvider.notifier).settleFriendSplit(selected.id, creditDaily: false);
      await ref.read(ledgerProvider.notifier).dismissInboxTransaction(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared split with ${selected.friendName}! Balance kept intact.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _approveJustMe(PendingTransaction item, String categoryId) async {
    try {
      await ref.read(ledgerProvider.notifier).approveInboxTransaction(
            item,
            categoryId: categoryId,
            bucket: Bucket.daily,
            note: 'Slice UPI',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded ₹${item.amountPaise ~/ 100} for ${item.merchant}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving transaction: $e')),
        );
      }
    }
  }

  Future<void> _splitWithFriends(PendingTransaction item, String categoryId) async {
    await showBillSplitSheet(
      context,
      totalAmountPaise: item.amountPaise,
      merchant: item.merchant,
      initialDate: item.localDate,
      initialCategoryId: categoryId,
      pendingInboxId: item.id,
    );
  }

  Future<void> _dismiss(PendingTransaction item) async {
    await ref.read(ledgerProvider.notifier).dismissInboxTransaction(item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction dismissed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _syncEmails() async {
    setState(() => _isSyncing = true);
    final result = await ref.read(ledgerProvider.notifier).syncSliceEmails();
    if (mounted) {
      setState(() => _isSyncing = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.newCount > 0
                  ? 'Found ${result.newCount} new Slice transaction${result.newCount > 1 ? 's' : ''}!'
                  : 'Up to date. No new Slice transactions found.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Sync failed'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  Future<void> _resyncClean() async {
    setState(() => _isSyncing = true);
    final result = await ref.read(ledgerProvider.notifier).clearPendingAndResync();
    if (mounted) {
      setState(() => _isSyncing = false);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.newCount > 0
                  ? 'Re-synced ${result.newCount} transactions with latest parser!'
                  : 'Re-sync complete. No new transactions found.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Re-sync failed'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }
}
