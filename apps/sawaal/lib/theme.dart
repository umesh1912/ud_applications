import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sawaal design system — "sticker book".
/// Thick ink outlines, hard offset shadows (no blur), chunky rounded type and
/// one bright colour per category. Things you can tap look like stickers you
/// can press: they sink into their shadow when pressed.
class SC extends ThemeExtension<SC> {
  const SC({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.shadow,
    required this.primary,
    required this.onPrimary,
    required this.right,
    required this.wrong,
    required this.lineWidth,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color shadow;
  final Color primary; // tangerine
  final Color onPrimary;
  final Color right;
  final Color wrong;
  final double lineWidth;

  static const light = SC(
    bg: Color(0xFFE4F4EC), // mint paper
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1C1B2E),
    muted: Color(0xFF55536E),
    line: Color(0xFF1C1B2E),
    shadow: Color(0xFF1C1B2E),
    primary: Color(0xFFFF7A2F),
    onPrimary: Color(0xFF1C1B2E),
    right: Color(0xFF2BC46F),
    wrong: Color(0xFFFF5263),
    lineWidth: 2.5,
  );

  static const dark = SC(
    bg: Color(0xFF16152A),
    card: Color(0xFF242341),
    ink: Color(0xFFF3F2FF),
    muted: Color(0xFFB4B2CF),
    line: Color(0xFF0A0A14),
    shadow: Color(0xFF07070F),
    primary: Color(0xFFFF8A45),
    onPrimary: Color(0xFF1C1B2E),
    right: Color(0xFF34D17C),
    wrong: Color(0xFFFF6676),
    lineWidth: 2.5,
  );

  static const contrast = SC(
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    muted: Color(0xFF1A1A1A),
    line: Color(0xFF000000),
    shadow: Color(0xFF000000),
    primary: Color(0xFFFFB000),
    onPrimary: Color(0xFF000000),
    right: Color(0xFF00843D),
    wrong: Color(0xFFC4001A),
    lineWidth: 3.5,
  );

  @override
  SC copyWith() => this;

  @override
  SC lerp(ThemeExtension<SC>? other, double t) => t < 0.5 ? this : (other as SC? ?? this);
}

extension SCX on BuildContext {
  SC get sc => Theme.of(this).extension<SC>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

TextStyle _f(String family, TextStyle s) {
  try {
    return GoogleFonts.getFont(family, textStyle: s);
  } catch (_) {
    return s;
  }
}

/// Baloo 2: round, friendly, and covers Devanagari for Hindi.
/// Mukta: clear Devanagari + Latin body face for long questions.
ThemeData buildTheme(Brightness b, {bool highContrast = false}) {
  final c = highContrast ? SC.contrast : (b == Brightness.dark ? SC.dark : SC.light);
  TextStyle d(double s, FontWeight w, [double h = 1.15]) =>
      _f('Baloo 2', TextStyle(fontSize: s, fontWeight: w, height: h, color: c.ink));
  TextStyle body(double s, FontWeight w, [double h = 1.45, Color? col]) =>
      _f('Mukta', TextStyle(fontSize: s, fontWeight: w, height: h, color: col ?? c.ink));

  final text = TextTheme(
    displayLarge: d(52, FontWeight.w800, 1.0),
    displayMedium: d(40, FontWeight.w800, 1.05),
    displaySmall: d(32, FontWeight.w800, 1.1),
    headlineMedium: d(26, FontWeight.w800),
    headlineSmall: d(22, FontWeight.w700),
    titleLarge: d(20, FontWeight.w700),
    titleMedium: body(17, FontWeight.w700, 1.3),
    titleSmall: body(15, FontWeight.w700, 1.3),
    bodyLarge: body(17, FontWeight.w500, 1.45),
    bodyMedium: body(15, FontWeight.w500, 1.45),
    bodySmall: body(13, FontWeight.w500, 1.4, c.muted),
    labelLarge: d(17, FontWeight.w700, 1.1),
    labelMedium: body(13.5, FontWeight.w700, 1.2),
    labelSmall: body(12, FontWeight.w700, 1.2, c.muted),
  );

  final isDark = !highContrast && b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: const Color(0xFF3BA7FF),
      onSecondary: c.ink,
      error: c.wrong,
      onError: Colors.white,
      surface: c.card,
      onSurface: c.ink,
    ),
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.line, width: c.lineWidth)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.line, width: c.lineWidth)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.primary, width: c.lineWidth + 0.5)),
      hintStyle: text.bodyMedium!.copyWith(color: c.muted),
      labelStyle: text.bodyMedium!.copyWith(color: c.muted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.ink : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.card),
      trackOutlineColor: WidgetStateProperty.all(c.line),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: c.line, width: c.lineWidth),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.card),
  );
}
