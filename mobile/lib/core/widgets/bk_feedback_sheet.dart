import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

enum BkFeedbackType {
  positive,
  encouragement,
}

/// Panneau bas de retour immédiat (« Sahel Modern » — Lot 4B.1).
///
/// Caractéristiques :
/// - Distinction visuelle et sémantique claire (Succès vs Encouragement bienveillant).
/// - Affichage optionnel du caractère ou mot cible en police `Kedebideri`.
/// - Bouton de réécoute explicite toujours accessible (>= 48 dp).
/// - Bouton d'action principale « Continuer » (>= 52 dp).
class BkFeedbackSheet extends StatelessWidget {
  final BkFeedbackType type;
  final String title;
  final String? message;
  final String? erfeText;
  final VoidCallback onContinue;
  final VoidCallback? onReplayAudio;
  final String continueLabel;
  final String replayLabel;

  const BkFeedbackSheet({
    super.key,
    required this.type,
    required this.title,
    required this.onContinue,
    this.message,
    this.erfeText,
    this.onReplayAudio,
    this.continueLabel = 'Continuer',
    this.replayLabel = 'Réécouter',
  });

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);
    final isPositive = type == BkFeedbackType.positive;

    final Color accentColor = isPositive
        ? palette.statusSuccess
        : palette.statusEncouragement;

    final IconData statusIcon = isPositive
        ? Icons.check_circle_rounded
        : Icons.hearing_rounded;

    final hasErfe = erfeText != null && erfeText!.trim().isNotEmpty;

    return Semantics(
      liveRegion: true,
      container: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
          border: Border.all(
            color: accentColor,
            width: 2.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  statusIcon,
                  key: const ValueKey('bk-feedback-status-icon'),
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (hasErfe) ...[
                  const SizedBox(width: AppTokens.spaceSm),
                  Text(
                    erfeText!,
                    style: AppTextStyles.erfeWordTitleOf(context),
                  ),
                ],
              ],
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.spaceLg),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 300;
                final replayButton = onReplayAudio == null
                    ? null
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTouchTarget,
                          minWidth: AppTokens.minTouchTarget,
                        ),
                        child: OutlinedButton.icon(
                          key: const ValueKey('bk-feedback-replay-button'),
                          onPressed: onReplayAudio,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            backgroundColor: palette.surface,
                            side: BorderSide(color: palette.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusControl,
                              ),
                            ),
                          ),
                          icon: Icon(
                            Icons.replay_rounded,
                            size: 20,
                            color: palette.accentGold,
                          ),
                          label: Text(
                            replayLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      );

                final continueButton = SizedBox(
                  height: AppTokens.primaryCtaHeight,
                  width: isCompact ? double.infinity : null,
                  child: FilledButton.icon(
                    key: const ValueKey('bk-feedback-continue-button'),
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: isPositive
                          ? palette.statusSuccess
                          : palette.accentGold,
                      foregroundColor: isPositive
                          ? AppColors.white
                          : palette.accentGoldForeground,
                      minimumSize: const Size(
                        AppTokens.minTouchTarget,
                        AppTokens.primaryCtaHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusControl,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      continueLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );

                if (isCompact && replayButton != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      replayButton,
                      const SizedBox(height: AppTokens.spaceSm),
                      continueButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    if (replayButton != null) ...[
                      replayButton,
                      const SizedBox(width: AppTokens.spaceSm),
                    ],
                    Expanded(child: continueButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
