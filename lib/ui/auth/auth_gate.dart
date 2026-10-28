import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/biometrics.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/primary_button.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      if (paused != null && DateTime.now().difference(paused).inSeconds > 60) {
        final biometricEnabled = ref.read(ledgerProvider).valueOrNull?.settings.biometricEnabled ?? false;
        if (biometricEnabled && mounted) {
          setState(() => _unlocked = false);
          _checkAuth();
        }
      }
    }
  }

  Future<void> _checkAuth() async {
    final ledger = ref.read(ledgerProvider).valueOrNull;
    if (ledger == null || !ledger.settings.biometricEnabled) {
      if (mounted) setState(() => _unlocked = true);
      return;
    }

    final success = await BiometricService.instance.authenticate();
    if (mounted && success) {
      setState(() => _unlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final enabled = ledger?.settings.biometricEnabled ?? false;

    if (!enabled || _unlocked) {
      return widget.child;
    }

    final t = TokenScope.of(context);

    return Scaffold(
      backgroundColor: t.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: Space.x8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.fingerprint_rounded, size: 64, color: t.accent),
              const SizedBox(height: Space.x4),
              Text(
                'P O C K E T',
                textAlign: TextAlign.center,
                style: TypeScale.heading(t.inkSoft).copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Pocket is Locked',
                textAlign: TextAlign.center,
                style: TypeScale.title(t.ink),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Unlock with fingerprint, face recognition, or your device PIN to view your ledger.',
                textAlign: TextAlign.center,
                style: TypeScale.caption(t.inkSoft),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Unlock Pocket',
                onPressed: _checkAuth,
              ),
              const SizedBox(height: Space.x4),
            ],
          ),
        ),
      ),
    );
  }
}
