import 'package:flutter/material.dart';

class PaperTokens {
  const PaperTokens({
    required this.paper,
    required this.card,
    required this.rule,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentTint,
    required this.over,
    required this.overTint,
    required this.caution,
  });

  final Color paper;
  final Color card;
  final Color rule;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color accentTint;
  final Color over;
  final Color overTint;
  final Color caution;

  static const light = PaperTokens(
    paper: Color(0xFFF7F4EC),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE4DFD2),
    ink: Color(0xFF1C1B18),
    inkSoft: Color(0xFF5E5A50),
    accent: Color(0xFF1F5C45),
    accentTint: Color(0xFFE3EEE8),
    over: Color(0xFFA33A2B),
    overTint: Color(0xFFF4E3DF),
    caution: Color(0xFF8A5A0B),
  );

  static const dark = PaperTokens(
    paper: Color(0xFF141412),
    card: Color(0xFF1C1B19),
    rule: Color(0xFF2E2C27),
    ink: Color(0xFFEDE9DF),
    inkSoft: Color(0xFFA8A294),
    accent: Color(0xFF7FBF9F),
    accentTint: Color(0xFF1F2B25),
    over: Color(0xFFE08A7B),
    overTint: Color(0xFF2F1F1C),
    caution: Color(0xFFD9A94E),
  );
}

class Space {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x12 = 48.0;
  static const margin = 20.0;
  static const cardRadius = 12.0;
  static const controlRadius = 8.0;
}

class Motion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 200);
  static const curve = Curves.easeOut;
}
