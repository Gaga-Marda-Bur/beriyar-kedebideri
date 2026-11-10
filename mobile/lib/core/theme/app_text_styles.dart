import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTextStyles {
  // --- Styles historiques conservés pour compatibilité ascendante -----------
  static const TextStyle beriyaLarge = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
    height: 1.1,
  );

  static const TextStyle beriyaMedium = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
    height: 1.1,
  );

  static const TextStyle beriyaSmall = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
    height: 1.1,
  );

  // --- Échelle typographique Erfe « Sahel Modern » (Lot 4B.1) --------------
  static const TextStyle erfeDisplayHero = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: AppTokens.erfeHeroSize, // 52 sp
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
    letterSpacing: AppTokens.erfeLetterSpacing,
    height: AppTokens.erfeLineHeight,
  );

  static const TextStyle erfeWordTitle = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: AppTokens.erfeWordSize, // 34 sp
    fontWeight: FontWeight.w700,
    color: AppColors.gold,
    letterSpacing: AppTokens.erfeLetterSpacing,
    height: AppTokens.erfeLineHeight,
  );

  static const TextStyle erfeOptionText = TextStyle(
    fontFamily: AppTokens.fontFamilyErfe,
    fontSize: AppTokens.erfeOptionSize, // 26 sp
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
    letterSpacing: AppTokens.erfeLetterSpacing,
    height: AppTokens.erfeLineHeight,
  );

  // --- Échelle typographique Latine / Système (Lot 4B.1) -------------------
  static const TextStyle latinHeading = TextStyle(
    fontFamily: AppTokens.fontFamilyLatin,
    fontSize: AppTokens.latinHeadingSize, // 22 sp
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const TextStyle latinInstruction = TextStyle(
    fontFamily: AppTokens.fontFamilyLatin,
    fontSize: AppTokens.latinInstructionSize, // 16 sp
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  static const TextStyle latinCaption = TextStyle(
    fontFamily: AppTokens.fontFamilyLatin,
    fontSize: AppTokens.latinCaptionSize, // 13 sp
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  // --- Variantes adaptatives au thème (Clair / Sombre) ---------------------
  static TextStyle erfeDisplayHeroOf(BuildContext context) {
    final palette = BkThemePalette.of(context);
    return erfeDisplayHero.copyWith(color: palette.erfeGlyphColor);
  }

  static TextStyle erfeWordTitleOf(BuildContext context) {
    final palette = BkThemePalette.of(context);
    return erfeWordTitle.copyWith(color: palette.erfeGlyphColor);
  }

  static TextStyle erfeOptionTextOf(BuildContext context) {
    final palette = BkThemePalette.of(context);
    return erfeOptionText.copyWith(color: palette.erfeGlyphColor);
  }
}
