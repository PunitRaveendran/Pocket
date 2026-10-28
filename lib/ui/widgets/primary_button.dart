import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final child = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: onPressed == null ? t.rule : t.accent,
        borderRadius: BorderRadius.circular(Space.controlRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Space.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x6),
            child: Center(
              child: Text(
                label,
                style: TypeScale.heading(onPressed == null ? t.inkSoft : t.paper),
              ),
            ),
          ),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Space.controlRadius),
          side: BorderSide(color: t.rule),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Space.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x6),
            child: Center(child: Text(label, style: TypeScale.heading(t.ink))),
          ),
        ),
      ),
    );
  }
}
