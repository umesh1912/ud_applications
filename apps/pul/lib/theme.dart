import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pul design system — "airmail".
/// The red-and-blue chevron border of an airmail envelope frames anything
/// that is about to cross a border (the quote, the receipt). Status is shown
/// as a round postmark. Headings use a tall condensed face like an envelope
/// label; figures use a sturdy sans with tabular numbers.
class PC extends ThemeExtension<PC> {
  const PC({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.blue,
    required this.red,
    required this.blueSoft,
    required this.ok,
    required this.warn,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color blue;
  final Color red;
  final Color blueSoft;
  final Color ok;
  final Color warn;

  static const light = PC(
    bg: Color(0xFFF4F5F9),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF141B2D),
    muted: Color(0xFF5B6478),
    rule: Color(0xFFDCE0E8),
    blue: Color(0xFF1F3F94),
    red: Color(0xFFD2352B),
    blueSoft: Color(0xFFE3E9F8),
    ok: Color(0xFF1E8E5A),
    warn: Color(0xFFB7790B),
  );

  static const dark = PC(
    bg: Color(0xFF0E1220),
    card: Color(0xFF181D30),
    ink: Color(0xFFE9ECF5),
    muted: Color(0xFFA3AAC0),
    rule: Color(0xFF2A3148),
    blue: Color(0xFF93AAFF),
    red: Color(0xFFFF7C72),
    blueSoft: Color(0xFF232C4D),
    ok: Color(0xFF5FD49A),
    warn: Color(0xFFF2BC52),
  );

  @override
  PC copyWith() => this;

  @override
  PC lerp(ThemeExtension<PC>? other, double t) => t < 0.5 ? this : (other as PC? ?? this);
}

extension PCX on BuildContext {
  PC get pc => Theme.of(this).extension<PC>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

TextStyle _f(String family, TextStyle s) {
  try {
    return GoogleFonts.getFont(family, textStyle: s);
  } catch (_) {
    return s;
  }
}

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? PC.dark : PC.light;
  TextStyle d(double s, [FontWeight w = FontWeight.w700]) =>
      _f('Archivo Narrow', TextStyle(fontSize: s, fontWeight: w, height: 1.1, color: c.ink, letterSpacing: -0.2));
  TextStyle u(double s, FontWeight w, [double h = 1.45, Color? col]) =>
      _f('Public Sans', TextStyle(fontSize: s, fontWeight: w, height: h, color: col ?? c.ink));

  final text = TextTheme(
    displayLarge: d(54),
    displayMedium: d(42),
    displaySmall: d(34),
    headlineMedium: d(28),
    headlineSmall: d(23),
    titleLarge: d(20, FontWeight.w600),
    titleMedium: u(16, FontWeight.w600, 1.3),
    titleSmall: u(14, FontWeight.w600, 1.3),
    bodyLarge: u(16, FontWeight.w400, 1.5),
    bodyMedium: u(14, FontWeight.w400, 1.45),
    bodySmall: u(12.5, FontWeight.w400, 1.4, c.muted),
    labelLarge: u(15, FontWeight.w600, 1.2),
    labelMedium: u(13, FontWeight.w600, 1.2),
    labelSmall: u(11.5, FontWeight.w600, 1.2, c.muted),
  );

  final scheme = ColorScheme(
    brightness: b,
    primary: c.blue,
    onPrimary: b == Brightness.dark ? c.bg : Colors.white,
    secondary: c.red,
    onSecondary: Colors.white,
    error: c.red,
    onError: Colors.white,
    surface: c.card,
    onSurface: c.ink,
    surfaceContainerHighest: c.blueSoft,
    outline: c.rule,
    outlineVariant: c.rule,
  );
  final r = BorderRadius.circular(12);

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: text,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.rule, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: r, side: BorderSide(color: c.rule)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.blue,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: c.rule, width: 1.2),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.blue, textStyle: text.labelLarge)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.rule)),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.rule)),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.blue, width: 1.6)),
      labelStyle: text.bodyMedium!.copyWith(color: c.muted),
      hintStyle: text.bodyMedium!.copyWith(color: c.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.blueSoft,
      side: BorderSide(color: c.rule),
      labelStyle: text.labelMedium!,
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.blueSoft,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(color: s.contains(WidgetState.selected) ? c.ink : c.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.blue : c.muted)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: r)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.blue : c.rule),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.blue, linearTrackColor: c.blueSoft),
  );
}
