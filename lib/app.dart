import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/ledger.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/auth/auth_gate.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell.dart';

class PocketApp extends ConsumerWidget {
  const PocketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final tokens = brightness == Brightness.dark ? PaperTokens.dark : PaperTokens.light;
    final ledger = ref.watch(ledgerProvider);

    return TokenScope(
      tokens: tokens,
      child: MaterialApp(
        title: 'Pocket',
        debugShowCheckedModeBanner: false,
        theme: PocketTheme.of(Brightness.light),
        darkTheme: PocketTheme.of(Brightness.dark),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1).clamp(1.0, 2.0))),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: ledger.when(
          loading: () => Scaffold(
            backgroundColor: tokens.paper,
            body: const SizedBox.shrink(),
          ),
          error: (e, _) => Scaffold(
            backgroundColor: tokens.paper,
            body: Center(child: Text('$e')),
          ),
          data: (data) => data.settings.onboarded ? const AuthGate(child: AppShell()) : const OnboardingScreen(),
        ),
      ),
    );
  }
}
