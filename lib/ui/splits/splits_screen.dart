import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../sheets/split_sheet.dart';
import '../widgets/chips.dart';
import '../widgets/hairline.dart';

enum SplitFilter { all, owedToMe, iOwe, settled }

class SplitsScreen extends ConsumerStatefulWidget {
  const SplitsScreen({super.key});

  @override
  ConsumerState<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends ConsumerState<SplitsScreen> {
  SplitFilter _filter = SplitFilter.all;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final async = ref.watch(ledgerProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Center(child: Text('$e')),
      data: (ledger) {
        final splits = ledger.friendSplits;
        final hide = ledger.settings.hideAmounts;

        final totalOwedToMe = ledger.totalOwedToMePaise;
        final totalIOwe = ledger.totalIOwePaise;
        final net = ledger.netFriendBalancePaise;

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
            onPressed: () => showSplitSheet(context),
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
                                  onPressed: () => _openGroupCalculator(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.x2),
                            Text(
                              Money.formatPaise(net.abs(), hide: hide),
                              style: TypeScale.figure(net > 0 ? t.accent : t.ink),
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

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
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
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
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
                                  onPressed: () => _confirmSettle(context, item),
                                  child: Text('Settle Up', style: TypeScale.caption(t.accent)),
                                ),
                                if (isOwed) ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      side: BorderSide(color: t.rule),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(Space.controlRadius),
                                      ),
                                    ),
                                    icon: Icon(Icons.share_outlined, size: 13, color: t.inkSoft),
                                    label: Text('Remind / UPI', style: TypeScale.caption(t.inkSoft)),
                                    onPressed: () => _openShareReminder(context, item),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 18, color: t.inkSoft),
                        color: t.card,
                        onSelected: (val) {
                          if (val == 'remind') {
                            _openShareReminder(context, item);
                          } else if (val == 'edit') {
                            showSplitSheet(context, editing: item);
                          } else if (val == 'delete') {
                            _confirmDelete(context, item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (isOwed && !item.isSettled)
                            PopupMenuItem(
                              value: 'remind',
                              child: Text('Remind (WhatsApp / UPI)', style: TypeScale.body(t.ink)),
                            ),
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

  Future<void> _confirmSettle(BuildContext context, FriendSplit split) async {
    final t = TokenScope.of(context);
    final isOwed = split.direction == SplitDirection.youAreOwed;
    var creditToToday = isOwed;

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
                    'Credit this amount to today’s spending allowance',
                    style: TypeScale.caption(t.ink),
                  ),
                  subtitle: Text(
                    'Since they gave you cash or UPI, your wallet/allowance expands today!',
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
    final t = TokenScope.of(context);
    final totalController = TextEditingController();
    final namesController = TextEditingController();
    final descController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Group Bill Splitter', style: TypeScale.heading(t.ink)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paid for lunch or a trip? Split equally among friends in seconds.',
                style: TypeScale.caption(t.inkSoft),
              ),
              const SizedBox(height: Space.x4),
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'Total Bill Amount (₹)',
                  prefixText: '₹ ',
                  prefixStyle: TypeScale.body(t.ink),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              const SizedBox(height: Space.x3),
              TextField(
                controller: namesController,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'Friends who share this (comma separated)',
                  hintText: 'Rahul, Aman, Sneha',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              const SizedBox(height: Space.x3),
              TextField(
                controller: descController,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'For what?',
                  hintText: 'e.g. Swiggy order, Canteen bill, Cab share',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          TextButton(
            onPressed: () async {
              final rawTotal = int.tryParse(totalController.text.trim()) ?? 0;
              final names = namesController.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              final desc = descController.text.trim();

              if (rawTotal <= 0 || names.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid bill total and friend names')),
                );
                return;
              }

              // Including the user, total people = names.length + 1
              final totalPeople = names.length + 1;
              final totalPaise = rawTotal * 100;
              final sharePaise = totalPaise ~/ totalPeople;

              final notifier = ref.read(ledgerProvider.notifier);
              for (final friend in names) {
                await notifier.addFriendSplit(
                  friendName: friend,
                  amountPaise: sharePaise,
                  direction: SplitDirection.youAreOwed,
                  date: LocalDate.today(),
                  note: desc.isNotEmpty ? '$desc (split of ₹$rawTotal)' : 'Bill split of ₹$rawTotal',
                );
              }

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Created ${names.length} splits of ${Money.formatPaise(sharePaise)} each!',
                    ),
                  ),
                );
              }
            },
            child: Text('Create Splits', style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );
  }

  void _openShareReminder(BuildContext context, FriendSplit item) {
    final t = TokenScope.of(context);
    final rupees = item.amountPaise ~/ 100;
    final forText = item.note.isNotEmpty ? ' for ${item.note}' : '';
    final message = 'Hey ${item.friendName}! Just a quick reminder about your share of ₹$rupees$forText on Pocket. You can GPay/PhonePe me when you get a chance! 🙌';
    final upiUriString = 'upi://pay?pn=PocketUser&am=$rupees&cu=INR&tn=${Uri.encodeComponent(item.note.isEmpty ? 'Pocket Split' : item.note)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Space.cardRadius)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: Space.x4),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: t.accentTint,
                    child: Text(
                      item.friendName.isNotEmpty ? item.friendName[0].toUpperCase() : '?',
                      style: TypeScale.body(t.accent).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remind ${item.friendName}', style: TypeScale.title(t.ink)),
                        Text('Share of ₹$rupees$forText', style: TypeScale.caption(t.inkSoft)),
                      ],
                    ),
                  ),
                  Text(
                    Money.formatPaise(item.amountPaise),
                    style: TypeScale.money(t.accent, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              // Message preview card
              Container(
                padding: const EdgeInsets.all(Space.x3),
                decoration: BoxDecoration(
                  color: t.paper,
                  border: Border.all(color: t.rule),
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                ),
                child: Text(
                  message,
                  style: TypeScale.body(t.ink).copyWith(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: Space.x4),
              // Action buttons
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                ),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Send on WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () async {
                  final waUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
                  try {
                    await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open WhatsApp. Copied text to clipboard!')),
                      );
                    }
                    await Clipboard.setData(ClipboardData(text: message));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: Space.x2),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.rule),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                ),
                icon: Icon(Icons.qr_code_2, size: 18, color: t.ink),
                label: Text(
                  'Open UPI App (GPay / PhonePe / Paytm)',
                  style: TypeScale.body(t.ink).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final upiUri = Uri.parse(upiUriString);
                  try {
                    final ok = await launchUrl(upiUri, mode: LaunchMode.externalApplication);
                    if (!ok) throw Exception();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UPI link copied to clipboard!')),
                      );
                    }
                    await Clipboard.setData(ClipboardData(text: upiUriString));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: Space.x2),
              TextButton.icon(
                icon: Icon(Icons.copy_outlined, size: 16, color: t.inkSoft),
                label: Text('Copy Reminder Text', style: TypeScale.caption(t.inkSoft)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder message copied to clipboard!')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
