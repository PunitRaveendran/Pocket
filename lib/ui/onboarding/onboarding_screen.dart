import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/slice_email_parser.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/app_password_guide_sheet.dart';
import '../widgets/chips.dart';
import '../widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  AmountValue _stipend = AmountValue.fromPaise(250000);
  int _startDay = 1;

  bool _enableSmsSync = true;
  bool _enableEmailSync = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _appPasswordController = TextEditingController();
  final TextEditingController _sendersController = TextEditingController(
    text: BankPresets.defaultSendersString,
  );
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _appPasswordController.dispose();
    _sendersController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final email = _emailController.text.trim();
    final pwd = _appPasswordController.text.trim();
    final hasValidCreds = _enableEmailSync && email.isNotEmpty && pwd.isNotEmpty;
    final customSenders = _sendersController.text.trim();

    await ref.read(ledgerProvider.notifier).completeOnboarding(
          stipendPaise: _stipend.paiseTotal <= 0 ? 250000 : _stipend.paiseTotal,
          cycleStartDay: _startDay,
          emailSyncEnabled: hasValidCreds,
          emailSyncAddress: hasValidCreds ? email : '',
          emailSyncAppPassword: hasValidCreds ? pwd : '',
          emailSyncSender: customSenders.isNotEmpty ? customSenders : BankPresets.defaultSendersString,
          smsSyncEnabled: _enableSmsSync,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(Copy.appName, style: TypeScale.caption(t.inkSoft)),
              const SizedBox(height: Space.x8),
              Expanded(child: _body(t)),
              Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: GhostButton(
                        label: Copy.back,
                        onPressed: () => setState(() => _page -= 1),
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: Space.x3),
                  Expanded(
                    child: PrimaryButton(
                      label: _page == 3
                          ? Copy.getStarted
                          : (_page == 2 && !_enableEmailSync && !_enableSmsSync ? 'Skip for now' : Copy.next),
                      onPressed: () async {
                        if (_page == 2) {
                          if (_enableSmsSync) {
                            final hasPerm = await ref.read(smsSyncServiceProvider).hasPermission();
                            if (!hasPerm) {
                              await ref.read(smsSyncServiceProvider).requestPermission();
                            }
                          }
                          if (_enableEmailSync) {
                            final email = _emailController.text.trim();
                            final pwd = _appPasswordController.text.trim();
                            if (email.isNotEmpty && pwd.isEmpty) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter your Google App Password or turn off email sync to skip.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                              return;
                            }
                          }
                        }
                        if (_page < 3) {
                          setState(() => _page += 1);
                        } else {
                          await _finish();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(PaperTokens t) {
    switch (_page) {
      case 0:
        return _step(
          t,
          Copy.onboardingTitle1,
          Copy.onboardingBody1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmountDisplay(value: _stipend),
              const SizedBox(height: Space.x4),
              Wrap(
                spacing: Space.x2,
                children: [
                  for (final r in [2000, 2500, 3000])
                    LedgerChip(
                      label: Money.formatPaise(r * 100),
                      selected: _stipend.paiseTotal == r * 100,
                      onTap: () => setState(() => _stipend = AmountValue.fromPaise(r * 100)),
                    ),
                ],
              ),
              const SizedBox(height: Space.x4),
              AmountPad(value: _stipend, onChanged: (v) => setState(() => _stipend = v)),
            ],
          ),
        );
      case 1:
        return _step(
          t,
          Copy.onboardingTitle2,
          Copy.onboardingBody2,
          Wrap(
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              for (final d in [1, 5, 10, 15, 20, 25])
                LedgerChip(
                  label: _ordinal(d),
                  selected: _startDay == d,
                  onTap: () => setState(() => _startDay = d),
                ),
            ],
          ),
        );
      case 2:
        return _step(
          t,
          'Auto-detect bank & UPI spends?',
          'Pocket runs 100% locally on your phone. Choose how to automatically capture spends — via instant SMS (recommended in India) or Bank Email alerts.',
          _buildAutoSyncStep(t),
        );
      default:
        return _step(t, Copy.onboardingTitle3, Copy.onboardingBody3, const SizedBox.shrink());
    }
  }

  Widget _buildAutoSyncStep(PaperTokens t) {
    final banks = BankPresets.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Option 1: Direct SMS Auto-Sync
        Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _enableSmsSync ? t.accent : t.rule,
              width: _enableSmsSync ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sms_rounded, size: 20, color: t.accent),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Direct SMS Auto-Sync',
                              style: TypeScale.heading(t.ink).copyWith(fontSize: 15),
                            ),
                            const SizedBox(width: 6),
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
                        const SizedBox(height: 2),
                        Text(
                          'Instant UPI & bank debit alert tracker',
                          style: TypeScale.caption(t.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _enableSmsSync,
                    activeThumbColor: t.paper,
                    activeTrackColor: t.accent,
                    onChanged: (v) {
                      setState(() => _enableSmsSync = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Auto-detects spends from GPay, PhonePe, Paytm, Slice, HDFC, SBI & all banks instantly from on-device SMS. Zero passwords needed.',
                style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: Space.x3),

        // Option 2: Bank Email Auto-Sync
        Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _enableEmailSync ? t.accent : t.rule,
              width: _enableEmailSync ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_rounded, size: 20, color: t.accent),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank Email Auto-Sync',
                          style: TypeScale.heading(t.ink).copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Local IMAP via Google App Password',
                          style: TypeScale.caption(t.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _enableEmailSync,
                    activeThumbColor: t.paper,
                    activeTrackColor: t.accent,
                    onChanged: (v) {
                      setState(() => _enableEmailSync = v);
                    },
                  ),
                ],
              ),
              if (_enableEmailSync) ...[
                const SizedBox(height: Space.x3),
                Divider(color: t.rule, height: 1),
                const SizedBox(height: Space.x3),
                Text('Gmail address', style: TypeScale.caption(t.inkSoft)),
                const SizedBox(height: Space.x1),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TypeScale.body(t.ink),
                  decoration: InputDecoration(
                    hintText: 'yourname@gmail.com',
                    hintStyle: TypeScale.body(t.inkSoft.withAlpha(150)),
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 18, color: t.inkSoft),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x3),
                    filled: true,
                    fillColor: t.paper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: Space.x3),
                Text('Google App Password', style: TypeScale.caption(t.inkSoft)),
                const SizedBox(height: Space.x1),
                TextField(
                  controller: _appPasswordController,
                  obscureText: _obscurePassword,
                  style: TypeScale.body(t.ink),
                  decoration: InputDecoration(
                    hintText: '16-character App Password',
                    hintStyle: TypeScale.body(t.inkSoft.withAlpha(150)),
                    prefixIcon: Icon(Icons.password_rounded, size: 18, color: t.inkSoft),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: t.inkSoft,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x3),
                    filled: true,
                    fillColor: t.paper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: Space.x2),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: t.inkSoft),
                    const SizedBox(width: Space.x1),
                    Expanded(
                      child: Text(
                        'Stored encrypted on this device.',
                        style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showAppPasswordGuideSheet(context, t),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline_rounded, size: 13, color: t.accent),
                          const SizedBox(width: 4),
                          Text(
                            'How to create?',
                            style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.x3),
                Text('Bank alert email IDs or domains (tap chip or type below):', style: TypeScale.caption(t.inkSoft)),
                const SizedBox(height: Space.x2),
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final b in banks)
                      LedgerChip(
                        label: b.displayName,
                        selected: _sendersController.text.contains(b.senders.first),
                        onTap: () {
                          setState(() {
                            final current = _sendersController.text
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
                            _sendersController.text = current.join(', ');
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: Space.x2),
                TextField(
                  controller: _sendersController,
                  maxLines: 2,
                  style: TypeScale.body(t.ink).copyWith(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. alerts@hdfcbank.net, sbi.co.in, slice',
                    hintStyle: TypeScale.caption(t.inkSoft.withAlpha(150)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
                    filled: true,
                    fillColor: t.paper,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.rule),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.accent, width: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _step(PaperTokens t, String title, String body, Widget child) {
    return ListView(
      children: [
        Text(title, style: TypeScale.title(t.ink)),
        const SizedBox(height: Space.x3),
        Text(body, style: TypeScale.body(t.inkSoft)),
        const SizedBox(height: Space.x6),
        child,
      ],
    );
  }

  String _ordinal(int d) {
    if (d == 1) return '1st';
    if (d == 2) return '2nd';
    if (d == 3) return '3rd';
    return '${d}th';
  }
}
