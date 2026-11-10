import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

enum BkOptionCardState {
  neutral,
  selected,
  correct,
  incorrect,
  disabled,
}

/// Carte de choix interactif Audio-First & Erfe (« Sahel Modern » — Lot 4B.1).
///
/// Caractéristiques :
/// - Hauteur minimale de 64 dp (cible tactile >= 48 dp WCAG 2.5.5).
/// - Rendu natif des glyphes Erfe via la police `Kedebideri` (26 sp+).
/// - Bouton d'écoute optionnel intégré (48x48 dp).
/// - États différenciés par couleur, bordure ET icône (accessibilité daltonisme).
class BkOptionCard extends StatelessWidget {
  final String label;
  final String? erfeText;
  final String? subtitle;
  final BkOptionCardState state;
  final VoidCallback? onTap;
  final VoidCallback? onPlayAudio;

  const BkOptionCard({
    super.key,
    required this.label,
    this.erfeText,
    this.subtitle,
    this.state = BkOptionCardState.neutral,
    this.onTap,
    this.onPlayAudio,
  });

  bool get _isInteractive => state != BkOptionCardState.disabled && onTap != null;

  String _stateSemanticDescription() {
    return switch (state) {
      BkOptionCardState.neutral => 'Non sélectionné',
      BkOptionCardState.selected => 'Sélectionné',
      BkOptionCardState.correct => 'Réponse correcte',
      BkOptionCardState.incorrect => 'Réponse à réessayer',
      BkOptionCardState.disabled => 'Désactivé',
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);

    final Color borderColor = switch (state) {
      BkOptionCardState.neutral => palette.border,
      BkOptionCardState.selected => palette.accentGold,
      BkOptionCardState.correct => palette.statusSuccess,
      BkOptionCardState.incorrect => palette.statusEncouragement,
      BkOptionCardState.disabled => palette.border.withValues(alpha: 0.45),
    };

    final Color backgroundColor = switch (state) {
      BkOptionCardState.neutral => palette.surface,
      BkOptionCardState.selected => palette.surfaceElevated,
      BkOptionCardState.correct => palette.surfaceElevated,
      BkOptionCardState.incorrect => palette.surface,
      BkOptionCardState.disabled => palette.surface.withValues(alpha: 0.6),
    };

    final IconData indicatorIcon = switch (state) {
      BkOptionCardState.neutral => Icons.radio_button_unchecked_rounded,
      BkOptionCardState.selected => Icons.radio_button_checked_rounded,
      BkOptionCardState.correct => Icons.check_circle_rounded,
      BkOptionCardState.incorrect => Icons.error_outline_rounded,
      BkOptionCardState.disabled => Icons.remove_circle_outline_rounded,
    };

    final Color indicatorColor = switch (state) {
      BkOptionCardState.neutral => palette.textSecondary,
      BkOptionCardState.selected => palette.accentGold,
      BkOptionCardState.correct => palette.statusSuccess,
      BkOptionCardState.incorrect => palette.statusEncouragement,
      BkOptionCardState.disabled => palette.textSecondary.withValues(alpha: 0.5),
    };

    final hasErfe = erfeText != null && erfeText!.trim().isNotEmpty;

    return Semantics(
      button: _isInteractive,
      enabled: _isInteractive,
      selected: state == BkOptionCardState.selected || state == BkOptionCardState.correct,
      label: hasErfe ? '$erfeText — $label' : label,
      value: _stateSemanticDescription(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(
          minHeight: AppTokens.optionCardMinHeight,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: borderColor,
            width: state == BkOptionCardState.neutral ? 1.4 : 2.2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('bk-option-card-tap'),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            onTap: _isInteractive ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceLg,
                vertical: AppTokens.spaceMd,
              ),
              child: Row(
                children: [
                  if (onPlayAudio != null) ...[
                    SizedBox(
                      width: AppTokens.minTouchTarget,
                      height: AppTokens.minTouchTarget,
                      child: IconButton(
                        key: const ValueKey('bk-option-audio-button'),
                        onPressed: onPlayAudio,
                        tooltip: 'Écouter l’option',
                        icon: Icon(
                          Icons.volume_up_rounded,
                          color: palette.accentGold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                  ],
                  if (hasErfe) ...[
                    Text(
                      erfeText!,
                      style: AppTextStyles.erfeOptionTextOf(context),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (label.isNotEmpty)
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: AppTextStyles.latinCaption.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Icon(
                    indicatorIcon,
                    key: const ValueKey('bk-option-state-icon'),
                    color: indicatorColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
