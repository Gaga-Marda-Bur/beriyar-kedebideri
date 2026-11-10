import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppColors {
  static const Color green = AppTokens.brandGreen;
  static const Color night = AppTokens.brandNight;
  static const Color surfaceDark = AppTokens.surfaceDark;
  static const Color surfaceLight = AppTokens.surfaceLight;
  static const Color gold = AppTokens.brandGold;
  static const Color goldGlow = AppTokens.goldGlow;
  static const Color goldText = AppTokens.brandGoldText;
  static const Color dark = AppTokens.brandDark;

  static const Color white = AppTokens.brandWhite;
  static const Color mutedSahara = AppTokens.mutedSahara;
  static const Color mutedWhite = AppTokens.brandMuted;
  static const Color mutedWhiteExtra = AppTokens.brandMutedExtra;
  static const Color neutralBorder = AppTokens.neutralBorder;

  static const Color glass = AppTokens.glassBg;
  static const Color glassBorder = AppTokens.glassBorder;
  static const Color shadowGold = AppTokens.shadowGold;

  // Couleurs Thème Clair (« Sahel Daylight »)
  static const Color lightBackground = AppTokens.lightBackground;
  static const Color lightSurface = AppTokens.lightSurface;
  static const Color lightSurfaceVariant = AppTokens.lightSurfaceVariant;
  static const Color lightTextPrimary = AppTokens.lightTextPrimary;
  static const Color lightTextSecondary = AppTokens.lightTextSecondary;
  static const Color lightBorder = AppTokens.lightBorder;
  static const Color lightGoldAccent = AppTokens.lightGoldAccent;

  // Statuts sémantiques
  static const Color success = AppTokens.statusSuccess;
  static const Color encouragement = AppTokens.statusEncouragement;
  static const Color warning = AppTokens.statusWarning;
  static const Color error = AppTokens.statusError;
  static const Color info = AppTokens.statusInfo;

  /// Calcule le ratio de contraste WCAG 2.1 entre deux couleurs (1.0 à 21.0).
  static double contrastRatio(Color foreground, Color background) {
    final l1 = foreground.computeLuminance();
    final l2 = background.computeLuminance();
    final brightest = math.max(l1, l2);
    final darkest = math.min(l1, l2);
    return (brightest + 0.05) / (darkest + 0.05);
  }
}

/// Extension de thème adaptative « Sahel Modern » pour supporter les modes Sombre et Clair
/// avec des contrastes conformes WCAG AA/AAA.
@immutable
class BkThemePalette extends ThemeExtension<BkThemePalette> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentGold;
  final Color accentGoldForeground;
  final Color erfeGlyphColor;
  final Color statusSuccess;
  final Color statusEncouragement;
  final Color statusError;

  const BkThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentGold,
    required this.accentGoldForeground,
    required this.erfeGlyphColor,
    required this.statusSuccess,
    required this.statusEncouragement,
    required this.statusError,
  });

  static const BkThemePalette dark = BkThemePalette(
    background: AppTokens.brandDark,
    surface: AppTokens.surfaceDark,
    surfaceElevated: AppTokens.surfaceLight,
    border: AppTokens.neutralBorder,
    textPrimary: AppTokens.brandWhite,
    textSecondary: AppTokens.mutedSahara,
    accentGold: AppTokens.brandGold,
    accentGoldForeground: AppTokens.brandGoldText,
    erfeGlyphColor: AppTokens.brandGold,
    statusSuccess: AppTokens.statusSuccess,
    statusEncouragement: AppTokens.statusEncouragement,
    statusError: AppTokens.statusError,
  );

  static const BkThemePalette light = BkThemePalette(
    background: AppTokens.lightBackground,
    surface: AppTokens.lightSurface,
    surfaceElevated: AppTokens.lightSurfaceVariant,
    border: AppTokens.lightBorder,
    textPrimary: AppTokens.lightTextPrimary,
    textSecondary: AppTokens.lightTextSecondary,
    accentGold: AppTokens.brandGold,
    accentGoldForeground: AppTokens.brandGoldText,
    erfeGlyphColor: AppTokens.lightTextPrimary,
    statusSuccess: AppTokens.statusSuccess,
    statusEncouragement: Color(0xFFB45309),
    statusError: Color(0xFFC62828),
  );

  static BkThemePalette of(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<BkThemePalette>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.light ? light : dark;
  }

  @override
  BkThemePalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentGold,
    Color? accentGoldForeground,
    Color? erfeGlyphColor,
    Color? statusSuccess,
    Color? statusEncouragement,
    Color? statusError,
  }) {
    return BkThemePalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accentGold: accentGold ?? this.accentGold,
      accentGoldForeground: accentGoldForeground ?? this.accentGoldForeground,
      erfeGlyphColor: erfeGlyphColor ?? this.erfeGlyphColor,
      statusSuccess: statusSuccess ?? this.statusSuccess,
      statusEncouragement: statusEncouragement ?? this.statusEncouragement,
      statusError: statusError ?? this.statusError,
    );
  }

  @override
  BkThemePalette lerp(ThemeExtension<BkThemePalette>? other, double t) {
    if (other is! BkThemePalette) return this;
    return BkThemePalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accentGold: Color.lerp(accentGold, other.accentGold, t)!,
      accentGoldForeground: Color.lerp(accentGoldForeground, other.accentGoldForeground, t)!,
      erfeGlyphColor: Color.lerp(erfeGlyphColor, other.erfeGlyphColor, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusEncouragement: Color.lerp(statusEncouragement, other.statusEncouragement, t)!,
      statusError: Color.lerp(statusError, other.statusError, t)!,
    );
  }
}
