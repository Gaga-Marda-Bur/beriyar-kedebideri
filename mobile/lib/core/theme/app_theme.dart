import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.goldText,
        secondary: AppColors.green,
        onSecondary: AppColors.white,
        surface: AppColors.night,
        onSurface: AppColors.white,
        error: AppColors.error,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        BkThemePalette.dark,
      ],
      fontFamily: AppTokens.fontFamilyLatin,
      fontFamilyFallback: const [AppTokens.fontFamilyErfe],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.goldText,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          side: const BorderSide(color: AppColors.neutralBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: -1.2,
          color: AppColors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
        headlineSmall: TextStyle(
          fontSize: AppTokens.latinHeadingSize,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: AppColors.mutedWhite,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.mutedWhite,
        ),
        bodySmall: TextStyle(
          fontSize: AppTokens.latinCaptionSize,
          height: 1.4,
          color: AppColors.mutedSahara,
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.green,
        onPrimary: AppColors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.goldText,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        error: Color(0xFFC62828),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        BkThemePalette.light,
      ],
      fontFamily: AppTokens.fontFamilyLatin,
      fontFamilyFallback: const [AppTokens.fontFamilyErfe],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.goldText,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          minimumSize: const Size(AppTokens.minTouchTarget, AppTokens.minTouchTarget),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: -1.2,
          color: AppColors.lightTextPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.lightTextPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: AppTokens.latinHeadingSize,
          fontWeight: FontWeight.w800,
          color: AppColors.lightTextPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.lightTextPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: AppColors.lightTextSecondary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppColors.lightTextSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: AppTokens.latinCaptionSize,
          height: 1.4,
          color: AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
