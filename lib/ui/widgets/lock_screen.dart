import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlock});

  final Future<void> Function() onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUnlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: t.accentTint,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.accent.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Center(
                    child: Icon(Icons.lock_outline_rounded, size: 36, color: t.accent),
                  ),
                ),
                const SizedBox(height: Space.x6),
                Text(
                  'Pocket is locked',
                  style: TypeScale.title(t.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x2),
                Text(
                  'Touch the fingerprint sensor or enter your device PIN to view your ledger.',
                  style: TypeScale.body(t.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x8),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onUnlock();
                  },
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: const Text('Unlock with Biometrics / PIN'),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.paper,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                    ),
                    textStyle: TypeScale.body(t.paper).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
