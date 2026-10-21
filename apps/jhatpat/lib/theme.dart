import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jhatpat design system — "the ticket".
/// Recharges and bills are printed as tickets: notched sides, a perforated
/// tear line, and a receipt with a torn zigzag edge once paid. Wide, punchy
/// display type for amounts; a plain readable sans for everything else.
/// One saffron for "pay", mint for cashback.
class JC extends ThemeExtension<JC> {
  const JC({
    required this.bg,
    required this.card,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.saffron,
    required this.onSaffron,
    required this.saffronSoft,
    required this.mint,
    required this.mintSoft,
    required this.danger,
  });

  final Color bg;
  final Color card;
  final Color ink;
  final Color muted;
  final Color rule;
  final Color saffron;
  final Color onSaffron;
  final Color saffronSoft;
  final Color mint;
  final Color mintSoft;
  final Color danger;

  static const light = JC(
    bg: Color(0xFFECEEF3),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF191A2E),
    muted: Color(0xFF5E6176),
    rule: Color(0xFFD8DBE5),
    saffron: Color(0xFFF26B1D),
    onSaffron: Color(0xFF191A2E),
    saffronSoft: Color(0xFFFDE6D8),
    mint: Color(0xFF00876F),
    mintSoft: Color(0xFFD5F2EC),
    danger: Color(0xFFCF3434),
  );

  static const dark = JC(
    bg: Color(0xFF101119),
    card: Color(0xFF1B1C28),
    ink: Color(0xFFF0F1F6),
    muted: Color(0xFFA5A8BC),
    rule: Color(0xFF2C2E40),
    saffron: Color(0xFFFF8A45),
    onSaffron: Color(0xFF191A2E),
    saffronSoft: Color(0xFF3A2619),
    mint: Color(0xFF3FD3B5),
    mintSoft: Color(0xFF15332D),
    danger: Color(0xFFFF6B6B),
  );

  @override
  JC copyWith() => this;

  @override
  JC lerp(ThemeExtension<JC>? other, double t) => t < 0.5 ? this : (other as JC? ?? this);
}

extension JCX on BuildContext {
  JC get jc => Theme.of(this).extension<JC>()!;
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

/// Wide display face for prices.
TextStyle price(BuildContext context, double size, {Color? color}) => _f(
      'Unbounded',
      TextStyle(fontSize: size, fontWeight: FontWeight.w700, height: 1.05, color: color ?? context.jc.ink, fontFeatures: tabular),
    );

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? JC.dark : JC.light;
  TextStyle d(double s, [FontWeight w = FontWeight.w700]) =>
      _f('Unbounded', TextStyle(fontSize: s, fontWeight: w, height: 1.15, color: c.ink, letterSpacing: -0.3));
  TextStyle u(double s, FontWeight w, [double h = 1.45, Color? col]) =>
      _f('Manrope', TextStyle(fontSize: s, fontWeight: w, height: h, color: col ?? c.ink));

  final text = TextTheme(
    displayLarge: d(44),
    displayMedium: d(36),
    displaySmall: d(28),
    headlineMedium: d(23),
    headlineSmall: d(19, FontWeight.w600),
    titleLarge: u(19, FontWeight.w800, 1.25),
    titleMedium: u(16, FontWeight.w700, 1.3),
    titleSmall: u(14, FontWeight.w700, 1.3),
    bodyLarge: u(16, FontWeight.w500, 1.5),
    bodyMedium: u(14, FontWeight.w500, 1.45),
    bodySmall: u(12.5, FontWeight.w500, 1.4, c.muted),
    labelLarge: u(15, FontWeight.w800, 1.2),
    labelMedium: u(13, FontWeight.w700, 1.2),
    labelSmall: u(11.5, FontWeight.w700, 1.2, c.muted),
  );

  final scheme = ColorScheme(
    brightness: b,
    primary: c.saffron,
    onPrimary: c.onSaffron,
    secondary: c.mint,
    onSecondary: Colors.white,
    error: c.danger,
    onError: Colors.white,
    surface: c.card,
    onSurface: c.ink,
    surfaceContainerHighest: c.saffronSoft,
    outline: c.rule,
    outlineVariant: c.rule,
  );
  final r = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    textTheme: text,
    extensions: [c],
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
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.saffron,
        foregroundColor: c.onSaffron,
        minimumSize: const Size(64, 54),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 50),
        side: BorderSide(color: c.rule, width: 1.4),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: r),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: b == Brightness.dark ? c.saffron : const Color(0xFFB4470A), textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.rule)),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.rule)),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.saffron, width: 1.8)),
      labelStyle: text.bodyMedium!.copyWith(color: c.muted),
      hintStyle: text.bodyMedium!.copyWith(color: c.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      selectedColor: c.saffronSoft,
      side: BorderSide(color: c.rule),
      labelStyle: text.labelMedium!,
      showCheckmark: false,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.saffronSoft,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(color: s.contains(WidgetState.selected) ? c.ink : c.muted),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.ink : c.muted)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: r)),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: c.bg),
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.ink,
      unselectedLabelColor: c.muted,
      indicatorColor: c.saffron,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelMedium,
      dividerColor: c.rule,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onSaffron : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.saffron : c.rule),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.saffron, linearTrackColor: c.saffronSoft),
  );
}
