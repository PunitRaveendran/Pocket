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

  /// True for dark themes. Handy for ThemeData brightness and status bar style.
  bool get isDark => paper.computeLuminance() < 0.5;

  // ───────────────────────── Dune (sand + terracotta) ─────────────────────────

  static const dune = PaperTokens(
    paper: Color(0xFFF7F3EB),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE6DEC9),
    ink: Color(0xFF2B2118),
    inkSoft: Color(0xFF736152),
    accent: Color(0xFFC85A32),
    accentTint: Color(0xFFF8EBE5),
    over: Color(0xFFB93826),
    overTint: Color(0xFFFBECE9),
    caution: Color(0xFFC68A1B),
  );

  static const duneNight = PaperTokens(
    paper: Color(0xFF16110D),
    card: Color(0xFF201914),
    rule: Color(0xFF342A21),
    ink: Color(0xFFF5ECE0),
    inkSoft: Color(0xFFB3A391),
    accent: Color(0xFFE08A5C),
    accentTint: Color(0xFF3A2216),
    over: Color(0xFFEF6B6B),
    overTint: Color(0xFF381C1C),
    caution: Color(0xFFE6BD5E),
  );

  // ───────────────────────── Sakura (blush + rose) ────────────────────────────

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

  /// Soft plum-tinted dark, lifted pink accent.
  static const sakuraNight = PaperTokens(
    paper: Color(0xFF171115),
    card: Color(0xFF21191E),
    rule: Color(0xFF33262D),
    ink: Color(0xFFF7EAEE),
    inkSoft: Color(0xFFB39AA4),
    accent: Color(0xFFEF9AB4),
    accentTint: Color(0xFF3A1D29),
    over: Color(0xFFFF7A66),
    overTint: Color(0xFF3A1D1A),
    caution: Color(0xFFE8B45A),
  );

  /// Near-black with a hot-pink accent. Best on OLED.
  static const sakuraNoir = PaperTokens(
    paper: Color(0xFF0C0709),
    card: Color(0xFF160E11),
    rule: Color(0xFF2A1B21),
    ink: Color(0xFFFAEFF2),
    inkSoft: Color(0xFFA68C96),
    accent: Color(0xFFF0709A),
    accentTint: Color(0xFF35121F),
    over: Color(0xFFFF7B5C),
    overTint: Color(0xFF371A12),
    caution: Color(0xFFF2C15C),
  );

  // ───────────────────────── Light, cool and clean ────────────────────────────

  /// Warm off-white with a deep ink-blue accent.
  static const linen = PaperTokens(
    paper: Color(0xFFF6F3EE),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE3DDD2),
    ink: Color(0xFF1B1D24),
    inkSoft: Color(0xFF5C6070),
    accent: Color(0xFF2E4A7D),
    accentTint: Color(0xFFE3E9F4),
    over: Color(0xFFA8382E),
    overTint: Color(0xFFF6E3E0),
    caution: Color(0xFF8A5A0B),
  );

  /// Airy cool-green white with a deep teal accent.
  static const seafoam = PaperTokens(
    paper: Color(0xFFF2F8F7),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFD9E8E5),
    ink: Color(0xFF11211F),
    inkSoft: Color(0xFF4E6764),
    accent: Color(0xFF0F766E),
    accentTint: Color(0xFFDAF0ED),
    over: Color(0xFFB4382C),
    overTint: Color(0xFFFAE5E2),
    caution: Color(0xFF8F5F0C),
  );

  // ───────────────────────── Monochrome pair ──────────────────────────────────

  /// Editorial monochrome light, near-black accent.
  static const paperwhite = PaperTokens(
    paper: Color(0xFFFAFAF9),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE7E5E4),
    ink: Color(0xFF1C1917),
    inkSoft: Color(0xFF6B6661),
    accent: Color(0xFF292524),
    accentTint: Color(0xFFEFEDEA),
    over: Color(0xFFB42318),
    overTint: Color(0xFFFBE9E6),
    caution: Color(0xFF8A5A0B),
  );

  /// Exact inverse of Paperwhite. Monochrome dark, near-white accent.
  static const paperblack = PaperTokens(
    paper: Color(0xFF0C0A09),
    card: Color(0xFF151311),
    rule: Color(0xFF292524),
    ink: Color(0xFFFAFAF9),
    inkSoft: Color(0xFFA8A29E),
    accent: Color(0xFFFAFAF9),
    accentTint: Color(0xFF262321),
    over: Color(0xFFF2766B),
    overTint: Color(0xFF2E1512),
    caution: Color(0xFFE5B95C),
  );

  // ───────────────────────── Dark, character themes ───────────────────────────

  /// Warm charcoal with muted gold.
  static const champagne = PaperTokens(
    paper: Color(0xFF121110),
    card: Color(0xFF1B1A17),
    rule: Color(0xFF2E2C26),
    ink: Color(0xFFF3EEE2),
    inkSoft: Color(0xFFA8A190),
    accent: Color(0xFFD9BC7A),
    accentTint: Color(0xFF332B16),
    over: Color(0xFFE5806F),
    overTint: Color(0xFF371E1A),
    caution: Color(0xFFE9A94F),
  );

  /// Neutral minimal dark with an ice-blue accent.
  static const graphite = PaperTokens(
    paper: Color(0xFF101113),
    card: Color(0xFF18191C),
    rule: Color(0xFF26282D),
    ink: Color(0xFFEDEEF0),
    inkSoft: Color(0xFF8B8E96),
    accent: Color(0xFFC9D2E3),
    accentTint: Color(0xFF20242C),
    over: Color(0xFFF07178),
    overTint: Color(0xFF341B1D),
    caution: Color(0xFFE5B95C),
  );

  /// Earthy olive-black with a fresh green accent.
  static const moss = PaperTokens(
    paper: Color(0xFF12150F),
    card: Color(0xFF1A1F16),
    rule: Color(0xFF2B3224),
    ink: Color(0xFFEDF0E4),
    inkSoft: Color(0xFF9AA58C),
    accent: Color(0xFFA8C97A),
    accentTint: Color(0xFF26331A),
    over: Color(0xFFE8806C),
    overTint: Color(0xFF371E19),
    caution: Color(0xFFE6BE5A),
  );

  // ───────────────────────── Originals ────────────────────────────────────────

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
    paper: Color(0xFF141416),
    card: Color(0xFF1E1E22),
    rule: Color(0xFF2C2C32),
    ink: Color(0xFFF1EDE4),
    inkSoft: Color(0xFFA39D90),
    accent: Color(0xFF7EBFA0),
    accentTint: Color(0xFF1A2A22),
    over: Color(0xFFE58878),
    overTint: Color(0xFF2C1C1A),
    caution: Color(0xFFE0B256),
  );

  static const velvet = PaperTokens(
    paper: Color(0xFF1E1E2E),
    card: Color(0xFF28283D),
    rule: Color(0xFF3B3B54),
    ink: Color(0xFFCDD6F4),
    inkSoft: Color(0xFFA6ADC8),
    accent: Color(0xFF94E2D5),
    accentTint: Color(0xFF203838),
    over: Color(0xFFF38BA8),
    overTint: Color(0xFF381F28),
    caution: Color(0xFFF9E2AF),
  );

  static const oatMilk = PaperTokens(
    paper: Color(0xFFFAF7F2),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE8E2D8),
    ink: Color(0xFF2B2421),
    inkSoft: Color(0xFF6B625E),
    accent: Color(0xFF4A705B),
    accentTint: Color(0xFFE2EBE5),
    over: Color(0xFFA8483B),
    overTint: Color(0xFFF8E7E5),
    caution: Color(0xFFB87828),
  );

  static const rosePine = PaperTokens(
    paper: Color(0xFF232136),
    card: Color(0xFF2A273F),
    rule: Color(0xFF3E3A59),
    ink: Color(0xFFE0DEF4),
    inkSoft: Color(0xFF908CAA),
    accent: Color(0xFFEBBCBA),
    accentTint: Color(0xFF38262E),
    over: Color(0xFFEB6F92),
    overTint: Color(0xFF3B1D28),
    caution: Color(0xFFF6C177),
  );

  static const eucalyptus = PaperTokens(
    paper: Color(0xFF171E1B),
    card: Color(0xFF212A26),
    rule: Color(0xFF323E38),
    ink: Color(0xFFE3ECE7),
    inkSoft: Color(0xFF8CA196),
    accent: Color(0xFF6EA58B),
    accentTint: Color(0xFF1D3329),
    over: Color(0xFFE57373),
    overTint: Color(0xFF361E1E),
    caution: Color(0xFFE5B760),
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

  static const pine = PaperTokens(
    paper: Color(0xFF0A130F),
    card: Color(0xFF131F19),
    rule: Color(0xFF23362C),
    ink: Color(0xFFECFDF5),
    inkSoft: Color(0xFF829E91),
    accent: Color(0xFF34D399),
    accentTint: Color(0xFF0F3928),
    over: Color(0xFFF87171),
    overTint: Color(0xFF381A1A),
    caution: Color(0xFFFBBF24),
  );

  static const lavender = PaperTokens(
    paper: Color(0xFFF8F6FC),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFE7E1F2),
    ink: Color(0xFF1F1A2C),
    inkSoft: Color(0xFF685C82),
    accent: Color(0xFF7C3AED),
    accentTint: Color(0xFFF0EAFE),
    over: Color(0xFFBE185D),
    overTint: Color(0xFFFCE7F3),
    caution: Color(0xFFB45309),
  );

  static const amber = PaperTokens(
    paper: Color(0xFF111113),
    card: Color(0xFF1C1C20),
    rule: Color(0xFF2E2E36),
    ink: Color(0xFFFDFBF7),
    inkSoft: Color(0xFF9E9EA8),
    accent: Color(0xFFF59E0B),
    accentTint: Color(0xFF382300),
    over: Color(0xFFEF4444),
    overTint: Color(0xFF3B1212),
    caution: Color(0xFFFBBF24),
  );

  /// All themes by display name, in picker order.
  static const all = <String, PaperTokens>{
    'Dune': dune,
    'Dune Night': duneNight,
    'Sakura': sakura,
    'Sakura Night': sakuraNight,
    'Sakura Noir': sakuraNoir,
    'Linen': linen,
    'Seafoam': seafoam,
    'Paperwhite': paperwhite,
    'Paperblack': paperblack,
    'Champagne': champagne,
    'Graphite': graphite,
    'Moss': moss,
    'Light': light,
    'Dark': dark,
    'Velvet': velvet,
    'Oat Milk': oatMilk,
    'Rose Pine': rosePine,
    'Eucalyptus': eucalyptus,
    'Matcha': matcha,
    'Espresso': espresso,
    'Nordic': nordic,
    'Pine': pine,
    'Lavender': lavender,
    'Amber': amber,
  };
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
