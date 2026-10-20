import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Display: Bricolage Grotesque — characterful, slightly quirky, reads like
/// hand-lettered lab labels at large sizes.
/// Body: Atkinson Hyperlegible — designed for legibility; students read a lot.
TextStyle _font(String family, TextStyle base) {
  try {
    return GoogleFonts.getFont(family, textStyle: base);
  } catch (_) {
    return base; // fall back to platform font if the family is unavailable
  }
}

TextTheme _textTheme(Color ink, Color muted) {
  TextStyle d(double size, FontWeight w, double height, [double ls = 0]) =>
      _font('Bricolage Grotesque',
          TextStyle(fontSize: size, fontWeight: w, height: height, letterSpacing: ls, color: ink));
  TextStyle b(double size, FontWeight w, double height, [Color? c]) =>
      _font('Atkinson Hyperlegible',
          TextStyle(fontSize: size, fontWeight: w, height: height, color: c ?? ink));

  // Scale ≈ 1.25 (major third) from a 16px body.
  return TextTheme(
    displayLarge: d(48, FontWeight.w700, 1.05, -1.2),
    displayMedium: d(39, FontWeight.w700, 1.08, -0.8),
    displaySmall: d(31, FontWeight.w700, 1.12, -0.5),
    headlineMedium: d(25, FontWeight.w700, 1.18, -0.3),
    headlineSmall: d(22, FontWeight.w600, 1.2, -0.2),
    titleLarge: d(20, FontWeight.w600, 1.25),
    titleMedium: b(16, FontWeight.w700, 1.3),
    titleSmall: b(14, FontWeight.w700, 1.3),
    bodyLarge: b(16, FontWeight.w400, 1.55),
    bodyMedium: b(14, FontWeight.w400, 1.5),
    bodySmall: b(12.5, FontWeight.w400, 1.45, muted),
    labelLarge: b(15, FontWeight.w700, 1.2),
    labelMedium: b(13, FontWeight.w700, 1.2),
    labelSmall: b(11.5, FontWeight.w700, 1.2, muted),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final vc = isDark ? ValenceColors.dark : ValenceColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? const Color(0xFF8FA8FF) : Palette.physics,
    onPrimary: isDark ? Palette.paperDark : Colors.white,
    secondary: vc.highlight,
    onSecondary: vc.highlightInk,
    error: Palette.wrong,
    onError: Colors.white,
    surface: vc.sheet,
    onSurface: vc.ink,
    surfaceContainerHighest: isDark ? const Color(0xFF1F2942) : const Color(0xFFEDF1F5),
    outline: vc.rule,
    outlineVariant: vc.rule,
  );

  final text = _textTheme(vc.ink, vc.muted);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: vc.paper,
    textTheme: text,
    extensions: [vc],
    dividerColor: vc.rule,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: vc.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: vc.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: vc.sheet,
      surfaceTintColor: Colors.transparent,
      indicatorColor: vc.highlight,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall!.copyWith(
          color: s.contains(WidgetState.selected) ? vc.ink : vc.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? vc.highlightInk : vc.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: vc.ink,
        foregroundColor: vc.paper,
        minimumSize: const Size(64, 52),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: vc.ink,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: vc.ink, width: 1.4),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: vc.ink, textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: vc.sheet,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: text.bodyMedium!.copyWith(color: vc.muted),
      hintStyle: text.bodyMedium!.copyWith(color: vc.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide(color: vc.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide(color: vc.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide(color: vc.ink, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: vc.sheet,
      selectedColor: vc.highlight,
      side: BorderSide(color: vc.rule),
      labelStyle: text.labelMedium!,
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: vc.sheet,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: vc.ink,
      contentTextStyle: text.bodyMedium!.copyWith(color: vc.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: vc.ink,
      linearTrackColor: vc.rule,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? vc.ink : vc.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? vc.highlight : vc.rule,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
