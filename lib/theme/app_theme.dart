import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

class TypeScale {
  static TextStyle figure(Color color) => TextStyle(
        fontFamily: 'Source Serif 4',
        fontSize: 48,
        height: 52 / 48,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        color: color,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
        letterSpacing: -0.8,
      );

  static TextStyle title(Color color) => TextStyle(
        fontFamily: 'Source Serif 4',
        fontSize: 24,
        height: 30 / 24,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        color: color,
      );

  static TextStyle heading(Color color) => TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 600)],
        color: color,
      );

  static TextStyle body(Color color) => TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        color: color,
      );

  static TextStyle caption(Color color) => TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        color: color,
      );

  static TextStyle money(Color color, {double size = 15, double height = 22 / 15}) =>
      TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: size,
        height: height,
        fontWeight: FontWeight.w400,
        fontVariations: const [FontVariation('wght', 400)],
        color: color,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
      );
}

class PocketTheme {
  static ThemeData of(Brightness brightness) {
    final t = brightness == Brightness.dark ? PaperTokens.dark : PaperTokens.light;
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: t.paper,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.accent,
        onPrimary: brightness == Brightness.dark ? t.paper : const Color(0xFFF7F4EC),
        secondary: t.inkSoft,
        onSecondary: t.paper,
        error: t.over,
        onError: t.paper,
        surface: t.card,
        onSurface: t.ink,
      ),
      textTheme: TextTheme(
        displayLarge: TypeScale.figure(t.ink),
        headlineMedium: TypeScale.title(t.ink),
        titleMedium: TypeScale.heading(t.ink),
        bodyMedium: TypeScale.body(t.ink),
        bodySmall: TypeScale.caption(t.inkSoft),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.paper,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TypeScale.title(t.ink),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: brightness == Brightness.dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
          systemStatusBarContrastEnforced: false,
        ),
      ),
      dividerColor: t.rule,
      splashFactory: NoSplash.splashFactory,
      highlightColor: t.accentTint,
      canvasColor: t.paper,
      cardColor: t.card,
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Space.cardRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Space.cardRadius)),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: TypeScale.body(t.paper),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class TokenScope extends InheritedWidget {
  const TokenScope({super.key, required this.tokens, required super.child});

  final PaperTokens tokens;

  static PaperTokens of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TokenScope>()!.tokens;
  }

  @override
  bool updateShouldNotify(TokenScope oldWidget) => tokens != oldWidget.tokens;
}

class PocketScrollBehavior extends MaterialScrollBehavior {
  const PocketScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
