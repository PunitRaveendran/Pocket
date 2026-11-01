import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum BalanceMode {
  currentBalance, // Set current available money in account/wallet
  monthlyStipend, // Set base monthly stipend in settings
}

class AdjustBalanceSheet extends ConsumerStatefulWidget {
  const AdjustBalanceSheet({super.key});

  @override
  ConsumerState<AdjustBalanceSheet> createState() => _AdjustBalanceSheetState();
}

class _AdjustBalanceSheetState extends ConsumerState<AdjustBalanceSheet> {
  BalanceMode _mode = BalanceMode.currentBalance;
  late AmountValue _amount;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;

    if (ledger == null) return const SizedBox.shrink();

    final today = LocalDate.today();
    final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
    final cycleStipend = effectiveStipendForCycle(ledger, cycle);
    final spentThisCycle = ordinaryThisCycle(ledger, cycle);
    final currentRemaining = cycleStipend - spentThisCycle;
    final rolloverPaise = rolloverSavingsFromPreviousCycle(ledger, cycle);

    final currentStipendPaise = ledger.settings.stipendPaise;

    if (!_initialized) {
      final initialPaise = _mode == BalanceMode.currentBalance
          ? (currentRemaining > 0 ? currentRemaining : 0)
          : currentStipendPaise;
      _amount = AmountValue.fromPaise(initialPaise);
      _initialized = true;
    }

    final targetPaise = _amount.paiseTotal;
    final diffPaise = _mode == BalanceMode.currentBalance
        ? targetPaise - currentRemaining
        : targetPaise - currentStipendPaise;

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
                          _mode == BalanceMode.currentBalance
                              ? 'Set your actual remaining pocket money balance'
                              : 'Set your regular monthly pocket money base',
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
              const SizedBox(height: Space.x4),

              // Segmented Mode Selector
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                  border: Border.all(color: t.rule),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mode = BalanceMode.currentBalance;
                            _amount = AmountValue.fromPaise(
                              currentRemaining > 0 ? currentRemaining : 0,
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _mode == BalanceMode.currentBalance ? t.accentTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Remaining Balance',
                            style: TypeScale.caption(
                              _mode == BalanceMode.currentBalance ? t.accent : t.inkSoft,
                            ).copyWith(
                              fontWeight: _mode == BalanceMode.currentBalance ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _mode = BalanceMode.monthlyStipend;
                            _amount = AmountValue.fromPaise(currentStipendPaise);
                          });
                        },
                        borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _mode == BalanceMode.monthlyStipend ? t.accentTint : Colors.transparent,
                            borderRadius: BorderRadius.circular(Space.controlRadius - 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Monthly Stipend',
                            style: TypeScale.caption(
                              _mode == BalanceMode.monthlyStipend ? t.accent : t.inkSoft,
                            ).copyWith(
                              fontWeight: _mode == BalanceMode.monthlyStipend ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (rolloverPaise > 0) ...[
                const SizedBox(height: Space.x2),
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
                          'Includes ₹${rolloverPaise ~/ 100} unspent rolled over from previous cycle',
                          style: TypeScale.caption(t.accent).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.x4),

              // Live Amount Display
              Center(child: AmountDisplay(value: _amount)),
              const SizedBox(height: Space.x2),

              // Comparison note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                  border: Border.all(color: t.rule),
                ),
                child: Row(
                  children: [
                    Icon(
                      diffPaise == 0
                          ? Icons.check_circle_outline
                          : (diffPaise > 0 ? Icons.trending_up : Icons.trending_down),
                      size: 16,
                      color: diffPaise == 0 ? t.inkSoft : (diffPaise > 0 ? t.accent : t.over),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _mode == BalanceMode.currentBalance
                            ? (diffPaise == 0
                                ? 'Matches current remaining monthly balance (${Money.formatPaise(currentRemaining)})'
                                : (diffPaise > 0
                                    ? 'Adjustment: +${Money.formatPaise(diffPaise)} will be added to balance'
                                    : 'Adjustment: -${Money.formatPaise(diffPaise.abs())} will be deducted to balance'))
                            : (diffPaise == 0
                                ? 'Matches current base stipend (${Money.formatPaise(currentStipendPaise)})${rolloverPaise > 0 ? " (+₹${rolloverPaise ~/ 100} rollover active)" : ""}'
                                : 'Will update monthly base from ${Money.formatPaise(currentStipendPaise)} to ${Money.formatPaise(targetPaise)}${rolloverPaise > 0 ? " (+₹${rolloverPaise ~/ 100} rollover stays active)" : ""}'),
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
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x4),

              // Confirm Button
              PrimaryButton(
                label: _mode == BalanceMode.currentBalance
                    ? 'Set Balance to ${Money.formatPaise(targetPaise)}'
                    : 'Save Base Stipend (${Money.formatPaise(targetPaise)})',
                onPressed: () => _applyChange(context, ledger, currentRemaining, currentStipendPaise),
              ),
              const SizedBox(height: Space.x2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyChange(
    BuildContext context,
    Ledger ledger,
    int currentRemaining,
    int currentStipendPaise,
  ) async {
    final targetPaise = _amount.paiseTotal;

    if (_mode == BalanceMode.monthlyStipend) {
      await ref.read(ledgerProvider.notifier).updateSettings(
            ledger.settings.copyWith(stipendPaise: targetPaise),
          );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Monthly base stipend updated to ${Money.formatPaise(targetPaise)}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // BalanceMode.currentBalance: Fix the account amount without reflecting in spending
    final diff = targetPaise - currentRemaining;
    if (diff == 0) {
      Navigator.pop(context);
      return;
    }

    final today = LocalDate.today();
    final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
    final spentThisCycle = ordinaryThisCycle(ledger, cycle);
    final rolloverPaise = rolloverSavingsFromPreviousCycle(ledger, cycle);
    final topUps = extraTopUpForCycle(ledger, cycle);
    final fixedDeductions = ledger.settings.totalFixedDeductionsPaise;

    // Adjust base stipend in settings so the calculated remaining balance
    // exactly equals the user's desired amount, with zero fake spending transactions.
    final newStipendPaise = (targetPaise + spentThisCycle + fixedDeductions - rolloverPaise - topUps)
        .clamp(0, 999999999);

    await ref.read(ledgerProvider.notifier).updateSettings(
          ledger.settings.copyWith(stipendPaise: newStipendPaise),
        );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account balance set to ${Money.formatPaise(targetPaise)}!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
