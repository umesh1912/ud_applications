import 'package:flutter/material.dart';

/// Valence design tokens.
///
/// Concept: a lab notebook. Cool paper with a faint graph grid, blueprint
/// ink, one highlighter yellow for "this matters", and one reagent colour per
/// subject. Subjects are drawn as periodic-table element tiles.
class Palette {
  Palette._();

  // Base — light
  static const paper = Color(0xFFF5F7F2); // cool, slightly green paper
  static const sheet = Color(0xFFFFFFFF); // raised surfaces
  static const ink = Color(0xFF16233F); // blueprint navy, primary text
  static const graphite = Color(0xFF576178); // secondary text
  static const rule = Color(0xFFD9DFE8); // grid lines, borders

  // Base — dark ("blackboard")
  static const paperDark = Color(0xFF0F1626);
  static const sheetDark = Color(0xFF172036);
  static const inkDark = Color(0xFFE7ECF6);
  static const graphiteDark = Color(0xFF9BA6BD);
  static const ruleDark = Color(0xFF26314C);

  // Signature
  static const highlighter = Color(0xFFFFE45C);
  static const highlighterInk = Color(0xFF3D3300);

  // Reagents — one per subject
  static const physics = Color(0xFF2F5BEA); // cobalt
  static const chemistry = Color(0xFFDB8400); // sodium flame
  static const biology = Color(0xFF23955A); // chlorophyll
  static const maths = Color(0xFFC2307A); // fuchsine stain
  static const computer = Color(0xFF0E8A9A); // copper-sulphate teal

  // Feedback
  static const correct = Color(0xFF1F8A4C);
  static const wrong = Color(0xFFC8372D);
  static const review = Color(0xFF7B4FD6);
}

/// 4-pt spacing scale.
class Space {
  Space._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20; // screen side padding
}

/// Radii encode hierarchy: element tiles are nearly square like a printed
/// periodic table; cards are softer; sheets are softest; chips are pills.
class Radii {
  Radii._();
  static const double tile = 6;
  static const double card = 14;
  static const double sheet = 24;
  static const double pill = 999;
}

class Motion {
  Motion._();
  static const quick = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const curve = Curves.easeOutCubic;
}

/// Theme-aware colours that Material's ColorScheme doesn't name.
@immutable
class ValenceColors extends ThemeExtension<ValenceColors> {
  const ValenceColors({
    required this.paper,
    required this.sheet,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.highlight,
    required this.highlightInk,
  });

  final Color paper;
  final Color sheet;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color highlight;
  final Color highlightInk;

  static const light = ValenceColors(
    paper: Palette.paper,
    sheet: Palette.sheet,
    ink: Palette.ink,
    muted: Palette.graphite,
    rule: Palette.rule,
    highlight: Palette.highlighter,
    highlightInk: Palette.highlighterInk,
  );

  static const dark = ValenceColors(
    paper: Palette.paperDark,
    sheet: Palette.sheetDark,
    ink: Palette.inkDark,
    muted: Palette.graphiteDark,
    rule: Palette.ruleDark,
    highlight: Color(0xFFE9CF3A),
    highlightInk: Color(0xFF231D00),
  );

  @override
  ValenceColors copyWith({
    Color? paper,
    Color? sheet,
    Color? ink,
    Color? muted,
    Color? rule,
    Color? highlight,
    Color? highlightInk,
  }) {
    return ValenceColors(
      paper: paper ?? this.paper,
      sheet: sheet ?? this.sheet,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      rule: rule ?? this.rule,
      highlight: highlight ?? this.highlight,
      highlightInk: highlightInk ?? this.highlightInk,
    );
  }

  @override
  ValenceColors lerp(ThemeExtension<ValenceColors>? other, double t) {
    if (other is! ValenceColors) return this;
    return ValenceColors(
      paper: Color.lerp(paper, other.paper, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      highlightInk: Color.lerp(highlightInk, other.highlightInk, t)!,
    );
  }
}

extension ValenceContext on BuildContext {
  ValenceColors get vc => Theme.of(this).extension<ValenceColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
}
