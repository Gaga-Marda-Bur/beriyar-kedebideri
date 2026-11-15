import 'package:flutter/material.dart';

import '../../../core/audio/audio_url_player.dart';
import '../../../core/audio/bk_audio_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bk_audio_hero_button.dart';
import '../../../core/widgets/bk_feedback_sheet.dart';
import '../../../core/widgets/bk_option_card.dart';
import '../../../core/widgets/glass_card.dart';
import '../srs/local_srs_service.dart';
import '../srs/srs_item_model.dart';

/// Interface minimale de séance de révision espacée Audio-First (Lot 4B.3).
///
/// Principes pédagogiques :
/// - Privilégie la correspondance Audio authentique -> Écriture Erfe.
/// - Ne révèle jamais la réponse Erfe attendue avant le choix de l'apprenant.
/// - Ne pénalise jamais l'apprenant lorsque l'audio d'un élément est absent.
/// - Met à jour les intervalles SRS (1, 3, 7, 14, 30 jours) localement hors ligne.
class SrsReviewSessionScreen extends StatefulWidget {
  final List<SrsItemRecord> items;
  final List<String> distractorPool;
  final LocalSrsService? srsService;
  final AudioUrlPlayer? audioPlayer;

  const SrsReviewSessionScreen({
    super.key,
    required this.items,
    this.distractorPool = const ['𖺠', '𖺡', '𖺣', '𖺵'],
    this.srsService,
    this.audioPlayer,
  });

  @override
  State<SrsReviewSessionScreen> createState() => _SrsReviewSessionScreenState();
}

class _SrsReviewSessionScreenState extends State<SrsReviewSessionScreen> {
  late final AudioUrlPlayer _audioPlayer;
  late final bool _ownsAudioPlayer;
  late final LocalSrsService _srsService;

  int _currentIndex = 0;
  bool _autoPlayEnabled = true;
  bool _answeredCurrent = false;
  bool _currentWasCorrect = false;
  String? _selectedOption;
  SrsItemRecord? _lastUpdatedRecord;
  final List<SrsItemRecord> _updatedRecords = [];

  @override
  void initState() {
    super.initState();
    _ownsAudioPlayer = widget.audioPlayer == null;
    _audioPlayer = widget.audioPlayer ?? AudioUrlPlayer();
    _srsService = widget.srsService ?? LocalSrsService();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      _autoPlayEnabled = await BkAudioPreferencesService.isAutoPlayEnabled();
    } catch (_) {
      _autoPlayEnabled = true;
    }
    if (!mounted) return;
    _playCurrentAudioIfAuto();
  }

  @override
  void dispose() {
    if (_ownsAudioPlayer) {
      _audioPlayer.dispose();
    }
    super.dispose();
  }

  bool _hasAudio(SrsItemRecord item) {
    return item.audioUrl != null && item.audioUrl!.trim().isNotEmpty;
  }

  void _playCurrentAudioIfAuto() {
    if (!_autoPlayEnabled ||
        widget.items.isEmpty ||
        _currentIndex >= widget.items.length) {
      return;
    }
    final current = widget.items[_currentIndex];
    if (_hasAudio(current)) {
      _audioPlayer.playUrl(current.audioUrl);
    } else {
      _audioPlayer.stop();
    }
  }

  void _playAudio(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _audioPlayer.playUrl(url);
    }
  }

  List<String> _buildOptionsFor(SrsItemRecord item) {
    final result = <String>[item.erfeText];
    for (final candidate in widget.distractorPool) {
      if (candidate != item.erfeText && !result.contains(candidate)) {
        result.add(candidate);
        if (result.length >= 3) break;
      }
    }
    for (final other in widget.items) {
      if (other.erfeText != item.erfeText && !result.contains(other.erfeText)) {
        result.add(other.erfeText);
        if (result.length >= 3) break;
      }
    }
    return result;
  }

  Future<void> _selectOption(SrsItemRecord item, String chosenErfe) async {
    if (_answeredCurrent) return;
    final isCorrect = chosenErfe == item.erfeText;
    final audioMissing = !_hasAudio(item);

    final updated = await _srsService.recordOutcome(
      itemType: item.itemType,
      erfeText: item.erfeText,
      unitSlug: item.unitSlug,
      correct: isCorrect,
      audioMissing: audioMissing,
      phonemeIpa: item.phonemeIpa,
      latinTranscription: item.latinTranscription,
      translationFr: item.translationFr,
      audioUrl: item.audioUrl,
    );

    if (!mounted) return;
    setState(() {
      _answeredCurrent = true;
      _currentWasCorrect = isCorrect;
      _selectedOption = chosenErfe;
      _lastUpdatedRecord = updated ?? item;
      if (updated != null) {
        _updatedRecords.add(updated);
      }
    });
  }

  void _nextItem() {
    if (!_answeredCurrent) return;
    setState(() {
      _currentIndex++;
      _answeredCurrent = false;
      _currentWasCorrect = false;
      _selectedOption = null;
      _lastUpdatedRecord = null;
    });
    _playCurrentAudioIfAuto();
  }

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);

    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          title: const Text('Révision espacée (SRS)'),
        ),
        body: AppBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: palette.statusSuccess,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun élément à réviser pour le moment',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Retour'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isFinished = _currentIndex >= widget.items.length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        title: Text(
          isFinished
              ? 'Bilan SRS (${_updatedRecords.length}/${widget.items.length})'
              : 'Révision SRS (${_currentIndex + 1}/${widget.items.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: isFinished
                ? _buildSummaryCard(palette)
                : _buildQuestionCard(widget.items[_currentIndex], palette),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(SrsItemRecord item, BkThemePalette palette) {
    final hasAudio = _hasAudio(item);
    final options = _buildOptionsFor(item);
    final promptHint = !hasAudio
        ? (item.translationFr.isNotEmpty
            ? 'Touchez l\'écriture Erfe correspondant à « ${item.translationFr} »'
            : item.phonemeIpa.isNotEmpty && item.phonemeIpa != 'À_VALIDER'
            ? 'Touchez le caractère Erfe du son /${item.phonemeIpa}/'
            : 'Touchez l\'écriture Erfe correspondante')
        : (item.translationFr.isNotEmpty
            ? 'Écoutez et touchez l\'écriture Erfe pour « ${item.translationFr} »'
            : item.phonemeIpa.isNotEmpty && item.phonemeIpa != 'À_VALIDER'
            ? 'Écoutez et touchez le caractère Erfe du son /${item.phonemeIpa}/'
            : 'Écoutez l\'enregistrement et touchez l\'écriture Erfe correspondante');

    return GlassCard(
      key: ValueKey('srs-question-${item.stableId}'),
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête : NE JAMAIS révéler `item.erfeText` avant la réponse !
              Text(
                promptHint,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceMd),
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                label: promptHint,
                onPlay: hasAudio ? () => _playAudio(item.audioUrl) : null,
              ),
              if (!hasAudio)
                Container(
                  key: const ValueKey('srs-audio-missing-banner'),
                  margin: const EdgeInsets.only(top: AppTokens.spaceSm),
                  padding: const EdgeInsets.all(AppTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    'Audio absent — aucune pénalité SRS ne sera appliquée en cas d\'erreur.',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppTokens.spaceXl),
              for (final optionErfe in options) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
                  child: BkOptionCard(
                    key: ValueKey('srs-option-${item.stableId}-$optionErfe'),
                    label: '',
                    erfeText: optionErfe,
                    state: !_answeredCurrent
                        ? BkOptionCardState.neutral
                        : optionErfe == item.erfeText
                        ? BkOptionCardState.correct
                        : (_selectedOption == optionErfe
                              ? BkOptionCardState.incorrect
                              : BkOptionCardState.disabled),
                    onTap: _answeredCurrent
                        ? null
                        : () => _selectOption(item, optionErfe),
                  ),
                ),
              ],
              if (_answeredCurrent && _lastUpdatedRecord != null) ...[
                const SizedBox(height: AppTokens.spaceSm),
                BkFeedbackSheet(
                  type: _currentWasCorrect
                      ? BkFeedbackType.positive
                      : BkFeedbackType.encouragement,
                  title: _currentWasCorrect
                      ? 'Mémorisation consolidée !'
                      : (!hasAudio
                            ? 'Audio absent — aucune pénalité'
                            : 'À revoir bientôt'),
                  message:
                      'Prochaine révision : dans ${_lastUpdatedRecord!.intervalDays} jour(s) · Niveau ${_lastUpdatedRecord!.masteryLevel}/5',
                  erfeText: item.erfeText,
                  onReplayAudio: hasAudio
                      ? () => _playAudio(item.audioUrl)
                      : null,
                  onContinue: _nextItem,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BkThemePalette palette) {
    return GlassCard(
      key: const ValueKey('srs-summary-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: palette.accentGold,
            size: 64,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            'Révision espacée terminée',
            style: TextStyle(
              color: palette.accentGold,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          for (final rec in _updatedRecords) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rec.erfeText,
                    style: AppTextStyles.erfeOptionTextOf(context),
                  ),
                  Text(
                    'Niveau ${rec.masteryLevel}/5 · +${rec.intervalDays} j',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTokens.spaceLg),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.primaryCtaHeight,
            ),
            child: FilledButton.icon(
              key: const ValueKey('srs-finish-button'),
              onPressed: () => Navigator.of(context).pop(_updatedRecords),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Terminer la révision'),
            ),
          ),
        ],
      ),
    );
  }
}
