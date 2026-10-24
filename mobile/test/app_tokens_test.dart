import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/app_tokens.dart';

void main() {
  group('AppTokens & AppColors Design System (Lot 3)', () {
    test('Tokens represent the canonical Beriya palette', () {
      expect(AppTokens.brandDark, const Color(0xFF061A14));
      expect(AppTokens.brandNight, const Color(0xFF0F3227));
      expect(AppTokens.brandGreen, const Color(0xFF1B4D3E));
      expect(AppTokens.brandGold, const Color(0xFFD4AF37));
      expect(AppTokens.brandGoldText, const Color(0xFF061A14));
    });

    test('Spacing tokens match 4/8/12/16/24/32/48 scale', () {
      expect(AppTokens.spaceXs, 4.0);
      expect(AppTokens.spaceSm, 8.0);
      expect(AppTokens.spaceMd, 12.0);
      expect(AppTokens.spaceLg, 16.0);
      expect(AppTokens.spaceXl, 24.0);
      expect(AppTokens.spaceXxl, 32.0);
      expect(AppTokens.spaceXxxl, 48.0);
    });

    test('Radii and touch target meet accessibility criteria', () {
      expect(AppTokens.radiusControl, 12.0);
      expect(AppTokens.radiusCard, 20.0);
      expect(AppTokens.radiusPill, 999.0);
      expect(AppTokens.minTouchTarget, greaterThanOrEqualTo(48.0));
    });

    test('Semantic status colors are defined', () {
      expect(AppTokens.statusSuccess, const Color(0xFF2E7D32));
      expect(AppTokens.statusWarning, const Color(0xFFFFA000));
      expect(AppTokens.statusError, const Color(0xFFE53935));
      expect(AppTokens.statusInfo, const Color(0xFF1976D2));
    });

    test('AppColors backwards-compatible aliases point to AppTokens', () {
      expect(AppColors.green, AppTokens.brandGreen);
      expect(AppColors.night, AppTokens.brandNight);
      expect(AppColors.gold, AppTokens.brandGold);
      expect(AppColors.goldText, AppTokens.brandGoldText);
      expect(AppColors.dark, AppTokens.brandDark);
      expect(AppColors.white, AppTokens.brandWhite);
      expect(AppColors.mutedWhite, AppTokens.brandMuted);
      expect(AppColors.mutedWhiteExtra, AppTokens.brandMutedExtra);
      expect(AppColors.glass, AppTokens.glassBg);
      expect(AppColors.glassBorder, AppTokens.glassBorder);
      expect(AppColors.shadowGold, AppTokens.shadowGold);
      expect(AppColors.success, AppTokens.statusSuccess);
      expect(AppColors.warning, AppTokens.statusWarning);
      expect(AppColors.error, AppTokens.statusError);
      expect(AppColors.info, AppTokens.statusInfo);
    });
  });
}
