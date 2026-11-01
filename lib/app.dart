import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/biometrics.dart';
import 'data/models.dart';
import 'state/ledger.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/widgets/lock_screen.dart';

class PocketApp extends ConsumerStatefulWidget {
  const PocketApp({super.key});

  @override
  ConsumerState<PocketApp> createState() => _PocketAppState();
}

class _PocketAppState extends ConsumerState<PocketApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Re-lock when app moves to background
      final ledger = ref.read(ledgerProvider).valueOrNull;
      if (ledger?.settings.biometricEnabled == true) {
        if (_isUnlocked) {
          setState(() {
            _isUnlocked = false;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      final ledger = ref.read(ledgerProvider).valueOrNull;
      if (ledger?.settings.biometricEnabled == true && !_isUnlocked && !_isAuthenticating) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      final success = await BiometricService.instance.authenticate(
        reason: 'Unlock Pocket to access your ledger',
      );
      if (mounted && success) {
        setState(() {
          _isUnlocked = true;
        });
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final ledger = ref.watch(ledgerProvider);
    final appThemeMode = ledger.value?.settings.appThemeMode ?? AppThemeMode.system;

    final Brightness activeBrightness;
    final ThemeMode themeMode;
    switch (appThemeMode) {
      case AppThemeMode.dark:
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.light:
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.system:
        activeBrightness = systemBrightness;
        themeMode = ThemeMode.system;
    }

    final tokens = activeBrightness == Brightness.dark ? PaperTokens.dark : PaperTokens.light;

    return TokenScope(
      tokens: tokens,
      child: MaterialApp(
        title: 'Pocket',
        debugShowCheckedModeBanner: false,
        theme: PocketTheme.of(Brightness.light),
        darkTheme: PocketTheme.of(Brightness.dark),
        themeMode: themeMode,
        scrollBehavior: const PocketScrollBehavior(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  activeBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
              statusBarBrightness:
                  activeBrightness == Brightness.dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  activeBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
              systemNavigationBarContrastEnforced: false,
              systemStatusBarContrastEnforced: false,
            ),
            child: MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
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
          data: (data) {
            if (!data.settings.onboarded) {
              return const OnboardingScreen();
            }
            if (data.settings.biometricEnabled && !_isUnlocked) {
              return LockScreen(
                onUnlock: _authenticate,
              );
            }
            return const AppShell();
          },
        ),
      ),
    );
  }
}
