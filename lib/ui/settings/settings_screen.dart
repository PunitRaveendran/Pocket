import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup.dart';
import '../../core/biometrics.dart';
import '../../core/export.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../sheets/receipt_sheet.dart';
import '../widgets/amount_pad.dart';
import '../widgets/category_icon.dart';
import '../widgets/cycle_day_picker.dart';
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
            subtitle: Text('Day monthly allowance refreshes (1–31)', style: TypeScale.caption(t.inkSoft)),
            trailing: Text(CycleDayPicker.ordinal(s.cycleStartDay), style: TypeScale.body(t.inkSoft)),
            onTap: () => _editDay(context, ref, s),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text('Allowance pacing', style: TypeScale.body(t.ink)),
            subtitle: Text('Track allowance by day or by 7-day week', style: TypeScale.caption(t.inkSoft)),
            trailing: DropdownButton<PacingMode>(
              value: s.pacingMode,
              underline: const SizedBox.shrink(),
              dropdownColor: t.card,
              style: TypeScale.body(t.accent),
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(pacingMode: mode));
                }
              },
              items: const [
                DropdownMenuItem(value: PacingMode.daily, child: Text('Daily')),
                DropdownMenuItem(value: PacingMode.weekly, child: Text('Weekly')),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text('Fixed monthly deductions', style: TypeScale.body(t.ink)),
            subtitle: Text(
              s.fixedDeductions.isEmpty
                  ? 'None (bus pass, mobile recharge, etc.)'
                  : '${s.fixedDeductions.length} active (Total: ${Money.formatPaise(s.totalFixedDeductionsPaise)})',
              style: TypeScale.caption(t.inkSoft),
            ),
            trailing: Icon(Icons.chevron_right, size: 20, color: t.inkSoft),
            onTap: () => _manageFixedDeductions(context, ref, ledger),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text('Leftover policy', style: TypeScale.body(t.ink)),
            subtitle: Text(
              s.leftoverPolicy == LeftoverPolicy.dynamicDistribute
                  ? 'Dynamic Distribute (spread over remaining days)'
                  : 'Save to Outings Pool (sweeps into Piggy Bank)',
              style: TypeScale.caption(t.inkSoft),
            ),
            trailing: DropdownButton<LeftoverPolicy>(
              value: s.leftoverPolicy,
              underline: const SizedBox.shrink(),
              dropdownColor: t.card,
              style: TypeScale.body(t.accent),
              onChanged: (policy) {
                if (policy != null) {
                  ref.read(ledgerProvider.notifier).setLeftoverPolicy(policy);
                }
              },
              items: const [
                DropdownMenuItem(
                  value: LeftoverPolicy.dynamicDistribute,
                  child: Text('Distribute'),
                ),
                DropdownMenuItem(
                  value: LeftoverPolicy.outingsPiggyBank,
                  child: Text('Piggy Bank'),
                ),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            title: Text('Biometric App Lock', style: TypeScale.body(t.ink)),
            subtitle: Text('Require fingerprint or device PIN on launch', style: TypeScale.caption(t.inkSoft)),
            value: s.biometricEnabled,
            activeThumbColor: t.paper,
            activeTrackColor: t.accent,
            onChanged: (v) async {
              final ok = await BiometricService.instance.authenticate(
                reason: v ? 'Verify identity to enable Biometric Lock' : 'Verify identity to disable Biometric Lock',
              );
              if (ok) {
                await ref.read(ledgerProvider.notifier).setBiometricEnabled(v);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Biometric authentication cancelled or not matched')),
                );
              }
            },
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.receipt_long_outlined, size: 20, color: t.inkSoft),
            title: Text('Month-End Paper Receipt', style: TypeScale.body(t.ink)),
            subtitle: Text('Thermal receipt of cycle spends & campus stats', style: TypeScale.caption(t.inkSoft)),
            onTap: () => showMonthEndReceipt(context, ledger),
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
            leading: Icon(Icons.backup_outlined, size: 20, color: t.inkSoft),
            title: Text('Backup Ledger Snapshot', style: TypeScale.body(t.ink)),
            subtitle: Text('Export complete encrypted JSON snapshot', style: TypeScale.caption(t.inkSoft)),
            onTap: () => _backupSnapshot(context, ledger),
          ),
          const Hairline(indent: Space.margin),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.settings_backup_restore_outlined, size: 20, color: t.inkSoft),
            title: Text('Restore from Backup', style: TypeScale.body(t.ink)),
            subtitle: Text('Restore all transactions and settings from snapshot', style: TypeScale.caption(t.inkSoft)),
            onTap: () => _restoreSnapshot(context, ref),
          ),
          const Hairline(indent: Space.margin),
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
    final day = await showCycleDayPickerSheet(context, initialDay: settings.cycleStartDay);
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

  Future<void> _manageFixedDeductions(BuildContext context, WidgetRef ref, Ledger ledger) async {
    final t = TokenScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final liveLedger = ref.watch(ledgerProvider).valueOrNull ?? ledger;
            final deductions = liveLedger.settings.fixedDeductions;
            final totalFixed = liveLedger.settings.totalFixedDeductionsPaise;
            final effective = liveLedger.settings.effectiveStipendPaise;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Fixed Monthly Deductions', style: TypeScale.title(t.ink)),
                    const SizedBox(height: Space.x2),
                    Text(
                      'Recurring student expenses (college bus pass, mobile recharge, mess fee) deducted before calculating daily allowance.',
                      style: TypeScale.caption(t.inkSoft),
                    ),
                    const SizedBox(height: Space.x3),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.card,
                        border: Border.all(color: t.rule),
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Fixed: ${Money.formatPaise(totalFixed)}', style: TypeScale.caption(t.inkSoft)),
                          Text('Effective Stipend: ${Money.formatPaise(effective)}',
                              style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.x3),
                    if (deductions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No fixed deductions added yet.', style: TypeScale.caption(t.inkSoft)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: deductions.length,
                          separatorBuilder: (context, index) => const Hairline(),
                          itemBuilder: (ctx, i) {
                            final d = deductions[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                d.title,
                                style: TypeScale.body(t.ink).copyWith(
                                  decoration: d.isEnabled ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Text(
                                '${Money.formatPaise(d.amountPaise)} / month',
                                style: TypeScale.caption(t.inkSoft),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: d.isEnabled,
                                    activeThumbColor: t.paper,
                                    activeTrackColor: t.accent,
                                    onChanged: (v) {
                                      ref.read(ledgerProvider.notifier).updateFixedDeduction(
                                            d.copyWith(isEnabled: v),
                                          );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 20, color: t.over),
                                    onPressed: () {
                                      ref.read(ledgerProvider.notifier).deleteFixedDeduction(d.id);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: Space.x4),
                    PrimaryButton(
                      label: '+ Add Recurring Cost',
                      onPressed: () => _addFixedDeductionDialog(ctx, ref, t),
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

  Future<void> _addFixedDeductionDialog(BuildContext context, WidgetRef ref, PaperTokens t) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Fixed Deduction', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: TypeScale.body(t.ink),
              cursorColor: t.accent,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. College Bus Pass, Mobile Recharge',
                labelStyle: TypeScale.caption(t.inkSoft),
              ),
            ),
            const SizedBox(height: Space.x3),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TypeScale.body(t.ink),
              cursorColor: t.accent,
              decoration: InputDecoration(
                labelText: 'Amount (₹ / month)',
                hintText: 'e.g. 400',
                labelStyle: TypeScale.caption(t.inkSoft),
              ),
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
    );

    if (ok == true && titleController.text.trim().isNotEmpty) {
      final rupees = int.tryParse(amountController.text.trim()) ?? 0;
      if (rupees > 0) {
        await ref.read(ledgerProvider.notifier).addFixedDeduction(
              title: titleController.text.trim(),
              amountPaise: rupees * 100,
            );
      }
    }
  }

  Future<void> _backupSnapshot(BuildContext context, Ledger ledger) async {
    final t = TokenScope.of(context);
    final jsonStr = BackupService.generateBackupJson(ledger);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Encrypted Backup Snapshot', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete snapshot of settings, categories, transactions, friend splits, and fixed costs.',
              style: TypeScale.body(t.inkSoft),
            ),
            const SizedBox(height: Space.x4),
            Container(
              height: 140,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.card,
                border: Border.all(color: t.rule),
                borderRadius: BorderRadius.circular(Space.controlRadius),
              ),
              child: SingleChildScrollView(
                child: Text(
                  jsonStr,
                  style: TypeScale.caption(t.inkSoft).copyWith(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup snapshot copied to clipboard')),
              );
            },
            child: Text('Copy to Clipboard', style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreSnapshot(BuildContext context, WidgetRef ref) async {
    final t = TokenScope.of(context);
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore from Backup', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warning: Restoring will overwrite all current local data with the contents of the backup snapshot.',
              style: TypeScale.caption(t.over),
            ),
            const SizedBox(height: Space.x3),
            TextField(
              controller: controller,
              maxLines: 5,
              style: TypeScale.caption(t.ink).copyWith(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Paste backup JSON snapshot here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore Now', style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      final repo = ref.read(repositoryProvider);
      final success = await BackupService.restoreFromJson(controller.text.trim(), repo);
      if (context.mounted) {
        if (success) {
          ref.invalidate(ledgerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ledger restored successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore. Please check the backup JSON format.')),
          );
        }
      }
    }
  }
}
