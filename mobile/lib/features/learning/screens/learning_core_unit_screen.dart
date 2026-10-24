import 'package:flutter/material.dart';
import '../../../core/audio/audio_url_player.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/beriya/beriya_keyboard.dart';
import '../../../shared/beriya/utf16_safe.dart';
import '../../progress/services/unit_progress_local_storage.dart';
import '../engine/tracing_engine.dart';
import '../engine/learning_session.dart';
import '../models/learning_unit_model.dart';
import '../widgets/interactive_tracing_pad.dart';
import '../widgets/syllable_fusion_widget.dart';

class LearningCoreUnitScreen extends StatefulWidget {
  final LearningUnitModel? unit;
  final String? unitSlug;
  final CachedContentService? contentService;

  const LearningCoreUnitScreen({
    super.key,
    this.unit,
    this.unitSlug,
    this.contentService,
  });

  @override
  State<LearningCoreUnitScreen> createState() => _LearningCoreUnitScreenState();
}

class _LearningCoreUnitScreenState extends State<LearningCoreUnitScreen> {
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();
  late final CachedContentService _contentService;

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

  @override
  void initState() {
    super.initState();
    _contentService = widget.contentService ?? CachedContentService();
    _initUnit();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initUnit() async {
    if (widget.unit != null) {
      _applyUnit(widget.unit!);
      return;
    }

    if (widget.unitSlug == null || widget.unitSlug!.trim().isEmpty) {
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
        _applyUnit(found);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Cette unité n\'est pas disponible sur cet appareil.\n\n'
              'Identifiant demandé : "${widget.unitSlug}"\n\n'
              'Veuillez télécharger le pack correspondant ou vérifier votre connexion.';
        });
      }
    } catch (e) {
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
    _playCurrentStepAudio();
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
      });
      await _persistSession();
      if (mounted) _playCurrentStepAudio();
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

  void _answer(bool correct) {
    if (!mounted ||
        _session == null ||
        _session!.resolved(_currentStep) ||
        _session!.finished) {
      return;
    }
    setState(() {
      _session!.answer(correct);
      _tracingAttempt =
          ((_session!.answers[_currentStep]?['successes'] as int? ?? 0) + 1)
              .clamp(1, 2);
    });
    if (correct) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _persistSession().catchError((Object _) {});
    if (!correct) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text('Réessaie.', 'Try again.', 'حاول مجددًا.')),
        ),
      );
    }
  }

  void _playCurrentStepAudio() {
    if (_steps.isEmpty || _currentStep >= _steps.length) return;
    final step = _steps[_currentStep];
    final audioUrl = step['audio_url'] as String?;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _audioPlayer.playUrl(audioUrl);
    } else {
      _audioPlayer.stop();
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
      _playCurrentStepAudio();
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
      _playCurrentStepAudio();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: AppBackground(
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      );
    }

    if (_errorMessage != null || _unit == null || _steps.isEmpty) {
      return Scaffold(
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
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.gold,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _unit != null ? _unit!.titleFr : 'Contenu indisponible',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Kedebideri',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? 'Cette unité n\'est pas disponible.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_unit!.titleFr} (${_currentStep + 1}/$totalSteps)',
          style: const TextStyle(fontSize: 16, fontFamily: 'Kedebideri'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Barre de progression supérieure
              LinearProgressIndicator(
                value: (_currentStep + 1) / totalSteps,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                minHeight: 6,
              ),
              ValueListenableBuilder<AudioPlaybackStatus>(
                valueListenable: _audioPlayer.status,
                builder: (context, status, _) => Semantics(
                  liveRegion: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (status == AudioPlaybackStatus.loading)
                        Text(
                          _text(
                            'Chargement audio…',
                            'Loading audio…',
                            'جارٍ تحميل الصوت…',
                          ),
                        ),
                      if (status == AudioPlaybackStatus.failed)
                        TextButton(
                          onPressed: _playCurrentStepAudio,
                          child: Text(
                            _text(
                              'Audio indisponible · Réessayer',
                              'Audio unavailable · Try again',
                              'الصوت غير متاح · حاول مجددًا',
                            ),
                          ),
                        ),
                      if (status == AudioPlaybackStatus.playing)
                        TextButton(
                          onPressed: _audioPlayer.pause,
                          child: Text(_text('Pause', 'Pause', 'إيقاف مؤقت')),
                        ),
                      if (status == AudioPlaybackStatus.paused)
                        TextButton(
                          onPressed: _playCurrentStepAudio,
                          child: Text(
                            _text('Réécouter', 'Listen again', 'استمع مجددًا'),
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
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildCurrentStepWidget(),
                      ),
                    ),
                  ),
                ),
              ),

              // Barre de navigation inférieure
              _buildBottomBar(totalSteps),
            ],
          ),
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

  // --- Cartes des Micro-Étapes ---

  Widget _buildDiscoveryCard(Map<String, dynamic> step) {
    final symbol = step['symbol'] as String? ?? '';
    final phonemeIpa = step['phoneme_ipa'] as String? ?? '';
    final label = step['label'] as String? ?? 'Écoute et découvre le caractère';
    final audioUrl = step['audio_url'] as String?;

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () {
              if (audioUrl != null && audioUrl.isNotEmpty) {
                _audioPlayer.playUrl(audioUrl);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Text(
                    symbol,
                    style: const TextStyle(
                      fontFamily: 'Kedebideri',
                      fontSize: 90,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.gold,
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: AppColors.night,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (phonemeIpa.isNotEmpty && phonemeIpa != 'À_VALIDER')
            Text(
              'Son : /$phonemeIpa/',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.night,
            ),
            onPressed: () {
              if (audioUrl != null && audioUrl.isNotEmpty) {
                _audioPlayer.playUrl(audioUrl);
              }
            },
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text(
              'Réécouter le son',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscriminationCard(Map<String, dynamic> step) {
    final target = step['target_symbol'] as String? ?? '';
    final other = step['other_symbol'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ?? 'Touche le bon caractère :';
    final audioUrl = step['audio_url'] as String?;

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            instruction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (audioUrl != null && audioUrl.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () => _audioPlayer.playUrl(audioUrl),
              icon: const Icon(Icons.volume_up_rounded, size: 20),
              label: const Text('Réécouter le son'),
            ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDiscriminationButton(
                symbol: target,
                isCorrect: true,
                audioUrl: audioUrl,
              ),
              _buildDiscriminationButton(
                symbol: other,
                isCorrect: false,
                audioUrl: audioUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscriminationButton({
    required String symbol,
    required bool isCorrect,
    String? audioUrl,
  }) {
    return InkWell(
      key: ValueKey('answer-$_currentStep-$symbol'),
      onTap: () {
        if (_session?.resolved(_currentStep) == true ||
            _session?.finished == true) {
          return;
        }
        _answer(isCorrect);
        if (!isCorrect) {
          if (audioUrl != null && audioUrl.isNotEmpty) {
            _audioPlayer.playUrl(audioUrl);
          }
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.night.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          symbol,
          style: const TextStyle(
            fontFamily: 'Kedebideri',
            fontSize: 56,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTracingCard(Map<String, dynamic> step) {
    final symbol = step['symbol'] as String? ?? '';
    final instruction =
        step['instruction'] as String? ?? 'Trace le caractère :';

    return GlassCard(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              instruction,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
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

  Widget _buildFusionCard(Map<String, dynamic> step) {
    final components =
        (step['components'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final syllable = step['result_syllable'] as String? ?? '';
    final c1 = components.isNotEmpty ? components[0] : '';
    final c2 = components.length > 1 ? components[1] : '';

    return GlassCard(
      child: Center(
        child: SyllableFusionWidget(
          consonantSymbol: c1,
          vowelSymbol: c2,
          resultingSyllable: syllable,
          onFused: () {
            _nextStep();
          },
        ),
      ),
    );
  }

  Widget _buildWordDecodingCard(Map<String, dynamic> step) {
    final word = step['word'] as String? ?? '';
    final latin = step['latin_transcription'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';
    final oralPrompt =
        step['oral_prompt'] as String? ?? 'Voici ton mot Beriya !';
    final audioUrl = step['audio_url'] as String?;

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            oralPrompt,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.public_rounded,
              color: AppColors.gold,
              size: 70,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word,
            style: const TextStyle(
              fontFamily: 'Kedebideri',
              fontSize: 64,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latin.isNotEmpty ? '$latin = $translation' : translation,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (audioUrl != null && audioUrl.isNotEmpty) ...[
                IconButton.filledTonal(
                  onPressed: () => _audioPlayer.playUrl(audioUrl),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
                const SizedBox(width: 12),
              ],
              FilledButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Écrire le mot au clavier'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardWordCard(Map<String, dynamic> step) {
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

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  instruction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (audioUrl != null && audioUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _audioPlayer.playUrl(audioUrl),
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          if (translation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sens : $translation',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          const SizedBox(height: 20),
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _typedText == targetWord
                    ? AppColors.green
                    : AppColors.gold,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _typedText.isEmpty ? '_  _' : _typedText,
              style: TextStyle(
                fontFamily: _typedText.isEmpty ? null : 'Kedebideri',
                fontSize: 40,
                color: _typedText == targetWord
                    ? AppColors.green
                    : AppColors.gold,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BeriyaKeyboard(
            scaffoldedKeys: keys,
            onInsert: (char) {
              if (_session?.resolved(_currentStep) == true ||
                  _session?.finished == true) {
                return;
              }
              setState(() {
                _typedText += char;
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
          FilledButton(
            key: const ValueKey('validate-encoding'),
            onPressed:
                _typedText.isEmpty || _session?.resolved(_currentStep) == true
                ? null
                : () => _answer(_typedText == targetWord),
            child: Text(_text('Valider', 'Check', 'تحقّق')),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard(Map<String, dynamic> step) {
    final title = _session?.finished == true
        ? _text('Session terminée', 'Session finished', 'انتهت الجلسة')
        : _text('Bilan de la session', 'Session review', 'ملخّص الجلسة');
    final message =
        '${_session?.score ?? 0}% · ${_text('Seuil', 'Pass mark', 'حدّ النجاح')} ${_unit!.minScoreToPass}%\n'
        '${_session?.passed == true ? _text('Unité maîtrisée', 'Unit mastered', 'تم إتقان الوحدة') : _text('À réviser', 'Needs review', 'تحتاج إلى مراجعة')}';
    final targetWord = step['target_word'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.gold, size: 90),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Kedebideri',
            ),
          ),
          if (targetWord.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              targetWord,
              style: const TextStyle(
                fontFamily: 'Kedebideri',
                fontSize: 48,
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (translation.isNotEmpty)
              Text(
                '($translation)',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
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

  Widget _buildBottomBar(int totalSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dark.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        spacing: 12,
        overflowSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed:
                _currentStep > 0 && !_saving && _session?.finished != true
                ? _prevStep
                : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Précédent'),
          ),
          FilledButton.icon(
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
        ],
      ),
    );
  }
}
