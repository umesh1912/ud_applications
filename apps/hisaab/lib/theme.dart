import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hisaab design system — "the passbook".
/// A bank passbook's calm: ruled rows, right-aligned figures with a running
/// balance, a date stamp on every entry. Amounts that matter are set large in
/// a serif; everything you operate is a quiet grotesk. Evergreen ink for
/// money you have, brass for goals, rust for money going out.
class HC extends ThemeExtension<HC> {
  const HC({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.green,
    required this.greenSoft,
    required this.band,
    required this.onBand,
    required this.brass,
    required this.spend,
    required this.earn,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color green; // primary
  final Color greenSoft;
  final Color band; // header band
  final Color onBand;
  final Color brass;
  final Color spend;
  final Color earn;

  static const light = HC(
    bg: Color(0xFFF0F2EF),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF12241F),
    muted: Color(0xFF5C6B66),
    rule: Color(0xFFD6DDD8),
    green: Color(0xFF0B4F3C),
    greenSoft: Color(0xFFDCEBE4),
    band: Color(0xFF0B4F3C),
    onBand: Color(0xFFF0F7F3),
    brass: Color(0xFFA8761F),
    spend: Color(0xFFB8432C),
    earn: Color(0xFF1D7F4E),
  );

  static const dark = HC(
    bg: Color(0xFF0D1714),
    card: Color(0xFF15221E),
    ink: Color(0xFFE6EFEB),
    muted: Color(0xFF9AB0A8),
    rule: Color(0xFF26372F),
    green: Color(0xFF6CCDA2),
    greenSoft: Color(0xFF1C3A2F),
    band: Color(0xFF103A2D),
    onBand: Color(0xFFE6F4EC),
    brass: Color(0xFFE0B25A),
    spend: Color(0xFFF08A70),
    earn: Color(0xFF6CCDA2),
  );

  @override
  HC copyWith() => this;

  @override
  HC lerp(ThemeExtension<HC>? other, double t) => t < 0.5 ? this : (other as HC? ?? this);
}

extension HCX on BuildContext {
  HC get hc => Theme.of(this).extension<HC>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

TextStyle _f(String family, TextStyle s) {
  try {
    return GoogleFonts.getFont(family, textStyle: s);
  } catch (_) {
    return s;
  }
}

/// Serif for money figures (Instrument Serif), Figtree for everything else.
TextStyle money(BuildContext context, double size, {Color? color}) => _f(
      'Instrument Serif',
      TextStyle(
        fontSize: size,
        height: 1.0,
        color: color ?? context.hc.ink,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
      ),
    );

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? HC.dark : HC.light;
  TextStyle u(double s, FontWeight w, [double h = 1.4, Color? col]) =>
      _f('Figtree', TextStyle(fontSize: s, fontWeight: w, height: h, color: col ?? c.ink));
  TextStyle d(double s) => _f('Instrument Serif', TextStyle(fontSize: s, height: 1.1, color: c.ink));

  final text = TextTheme(
    displayLarge: d(56),
    displayMedium: d(44),
    displaySmall: d(34),
    headlineMedium: d(28),
    headlineSmall: u(20, FontWeight.w700, 1.25),
    titleLarge: u(18, FontWeight.w700, 1.3),
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
    primary: c.green,
    onPrimary: b == Brightness.dark ? c.bg : Colors.white,
    secondary: c.brass,
    onSecondary: Colors.white,
    error: c.spend,
    onError: Colors.white,
    surface: c.card,
    onSurface: c.ink,
    surfaceContainerHighest: c.greenSoft,
    outline: c.rule,
    outlineVariant: c.rule,
  );

  final r8 = BorderRadius.circular(10);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: text,
    extensions: [c],
    dividerColor: c.rule,
    dividerTheme: DividerThemeData(color: c.rule, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: r8, side: BorderSide(color: c.rule)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.green,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(64, 50),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r8),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: c.rule, width: 1.2),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.green, textStyle: text.labelLarge)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.green,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: r8, borderSide: BorderSide(color: c.rule)),
      enabledBorder: OutlineInputBorder(borderRadius: r8, borderSide: BorderSide(color: c.rule)),
      focusedBorder: OutlineInputBorder(borderRadius: r8, borderSide: BorderSide(color: c.green, width: 1.6)),
      labelStyle: text.bodyMedium!.copyWith(color: c.muted),
      hintStyle: text.bodyMedium!.copyWith(color: c.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.greenSoft,
      side: BorderSide(color: c.rule),
      labelStyle: text.labelMedium!,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.greenSoft,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(color: s.contains(WidgetState.selected) ? c.ink : c.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.green : c.muted),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
      shape: RoundedRectangleBorder(borderRadius: r8),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.green, linearTrackColor: c.greenSoft),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.green : c.rule),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: c.greenSoft,
        selectedForegroundColor: c.ink,
        foregroundColor: c.muted,
        side: BorderSide(color: c.rule),
        textStyle: text.labelMedium,
      ),
    ),
  );
}
