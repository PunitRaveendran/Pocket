import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/models.dart';
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
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final ledger = ref.watch(ledgerProvider);
    final appThemeMode = ledger.value?.settings.appThemeMode ?? AppThemeMode.system;

    final Brightness activeBrightness;
    final PaperTokens tokens;
    final ThemeMode themeMode;
    switch (appThemeMode) {
      case AppThemeMode.system:
        activeBrightness = systemBrightness;
        tokens = activeBrightness == Brightness.dark ? PaperTokens.dark : PaperTokens.light;
        themeMode = ThemeMode.system;
      case AppThemeMode.dune:
        tokens = PaperTokens.dune;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.duneNight:
        tokens = PaperTokens.duneNight;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.sakura:
        tokens = PaperTokens.sakura;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.sakuraNight:
        tokens = PaperTokens.sakuraNight;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.sakuraNoir:
        tokens = PaperTokens.sakuraNoir;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.linen:
        tokens = PaperTokens.linen;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.seafoam:
        tokens = PaperTokens.seafoam;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.paperwhite:
        tokens = PaperTokens.paperwhite;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.paperblack:
        tokens = PaperTokens.paperblack;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.champagne:
        tokens = PaperTokens.champagne;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.graphite:
        tokens = PaperTokens.graphite;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.moss:
        tokens = PaperTokens.moss;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.light:
        tokens = PaperTokens.light;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.dark:
        tokens = PaperTokens.dark;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.velvet:
        tokens = PaperTokens.velvet;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.oatMilk:
        tokens = PaperTokens.oatMilk;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.rosePine:
        tokens = PaperTokens.rosePine;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.eucalyptus:
        tokens = PaperTokens.eucalyptus;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.matcha:
        tokens = PaperTokens.matcha;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.espresso:
        tokens = PaperTokens.espresso;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.nordic:
        tokens = PaperTokens.nordic;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.pine:
        tokens = PaperTokens.pine;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.lavender:
        tokens = PaperTokens.lavender;
        activeBrightness = Brightness.light;
        themeMode = ThemeMode.light;
      case AppThemeMode.amber:
        tokens = PaperTokens.amber;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
      case AppThemeMode.oled || AppThemeMode.cyberpunk:
        tokens = PaperTokens.velvet;
        activeBrightness = Brightness.dark;
        themeMode = ThemeMode.dark;
    }

    return TokenScope(
      tokens: tokens,
      child: MaterialApp(
        title: 'Pocket',
        debugShowCheckedModeBanner: false,
        theme: PocketTheme.of(Brightness.light, tokens),
        darkTheme: PocketTheme.of(Brightness.dark, tokens),
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
          data: (data) => data.settings.onboarded
              ? const AuthGate(child: AppShell())
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
