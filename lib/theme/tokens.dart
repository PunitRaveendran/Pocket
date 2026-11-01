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
    paper: Color(0xFF0C0C0B),
    card: Color(0xFF161614),
    rule: Color(0xFF262521),
    ink: Color(0xFFF1EDE4),
    inkSoft: Color(0xFFA39D90),
    accent: Color(0xFF86CCA7),
    accentTint: Color(0xFF182920),
    over: Color(0xFFE58878),
    overTint: Color(0xFF2C1C1A),
    caution: Color(0xFFE0B256),
  );

  static const matcha = PaperTokens(
    paper: Color(0xFFF3F6F1),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFDCE4D8),
    ink: Color(0xFF1B241A),
    inkSoft: Color(0xFF536652),
    accent: Color(0xFF2C6E49),
    accentTint: Color(0xFFDDF0E5),
    over: Color(0xFFA83A2E),
    overTint: Color(0xFFF8E5E2),
    caution: Color(0xFF966E14),
  );

  static const espresso = PaperTokens(
    paper: Color(0xFF181412),
    card: Color(0xFF241F1C),
    rule: Color(0xFF38312B),
    ink: Color(0xFFF6EDE7),
    inkSoft: Color(0xFFB8A99F),
    accent: Color(0xFFD4A373),
    accentTint: Color(0xFF382618),
    over: Color(0xFFE57373),
    overTint: Color(0xFF361C1C),
    caution: Color(0xFFE6B86A),
  );

  static const nordic = PaperTokens(
    paper: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    rule: Color(0xFF334155),
    ink: Color(0xFFF8FAFC),
    inkSoft: Color(0xFF94A3B8),
    accent: Color(0xFF38BDF8),
    accentTint: Color(0xFF0C384E),
    over: Color(0xFFF87171),
    overTint: Color(0xFF3B1818),
    caution: Color(0xFFFBBF24),
  );

  static const sakura = PaperTokens(
    paper: Color(0xFFFDF7F8),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFEEDADB),
    ink: Color(0xFF26191C),
    inkSoft: Color(0xFF6F5158),
    accent: Color(0xFFB84568),
    accentTint: Color(0xFFFCE1E8),
    over: Color(0xFFB83030),
    overTint: Color(0xFFFDE4E4),
    caution: Color(0xFF8A5A0B),
  );

  static const oled = PaperTokens(
    paper: Color(0xFF000000),
    card: Color(0xFF111111),
    rule: Color(0xFF222222),
    ink: Color(0xFFFFFFFF),
    inkSoft: Color(0xFF8E8E93),
    accent: Color(0xFF00E676),
    accentTint: Color(0xFF0A2914),
    over: Color(0xFFFF5252),
    overTint: Color(0xFF2E0D0D),
    caution: Color(0xFFFFD600),
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
