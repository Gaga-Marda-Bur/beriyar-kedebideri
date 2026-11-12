import 'package:flutter/material.dart';
import '../../../core/audio/audio_url_player.dart';
import '../../../core/audio/bk_audio_preferences.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bk_audio_hero_button.dart';
import '../../../core/widgets/bk_feedback_sheet.dart';
import '../../../core/widgets/bk_option_card.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/beriya/beriya_keyboard.dart';
import '../../../shared/beriya/utf16_safe.dart';
import '../../../shared/beriya/transliteration.dart';
import '../../progress/services/unit_progress_local_storage.dart';
import '../../quiz/models/quiz_question_model.dart';
import '../engine/tracing_engine.dart';
import '../engine/learning_session.dart';
import '../models/learning_unit_model.dart';
import '../srs/local_srs_service.dart';
import '../srs/srs_item_model.dart';
import '../widgets/interactive_tracing_pad.dart';
import '../widgets/syllable_fusion_widget.dart';
import 'srs_review_session_screen.dart';

class LearningCoreUnitScreen extends StatefulWidget {
  final LearningUnitModel? unit;
  final String? unitSlug;
  final CachedContentService? contentService;
  final LocalSrsService? srsService;

  const LearningCoreUnitScreen({
    super.key,
    this.unit,
    this.unitSlug,
    this.contentService,
    this.srsService,
  });

  @override
  State<LearningCoreUnitScreen> createState() => _LearningCoreUnitScreenState();
}

class _LearningCoreUnitScreenState extends State<LearningCoreUnitScreen> {
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();
  late final CachedContentService _contentService;
  late final LocalSrsService _srsService;

  LearningUnitModel? _unit;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentStep = 0;
  List<Map<String, dynamic>> _steps = [];

  LearningSession? _session;
  Future<void> _pendingSave = Future.value();
  bool _saving = false;

  int _tracingAttempt = 1;
  String _typedText = '';
  bool _autoPlayEnabled = true;
  final Map<int, String> _lastSelectedSymbolByStep = {};
  Map<String, SrsItemRecord> _srsRecordsByStableId = {};

  @override
  void initState() {
    super.initState();
    _contentService = widget.contentService ?? CachedContentService();
    _srsService = widget.srsService ?? LocalSrsService();
    _initUnit();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initUnit() async {
    if (widget.unit != null) {
      await _applyUnit(widget.unit!);
      return;
    }

    if (widget.unitSlug == null || widget.unitSlug!.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Aucune unité spécifiée.';
      });
      return;
    }

    try {
      final units = await _contentService.loadUnits();
      LearningUnitModel? found;

      try {
        found = units.firstWhere((u) => u.slug == widget.unitSlug);
      } catch (_) {}

      if (found != null) {
        await _applyUnit(found);
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Cette unité n\'est pas disponible sur cet appareil.\n\n'
              'Identifiant demandé : "${widget.unitSlug}"\n\n'
              'Veuillez télécharger le pack correspondant ou vérifier votre connexion.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Impossible de charger l\'unité demandée.\n\n'
            'Veuillez vérifier vos packs installés ou votre connexion.';
      });
    }
  }

  Future<void> _applyUnit(LearningUnitModel unit) async {
    final steps = unit.effectiveCoreFlow;
    final actionableSteps = steps
        .where((s) => s['step_type'] != 'celebration')
        .toList();

    const supported = {
      'discovery',
      'discrimination',
      'tracing',
      'fusion',
      'word_decoding',
      'keyboard_encoding',
      'celebration',
    };
    if (actionableSteps.isEmpty ||
        steps.any((step) => !supported.contains(step['step_type']))) {
      if (!mounted) return;
      setState(() {
        _unit = unit;
        _steps = [];
        _isLoading = false;
        _errorMessage =
            'Cette unité est en cours de validation pédagogique.\n\n'
            'Ses exercices et ressources associées ne sont pas encore disponibles publiquement.';
      });
      return;
    }

    final session = LearningSession(steps, {
      'recognition': unit.weightRecognition,
      'tracing': unit.enableTracing ? unit.weightTracing : 0,
      'encoding': unit.weightEncoding,
    }, unit.minScoreToPass);
    await _progressStorage.restoreSession(unit.slug, session);
    try {
      await _srsService.reconcileWithUnit(unit);
      _srsRecordsByStableId = await _srsService.loadAllMap();
    } catch (_) {
      _srsRecordsByStableId = <String, SrsItemRecord>{};
    }
    try {
      _autoPlayEnabled = await BkAudioPreferencesService.isAutoPlayEnabled();
    } catch (_) {
      _autoPlayEnabled = true;
    }
    if (!mounted) return;
    setState(() {
      _unit = unit;
      _steps = steps;
      _session = session;
      _isLoading = false;
      _errorMessage = null;
      _currentStep = session.currentStep;
      _tracingAttempt =
          ((session.answers[session.currentStep]?['successes'] as int? ?? 0) +
                  1)
              .clamp(1, 2);
      _typedText = session.typedText;
    });
    _autoPlayCurrentStepIfEnabled();
  }

  Future<void> _toggleAutoPlay() async {
    final nextValue = !_autoPlayEnabled;
    setState(() {
      _autoPlayEnabled = nextValue;
    });
    await BkAudioPreferencesService.setAutoPlayAudio(nextValue);
    if (!nextValue) {
      await _audioPlayer.stop();
    }
  }

  Future<void> _persistSession() {
    if (_session == null || _unit == null) return Future.value();
    _session!.currentStep = _currentStep;
    _session!.typedText = _typedText;
    final snapshot = LearningSession(
      _steps,
      _session!.weights,
      _session!.threshold,
    )..restore(_session!.toJson());
    final slug = _unit!.slug;
    final write = _pendingSave.then(
      (_) => _progressStorage.saveSession(slug, snapshot),
    );
    _pendingSave = write.catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                'Enregistrement impossible. Réessaie avant de quitter.',
                'Could not save. Try again before leaving.',
                'تعذّر الحفظ. حاول مجددًا قبل المغادرة.',
              ),
            ),
          ),
        );
      }
    });
    return write;
  }

  String _text(String fr, String en, String ar) =>
      switch (Localizations.localeOf(context).languageCode) {
        'en' => en,
        'ar' => ar,
        _ => fr,
      };

  Future<void> _restartSession() async {
    if (_saving || _session == null || _unit == null) return;
    setState(() => _saving = true);
    try {
      await _pendingSave;
      await _progressStorage.archiveSession(_unit!.slug, _session!);
      if (!mounted) return;
      setState(() {
        _session = LearningSession(
          _steps,
          _session!.weights,
          _session!.threshold,
        );
        _currentStep = 0;
        _typedText = '';
        _lastSelectedSymbolByStep.clear();
      });
      await _persistSession();
      if (mounted) _autoPlayCurrentStepIfEnabled();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                'Enregistrement impossible. Réessaie.',
                'Could not save. Try again.',
                'تعذّر الحفظ. حاول مجددًا.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _answer(bool correct, {String? selectedSymbol}) {
    if (!mounted ||
        _session == null ||
        _session!.resolved(_currentStep) ||
        _session!.finished) {
      return;
    }
    final isFirstAttempt = _session!.answers[_currentStep] == null;
    final currentStepMap = _steps[_currentStep];
    setState(() {
      if (selectedSymbol != null) {
        _lastSelectedSymbolByStep[_currentStep] = selectedSymbol;
      }
      _session!.answer(correct);
      _tracingAttempt =
          ((_session!.answers[_currentStep]?['successes'] as int? ?? 0) + 1)
              .clamp(1, 2);
    });
    if (correct) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _persistSession().catchError((Object _) {});
    if (isFirstAttempt) {
      _recordStepSrs(currentStepMap, correct);
    }
  }

  Future<void> _recordStepSrs(
    Map<String, dynamic> step,
    bool firstAttemptCorrect,
  ) async {
    final unit = _unit;
    if (unit == null) return;
    final erfeTarget = _stepErfeTarget(step);
    if (erfeTarget.trim().isEmpty) return;
    final stepType = step['step_type'] as String? ?? '';
    final itemType = (stepType == 'encoding' || step.containsKey('target_word'))
        ? 'word'
        : 'char';
    final label = (step['french_translation'] ?? step['label'] ?? '')
        .toString();
    final audioUrl = step['audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);
    try {
      final updated = await _srsService.recordOutcome(
        unitSlug: unit.slug,
        itemType: itemType,
        erfeText: erfeTarget,
        correct: firstAttemptCorrect,
        audioMissing: !hasAudio,
        label: label,
        audioUrl: audioUrl,
      );
      if (updated != null && mounted) {
        setState(() {
          _srsRecordsByStableId = {
            ..._srsRecordsByStableId,
            updated.stableId: updated,
          };
        });
      }
    } catch (_) {
      // Never block lesson progression if local SRS storage fails.
    }
  }

  bool _stepHasAudio(Map<String, dynamic> step) {
    final audioUrl = step['audio_url'] as String?;
    return audioUrl != null && audioUrl.trim().isNotEmpty;
  }

  void _autoPlayCurrentStepIfEnabled() {
    if (!_autoPlayEnabled) {
      _audioPlayer.stop();
      return;
    }
    _playCurrentStepAudio();
  }

  void _playCurrentStepAudio() {
    if (_steps.isEmpty || _currentStep >= _steps.length) return;
    final step = _steps[_currentStep];
    final audioUrl = step['audio_url'] as String?;
    if (audioUrl != null && audioUrl.trim().isNotEmpty) {
      _audioPlayer.playUrl(audioUrl);
    } else {
      _audioPlayer.stop();
    }
  }

  void _playStepAudioUrl(String? audioUrl) {
    if (audioUrl != null && audioUrl.trim().isNotEmpty) {
      _audioPlayer.playUrl(audioUrl);
    }
  }

  void _nextStep() {
    if (!mounted ||
        _session == null ||
        _session!.finished ||
        !_session!.canAdvance) {
      return;
    }
    _session!.viewed.add(_currentStep);
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _tracingAttempt =
            ((_session!.answers[_currentStep]?['successes'] as int? ?? 0) + 1)
                .clamp(1, 2);
        _typedText = '';
      });
      _session!.currentStep = _currentStep;
      _persistSession().catchError((Object _) {});
      _autoPlayCurrentStepIfEnabled();
    } else {
      _finishUnit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0 && !_saving && _session?.finished != true) {
      setState(() {
        _currentStep--;
        _tracingAttempt =
            ((_session!.answers[_currentStep]?['successes'] as int? ?? 0) + 1)
                .clamp(1, 2);
        _typedText = '';
      });
      _session!.currentStep = _currentStep;
      _persistSession().catchError((Object _) {});
      _autoPlayCurrentStepIfEnabled();
    }
  }

  Future<void> _finishUnit() async {
    if (_session == null ||
        _saving ||
        _session!.finished ||
        _currentStep != _steps.length - 1) {
      return;
    }
    _session!.viewed.add(_currentStep);
    setState(() => _saving = true);
    _session!.finished = true;
    try {
      await _persistSession();
    } catch (_) {
      _session!.finished = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _phaseLabelForStep(String stepType) {
    return switch (stepType) {
      'discovery' => _text('1. ÉCOUTER', '1. LISTEN', '١. استمع'),
      'discrimination' => _text('2. RECONNAÎTRE', '2. RECOGNIZE', '٢. تعرّف'),
      'fusion' || 'word_decoding' => _text('3. LIRE', '3. READ', '٣. اقرأ'),
      'keyboard_encoding' => _text('4. COMPOSER', '4. COMPOSE', '٤. ركّب'),
      'tracing' => _text('PRATIQUER', 'PRACTICE', 'تدرّب'),
      'celebration' => _text('5. RÉVISER', '5. REVIEW', '٥. راجع'),
      _ => _text('SÉANCE', 'SESSION', 'جلسة'),
    };
  }

  IconData _phaseIconForStep(String stepType) {
    return switch (stepType) {
      'discovery' => Icons.headphones_rounded,
      'discrimination' => Icons.touch_app_rounded,
      'fusion' || 'word_decoding' => Icons.menu_book_rounded,
      'keyboard_encoding' => Icons.keyboard_alt_rounded,
      'tracing' => Icons.gesture_rounded,
      'celebration' => Icons.auto_awesome_rounded,
      _ => Icons.school_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = BkThemePalette.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.background,
        body: AppBackground(
          child: Center(
            child: CircularProgressIndicator(color: palette.accentGold),
          ),
        ),
      );
    }

    if (_errorMessage != null || _unit == null || _steps.isEmpty) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: Text(_unit?.titleFr ?? 'Alphabétisation Beriya Erfe'),
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
                      Icons.info_outline_rounded,
                      color: palette.accentGold,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _unit != null ? _unit!.titleFr : 'Contenu indisponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.accentGold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kedebideri',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? 'Cette unité n\'est pas disponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Retour au parcours'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final totalSteps = _steps.length;
    final currentStepMap = _steps[_currentStep];
    final currentStepType = currentStepMap['step_type'] as String? ?? '';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        title: Text(
          '${_unit!.titleFr} (${_currentStep + 1}/$totalSteps)',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'Kedebideri',
            color: palette.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: _text('Quitter la séance', 'Close session', 'إغلاق الجلسة'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Semantics(
            button: true,
            toggled: _autoPlayEnabled,
            label: _autoPlayEnabled
                ? _text(
                    'Lecture audio automatique activée',
                    'Auto-play audio enabled',
                    'التشغيل التلقائي للصوت مفعّل',
                  )
                : _text(
                    'Lecture audio automatique désactivée',
                    'Auto-play audio disabled',
                    'التشغيل التلقائي للصوت معطّل',
                  ),
            child: IconButton(
              key: const ValueKey('toggle-autoplay-button'),
              constraints: const BoxConstraints(
                minWidth: AppTokens.minTouchTarget,
                minHeight: AppTokens.minTouchTarget,
              ),
              tooltip: _autoPlayEnabled
                  ? _text('Auto-play : activé', 'Auto-play: ON', 'التشغيل التلقائي: مفعّل')
                  : _text('Auto-play : désactivé', 'Auto-play: OFF', 'التشغيل التلقائي: معطّل'),
              onPressed: _toggleAutoPlay,
              icon: Icon(
                _autoPlayEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: _autoPlayEnabled
                    ? palette.accentGold
                    : palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Barre de progression supérieure
              Semantics(
                label: _text(
                  'Étape ${_currentStep + 1} sur $totalSteps',
                  'Step ${_currentStep + 1} of $totalSteps',
                  'الخطوة ${_currentStep + 1} من $totalSteps',
                ),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / totalSteps,
                  backgroundColor: palette.border.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(palette.accentGold),
                  minHeight: 6,
                ),
              ),

              // En-tête de phase pédagogique (1. ÉCOUTER / 2. RECONNAÎTRE / 3. LIRE / 4. COMPOSER / 5. RÉVISER)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        key: const ValueKey('session-phase-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                          border: Border.all(color: palette.accentGold, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _phaseIconForStep(currentStepType),
                              size: 16,
                              color: palette.accentGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _phaseLabelForStep(currentStepType),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: palette.accentGold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<AudioPlaybackStatus>(
                        valueListenable: _audioPlayer.status,
                        builder: (context, status, _) => Semantics(
                          liveRegion: true,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              if (status == AudioPlaybackStatus.loading)
                                Text(
                                  _text(
                                    'Chargement audio…',
                                    'Loading audio…',
                                    'جارٍ تحميل الصوت…',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              if (status == AudioPlaybackStatus.failed &&
                                  _stepHasAudio(currentStepMap))
                                TextButton.icon(
                                  key: const ValueKey('audio-failed-retry-button'),
                                  onPressed: _playCurrentStepAudio,
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: palette.statusEncouragement,
                                  ),
                                  label: Text(
                                    _text(
                                      'Audio indisponible · Réessayer',
                                      'Audio unavailable · Try again',
                                      'الصوت غير متاح · حاول مجددًا',
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.statusEncouragement,
                                    ),
                                  ),
                                ),
                              if (status == AudioPlaybackStatus.playing)
                                TextButton.icon(
                                  onPressed: _audioPlayer.pause,
                                  icon: const Icon(Icons.pause_rounded, size: 16),
                                  label: Text(
                                    _text('Pause', 'Pause', 'إيقاف مؤقت'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: AnimatedSwitcher(
                      duration: disableAnimations
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildCurrentStepWidget(),
                      ),
                    ),
                  ),
                ),
              ),

              // Barre de navigation inférieure
              _buildBottomBar(totalSteps, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingAudioBanner(BkThemePalette palette) {
    return Semantics(
      container: true,
      label: _text(
        'Enregistrement audio non disponible pour cet élément. Vous pouvez continuer avec l\'écriture Erfe.',
        'Audio recording not available for this item. You can continue with the Erfe script.',
        'التسجيل الصوتي غير متوفر لهذا العنصر. يمكنك المتابعة.',
      ),
      child: Container(
        key: const ValueKey('audio-missing-banner'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppTokens.spaceSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.volume_off_rounded,
              color: AppColors.info,
              size: 20,
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Text(
                _text(
                  'Audio en cours d\'enregistrement — observez la forme Erfe pour continuer.',
                  'Audio recording pending — observe the Erfe form to continue.',
                  'التسجيل الصوتي قيد الإعداد — لاحظ شكل الحرف للمتابعة.',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    if (_steps.isEmpty || _currentStep >= _steps.length) {
      return const SizedBox.shrink();
    }

    final step = _steps[_currentStep];
    final stepType = step['step_type'] as String? ?? '';

    switch (stepType) {
      case 'discovery':
        return _buildDiscoveryCard(step);
      case 'discrimination':
        return _buildDiscriminationCard(step);
      case 'tracing':
        return _buildTracingCard(step);
      case 'fusion':
        return _buildFusionCard(step);
      case 'word_decoding':
        return _buildWordDecodingCard(step);
      case 'keyboard_encoding':
        return _buildKeyboardWordCard(step);
      case 'celebration':
      default:
        return _buildCelebrationCard(step);
    }
  }

  // --- Étape 1 : ÉCOUTER (discovery) ---

  Widget _buildDiscoveryCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final symbol = step['symbol'] as String? ?? '';
    final phonemeIpa = step['phoneme_ipa'] as String? ?? '';
    final label = step['label'] as String? ?? 'Écoute et découvre le caractère';
    final audioUrl = step['audio_url'] as String?;
    final slowAudioUrl = step['slow_audio_url'] as String?;
    final letterNameAudioUrl = step['letter_name_audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);

    return GlassCard(
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceLg),
              if (symbol.isNotEmpty) ...[
                Semantics(
                  label: 'Caractère Erfe $symbol',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXl,
                      vertical: AppTokens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(
                        color: palette.accentGold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      symbol,
                      style: AppTextStyles.erfeDisplayHeroOf(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
              ],
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                label: label,
                onPlay: hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
                onPlaySlow:
                    slowAudioUrl != null && slowAudioUrl.trim().isNotEmpty
                    ? () => _playStepAudioUrl(slowAudioUrl)
                    : null,
              ),
              if (!hasAudio) _buildMissingAudioBanner(palette),
              if (phonemeIpa.isNotEmpty && phonemeIpa != 'À_VALIDER') ...[
                const SizedBox(height: AppTokens.spaceMd),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: AppTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Son : /$phonemeIpa/',
                    style: TextStyle(
                      color: palette.accentGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              if (letterNameAudioUrl != null &&
                  letterNameAudioUrl.trim().isNotEmpty) ...[
                const SizedBox(height: AppTokens.spaceMd),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  child: OutlinedButton.icon(
                    key: const ValueKey('letter-name-audio-button'),
                    onPressed: () => _playStepAudioUrl(letterNameAudioUrl),
                    icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                    label: Text(
                      _text(
                        'Nom de la lettre',
                        'Letter name',
                        'اسم الحرف',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // --- Étape 2 : RECONNAÎTRE (discrimination) ---

  Widget _buildDiscriminationCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final target = step['target_symbol'] as String? ?? '';
    final other = step['other_symbol'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ?? 'Touche le bon caractère :';
    final audioUrl = step['audio_url'] as String?;
    final slowAudioUrl = step['slow_audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);

    final stepAnswer = _session?.answers[_currentStep];
    final isResolved = _session?.resolved(_currentStep) == true;
    final hasAttempted = stepAnswer != null;
    final lastSelected = _lastSelectedSymbolByStep[_currentStep];

    final options = <MapEntry<String, bool>>[
      MapEntry(target, true),
      if (other.isNotEmpty) MapEntry(other, false),
    ];

    return GlassCard(
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                instruction,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceMd),
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                label: instruction,
                onPlay: hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
                onPlaySlow:
                    slowAudioUrl != null && slowAudioUrl.trim().isNotEmpty
                    ? () => _playStepAudioUrl(slowAudioUrl)
                    : null,
              ),
              if (!hasAudio) _buildMissingAudioBanner(palette),
              const SizedBox(height: AppTokens.spaceXl),
              for (final opt in options) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
                  child: BkOptionCard(
                    key: ValueKey('answer-$_currentStep-${opt.key}'),
                    label: '',
                    erfeText: opt.key,
                    state: isResolved
                        ? (opt.value
                              ? BkOptionCardState.correct
                              : BkOptionCardState.neutral)
                        : (lastSelected == opt.key && !opt.value
                              ? BkOptionCardState.incorrect
                              : BkOptionCardState.neutral),
                    onTap: () {
                      if (_session?.resolved(_currentStep) == true ||
                          _session?.finished == true) {
                        return;
                      }
                      _answer(opt.value, selectedSymbol: opt.key);
                      if (!opt.value && hasAudio) {
                        _playStepAudioUrl(audioUrl);
                      }
                    },
                  ),
                ),
              ],
              if (hasAttempted) ...[
                const SizedBox(height: AppTokens.spaceSm),
                BkFeedbackSheet(
                  type: isResolved
                      ? BkFeedbackType.positive
                      : BkFeedbackType.encouragement,
                  title: isResolved
                      ? _text(
                          'Excellente écoute !',
                          'Great listening!',
                          'استماع ممتاز!',
                        )
                      : _text(
                          'Écoutez encore une fois',
                          'Listen one more time',
                          'استمع مرة أخرى',
                        ),
                  message: isResolved
                      ? _text(
                          'Vous avez reconnu le caractère Erfe correspondant.',
                          'You recognized the matching Erfe character.',
                          'لقد تعرفت على حرف الإرفي الصحيح.',
                        )
                      : _text(
                          'Réécoutez le son puis touchez le caractère Erfe correspondant.',
                          'Replay the sound and tap the matching Erfe character.',
                          'أعد الاستماع ثم المس الحرف الصحيح.',
                        ),
                  erfeText: isResolved ? target : null,
                  onReplayAudio:
                      hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
                  onContinue: isResolved
                      ? _nextStep
                      : () {
                          if (hasAudio) _playStepAudioUrl(audioUrl);
                        },
                  continueLabel: isResolved
                      ? _text('Continuer', 'Continue', 'متابعة')
                      : _text('Réécouter', 'Listen again', 'أعد الاستماع'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTracingCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final symbol = step['symbol'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ?? 'Trace le caractère :';

    return GlassCard(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              instruction,
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            InteractiveTracingPad(
              key: ValueKey('trace-$_currentStep'),
              symbol: symbol,
              targetStrokes: TracingEngine.getStrokesForSymbol(symbol),
              currentAttempt: _tracingAttempt,
              totalAttemptsRequired: 2,
              onTraceCompleted: (result) {
                _answer(result.isSuccess);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Étape 3 : LIRE (fusion & word_decoding) ---

  Widget _buildFusionCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final components =
        (step['components'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final syllable = step['result_syllable'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ??
        'Écoute comment les sons fusionnent pour former une syllabe';
    final audioUrl = step['audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);
    final c1 = components.isNotEmpty ? components[0] : '';
    final c2 = components.length > 1 ? components[1] : '';

    return GlassCard(
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            children: [
              Text(
                instruction,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceMd),
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                label: instruction,
                onPlay: hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
              ),
              if (!hasAudio) _buildMissingAudioBanner(palette),
              const SizedBox(height: AppTokens.spaceLg),
              Center(
                child: SyllableFusionWidget(
                  consonantSymbol: c1,
                  vowelSymbol: c2,
                  resultingSyllable: syllable,
                  onFused: () {
                    _nextStep();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWordDecodingCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final word = step['word'] as String? ?? '';
    final latin = step['latin_transcription'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';
    final oralPrompt =
        step['oral_prompt'] as String? ?? 'Voici ton mot Beriya !';
    final audioUrl = step['audio_url'] as String?;
    final slowAudioUrl = step['slow_audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);

    return GlassCard(
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                oralPrompt,
                style: TextStyle(
                  color: palette.accentGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.spaceLg),
              if (word.isNotEmpty) ...[
                Semantics(
                  label: 'Mot Erfe $word',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceXl,
                      vertical: AppTokens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(
                        color: palette.accentGold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      word,
                      style: AppTextStyles.erfeDisplayHeroOf(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
              ],
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                label: oralPrompt,
                onPlay: hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
                onPlaySlow:
                    slowAudioUrl != null && slowAudioUrl.trim().isNotEmpty
                    ? () => _playStepAudioUrl(slowAudioUrl)
                    : null,
              ),
              if (!hasAudio) _buildMissingAudioBanner(palette),
              const SizedBox(height: AppTokens.spaceLg),
              if (latin.isNotEmpty || translation.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      if (latin.isNotEmpty)
                        Text(
                          latin,
                          style: TextStyle(
                            color: palette.accentGold,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (translation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          latin.isNotEmpty ? '$latin = $translation' : translation,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppTokens.spaceXl),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                ),
                child: FilledButton.icon(
                  onPressed: _nextStep,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Écrire le mot au clavier'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Étape 4 : COMPOSER (keyboard_encoding) ---

  Widget _buildKeyboardWordCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final targetWord = step['target_word'] as String? ?? '';
    final latin = step['latin_transcription'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ??
        'Écris le mot "${latin.isNotEmpty ? latin : targetWord}" au clavier :';
    final keys =
        (step['keyboard_keys'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final audioUrl = step['audio_url'] as String?;
    final hasAudio = _stepHasAudio(step);

    final stepAnswer = _session?.answers[_currentStep];
    final isResolved = _session?.resolved(_currentStep) == true;
    final hasAttempted = stepAnswer != null;
    final matchesTarget = QuizQuestionModel.evaluateTextAnswer(
      submitted: _typedText,
      expected: targetWord,
    );

    return GlassCard(
      child: ValueListenableBuilder<AudioPlaybackStatus>(
        valueListenable: _audioPlayer.status,
        builder: (context, status, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                instruction,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                  child: Text(
                    'Sens : $translation',
                    style: TextStyle(color: palette.textSecondary, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: AppTokens.spaceMd),
              BkAudioHeroButton(
                status: hasAudio ? status : AudioPlaybackStatus.idle,
                autoPlay: false,
                size: 64,
                label: instruction,
                onPlay: hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
              ),
              if (!hasAudio) _buildMissingAudioBanner(palette),
              const SizedBox(height: AppTokens.spaceLg),
              Semantics(
                label: _typedText.isEmpty
                    ? _text('Zone de saisie Erfe vide', 'Empty Erfe input', 'حقل الإدخال فارغ')
                    : 'Saisie Erfe : $_typedText',
                child: Container(
                  key: const ValueKey('encoding-input-display'),
                  constraints: const BoxConstraints(minHeight: 72),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: AppTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                    border: Border.all(
                      color: matchesTarget
                          ? palette.statusSuccess
                          : palette.accentGold,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _typedText.isEmpty ? '_  _' : _typedText,
                    style: TextStyle(
                      fontFamily: _typedText.isEmpty ? null : 'Kedebideri',
                      fontSize: 38,
                      height: 1.25,
                      color: matchesTarget
                          ? palette.statusSuccess
                          : palette.textPrimary,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              BeriyaKeyboard(
                scaffoldedKeys: keys,
                onInsert: (char) {
                  if (_session?.resolved(_currentStep) == true ||
                      _session?.finished == true) {
                    return;
                  }
                  setState(() {
                    _typedText = normalizeErfe(_typedText + char);
                  });
                  _persistSession().catchError((Object _) {});
                },
                onBackspace: () {
                  if (_session?.resolved(_currentStep) == true ||
                      _session?.finished == true) {
                    return;
                  }
                  if (_typedText.isNotEmpty) {
                    setState(() {
                      _typedText = Utf16Safe.dropLast(_typedText);
                    });
                    _persistSession().catchError((Object _) {});
                  }
                },
                onSpace: () {},
                onClear: () {
                  if (_session?.resolved(_currentStep) == true ||
                      _session?.finished == true) {
                    return;
                  }
                  setState(() {
                    _typedText = '';
                  });
                  _persistSession().catchError((Object _) {});
                },
              ),
              const SizedBox(height: AppTokens.spaceMd),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                ),
                child: FilledButton(
                  key: const ValueKey('validate-encoding'),
                  onPressed:
                      _typedText.trim().isEmpty ||
                          _session?.resolved(_currentStep) == true
                      ? null
                      : () => _answer(
                          QuizQuestionModel.evaluateTextAnswer(
                            submitted: _typedText,
                            expected: targetWord,
                          ),
                        ),
                  child: Text(_text('Valider', 'Check', 'تحقّق')),
                ),
              ),
              if (hasAttempted) ...[
                const SizedBox(height: AppTokens.spaceMd),
                BkFeedbackSheet(
                  type: isResolved
                      ? BkFeedbackType.positive
                      : BkFeedbackType.encouragement,
                  title: isResolved
                      ? _text(
                          'Mot Erfe validé !',
                          'Erfe word validated!',
                          'تم التحقق من الكلمة!',
                        )
                      : _text(
                          'Vérifiez les caractères Erfe',
                          'Check the Erfe characters',
                          'تحقق من حروف الإرفي',
                        ),
                  message: isResolved
                      ? _text(
                          'Votre saisie correspond exactement au mot attendu.',
                          'Your input matches the expected word.',
                          'إدخالك يطابق الكلمة المطلوبة.',
                        )
                      : _text(
                          'Réécoutez le mot et corrigez votre saisie avec le clavier Erfe.',
                          'Replay the word and adjust your input on the Erfe keyboard.',
                          'أعد الاستماع وعدّل الإدخال.',
                        ),
                  erfeText: isResolved ? targetWord : null,
                  onReplayAudio:
                      hasAudio ? () => _playStepAudioUrl(audioUrl) : null,
                  onContinue: isResolved
                      ? _nextStep
                      : () {
                          if (hasAudio) _playStepAudioUrl(audioUrl);
                        },
                  continueLabel: isResolved
                      ? _text('Continuer', 'Continue', 'متابعة')
                      : _text('Réécouter', 'Listen again', 'أعد الاستماع'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // --- Étape 5 : RÉVISER (celebration / bilan de la séance) ---

  String _stepErfeTarget(Map<String, dynamic> step) {
    return (step['target_symbol'] ??
            step['target_word'] ??
            step['symbol'] ??
            step['word'] ??
            '')
        .toString();
  }

  Widget _buildCelebrationCard(Map<String, dynamic> step) {
    final palette = BkThemePalette.of(context);
    final title = _session?.finished == true
        ? _text('Session terminée', 'Session finished', 'انتهت الجلسة')
        : _text('Bilan de la session', 'Session review', 'ملخّص الجلسة');
    final message =
        '${_session?.score ?? 0}% · ${_text('Seuil', 'Pass mark', 'حدّ النجاح')} ${_unit!.minScoreToPass}%\n'
        '${_session?.passed == true ? _text('Unité maîtrisée', 'Unit mastered', 'تم إتقان الوحدة') : _text('À réviser', 'Needs review', 'تحتاج إلى مراجعة')}';
    final targetWord = step['target_word'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';

    final masteredItems = <Map<String, dynamic>>[];
    final difficultItems = <Map<String, dynamic>>[];

    for (var i = 0; i < _steps.length; i++) {
      final s = _steps[i];
      if (LearningSession.category(s) == null) continue;
      final ans = _session?.answers[i];
      if (ans == null) continue;
      if (ans['first_correct'] == true) {
        masteredItems.add(s);
      } else {
        difficultItems.add(s);
      }
    }

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.stars_rounded, color: palette.accentGold, size: 76),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.accentGold,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontFamily: 'Kedebideri',
            ),
          ),
          if (targetWord.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              targetWord,
              textAlign: TextAlign.center,
              style: AppTextStyles.erfeDisplayHeroOf(context).copyWith(
                color: palette.accentGold,
              ),
            ),
            if (translation.isNotEmpty)
              Text(
                '($translation)',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 16),
              ),
          ],
          const SizedBox(height: AppTokens.spaceLg),

          // Section 1 : Éléments réussis dès le 1er essai
          Container(
            key: const ValueKey('review-mastered-section'),
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: palette.statusSuccess.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: palette.statusSuccess,
                      size: 20,
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Text(
                        _text(
                          'Éléments réussis (${masteredItems.length})',
                          'Mastered items (${masteredItems.length})',
                          'العناصر المتقنة (${masteredItems.length})',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                if (masteredItems.isEmpty)
                  Text(
                    _text(
                      'Continuez à vous entraîner pour consolider ces éléments.',
                      'Keep practicing to master these items.',
                      'واصل التدرب لإتقان هذه العناصر.',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppTokens.spaceSm,
                    runSpacing: AppTokens.spaceSm,
                    children: [
                      for (final item in masteredItems)
                        _buildReviewItemChip(item, palette, isDifficult: false),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.spaceMd),

          // Section 2 : Éléments difficiles / à revoir
          Container(
            key: const ValueKey('review-difficult-section'),
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: palette.surfaceElevated,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: difficultItems.isEmpty
                    ? palette.border
                    : palette.statusEncouragement.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.autorenew_rounded,
                      color: difficultItems.isEmpty
                          ? palette.textSecondary
                          : palette.statusEncouragement,
                      size: 20,
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Text(
                        _text(
                          'Éléments à consolider (${difficultItems.length})',
                          'Items to review (${difficultItems.length})',
                          'عناصر للمراجعة (${difficultItems.length})',
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                if (difficultItems.isEmpty)
                  Text(
                    _text(
                      'Aucun élément difficile — parcours sans faute !',
                      'No difficult items — flawless session!',
                      'لا توجد عناصر صعبة — أداء ممتاز!',
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textSecondary,
                    ),
                  )
                else
                  Wrap(
                    spacing: AppTokens.spaceSm,
                    runSpacing: AppTokens.spaceSm,
                    children: [
                      for (final item in difficultItems)
                        _buildReviewItemChip(item, palette, isDifficult: true),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppTokens.spaceXl),
          if (_srsItemsForUnit().isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.minTouchTarget,
              ),
              child: OutlinedButton.icon(
                key: const ValueKey('launch-srs-review-button'),
                onPressed: _openSrsReviewSession,
                icon: Icon(
                  Icons.schedule_rounded,
                  color: palette.accentGold,
                ),
                label: Text(
                  _text(
                    'Séance de révision espacée (${_srsItemsForUnit().length})',
                    'Spaced repetition review (${_srsItemsForUnit().length})',
                    'مراجعة متباعدة (${_srsItemsForUnit().length})',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.primaryCtaHeight,
            ),
            child: FilledButton.icon(
              onPressed: _saving
                  ? null
                  : _session?.finished == true
                  ? () => Navigator.of(context).pop()
                  : _finishUnit,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                _session?.finished == true
                    ? _text('Retour au parcours', 'Back to path', 'العودة للمسار')
                    : _text(
                        'Terminer la session',
                        'Finish session',
                        'إنهاء الجلسة',
                      ),
              ),
            ),
          ),
          if (_session?.finished == true)
            TextButton(
              onPressed: _restartSession,
              child: Text(
                _text(
                  'Recommencer la session',
                  'Practice again',
                  'إعادة التدريب',
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<SrsItemRecord> _srsItemsForUnit() {
    final slug = _unit?.slug;
    if (slug == null) return const [];
    final unitRecords = _srsRecordsByStableId.values
        .where((r) => r.unitSlug == slug)
        .toList();
    final dueOrDifficult = unitRecords
        .where((r) => r.isDifficult || r.isDueAt(DateTime.now()))
        .toList();
    return dueOrDifficult.isNotEmpty ? dueOrDifficult : unitRecords;
  }

  Future<void> _openSrsReviewSession() async {
    final items = _srsItemsForUnit();
    if (items.isEmpty || _unit == null) return;
    final distractors = <String>{
      for (final ch in _unit!.characters)
        if (ch.symbol.trim().isNotEmpty) ch.symbol.trim(),
      for (final w in _unit!.words)
        if (w.beriyaText.trim().isNotEmpty) w.beriyaText.trim(),
      for (final r in _srsRecordsByStableId.values)
        if (r.erfeText.trim().isNotEmpty) r.erfeText.trim(),
    }.toList();
    await Navigator.of(context).push<List<SrsItemRecord>>(
      MaterialPageRoute(
        builder: (_) => SrsReviewSessionScreen(
          items: items,
          srsService: _srsService,
          distractorPool: distractors,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final refreshed = await _srsService.loadAllMap();
      if (mounted) {
        setState(() {
          _srsRecordsByStableId = refreshed;
        });
      }
    } catch (_) {}
  }

  SrsItemRecord? _srsRecordForStep(Map<String, dynamic> item) {
    final erfe = _stepErfeTarget(item);
    if (erfe.trim().isEmpty) return null;
    final stepType = item['step_type'] as String? ?? '';
    final itemType = (stepType == 'encoding' || item.containsKey('target_word'))
        ? 'word'
        : 'char';
    final stableId = SrsItemRecord.buildStableId(
      itemType: itemType,
      erfeText: erfe,
    );
    return _srsRecordsByStableId[stableId];
  }

  Widget _buildReviewItemChip(
    Map<String, dynamic> item,
    BkThemePalette palette, {
    required bool isDifficult,
  }) {
    final erfe = _stepErfeTarget(item);
    final audioUrl = item['audio_url'] as String?;
    final hasAudio = audioUrl != null && audioUrl.trim().isNotEmpty;
    final srsRecord = _srsRecordForStep(item);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        border: Border.all(
          color: isDifficult ? palette.statusEncouragement : palette.statusSuccess,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            erfe,
            style: AppTextStyles.erfeOptionTextOf(context),
          ),
          if (srsRecord != null && srsRecord.intervalDays > 0) ...[
            const SizedBox(width: AppTokens.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
              child: Text(
                '+${srsRecord.intervalDays} j',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.accentGold,
                ),
              ),
            ),
          ],
          if (hasAudio) ...[
            const SizedBox(width: AppTokens.spaceXs),
            IconButton(
              constraints: const BoxConstraints(
                minWidth: AppTokens.minTouchTarget,
                minHeight: AppTokens.minTouchTarget,
              ),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.volume_up_rounded,
                size: 20,
                color: palette.accentGold,
              ),
              tooltip: _text('Réécouter', 'Replay', 'أعد الاستماع'),
              onPressed: () => _playStepAudioUrl(audioUrl),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(int totalSteps, BkThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        spacing: 12,
        overflowSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: OutlinedButton.icon(
              onPressed:
                  _currentStep > 0 && !_saving && _session?.finished != true
                  ? _prevStep
                  : null,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Précédent'),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: FilledButton.icon(
              key: const ValueKey('learning-next'),
              onPressed:
                  _saving ||
                      _session?.finished == true ||
                      _session?.canAdvance != true
                  ? null
                  : _currentStep < totalSteps - 1
                  ? _nextStep
                  : _finishUnit,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _currentStep < totalSteps - 1 ? 'Continuer' : 'Terminer',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
