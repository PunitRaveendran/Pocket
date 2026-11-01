import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

Future<void> showOverspendSheet(
  BuildContext context, {
  required int overPaise,
  required LocalDate date,
  required List<Txn> dayTxns,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => OverspendSheet(
      overPaise: overPaise,
      date: date,
      dayTxns: dayTxns,
    ),
  );
}

class OverspendSheet extends ConsumerWidget {
  const OverspendSheet({
    super.key,
    required this.overPaise,
    required this.date,
    required this.dayTxns,
  });

  final int overPaise;
  final LocalDate date;
  final List<Txn> dayTxns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final hide = ledger?.settings.hideAmounts ?? false;

    final overFormatted = Money.formatPaise(overPaise, hide: hide);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: t.over, size: 24),
                const SizedBox(width: 8),
                Text('Manage Overspent', style: TypeScale.title(t.ink)),
              ],
            ),
            const SizedBox(height: Space.x2),
            Text(
              'You are $overFormatted over today’s allowance. Choose how to handle it:',
              style: TypeScale.body(t.inkSoft),
            ),
            const SizedBox(height: Space.x6),


            // Option 2: Reclassify a transaction to Outings
            if (dayTxns.any((x) => x.bucket == Bucket.daily && x.direction == Direction.debit)) ...[
              _ActionCard(
                icon: Icons.directions_walk_outlined,
                title: 'Move a spend to Outings',
                subtitle:
                    'Was one of today’s spends a trip or social night out? Move it to Outings so today’s meal allowance recovers.',
                onTap: () => _showReclassifyDialog(context, ref),
              ),
              const SizedBox(height: Space.x3),
            ],

            // Option 3: Spread over remaining days advice
            _ActionCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Spread over remaining cycle days',
              subtitle:
                  'Keep it as-is. Check the Insights tab to see your new safe daily pace for the rest of the month.',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: Space.x4),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReclassifyDialog(BuildContext context, WidgetRef ref) async {
    final t = TokenScope.of(context);
    final debits = dayTxns.where((x) => x.bucket == Bucket.daily && x.direction == Direction.debit).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select spend to move to Outings', style: TypeScale.heading(t.ink)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: debits.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final txn = debits[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(txn.merchant, style: TypeScale.body(t.ink)),
                subtitle: Text(txn.note.isNotEmpty ? txn.note : 'Daily expense', style: TypeScale.caption(t.inkSoft)),
                trailing: Text(Money.formatPaise(txn.amountPaise), style: TypeScale.money(t.ink, size: 15)),
                onTap: () async {
                  await ref.read(ledgerProvider.notifier).reclassifyTxnAsOuting(
                        txn,
                        outingTitle: txn.merchant,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Moved "${txn.merchant}" to Outings')),
                    );
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Space.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: t.rule),
          borderRadius: BorderRadius.circular(Space.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.accentTint,
                borderRadius: BorderRadius.circular(Space.controlRadius),
              ),
              child: Icon(icon, size: 20, color: t.accent),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TypeScale.heading(t.ink)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TypeScale.caption(t.inkSoft)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: t.inkSoft),
          ],
        ),
      ),
    );
  }
}
