import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/primary_button.dart';

Future<void> showAdjustBalanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const AdjustBalanceSheet(),
  );
}

class AdjustBalanceSheet extends ConsumerStatefulWidget {
  const AdjustBalanceSheet({super.key});

  @override
  ConsumerState<AdjustBalanceSheet> createState() => _AdjustBalanceSheetState();
}

class _AdjustBalanceSheetState extends ConsumerState<AdjustBalanceSheet> {
  late AmountValue _amount;
  bool _initialized = false;
  bool _isFirstDigit = true;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;

    if (ledger == null) return const SizedBox.shrink();

    final today = LocalDate.today();
    final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
    final cycleKey = cycle.start.ymd;
    final hasCycleOverride = ledger.settings.cycleAdjustments.containsKey(cycleKey);
    final rolloverPaise = hasCycleOverride ? 0 : rolloverSavingsFromPreviousCycle(ledger, cycle);
    final currentRemaining = effectiveStipendForCycle(ledger, cycle) - ordinaryThisCycle(ledger, cycle);
    final currentStipendPaise = ledger.settings.stipendPaise;

    if (!_initialized) {
      final initialPaise = currentRemaining >= 0
          ? currentRemaining
          : (currentStipendPaise > 0 ? currentStipendPaise : 100000);
      _amount = AmountValue.fromPaise(initialPaise);
      _isFirstDigit = true;
      _initialized = true;
    }

    final targetPaise = _amount.paiseTotal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x3, Space.margin, Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
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
              const SizedBox(height: Space.x3),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined, size: 20, color: t.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modify Account Balance', style: TypeScale.title(t.ink)),
                        Text(
                          'Directly set your remaining pocket money balance',
                          style: TypeScale.caption(t.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: t.inkSoft),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),

              if (rolloverPaise > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.accentTint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_toggle_off, size: 14, color: t.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Current balance includes ₹${rolloverPaise ~/ 100} unspent rolled over from previous cycle',
                          style: TypeScale.caption(t.accent).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.x2),
              ],

              // Live Amount Display
              Center(child: AmountDisplay(value: _amount)),
              const SizedBox(height: Space.x2),

              // Reassuring explanation (never negative warnings or deduction messages)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                  border: Border.all(color: t.rule),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: t.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        targetPaise == currentRemaining
                            ? 'Matches current remaining balance (${Money.formatPaise(currentRemaining)})'
                            : 'Sets remaining balance directly to ${Money.formatPaise(targetPaise)} with zero spending entries',
                        style: TypeScale.caption(t.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x3),

              // Amount Pad
              AmountPad(
                value: _amount,
                clearOnFirstDigit: _isFirstDigit,
                onFirstDigitCleared: () => setState(() => _isFirstDigit = false),
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x4),

              // Confirm Button
              PrimaryButton(
                label: 'Set Balance to ${Money.formatPaise(targetPaise)}',
                onPressed: () => _applyChange(context, ledger),
              ),
              const SizedBox(height: Space.x2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyChange(BuildContext context, Ledger ledger) async {
    final targetPaise = _amount.paiseTotal;
    if (targetPaise <= 0) return;

    final today = LocalDate.today();
    final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
    final cycleKey = cycle.start.ymd;
    final spentThisCycle = ordinaryThisCycle(ledger, cycle);

    final newAdjustments = Map<String, int>.from(ledger.settings.cycleAdjustments);
    newAdjustments[cycleKey] = targetPaise + spentThisCycle;

    // Ensure base monthly stipend is valid if it was corrupted to <= 6000
    final healedStipend = ledger.settings.stipendPaise <= 6000 || ledger.settings.stipendPaise == targetPaise
        ? targetPaise
        : ledger.settings.stipendPaise;

    await ref.read(ledgerProvider.notifier).updateSettings(
          ledger.settings.copyWith(
            stipendPaise: healedStipend,
            cycleAdjustments: newAdjustments,
          ),
        );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account balance updated to ${Money.formatPaise(targetPaise)}!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
