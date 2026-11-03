import 'package:flutter/material.dart';

import '../widgets/motion.dart';

/// Tiranga palette: saffron, white, India green - plus clear money colours.
/// Mid-tone colours are chosen so they read well on both white and dark.
class Tiranga {
  static const saffron = Color(0xFFFF8F1F);
  static const saffronDeep = Color(0xFFE8700A);
  static const green = Color(0xFF138808);
  static const greenBright = Color(0xFF2EB82E);
  static const white = Color(0xFFFFFFFF);

  // Light mode surfaces (Revolut-style soft grey page, white cards)
  static const lightPage = Color(0xFFF6F7F9);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF14161A);
  static const lightMuted = Color(0xFF6B7280);

  // Dark mode surfaces: pure black page, neutral grey cards (no blue tint)
  static const darkPage = Color(0xFF000000);
  static const darkCard = Color(0xFF141414);
  static const darkRaised = Color(0xFF1E1E1E); // dialogs, menus
  static const darkLine = Color(0xFF2C2C2C);
  static const darkText = Color(0xFFF5F5F5);
  static const darkMuted = Color(0xFFA3A3A3);
}

// Nirmala UI (Windows) draws every Indian script; Segoe UI covers Urdu.
const _devanagariFallback = ['Nirmala UI', 'Segoe UI', 'Mangal', 'Noto Sans Devanagari'];

ThemeData buildHisaabTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final page = dark ? Tiranga.darkPage : Tiranga.lightPage;
  final card = dark ? Tiranga.darkCard : Tiranga.lightCard;
  final text = dark ? Tiranga.darkText : Tiranga.lightText;
  final muted = dark ? Tiranga.darkMuted : Tiranga.lightMuted;
  final line = dark ? Tiranga.darkLine : const Color(0xFFE5E7EB);
  final raised = dark ? Tiranga.darkRaised : Tiranga.lightCard;

  final scheme = ColorScheme.fromSeed(
    seedColor: Tiranga.saffron,
    brightness: brightness,
  ).copyWith(
    primary: dark ? Tiranga.saffron : Tiranga.saffronDeep,
    onPrimary: Colors.white,
    secondary: dark ? Tiranga.greenBright : Tiranga.green,
    onSecondary: Colors.white,
    surface: card,
    onSurface: text,
    onSurfaceVariant: muted,
    outline: line,
    outlineVariant: line,
    surfaceTint: Colors.transparent,
    // Keep every surface neutral (the seed would tint them).
    surfaceContainerLowest: page,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: raised,
    surfaceBright: raised,
    surfaceDim: page,
    inverseSurface: dark ? const Color(0xFFEDEDED) : const Color(0xFF1E1E1E),
    onInverseSurface: dark ? Colors.black : Colors.white,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    canvasColor: page,
    fontFamilyFallback: _devanagariFallback,
    visualDensity: VisualDensity.comfortable,
    // Same light fade-and-slide page change on Windows and Android.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: page,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1),
    dialogTheme: DialogThemeData(backgroundColor: raised, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: raised, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: raised, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: line),
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF262626) : const Color(0xFF1E1E1E),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
