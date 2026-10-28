import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/category_icon.dart';
import '../widgets/hairline.dart';
import '../widgets/primary_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    if (ledger == null) return const SizedBox.shrink();
    final s = ledger.settings;

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(title: const Text(Copy.settings)),
      body: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text(Copy.monthlyStipend, style: TypeScale.body(t.ink)),
            subtitle: Text('Splits into your daily target', style: TypeScale.caption(t.inkSoft)),
            trailing: Text(
              Money.formatPaise(s.stipendPaise, hide: s.hideAmounts),
              style: TypeScale.money(t.ink),
            ),
            onTap: () => _editStipend(context, ref, s.stipendPaise),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text(Copy.cycleStart, style: TypeScale.body(t.ink)),
            subtitle: Text('Day monthly allowance refreshes', style: TypeScale.caption(t.inkSoft)),
            trailing: Text(_ordinal(s.cycleStartDay), style: TypeScale.body(t.inkSoft)),
            onTap: () => _editDay(context, ref, s),
          ),
          const Hairline(indent: Space.margin),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text(Copy.hideAmounts, style: TypeScale.body(t.ink)),
            subtitle: Text(Copy.hideAmountsHint, style: TypeScale.caption(t.inkSoft)),
            value: s.hideAmounts,
            activeThumbColor: t.paper,
            activeTrackColor: t.accent,
            onChanged: (v) => ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(hideAmounts: v)),
          ),
          const SizedBox(height: Space.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Text(Copy.categories, style: TypeScale.heading(t.ink)),
          ),
          const SizedBox(height: Space.x2),
          for (final c in ledger.categories)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(categoryIcon(c.icon), size: 20, color: t.inkSoft),
              title: Text(c.name, style: TypeScale.body(t.ink)),
              subtitle: c.isSystem
                  ? Text('Built in', style: TypeScale.caption(t.inkSoft))
                  : Text('Custom category', style: TypeScale.caption(t.inkSoft)),
              trailing: c.isSystem
                  ? null
                  : IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: t.over),
                      tooltip: 'Delete category',
                      onPressed: () => _deleteCategory(context, ref, c),
                    ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.add, size: 20, color: t.accent),
            title: Text(Copy.addCategory, style: TypeScale.body(t.accent)),
            onTap: () => _addCategory(context, ref, t),
          ),
          const SizedBox(height: Space.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Text('Data & Privacy', style: TypeScale.heading(t.ink)),
          ),
          const SizedBox(height: Space.x2),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.table_chart_outlined, size: 20, color: t.inkSoft),
            title: Text('Export to CSV', style: TypeScale.body(t.ink)),
            subtitle: Text('Export transactions for spreadsheet use', style: TypeScale.caption(t.inkSoft)),
            onTap: () => _exportCsv(context, ledger),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.delete_forever_outlined, size: 20, color: t.over),
            title: Text(Copy.deleteAll, style: TypeScale.body(t.over)),
            subtitle: Text('Wipes local database completely', style: TypeScale.caption(t.inkSoft)),
            onTap: () => _wipe(context, ref, t),
          ),
          const SizedBox(height: Space.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Text(
              'Pocket stores everything locally on this device. No account, no cloud servers, and no tracking.',
              style: TypeScale.caption(t.inkSoft),
            ),
          ),
          const SizedBox(height: Space.x12),
        ],
      ),
    );
  }

  String _ordinal(int d) {
    if (d == 1) return '1st';
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }

  Future<void> _editStipend(BuildContext context, WidgetRef ref, int current) async {
    var value = AmountValue.fromPaise(current);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final t = TokenScope.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Copy.monthlyStipend, style: TypeScale.title(t.ink)),
                    const SizedBox(height: Space.x2),
                    Text(
                      'How much pocket money / stipend lands each month?',
                      style: TypeScale.caption(t.inkSoft),
                    ),
                    const SizedBox(height: Space.x4),
                    AmountDisplay(value: value),
                    const SizedBox(height: Space.x4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final r in [2000, 2500, 3000])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ActionChip(
                              label: Text('₹$r'),
                              backgroundColor: value.paiseTotal == r * 100 ? t.accentTint : t.card,
                              side: BorderSide(
                                color: value.paiseTotal == r * 100 ? t.accent : t.rule,
                              ),
                              onPressed: () {
                                setSt(() => value = AmountValue.fromPaise(r * 100));
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.x4),
                    AmountPad(value: value, onChanged: (v) => setSt(() => value = v)),
                    const SizedBox(height: Space.x4),
                    PrimaryButton(
                      label: Copy.save,
                      onPressed: () async {
                        final ledger = ref.read(ledgerProvider).valueOrNull;
                        if (ledger == null) return;
                        await ref.read(ledgerProvider.notifier).updateSettings(
                              ledger.settings.copyWith(stipendPaise: value.paiseTotal),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _editDay(BuildContext context, WidgetRef ref, Settings settings) async {
    final t = TokenScope.of(context);
    final day = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(Copy.cycleStart, style: TypeScale.heading(t.ink)),
        children: [
          for (final d in [1, 5, 10, 15, 20, 25])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(_ordinal(d), style: TypeScale.body(t.ink)),
            ),
        ],
      ),
    );
    if (day != null) {
      await ref.read(ledgerProvider.notifier).updateSettings(settings.copyWith(cycleStartDay: day));
    }
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref, PaperTokens t) async {
    final controller = TextEditingController();
    var selectedIcon = 'custom';

    final ok = await showDialog<bool>(
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(Copy.save, style: TypeScale.body(t.accent)),
            ),
          ],
        ),
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      await ref.read(ledgerProvider.notifier).addCategory(
            controller.text.trim(),
            icon: selectedIcon,
          );
    }
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
    final t = TokenScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?', style: TypeScale.heading(t.ink)),
        content: Text(
          'Any existing expenses in this category will be moved to Misc.',
          style: TypeScale.body(t.inkSoft),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(ledgerProvider.notifier).deleteCategory(category.id);
    }
  }

  Future<void> _exportCsv(BuildContext context, Ledger ledger) async {
    final t = TokenScope.of(context);
    final csv = LedgerExport.toCsv(ledger);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export to CSV', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ledger.transactions.length} transactions ready for export.',
              style: TypeScale.body(t.ink),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'CSV content is not encrypted. You can copy it to your clipboard to paste into Google Sheets or Excel.',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x4),
            Container(
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.paper,
                border: Border.all(color: t.rule),
                borderRadius: BorderRadius.circular(Space.controlRadius),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csv.isEmpty ? 'No transactions to export.' : csv,
                  style: TypeScale.caption(t.inkSoft).copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
            },
            child: Text('Copy to Clipboard', style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _wipe(BuildContext context, WidgetRef ref, PaperTokens t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Copy.deleteAll, style: TypeScale.heading(t.ink)),
        content: Text(Copy.deleteAllBody, style: TypeScale.body(t.inkSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Copy.deleteConfirm, style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(ledgerProvider.notifier).wipe();
  }
}
