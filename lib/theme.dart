import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de Apple: colores de sistema de iOS en modo claro.
abstract final class AppColors {
  /// Fondo agrupado de iOS (systemGroupedBackground).
  static const background = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFE5E5EA);

  static const label = Color(0xFF000000);
  static const secondaryLabel = Color(0x993C3C43);
  static const tertiaryLabel = Color(0x4D3C3C43);
  static const separator = Color(0x333C3C43);
  static const fill = Color(0x1F787880);

  static const blue = Color(0xFF007AFF);
  static const cyan = Color(0xFF32ADE6);
  static const indigo = Color(0xFF5856D6);
  static const purple = Color(0xFFAF52DE);
  static const pink = Color(0xFFFF2D55);
  static const green = Color(0xFF34C759);

  /// Solo para lo que significa "grabando" o "borrar".
  static const red = Color(0xFFFF3B30);

  /// Acento principal: el azul de sistema de Apple.
  static const accent = blue;

  /// Azul con algo de volumen, como un botón de cristal tintado.
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3D9BFF), blue, Color(0xFF0062D6)],
    stops: [0, 0.5, 1],
  );
}

abstract final class AppText {
  static const family = 'Inter';

  static const largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.1,
    color: AppColors.label,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.label,
  );

  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
    color: AppColors.label,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.4,
    color: AppColors.secondaryLabel,
  );

  static const footnote = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppColors.secondaryLabel,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.tertiaryLabel,
  );
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.light().copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.cyan,
    surface: AppColors.surface,
    onSurface: AppColors.label,
    onSurfaceVariant: AppColors.secondaryLabel,
    outline: AppColors.separator,
    outlineVariant: AppColors.separator,
    error: AppColors.red,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.light,
    fontFamily: AppText.family,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      fontFamily: AppText.family,
      bodyColor: AppColors.label,
      displayColor: AppColors.label,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.light, primaryColor: AppColors.accent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xF21C1C1E),
      elevation: 0,
      contentTextStyle: AppText.headline.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
      actionTextColor: const Color(0xFF0A84FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.fill,
      thumbColor: Colors.white,
      overlayColor: AppColors.accent.withValues(alpha: 0.08),
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3, pressedElevation: 5),
      trackShape: const RoundedRectSliderTrackShape(),
      showValueIndicator: ShowValueIndicator.never,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: AppColors.tertiaryLabel),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
