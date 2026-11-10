import 'package:flutter/material.dart';

import '../audio/audio_url_player.dart';
import '../audio/bk_audio_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Bouton central d'écoute Audio-First (« Sahel Modern » — Lot 4B.1).
///
/// Caractéristiques :
/// - Cible tactile principale large (84 dp par défaut, >= 48 dp WCAG 2.5.5).
/// - Bouton de réécoute explicite toujours visible (>= 48 dp de hauteur).
/// - Bouton optionnel d'écoute lente décomposée (>= 48 dp de hauteur).
/// - Respecte la préférence utilisateur de lecture automatique (`BkAudioPreferencesService`).
/// - Compatible thèmes Sombre et Clair, sans animation lourde bloquante.
class BkAudioHeroButton extends StatefulWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onPlaySlow;
  final AudioPlaybackStatus status;
  final bool autoPlay;
  final String label;
  final String replayLabel;
  final String slowLabel;
  final String? semanticLabel;
  final double size;
  final bool showReplayButton;

  const BkAudioHeroButton({
    super.key,
    required this.onPlay,
    this.onPlaySlow,
    this.status = AudioPlaybackStatus.idle,
    this.autoPlay = false,
    this.label = 'Écouter la prononciation',
    this.replayLabel = 'Réécouter',
    this.slowLabel = 'Écoute lente',
    this.semanticLabel,
    this.size = AppTokens.audioHeroButtonSize,
    this.showReplayButton = true,
  });

  @override
  State<BkAudioHeroButton> createState() => _BkAudioHeroButtonState();
}

class _BkAudioHeroButtonState extends State<BkAudioHeroButton> {
  bool _hasTriggeredAutoPlay = false;

  @override
  void initState() {
    super.initState();
    _maybeTriggerAutoPlay();
  }

  @override
  void didUpdateWidget(covariant BkAudioHeroButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoPlay && widget.autoPlay && !_hasTriggeredAutoPlay) {
      _maybeTriggerAutoPlay();
    }
  }

  Future<void> _maybeTriggerAutoPlay() async {
    if (!widget.autoPlay || _hasTriggeredAutoPlay || widget.onPlay == null) {
      return;
    }
    _hasTriggeredAutoPlay = true;
    final enabled = await BkAudioPreferencesService.isAutoPlayEnabled();
    if (!mounted || !enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onPlay?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);
    final isPlaying = widget.status == AudioPlaybackStatus.playing;
    final isLoading = widget.status == AudioPlaybackStatus.loading;
    final isFailed = widget.status == AudioPlaybackStatus.failed;

    final effectiveSize = widget.size < AppTokens.minTouchTarget
        ? AppTokens.minTouchTarget
        : widget.size;

    final ringColor = isFailed
        ? palette.statusError.withValues(alpha: 0.28)
        : palette.accentGold.withValues(alpha: isPlaying ? 0.35 : 0.16);

    final IconData mainIcon = switch (widget.status) {
      AudioPlaybackStatus.playing => Icons.graphic_eq_rounded,
      AudioPlaybackStatus.paused => Icons.play_arrow_rounded,
      AudioPlaybackStatus.failed => Icons.refresh_rounded,
      _ => Icons.volume_up_rounded,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: widget.onPlay != null,
          label: widget.semanticLabel ?? widget.label,
          value: widget.status.name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(isPlaying ? 12.0 : 8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ringColor,
              border: Border.all(
                color: isFailed
                    ? palette.statusError
                    : palette.accentGold.withValues(alpha: isPlaying ? 0.85 : 0.45),
                width: isPlaying ? 2.2 : 1.4,
              ),
            ),
            child: Material(
              color: isFailed ? palette.statusError : palette.accentGold,
              shape: const CircleBorder(),
              elevation: isPlaying ? AppTokens.elevationHigh : AppTokens.elevationMedium,
              child: InkWell(
                key: const ValueKey('bk-audio-hero-circle'),
                customBorder: const CircleBorder(),
                onTap: widget.onPlay,
                child: SizedBox(
                  width: effectiveSize,
                  height: effectiveSize,
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: palette.accentGoldForeground,
                            ),
                          )
                        : Icon(
                            mainIcon,
                            size: effectiveSize * 0.44,
                            color: isFailed
                                ? AppColors.white
                                : palette.accentGoldForeground,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceSm,
          children: [
            if (widget.showReplayButton)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                  minWidth: AppTokens.minTouchTarget,
                ),
                child: OutlinedButton.icon(
                  key: const ValueKey('bk-audio-replay-button'),
                  onPressed: widget.onPlay,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    backgroundColor: palette.surfaceElevated,
                    side: BorderSide(color: palette.border, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceLg,
                      vertical: AppTokens.spaceSm,
                    ),
                  ),
                  icon: Icon(
                    isFailed ? Icons.refresh_rounded : Icons.replay_rounded,
                    size: 20,
                    color: isFailed ? palette.statusError : palette.accentGold,
                  ),
                  label: Text(
                    widget.replayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            if (widget.onPlaySlow != null)
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                  minWidth: AppTokens.minTouchTarget,
                ),
                child: OutlinedButton.icon(
                  key: const ValueKey('bk-audio-slow-button'),
                  onPressed: widget.onPlaySlow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    backgroundColor: palette.surface,
                    side: BorderSide(color: palette.border, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceLg,
                      vertical: AppTokens.spaceSm,
                    ),
                  ),
                  icon: Icon(
                    Icons.slow_motion_video_rounded,
                    size: 20,
                    color: palette.accentGold,
                  ),
                  label: Text(
                    widget.slowLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
