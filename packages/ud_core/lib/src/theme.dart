import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Paper & Ink" design tokens shared by all UD apps. Each app supplies its
/// own accent colour; everything else stays consistent across the family.
@immutable
class UdTokens extends ThemeExtension<UdTokens> {
  const UdTokens({
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.displayFamily,
  });

  final Color paper;
  final Color card;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color danger;
  final String displayFamily;

  static UdTokens of(BuildContext context) =>
      Theme.of(context).extension<UdTokens>()!;

  @override
  UdTokens copyWith({Color? accent}) => UdTokens(
        paper: paper,
        card: card,
        ink: ink,
        inkSoft: inkSoft,
        inkFaint: inkFaint,
        line: line,
        accent: accent ?? this.accent,
        accentSoft: accentSoft,
        onAccent: onAccent,
        danger: danger,
        displayFamily: displayFamily,
      );

  @override
  UdTokens lerp(ThemeExtension<UdTokens>? other, double t) {
    if (other is! UdTokens) return this;
    return UdTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      displayFamily: t < 0.5 ? displayFamily : other.displayFamily,
    );
  }
}

/// Font pairing per language. Latin text uses Fraunces (display) and
/// Literata (reading); Indian scripts use the matching Noto Serif family so
/// the whole family keeps a serif voice in every language.
class UdFonts {
  static String display(String lang) => switch (lang) {
        'hi' => 'Noto Serif Devanagari',
        'gu' => 'Noto Serif Gujarati',
        _ => 'Fraunces',
      };

  static String body(String lang) => switch (lang) {
        'hi' => 'Noto Serif Devanagari',
        'gu' => 'Noto Serif Gujarati',
        _ => 'Literata',
      };

  /// Families used as fallback so mixed text (e.g. an English file name in a
  /// Hindi screen) still renders in a serif.
  static List<String> fallback() => [
        GoogleFonts.getFont('Literata').fontFamily!,
        GoogleFonts.getFont('Noto Serif Devanagari').fontFamily!,
        GoogleFonts.getFont('Noto Serif Gujarati').fontFamily!,
      ];
}

class UdTheme {
  static ThemeData build({
    required Color accent,
    required Brightness brightness,
    required String lang,
  }) {
    final dark = brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF14130F) : const Color(0xFFF6F1E7);
    final card = dark ? const Color(0xFF1E1C17) : const Color(0xFFFFFCF5);
    final ink = dark ? const Color(0xFFF2ECDF) : const Color(0xFF1D1B16);
    final inkSoft = dark ? const Color(0xFFB9B1A2) : const Color(0xFF5C574D);
    final inkFaint = dark ? const Color(0xFF7A7366) : const Color(0xFF9A9284);
    final line = dark ? const Color(0xFF2E2B24) : const Color(0xFFE4DCCC);
    final acc = dark ? Color.lerp(accent, Colors.white, 0.22)! : accent;
    final accentSoft = Color.alphaBlend(
        acc.withValues(alpha: dark ? 0.18 : 0.12), card);
    const danger = Color(0xFFB3261E);

    final displayFamily = UdFonts.display(lang);
    final bodyFamily = UdFonts.body(lang);
    final fallback = UdFonts.fallback();

    TextStyle d(double size, FontWeight w, {double h = 1.12, double ls = -0.4}) =>
        GoogleFonts.getFont(displayFamily,
                fontSize: size,
                fontWeight: w,
                height: h,
                letterSpacing: lang == 'en' ? ls : 0,
                color: ink)
            .copyWith(fontFamilyFallback: fallback);

    TextStyle b(double size, FontWeight w, {double h = 1.45, Color? c}) =>
        GoogleFonts.getFont(bodyFamily,
                fontSize: size, fontWeight: w, height: h, color: c ?? ink)
            .copyWith(fontFamilyFallback: fallback);

    final textTheme = TextTheme(
      displayLarge: d(54, FontWeight.w600, h: 1.0, ls: -1.6),
      displayMedium: d(42, FontWeight.w600, h: 1.04, ls: -1.2),
      displaySmall: d(34, FontWeight.w600, h: 1.08, ls: -0.9),
      headlineLarge: d(30, FontWeight.w600, ls: -0.7),
      headlineMedium: d(26, FontWeight.w600, ls: -0.5),
      headlineSmall: d(22, FontWeight.w600, ls: -0.3),
      titleLarge: d(20, FontWeight.w600, ls: -0.2),
      titleMedium: b(16, FontWeight.w600, h: 1.3),
      titleSmall: b(14, FontWeight.w600, h: 1.3),
      bodyLarge: b(16, FontWeight.w400),
      bodyMedium: b(14.5, FontWeight.w400),
      bodySmall: b(12.5, FontWeight.w400, c: inkSoft),
      labelLarge: b(15, FontWeight.w600, h: 1.2),
      labelMedium: b(13, FontWeight.w600, h: 1.2),
      labelSmall: b(11.5, FontWeight.w600, h: 1.2, c: inkSoft),
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: acc,
      onPrimary: Colors.white,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: inkSoft,
      outline: line,
      outlineVariant: line,
      error: danger,
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: line,
      iconTheme: IconThemeData(color: ink, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: acc,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(color: line, width: 1.2),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: acc,
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: b(14.5, FontWeight.w500, c: paper),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: line,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      extensions: [
        UdTokens(
          paper: paper,
          card: card,
          ink: ink,
          inkSoft: inkSoft,
          inkFaint: inkFaint,
          line: line,
          accent: acc,
          accentSoft: accentSoft,
          onAccent: Colors.white,
          danger: danger,
          displayFamily: displayFamily,
        ),
      ],
    );
  }
}
