import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apariencia elegida por el usuario.
enum Appearance {
  system('Automático'),
  light('Claro'),
  dark('Oscuro');

  const Appearance(this.label);

  final String label;

  static Appearance parse(String? name) =>
      Appearance.values.firstWhere((a) => a.name == name, orElse: () => Appearance.system);

  bool resolve(Brightness platform) => switch (this) {
    Appearance.system => platform == Brightness.dark,
    Appearance.light => false,
    Appearance.dark => true,
  };
}

/// Paleta de Apple: colores de sistema de iOS en modo claro u oscuro.
///
/// La app se reconstruye entera al cambiar de modo, así que basta con leer
/// estos valores en `build`.
abstract final class AppColors {
  /// Modo activo. Lo fija la raíz de cada app (principal y ventana flotante).
  static bool dark = false;

  static Color get background => dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color get surface => dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  static Color get surfaceHigh => dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

  static Color get label => dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  static Color get secondaryLabel => dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
  static Color get tertiaryLabel => dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43);
  static Color get separator => dark ? const Color(0x33FFFFFF) : const Color(0x333C3C43);
  static Color get fill => dark ? const Color(0x3D787880) : const Color(0x1F787880);

  /// Color del cristal: blanco esmerilado de día, grafito de noche.
  static Color get glass => dark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF);

  static Color get blue => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  static Color get cyan => dark ? const Color(0xFF64D2FF) : const Color(0xFF32ADE6);
  static Color get indigo => dark ? const Color(0xFF5E5CE6) : const Color(0xFF5856D6);
  static Color get purple => dark ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE);
  static Color get pink => dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);
  static Color get green => dark ? const Color(0xFF30D158) : const Color(0xFF34C759);

  /// Solo para lo que significa "grabando" o "borrar".
  static Color get red => dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);

  /// Acento principal: el azul de sistema de Apple.
  static Color get accent => blue;

  /// Azul con algo de volumen, como un botón de cristal tintado.
  static LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF409CFF), Color(0xFF0A84FF), Color(0xFF0066E0)]
        : const [Color(0xFF3D9BFF), Color(0xFF007AFF), Color(0xFF0062D6)],
    stops: const [0, 0.5, 1],
  );

  /// Barra de estado con iconos que contrastan con el fondo.
  static SystemUiOverlayStyle get systemOverlay => (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
      .copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent);
}

abstract final class AppText {
  static const family = 'Inter';

  static TextStyle get largeTitle => TextStyle(
    fontFamily: family,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.1,
    height: 1.1,
    color: AppColors.label,
  );

  static TextStyle get title => TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.label,
  );

  static TextStyle get headline => TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
    color: AppColors.label,
  );

  static TextStyle get body => TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.4,
    color: AppColors.secondaryLabel,
  );

  static TextStyle get footnote => TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: AppColors.secondaryLabel,
  );

  static TextStyle get caption => TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.tertiaryLabel,
  );
}

ThemeData buildTheme() {
  final dark = AppColors.dark;
  final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
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
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: AppText.family,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      fontFamily: AppText.family,
      bodyColor: AppColors.label,
      displayColor: AppColors.label,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      primaryColor: AppColors.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: AppColors.systemOverlay,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xF23A3A3C) : const Color(0xF21C1C1E),
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
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: AppColors.tertiaryLabel),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.accent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
