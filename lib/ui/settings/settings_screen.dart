import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/backup.dart';
import '../../core/biometrics.dart';
import '../../core/export.dart';
import '../../core/money.dart';
import '../../core/slice_email_parser.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../sheets/adjust_balance_sheet.dart';
import '../insights/insights_screen.dart';
import '../sheets/receipt_sheet.dart';
import '../widgets/amount_pad.dart';
import '../widgets/app_password_guide_sheet.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/cycle_day_picker.dart';
import '../widgets/hairline.dart';
import '../widgets/primary_button.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.isTab = false});

  final bool isTab;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _storageSizeBytes;
  bool _isOptimizing = false;
  bool _isSyncingSlice = false;
  bool _isSyncingSms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStorageSize());
  }

  Future<void> _refreshStorageSize() async {
    final bytes = await ref.read(ledgerProvider.notifier).getStorageSizeBytes();
    if (mounted) {
      setState(() => _storageSizeBytes = bytes);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Lightweight (< 50 KB)';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _optimizeStorage(BuildContext context, PaperTokens t) async {
    if (_isOptimizing) return;
    setState(() => _isOptimizing = true);
    try {
      await ref.read(ledgerProvider.notifier).optimizeStorage();
      await _refreshStorageSize();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SQLite database defragmented & compacted! Footprint: ${_formatBytes(_storageSizeBytes ?? 0)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOptimizing = false);
      }
    }
  }

  Future<void> _checkIntegrity(BuildContext context, PaperTokens t) async {
    final result = await ref.read(ledgerProvider.notifier).checkIntegrity();
    if (context.mounted) {
      final isHealthy = result.toLowerCase() == 'ok';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(isHealthy ? Icons.check_circle : Icons.warning_amber, color: isHealthy ? t.accent : t.over, size: 22),
              const SizedBox(width: 8),
              Text('Database Integrity', style: TypeScale.heading(t.ink)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHealthy
                    ? 'Status: Verified Clean & Uncorrupted (PRAGMA integrity_check passed).'
                    : 'Integrity check result: $result',
                style: TypeScale.body(t.inkSoft),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'WAL mode, foreign keys, and indexes are active on this device.',
                style: TypeScale.caption(t.inkSoft),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TypeScale.body(t.accent)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _purgeTrash(BuildContext context, PaperTokens t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Purge Deleted Trash', style: TypeScale.heading(t.ink)),
        content: Text(
          'Permanently deletes soft-deleted records older than 30 days and reclaims on-disk database pages.',
          style: TypeScale.body(t.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Purge Now', style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );

    if (ok == true) {
      final count = await ref.read(ledgerProvider.notifier).purgeDeletedRecords(olderThanDays: 30);
      await _refreshStorageSize();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Purged $count old deleted records. Database compacted!'
                  : 'Trash is already clean. No records older than 30 days.',
            ),
          ),
        );
      }
    }
  }

  Widget _sectionHeader(PaperTokens t, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.margin, Space.x5, Space.margin, Space.x2),
      child: Text(
        title,
        style: TypeScale.caption(t.inkSoft).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    if (ledger == null) return const SizedBox.shrink();
    final s = ledger.settings;

    final listContent = ListView(
      children: [
        // Section 0: Insights & Visual Analytics
        _sectionHeader(t, 'THIS CYCLE & INSIGHTS'),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.insights_rounded, size: 20, color: t.accent),
            title: Text('This Cycle & Insights', style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Interactive graphs, burn rate pace & category breakdown',
              style: TypeScale.caption(t.inkSoft),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(Space.margin, Space.x2, Space.margin, Space.x6),
                child: InsightsScreen(isEmbedded: true),
              ),
            ],
          ),
        ),
        const Hairline(),

        // Section 1: Budget & Allowance
        _sectionHeader(t, 'BUDGET & PACING'),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.account_balance_wallet_outlined, size: 20, color: t.accent),
            title: Text('Budget & Pacing', style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Stipend: ${Money.formatPaise(s.stipendPaise, hide: s.hideAmounts)} · Refresh day ${CycleDayPicker.ordinal(s.cycleStartDay)}',
              style: TypeScale.caption(t.inkSoft),
            ),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text(Copy.monthlyStipend, style: TypeScale.body(t.ink)),
                subtitle: Text('Base pocket money or allowance', style: TypeScale.caption(t.inkSoft)),
                trailing: Text(
                  Money.formatPaise(s.stipendPaise, hide: s.hideAmounts),
                  style: TypeScale.money(t.ink),
                ),
                onTap: () => _editStipend(context, ref, s.stipendPaise),
              ),
              const Hairline(indent: Space.margin + 32),
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text('Adjust Account Balance', style: TypeScale.body(t.ink)),
                subtitle: Text('Manually correct current balance or base stipend', style: TypeScale.caption(t.inkSoft)),
                trailing: Icon(Icons.tune, color: t.accent, size: 20),
                onTap: () => showAdjustBalanceSheet(context),
              ),
              const Hairline(indent: Space.margin + 32),
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text(Copy.cycleStart, style: TypeScale.body(t.ink)),
                subtitle: Text('Monthly refresh day', style: TypeScale.caption(t.inkSoft)),
                trailing: Text(CycleDayPicker.ordinal(s.cycleStartDay), style: TypeScale.body(t.inkSoft)),
                onTap: () => _editDay(context, ref, s),
              ),
              const Hairline(indent: Space.margin + 32),
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text('Leftover policy', style: TypeScale.body(t.ink)),
                subtitle: Text(
                  s.leftoverPolicy == LeftoverPolicy.dynamicDistribute
                      ? 'Distribute over remaining days'
                      : 'Save into Outings Piggy Bank',
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
              const Hairline(indent: Space.margin + 32),
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text('Month-to-Month Rollover', style: TypeScale.body(t.ink)),
                subtitle: Text(
                  'Roll unspent savings into next month’s stipend',
                  style: TypeScale.caption(t.inkSoft),
                ),
                value: s.rolloverUnspent,
                activeThumbColor: t.paper,
                activeTrackColor: t.accent,
                onChanged: (v) => ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(rolloverUnspent: v)),
              ),
            ],
          ),
        ),
        const Hairline(),

        // Section 2: Appearance & Privacy
        _sectionHeader(t, 'APPEARANCE & PRIVACY'),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
            leading: Icon(Icons.palette_outlined, size: 20, color: t.accent),
            title: Text('Appearance & Privacy', style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Theme · Hide amounts · Biometric lock · Receipts',
              style: TypeScale.caption(t.inkSoft),
            ),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text('Theme', style: TypeScale.body(t.ink)),
                subtitle: Text(
                  switch (s.appThemeMode) {
                    AppThemeMode.system => 'System default',
                    AppThemeMode.light => 'Light mode (editorial warm paper)',
                    AppThemeMode.dark => 'Dark mode (editorial charcoal)',
                    AppThemeMode.matcha => 'Matcha Zen (calming tea paper)',
                    AppThemeMode.espresso => 'Café Mocha (warm espresso & caramel)',
                    AppThemeMode.nordic => 'Nordic Slate (deep navy & frost blue)',
                    AppThemeMode.sakura => 'Sakura Blossom (soft blush & rose)',
                    AppThemeMode.oled => 'Midnight OLED (pure black battery saver)',
                  },
                  style: TypeScale.caption(t.inkSoft),
                ),
                trailing: DropdownButton<AppThemeMode>(
                  value: s.appThemeMode,
                  underline: const SizedBox.shrink(),
                  dropdownColor: t.card,
                  style: TypeScale.body(t.accent),
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(ledgerProvider.notifier).setThemeMode(mode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: AppThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: AppThemeMode.light, child: Text('Paper (Light)')),
                    DropdownMenuItem(value: AppThemeMode.dark, child: Text('Charcoal (Dark)')),
                    DropdownMenuItem(value: AppThemeMode.matcha, child: Text('Matcha Zen')),
                    DropdownMenuItem(value: AppThemeMode.espresso, child: Text('Café Espresso')),
                    DropdownMenuItem(value: AppThemeMode.nordic, child: Text('Nordic Slate')),
                    DropdownMenuItem(value: AppThemeMode.sakura, child: Text('Sakura Rose')),
                    DropdownMenuItem(value: AppThemeMode.oled, child: Text('OLED Black')),
                  ],
                ),
              ),
              const Hairline(indent: Space.margin + 32),
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text(Copy.hideAmounts, style: TypeScale.body(t.ink)),
                subtitle: Text('Tap amounts or toggle to mask numbers', style: TypeScale.caption(t.inkSoft)),
                value: s.hideAmounts,
                activeThumbColor: t.paper,
                activeTrackColor: t.accent,
                onChanged: (v) => ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(hideAmounts: v)),
              ),
              const Hairline(indent: Space.margin + 32),
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                title: Text('Biometric App Lock', style: TypeScale.body(t.ink)),
                subtitle: Text('Fingerprint or device PIN on launch', style: TypeScale.caption(t.inkSoft)),
                value: s.biometricEnabled,
                activeThumbColor: t.paper,
                activeTrackColor: t.accent,
                onChanged: (v) async {
                  if (v) {
                    final available = await BiometricService.instance.isAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No biometric sensor or device screen lock configured.')),
                        );
                      }
                      return;
                    }
                  }
                  final ok = await BiometricService.instance.authenticate(
                    reason: v ? 'Confirm fingerprint or PIN to enable lock' : 'Confirm fingerprint or PIN to disable lock',
                  );
                  if (ok) {
                    await ref.read(ledgerProvider.notifier).setBiometricEnabled(v);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Authentication failed or cancelled')),
                    );
                  }
                },
              ),
              const Hairline(indent: Space.margin + 32),
              ListTile(
                contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                leading: Icon(Icons.receipt_long_outlined, size: 20, color: t.inkSoft),
                title: Text('Month-End Paper Receipt', style: TypeScale.body(t.ink)),
                subtitle: Text('View thermal breakdown of cycle spends', style: TypeScale.caption(t.inkSoft)),
                trailing: Icon(Icons.chevron_right, size: 18, color: t.inkSoft),
                onTap: () => showMonthEndReceipt(context, ledger),
              ),
            ],
          ),
        ),
        const Hairline(),

          const SizedBox(height: Space.x3),
          // Section: Bank SMS & Email Sync (Universal)
          _sectionHeader(t, 'AUTOMATION & SYNC'),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(Icons.sms_rounded, size: 20, color: s.smsSyncEnabled ? t.accent : t.inkSoft),
              title: Row(
                children: [
                  Text('Bank SMS Auto-Sync', style: TypeScale.body(t.ink)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Recommended',
                      style: TypeScale.caption(t.accent).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                s.smsSyncEnabled
                    ? 'Active · Instant UPI & bank SMS tracker'
                    : 'Off · Zero passwords, local on-device SMS parsing',
                style: TypeScale.caption(s.smsSyncEnabled ? t.accent : t.inkSoft).copyWith(
                  fontWeight: s.smsSyncEnabled ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  title: Text('Enable SMS Auto-Sync', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    'Detects spends from GPay, PhonePe, Paytm, Slice, HDFC, SBI & all banks instantly. 100% on-device, no cloud.',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  value: s.smsSyncEnabled,
                  activeThumbColor: t.paper,
                  activeTrackColor: t.accent,
                  onChanged: (v) async {
                    if (v) {
                      final granted = await ref.read(smsSyncServiceProvider).requestPermission();
                      if (granted) {
                        await ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(smsSyncEnabled: true));
                        await ref.read(ledgerProvider.notifier).syncSms();
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('SMS permission denied. Please allow SMS permission in Android settings.')),
                          );
                        }
                      }
                    } else {
                      await ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(smsSyncEnabled: false));
                    }
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.refresh_rounded, size: 18, color: t.accent),
                  title: Text('Scan & Sync SMS Now', style: TypeScale.body(t.accent)),
                  subtitle: Text(
                    s.smsSyncLastSyncedMs != null
                        ? 'Last scanned: ${DateFormat('d MMM, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(s.smsSyncLastSyncedMs!))}'
                        : 'Never scanned',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  trailing: _isSyncingSms
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _isSyncingSms ? null : () => _triggerManualSmsSync(context, ref),
                ),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(Icons.mark_email_read_rounded, size: 20, color: s.emailSyncEnabled ? t.accent : t.inkSoft),
              title: Text('Bank Email Auto-Sync', style: TypeScale.body(t.ink)),
              subtitle: Text(
                s.emailSyncEnabled
                    ? (s.emailSyncAddress.isNotEmpty
                        ? 'Active · ${s.emailSyncAddress}'
                        : 'Enabled · Credentials needed')
                    : 'Off · Local IMAP email alerts across all banks',
                style: TypeScale.caption(s.emailSyncEnabled ? t.accent : t.inkSoft).copyWith(
                  fontWeight: s.emailSyncEnabled ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  title: Text('Enable Bank Email Auto-Sync', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    'Fetches transaction emails from HDFC, SBI, Slice, ICICI & more via local on-device IMAP',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  value: s.emailSyncEnabled,
                  activeThumbColor: t.paper,
                  activeTrackColor: t.accent,
                  onChanged: (v) => ref.read(ledgerProvider.notifier).updateSettings(s.copyWith(emailSyncEnabled: v)),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.alternate_email_rounded, size: 18, color: t.inkSoft),
                  title: Text('Gmail Address', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    s.emailSyncAddress.isNotEmpty ? s.emailSyncAddress : 'Not set (e.g. yourname@gmail.com)',
                    style: TypeScale.caption(s.emailSyncAddress.isNotEmpty ? t.ink : t.inkSoft),
                  ),
                  trailing: Icon(Icons.edit_outlined, size: 18, color: t.inkSoft),
                  onTap: () => _editEmailAddress(context, ref, s, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.password_rounded, size: 18, color: t.inkSoft),
                  title: Text('Google App Password', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    s.emailSyncAppPassword.isNotEmpty
                        ? '•••• •••• •••• •••• (Configured offline)'
                        : 'Not set (16-character Google App Password)',
                    style: TypeScale.caption(s.emailSyncAppPassword.isNotEmpty ? t.accent : t.inkSoft),
                  ),
                  trailing: Icon(Icons.edit_outlined, size: 18, color: t.inkSoft),
                  onTap: () => _editEmailAppPassword(context, ref, s, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.help_outline_rounded, size: 18, color: t.accent),
                  title: Text('How to get an App Password?', style: TypeScale.body(t.accent)),
                  subtitle: Text('Step-by-step 60-second setup guide', style: TypeScale.caption(t.inkSoft)),
                  trailing: Icon(Icons.chevron_right_rounded, size: 20, color: t.accent),
                  onTap: () => showAppPasswordGuideSheet(context, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.mark_email_read_outlined, size: 18, color: t.inkSoft),
                  title: Text('Monitored Banks & Senders', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    s.emailSyncSender.isEmpty ? 'All popular banks' : s.emailSyncSender,
                    style: TypeScale.caption(t.inkSoft),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(Icons.edit_outlined, size: 18, color: t.inkSoft),
                  onTap: () => _editEmailSender(context, ref, s, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.label_outline_rounded, size: 18, color: t.inkSoft),
                  title: Text('Gmail Inbox Organization', style: TypeScale.body(t.ink)),
                  subtitle: Text(
                    'Processed emails are moved to the "Slice" label and removed from Inbox',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.refresh_rounded, size: 18, color: t.accent),
                  title: Text('Test & Sync Email Now', style: TypeScale.body(t.accent)),
                  subtitle: Text(
                    s.emailSyncLastSyncedMs != null
                        ? 'Last synced: ${DateFormat('d MMM, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(s.emailSyncLastSyncedMs!))}'
                        : 'Never synced',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  trailing: _isSyncingSlice
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _isSyncingSlice ? null : () => _triggerManualSync(context, ref),
                ),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),

          const SizedBox(height: Space.x3),
          // Section 3: Categories & Customization (Collapsible)
          _sectionHeader(t, 'ORGANIZATION & DATA'),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(Icons.category_outlined, size: 20, color: t.inkSoft),
              title: Text('Categories (${ledger.categories.length})', style: TypeScale.body(t.ink)),
              subtitle: Text('Drag ≡ to reorder · decides order across app', style: TypeScale.caption(t.inkSoft)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin + 32, vertical: 4),
                  child: Text(
                    'Drag using the ≡ handle to prioritize which categories appear first across Today, Spend Sheet, and Insights.',
                    style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 12),
                  ),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: ledger.categories.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) async {
                    HapticFeedback.mediumImpact();
                    if (newIndex > oldIndex) newIndex -= 1;
                    final items = List<Category>.from(ledger.categories);
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    await ref.read(ledgerProvider.notifier).reorderCategories(items.map((c) => c.id).toList());
                  },
                  itemBuilder: (context, index) {
                    final c = ledger.categories[index];
                    return ListTile(
                      key: ValueKey(c.id),
                      contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                      leading: Icon(categoryIcon(c.icon), size: 18, color: t.inkSoft),
                      title: Text(c.name, style: TypeScale.body(t.ink)),
                      subtitle: Text(c.isSystem ? 'Built in' : 'Custom', style: TypeScale.caption(t.inkSoft)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!c.isSystem)
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: t.over),
                              tooltip: 'Delete category',
                              onPressed: () => _deleteCategory(context, ref, c),
                            ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              child: Icon(Icons.drag_handle, size: 20, color: t.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.add, size: 18, color: t.accent),
                  title: Text(Copy.addCategory, style: TypeScale.body(t.accent)),
                  onTap: () => _addCategory(context, ref, t),
                ),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),
          // Section: Friends Management (Collapsible)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(Icons.people_alt_outlined, size: 20, color: t.inkSoft),
              title: Text('Saved Friends (${ledger.allFriendSuggestions.length})', style: TypeScale.body(t.ink)),
              subtitle: Text('Manage quick suggestion pills for bill splits', style: TypeScale.caption(t.inkSoft)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.margin + 32, vertical: 4),
                  child: Text(
                    'Friends saved here appear as quick-tap pills across Spend Sheet and Bill Splits so you never have to type their names.',
                    style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 12),
                  ),
                ),
                const SizedBox(height: Space.x2),
                if (ledger.allFriendSuggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.margin + 32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in ledger.allFriendSuggestions)
                            InputChip(
                              avatar: CircleAvatar(
                                backgroundColor: t.accentTint,
                                child: Text(
                                  f.isNotEmpty ? f[0].toUpperCase() : '?',
                                  style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              label: Text(f, style: TypeScale.body(t.ink).copyWith(fontSize: 13)),
                              deleteIcon: Icon(Icons.close, size: 16, color: t.inkSoft),
                              onDeleted: () => _deleteFriend(context, ref, f),
                              backgroundColor: t.card,
                              side: BorderSide(color: t.rule),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Space.x2),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.person_add_alt_1, size: 18, color: t.accent),
                  title: Text('Add Friend', style: TypeScale.body(t.accent)),
                  onTap: () => _addFriend(context, ref, t),
                ),
              ],
            ),
          ),
          const Hairline(indent: Space.margin),
          // Section 4: Storage & Data Tools (Collapsible)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: Space.margin),
              leading: Icon(Icons.storage_outlined, size: 20, color: t.inkSoft),
              title: Text('Backup & Storage Tools', style: TypeScale.body(t.ink)),
              subtitle: Text(
                '${_formatBytes(_storageSizeBytes ?? 0)} · Local offline SQLite',
                style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600),
              ),
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.backup_outlined, size: 18, color: t.inkSoft),
                  title: Text('Backup Snapshot (JSON)', style: TypeScale.body(t.ink)),
                  subtitle: Text('Export copyable ledger backup', style: TypeScale.caption(t.inkSoft)),
                  onTap: () => _backupSnapshot(context, ledger),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.settings_backup_restore_outlined, size: 18, color: t.inkSoft),
                  title: Text('Restore from Backup', style: TypeScale.body(t.ink)),
                  subtitle: Text('Paste JSON backup to restore', style: TypeScale.caption(t.inkSoft)),
                  onTap: () => _restoreSnapshot(context, ref),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.table_chart_outlined, size: 18, color: t.inkSoft),
                  title: Text('Export to CSV', style: TypeScale.body(t.ink)),
                  subtitle: Text('For Excel and Google Sheets', style: TypeScale.caption(t.inkSoft)),
                  onTap: () => _exportCsv(context, ledger),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.cleaning_services_outlined, size: 18, color: t.inkSoft),
                  title: Text('Compact & Optimize Storage', style: TypeScale.body(t.ink)),
                  subtitle: Text('Defragments SQLite database pages', style: TypeScale.caption(t.inkSoft)),
                  trailing: _isOptimizing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: () => _optimizeStorage(context, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.verified_user_outlined, size: 18, color: t.inkSoft),
                  title: Text('Verify Database Integrity', style: TypeScale.body(t.ink)),
                  onTap: () => _checkIntegrity(context, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.auto_delete_outlined, size: 18, color: t.caution),
                  title: Text('Purge Deleted Trash (>30 Days)', style: TypeScale.body(t.ink)),
                  onTap: () => _purgeTrash(context, t),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: Space.margin + 32, right: Space.margin),
                  leading: Icon(Icons.delete_forever_outlined, size: 18, color: t.over),
                  title: Text(Copy.deleteAll, style: TypeScale.body(t.over)),
                  subtitle: Text('Wipes all local data', style: TypeScale.caption(t.inkSoft)),
                  onTap: () => _wipe(context, ref, t),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Text(
              'Pocket operates 100% locally on your device with no cloud servers, no account, and zero tracking.',
              style: TypeScale.caption(t.inkSoft),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Space.x12),
        ],
      );

    if (widget.isTab) {
      return Material(
        color: t.paper,
        child: listContent,
      );
    }

    return Scaffold(
      backgroundColor: t.paper,
      appBar: AppBar(title: const Text(Copy.settings)),
      body: listContent,
    );
  }

  Future<void> _editStipend(BuildContext context, WidgetRef ref, int current) async {
    var value = AmountValue.fromPaise(current);
    var isFirstDigit = true;
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
                                setSt(() {
                                  value = AmountValue.fromPaise(r * 100);
                                  isFirstDigit = true;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.x4),
                    AmountPad(
                      value: value,
                      clearOnFirstDigit: isFirstDigit,
                      onFirstDigitCleared: () => setSt(() => isFirstDigit = false),
                      onChanged: (v) => setSt(() => value = v),
                    ),
                    const SizedBox(height: Space.x4),
                    PrimaryButton(
                      label: Copy.save,
                      onPressed: () async {
                        final ledger = ref.read(ledgerProvider).valueOrNull;
                        if (ledger == null) return;
                        await ref.read(ledgerProvider.notifier).updateSettings(
                              ledger.settings.copyWith(
                                stipendPaise: value.paiseTotal,
                              ),
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

  Future<void> _addFriend(BuildContext context, WidgetRef ref, PaperTokens t) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Friend', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a frequent friend to appear as a quick-tap pill during bill splits.',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x2),
            TextField(
              controller: controller,
              autofocus: true,
              style: TypeScale.body(t.ink),
              cursorColor: t.accent,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (val) {
                final v = val.trim();
                if (v.isNotEmpty) {
                  Navigator.pop(ctx, v);
                }
              },
              decoration: InputDecoration(
                hintText: "Friend's name (e.g. Rahul)",
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
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
              final v = controller.text.trim();
              if (v.isNotEmpty) {
                Navigator.pop(ctx, v);
              }
            },
            child: Text('Add', style: TypeScale.body(t.accent).copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ref.read(ledgerProvider.notifier).addFriend(name.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${name.trim()}" to saved friends.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteFriend(BuildContext context, WidgetRef ref, String friendName) async {
    final t = TokenScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "$friendName"?', style: TypeScale.heading(t.ink)),
        content: Text(
          'This will remove "$friendName" from your quick-suggestion pills. Existing split history will remain intact.',
          style: TypeScale.body(t.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TypeScale.body(t.over)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(ledgerProvider.notifier).deleteFriend(friendName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$friendName" from saved friends.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

    try {
      final clip = await Clipboard.getData('text/plain');
      if (clip?.text != null && clip!.text!.trim().startsWith('{')) {
        controller.text = clip.text!.trim();
      }
    } catch (_) {}

    if (controller.text.isEmpty) {
      final candidates = [
        '/data/local/tmp/backup.json',
        '/storage/emulated/0/Android/data/app.pocket.pocket/files/backup.json',
        '/sdcard/Android/data/app.pocket.pocket/files/backup.json',
      ];
      for (final path in candidates) {
        try {
          final f = File(path);
          if (await f.exists()) {
            final content = await f.readAsString();
            if (content.trim().startsWith('{')) {
              controller.text = content.trim();
              break;
            }
          }
        } catch (_) {}
      }
      if (controller.text.isEmpty) {
        try {
          final docs = await getApplicationDocumentsDirectory();
          final f = File(p.join(docs.path, 'backup.json'));
          if (await f.exists()) {
            final content = await f.readAsString();
            if (content.trim().startsWith('{')) {
              controller.text = content.trim();
            }
          }
        } catch (_) {}
      }
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Restore from Backup', style: TypeScale.heading(t.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warning: Restoring will overwrite all current local data with the contents of the backup snapshot.',
                style: TypeScale.caption(t.over),
              ),
              const SizedBox(height: Space.x2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(Icons.content_paste, size: 14, color: t.accent),
                    label: Text('Paste from Clipboard', style: TypeScale.caption(t.accent)),
                    onPressed: () async {
                      final clip = await Clipboard.getData('text/plain');
                      if (clip?.text != null) {
                        setDlgState(() {
                          controller.text = clip!.text!.trim();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: Space.x1),
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
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      final repo = ref.read(repositoryProvider);
      final success = await BackupService.restoreFromJson(controller.text.trim(), repo);
      if (context.mounted) {
        if (success) {
          await ref.read(ledgerProvider.notifier).reload();
          ref.invalidate(ledgerProvider);
          await _refreshStorageSize();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ledger restored successfully!')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore. Invalid format or corrupted data prevented import; your existing data was kept safe.')),
          );
        }
      }
    }
  }

  Future<void> _editEmailAddress(
    BuildContext context,
    WidgetRef ref,
    Settings settings,
    PaperTokens t,
  ) async {
    final controller = TextEditingController(text: settings.emailSyncAddress);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gmail Address', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Gmail address where you receive Slice transaction alerts.',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x3),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: TypeScale.body(t.ink),
              decoration: InputDecoration(
                hintText: 'e.g. yourname@gmail.com',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
              ),
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
    );
    if (ok == true) {
      await ref.read(ledgerProvider.notifier).updateSettings(
            settings.copyWith(emailSyncAddress: controller.text.trim()),
          );
    }
  }

  Future<void> _editEmailAppPassword(
    BuildContext context,
    WidgetRef ref,
    Settings settings,
    PaperTokens t,
  ) async {
    final controller = TextEditingController(text: settings.emailSyncAppPassword);
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Google App Password', style: TypeScale.heading(t.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate a 16-character App Password at:\nmyaccount.google.com/apppasswords\n\nYour actual Google password is never required or stored. This password is kept 100% offline in your device’s local database.',
                style: TypeScale.caption(t.inkSoft),
              ),
              const SizedBox(height: Space.x3),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                style: TypeScale.body(t.ink),
                decoration: InputDecoration(
                  hintText: '16-character app password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: t.inkSoft,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                showAppPasswordGuideSheet(context, t);
              },
              child: Text('Step-by-step Guide', style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600)),
            ),
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
    if (ok == true) {
      await ref.read(ledgerProvider.notifier).updateSettings(
            settings.copyWith(emailSyncAppPassword: controller.text.trim()),
          );
    }
  }

  Future<void> _editEmailSender(
    BuildContext context,
    WidgetRef ref,
    Settings settings,
    PaperTokens t,
  ) async {
    final controller = TextEditingController(
      text: settings.emailSyncSender.isEmpty ? BankPresets.defaultSendersString : settings.emailSyncSender,
    );
    final banks = BankPresets.all;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Monitored Banks & Senders', style: TypeScale.heading(t.ink)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select banks to auto-include their sender addresses, or customize below:',
                  style: TypeScale.caption(t.inkSoft),
                ),
                const SizedBox(height: Space.x3),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final b in banks) ...[
                      LedgerChip(
                        label: b.displayName,
                        selected: controller.text.contains(b.senders.first),
                        onTap: () {
                          setDialogState(() {
                            final current = controller.text
                                .split(RegExp(r'[,;]'))
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toSet();
                            if (current.contains(b.senders.first)) {
                              for (final s in b.senders) {
                                current.remove(s);
                              }
                            } else {
                              current.addAll(b.senders);
                            }
                            controller.text = current.join(', ');
                          });
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Space.x3),
                Text('Sender addresses (comma-separated):', style: TypeScale.caption(t.inkSoft)),
                const SizedBox(height: Space.x1),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: TypeScale.body(t.ink),
                  decoration: InputDecoration(
                    hintText: BankPresets.defaultSendersString,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.rule)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: t.accent)),
                  ),
                ),
              ],
            ),
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
    if (ok == true) {
      await ref.read(ledgerProvider.notifier).updateSettings(
            settings.copyWith(emailSyncSender: controller.text.trim()),
          );
    }
  }

  Future<void> _triggerManualSmsSync(BuildContext context, WidgetRef ref) async {
    setState(() => _isSyncingSms = true);
    try {
      final res = await ref.read(ledgerProvider.notifier).syncSms(force: true);
      if (context.mounted) {
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.newCount > 0
                    ? 'SMS sync complete! Found ${res.newCount} new transaction${res.newCount > 1 ? 's' : ''}. Check the Today tab.'
                    : 'SMS sync complete. No new bank SMS transactions found.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorMessage ?? 'SMS sync failed'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncingSms = false);
    }
  }

  Future<void> _triggerManualSync(BuildContext context, WidgetRef ref) async {
    setState(() => _isSyncingSlice = true);
    try {
      final res = await ref.read(ledgerProvider.notifier).syncSliceEmails();
      if (context.mounted) {
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.newCount > 0
                    ? 'Sync complete! Found ${res.newCount} new bank transaction${res.newCount > 1 ? 's' : ''}. Check the Today tab.'
                    : 'Sync complete. No new bank transactions found.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorMessage ?? 'Email sync failed'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSyncingSlice = false);
    }
  }
}

