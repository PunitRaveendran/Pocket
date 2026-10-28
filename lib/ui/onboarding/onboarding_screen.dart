import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
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

  Future<void> _finish() async {
    await ref.read(ledgerProvider.notifier).completeOnboarding(
          stipendPaise: _stipend.paiseTotal <= 0 ? 250000 : _stipend.paiseTotal,
          cycleStartDay: _startDay,
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
                      label: _page == 2 ? Copy.getStarted : Copy.next,
                      onPressed: () {
                        if (_page < 2) {
                          setState(() => _page += 1);
                        } else {
                          _finish();
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
      default:
        return _step(t, Copy.onboardingTitle3, Copy.onboardingBody3, const SizedBox.shrink());
    }
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
