import 'package:flutter/material.dart';

/// Tokens de design partagés Beřiyar Kedebideři — Design System « Sahel Modern » (Lot 4B.1).
///
/// Source commune alignée avec les variables CSS de `brand.css` et les spécifications Phase 4A :
/// - Palette Sombre (« Nuit Sahélienne ») : Vert profond (#1B4D3E), Vert nocturne (#0F3227),
///   Or sahélien (#D4AF37), Fond nuit (#061A14), Surfaces (#0B251D / #133D30).
/// - Palette Claire (« Sable & Acacia ») : Sable chaud (#FAF7F0), Ivoire (#FFFFFF),
///   Surface pierre (#F1ECE1), Texte nuit (#061A14), Or profond accessible (#7A5D00).
/// - Statuts sémantiques (succès, encouragement, avertissement, erreur, info).
/// - Échelle d'espacements (4, 8, 12, 16, 24, 32, 48).
/// - Rayons de bordure (contrôle: 12, carte: 20, feuille: 28, pilule: 999).
/// - Élévations (0, 2, 4, 8) et cibles tactiles minimales (48 dp — WCAG 2.5.5).
abstract class AppTokens {
  // --- Couleurs de marque (Thème Sombre « Sahel Night ») --------------------
  static const Color brandDark = Color(0xFF061A14);
  static const Color surfaceDark = Color(0xFF0B251D);
  static const Color brandNight = Color(0xFF0F3227);
  static const Color surfaceLight = Color(0xFF133D30);
  static const Color brandGreen = Color(0xFF1B4D3E);
  static const Color brandGold = Color(0xFFD4AF37);
  static const Color goldGlow = Color(0xFFF3E5AB);
  static const Color brandGoldText = Color(0xFF061A14);
  static const Color brandWhite = Colors.white;
  static const Color mutedSahara = Color(0xFFC2CDBE);
  static const Color brandMuted = Color(0xB8FFFFFF); // ~72% blanc, contraste > 4.5:1
  static const Color brandMutedExtra = Color(0xD9FFFFFF); // ~85% blanc
  static const Color neutralBorder = Color(0xFF244A3E);

  // --- Couleurs Thème Clair (« Sahel Daylight ») ----------------------------
  static const Color lightBackground = Color(0xFFFAF7F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1ECE1);
  static const Color lightTextPrimary = Color(0xFF061A14);
  static const Color lightTextSecondary = Color(0xFF2C4C3E);
  static const Color lightBorder = Color(0xFFD5CFC0);
  static const Color lightGoldAccent = Color(0xFF7A5D00); // Contraste > 5.5:1 sur fond clair

  // --- Rôles sémantiques de statut -----------------------------------------
  static const Color statusSuccess = Color(0xFF2E7D32);
  static const Color statusEncouragement = Color(0xFFD97706);
  static const Color statusWarning = Color(0xFFFFA000);
  static const Color statusError = Color(0xFFE53935);
  static const Color statusInfo = Color(0xFF1976D2);

  // --- Verre et reflets ----------------------------------------------------
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x42D4AF37);
  static const Color shadowGold = Color(0x38D4AF37);

  // --- Échelle d'espacements -----------------------------------------------
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double spaceXxl = 32.0;
  static const double spaceXxxl = 48.0;

  // --- Rayons de bordure ---------------------------------------------------
  static const double radiusControl = 12.0;
  static const double radiusCard = 20.0;
  static const double radiusSheet = 28.0;
  static const double radiusPill = 999.0;

  // --- Élévations ----------------------------------------------------------
  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // --- Typographie & Lisibilité Erfe ---------------------------------------
  static const String fontFamilyErfe = 'Kedebideri';
  static const String fontFamilyLatin = 'Roboto';

  static const double erfeHeroSize = 52.0;
  static const double erfeWordSize = 34.0;
  static const double erfeOptionSize = 26.0;
  static const double erfeLetterSpacing = 1.5;
  static const double erfeLineHeight = 1.2;

  static const double latinHeadingSize = 22.0;
  static const double latinInstructionSize = 16.0;
  static const double latinCaptionSize = 13.0;

  // --- Cibles tactiles et dimensions composants (WCAG 2.5.5) ---------------
  static const double minTouchTarget = 48.0;
  static const double audioHeroButtonSize = 84.0;
  static const double learningNodeSize = 72.0;
  static const double optionCardMinHeight = 64.0;
  static const double primaryCtaHeight = 52.0;
}
