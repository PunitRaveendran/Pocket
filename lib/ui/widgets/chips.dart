import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class LedgerChip extends StatelessWidget {
  const LedgerChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    return Material(
      color: selected ? t.accentTint : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? t.accent : t.rule),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? t.accent : t.inkSoft),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TypeScale.caption(selected ? t.accent : t.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
