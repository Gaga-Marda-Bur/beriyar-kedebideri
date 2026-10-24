import 'package:flutter/material.dart';

/// Tokens de design partagés Beřiyar Kedebideři (audit Lot 3).
///
/// Source commune alignée avec les variables CSS de `brand.css` :
/// - Vert profond (#1B4D3E), Vert nocturne (#0F3227), Or (#D4AF37), Sombre (#061A14).
/// - Statuts sémantiques (succès, avertissement, erreur, info).
/// - Échelle d'espacements (4, 8, 12, 16, 24, 32, 48).
/// - Rayons de bordure (contrôle: 12, carte: 20, pilule: 999).
/// - Cible tactile minimale : 48px.
abstract class AppTokens {
  // --- Couleurs de marque ---------------------------------------------------
  static const Color brandDark = Color(0xFF061A14);
  static const Color brandNight = Color(0xFF0F3227);
  static const Color brandGreen = Color(0xFF1B4D3E);
  static const Color brandGold = Color(0xFFD4AF37);
  static const Color brandGoldText = Color(0xFF061A14);
  static const Color brandWhite = Colors.white;
  static const Color brandMuted = Color(0xB8FFFFFF); // ~72% blanc, contraste > 4.5:1
  static const Color brandMutedExtra = Color(0xD9FFFFFF); // ~85% blanc

  // --- Rôles sémantiques de statut -----------------------------------------
  static const Color statusSuccess = Color(0xFF2E7D32);
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
  static const double radiusPill = 999.0;

  // --- Cible tactile minimale d'accessibilité (WCAG 2.5.5) -----------------
  static const double minTouchTarget = 48.0;
}
