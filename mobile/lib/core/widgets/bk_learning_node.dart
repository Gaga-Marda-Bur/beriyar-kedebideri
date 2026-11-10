import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

enum BkLearningNodeStatus {
  locked,
  available,
  inProgress,
  completed,
  reviewDue,
}

/// Nœud du chemin d'apprentissage « Sahel Modern » (Lot 4B.1).
///
/// Représente une étape du parcours avec :
/// - Anneau de progression (0% à 100%).
/// - Aperçu optionnel du glyphe Erfe en police `Kedebideri`.
/// - États distincts par icône, bordure et texte (pas uniquement la couleur).
/// - Cible tactile accessible >= 48 dp (72 dp par défaut).
class BkLearningNode extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? erfeSymbol;
  final BkLearningNodeStatus status;
  final double progress;
  final VoidCallback? onTap;
  final double size;

  const BkLearningNode({
    super.key,
    required this.title,
    this.subtitle,
    this.erfeSymbol,
    this.status = BkLearningNodeStatus.available,
    this.progress = 0.0,
    this.onTap,
    this.size = AppTokens.learningNodeSize,
  });

  bool get _isInteractive => status != BkLearningNodeStatus.locked && onTap != null;

  String _statusLabel() {
    return switch (status) {
      BkLearningNodeStatus.locked => 'Verrouillé',
      BkLearningNodeStatus.available => 'Disponible',
      BkLearningNodeStatus.inProgress => 'En cours',
      BkLearningNodeStatus.completed => 'Maîtrisé',
      BkLearningNodeStatus.reviewDue => 'À réviser',
    };
  }

  IconData _statusIcon() {
    return switch (status) {
      BkLearningNodeStatus.locked => Icons.lock_outline_rounded,
      BkLearningNodeStatus.available => Icons.play_arrow_rounded,
      BkLearningNodeStatus.inProgress => Icons.headphones_rounded,
      BkLearningNodeStatus.completed => Icons.star_rounded,
      BkLearningNodeStatus.reviewDue => Icons.autorenew_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);
    final effectiveSize = size < AppTokens.minTouchTarget
        ? AppTokens.minTouchTarget
        : size;
    final clampedProgress = progress.clamp(0.0, 1.0);

    final Color nodeFill = switch (status) {
      BkLearningNodeStatus.locked => palette.surface,
      BkLearningNodeStatus.inProgress => palette.accentGold,
      BkLearningNodeStatus.completed => palette.surfaceElevated,
      BkLearningNodeStatus.reviewDue => palette.surfaceElevated,
      BkLearningNodeStatus.available => palette.surfaceElevated,
    };

    final Color ringColor = switch (status) {
      BkLearningNodeStatus.locked => palette.border,
      BkLearningNodeStatus.inProgress => palette.accentGold,
      BkLearningNodeStatus.completed => palette.accentGold,
      BkLearningNodeStatus.reviewDue => palette.statusEncouragement,
      BkLearningNodeStatus.available => palette.accentGold.withValues(alpha: 0.7),
    };

    final Color contentColor = switch (status) {
      BkLearningNodeStatus.locked => palette.textSecondary.withValues(alpha: 0.65),
      BkLearningNodeStatus.inProgress => palette.accentGoldForeground,
      BkLearningNodeStatus.completed => palette.erfeGlyphColor,
      BkLearningNodeStatus.reviewDue => palette.statusEncouragement,
      BkLearningNodeStatus.available => palette.erfeGlyphColor,
    };

    final hasErfe = erfeSymbol != null && erfeSymbol!.trim().isNotEmpty;

    return Semantics(
      button: _isInteractive,
      enabled: _isInteractive,
      label: '$title — ${_statusLabel()}',
      value: '${(clampedProgress * 100).round()}%',
      child: Opacity(
        opacity: status == BkLearningNodeStatus.locked ? 0.68 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('bk-learning-node-tap'),
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                onTap: _isInteractive ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.spaceXs),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: effectiveSize + 12,
                        height: effectiveSize + 12,
                        child: CircularProgressIndicator(
                          value: status == BkLearningNodeStatus.completed
                              ? 1.0
                              : clampedProgress,
                          strokeWidth: 4.0,
                          backgroundColor: palette.border,
                          valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                        ),
                      ),
                      Container(
                        width: effectiveSize,
                        height: effectiveSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: nodeFill,
                          border: Border.all(
                            color: ringColor,
                            width: status == BkLearningNodeStatus.inProgress ? 2.5 : 1.6,
                          ),
                        ),
                        child: Center(
                          child: hasErfe && status != BkLearningNodeStatus.locked
                              ? Text(
                                  erfeSymbol!,
                                  style: AppTextStyles.erfeOptionText.copyWith(
                                    color: contentColor,
                                    fontSize: effectiveSize * 0.38,
                                  ),
                                )
                              : Icon(
                                  _statusIcon(),
                                  size: effectiveSize * 0.42,
                                  color: contentColor,
                                ),
                        ),
                      ),
                      if (status == BkLearningNodeStatus.completed ||
                          status == BkLearningNodeStatus.reviewDue)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status == BkLearningNodeStatus.completed
                                  ? palette.statusSuccess
                                  : palette.statusEncouragement,
                              border: Border.all(
                                color: palette.background,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              status == BkLearningNodeStatus.completed
                                  ? Icons.check_rounded
                                  : Icons.priority_high_rounded,
                              size: 12,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.latinCaption.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
