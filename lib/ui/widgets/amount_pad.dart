import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class AmountValue {
  const AmountValue({required this.rupeeDigits, required this.paise});
  final String rupeeDigits;
  final int paise;

  int get paiseTotal => Money.fromDigitsAndPaise(rupeeDigits, paise);

  static AmountValue fromPaise(int paise) {
    return AmountValue(rupeeDigits: '${paise ~/ 100}', paise: paise % 100);
  }
}

class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.value, this.large = true});
  final AmountValue value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final rupees = int.tryParse(value.rupeeDigits) ?? 0;
    final grouped = Money.groupRupees(rupees);
    final paise = value.paise.toString().padLeft(2, '0');
    final text = '₹$grouped.$paise';
    return Semantics(
      liveRegion: true,
      value: Money.spokenRupees(value.paiseTotal),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: large ? TypeScale.figure(t.ink) : TypeScale.title(t.ink),
        ),
      ),
    );
  }
}

class AmountPad extends StatelessWidget {
  const AmountPad({super.key, required this.value, required this.onChanged});

  final AmountValue value;
  final ValueChanged<AmountValue> onChanged;

  void _digit(String d) {
    HapticFeedback.selectionClick();
    var digits = value.rupeeDigits;
    if (digits.length >= 7) return;
    if (digits == '0') {
      digits = d;
    } else {
      digits = digits + d;
    }
    onChanged(AmountValue(rupeeDigits: digits, paise: value.paise));
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    if (value.rupeeDigits.length <= 1) {
      onChanged(const AmountValue(rupeeDigits: '0', paise: 0));
      return;
    }
    onChanged(AmountValue(
      rupeeDigits: value.rupeeDigits.substring(0, value.rupeeDigits.length - 1),
      paise: value.paise,
    ));
  }

  void _addQuick(int addRupees) {
    HapticFeedback.selectionClick();
    final current = int.tryParse(value.rupeeDigits) ?? 0;
    final updated = current + addRupees;
    if (updated > 999999) return;
    onChanged(AmountValue(rupeeDigits: '$updated', paise: value.paise));
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final quickPresets = [10, 20, 50, 100];
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              for (final p in quickPresets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        side: BorderSide(color: t.rule),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: t.card,
                        foregroundColor: t.inkSoft,
                      ),
                      onPressed: () => _addQuick(p),
                      child: Text('+₹$p', style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (final row in keys)
          Row(
            children: [
              for (final k in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: k.isEmpty
                        ? const SizedBox(height: 52)
                        : _Key(
                            label: k,
                            color: t.ink,
                            soft: t.inkSoft,
                            tint: t.accentTint,
                            onTap: k == '⌫' ? _backspace : () => _digit(k),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.color,
    required this.soft,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color soft;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Space.controlRadius),
        splashColor: tint,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: TypeScale.heading(label == '⌫' ? soft : color).copyWith(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}
