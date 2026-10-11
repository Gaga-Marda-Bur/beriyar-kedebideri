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
import '../models/learning_unit_model.dart';
import '../widgets/interactive_tracing_pad.dart';
import '../widgets/syllable_fusion_widget.dart';

class LearningCoreUnitScreen extends StatefulWidget {
  final LearningUnitModel? unit;
  final String? unitSlug;

  const LearningCoreUnitScreen({
    super.key,
    this.unit,
    this.unitSlug,
  });

  @override
  State<LearningCoreUnitScreen> createState() => _LearningCoreUnitScreenState();
}

class _LearningCoreUnitScreenState extends State<LearningCoreUnitScreen> {
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();
  final CachedContentService _contentService = CachedContentService();

  LearningUnitModel? _unit;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentStep = 0;
  List<Map<String, dynamic>> _steps = [];

  // Progression & scores
  double _scoreRecognition = 1.0;
  double _scoreTracing = 1.0;
  double _scoreEncoding = 1.0;

  int _tracingAttempt = 1;
  String _typedText = '';

  @override
  void initState() {
    super.initState();
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

    try {
      final units = await _contentService.loadUnits();
      LearningUnitModel? found;

      if (widget.unitSlug != null && widget.unitSlug!.isNotEmpty) {
        try {
          found = units.firstWhere((u) => u.slug == widget.unitSlug);
        } catch (_) {}
      }

      // Fallback sur la première unité disponible
      found ??= units.isNotEmpty ? units.first : null;

      found ??= _createFallbackUnit1();
      _applyUnit(found);
    } catch (e) {
      _applyUnit(_createFallbackUnit1());
    }
  }

  static LearningUnitModel _createFallbackUnit1() {
    return LearningUnitModel.fromJson({
      'id': 1,
      'title_fr': 'Unité 1 : La consonne Be (𖺡)',
      'slug': 'unite-1',
      'level': 'beginner',
      'enable_tracing': false,
      'weight_recognition': 50,
      'weight_tracing': 0,
      'weight_encoding': 50,
      'characters': [
        {
          'id': 1,
          'name_fr': 'Be',
          'phoneme_ipa': 'b',
          'symbol': '𖺡',
          'character': '𖺡',
          'latin_transcription': 'b',
          'character_type': 'consonant',
          'order_index': 1,
        },
        {
          'id': 2,
          'name_fr': 'E',
          'phoneme_ipa': 'e',
          'symbol': '𖺣',
          'character': '𖺣',
          'latin_transcription': 'e',
          'character_type': 'vowel',
          'order_index': 2,
        },
      ],
      'distractor_characters': [
        {
          'id': 3,
          'name_fr': 'A',
          'phoneme_ipa': 'a',
          'symbol': '𖺠',
          'character': '𖺠',
          'latin_transcription': 'a',
          'character_type': 'vowel',
          'order_index': 3,
        },
      ],
      'words': [
        {
          'id': 1,
          'beriya_text': '𖺡𖺣',
          'latin_transcription': 'be',
          'french_translation': 'pays',
          'english_translation': 'country',
          'arabic_translation': 'بلد',
        }
      ],
      'target_word': {
        'id': 1,
        'beriya_text': '𖺡𖺣',
        'latin_transcription': 'be',
        'french_translation': 'pays',
        'english_translation': 'country',
        'arabic_translation': 'بلد',
      },
      'status': 'published',
      'is_active': true,
      'available_offline': true,
    });
  }

  void _applyUnit(LearningUnitModel unit) {
    setState(() {
      _unit = unit;
      _steps = unit.effectiveCoreFlow;
      _isLoading = false;
      _currentStep = 0;
      _tracingAttempt = 1;
      _typedText = '';
    });
    _playCurrentStepAudio();
  }

  void _playCurrentStepAudio() {
    if (_steps.isEmpty || _currentStep >= _steps.length) return;
    final step = _steps[_currentStep];
    final audioUrl = step['audio_url'] as String?;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _audioPlayer.playUrl(audioUrl);
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _tracingAttempt = 1;
        _typedText = '';
      });
      _playCurrentStepAudio();
    } else {
      _finishUnit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _typedText = '';
      });
      _playCurrentStepAudio();
    }
  }

  Future<void> _finishUnit() async {
    if (_unit == null) return;

    final wRec = _unit!.enableTracing ? (_unit!.weightRecognition / 100.0) : 0.50;
    final wTra = _unit!.enableTracing ? (_unit!.weightTracing / 100.0) : 0.0;
    final wEnc = _unit!.enableTracing ? (_unit!.weightEncoding / 100.0) : 0.50;

    final weightedScore = (
      (wRec * _scoreRecognition) +
      (wTra * _scoreTracing) +
      (wEnc * _scoreEncoding)
    ) * 100;

    await _progressStorage.completeUnit(
      unitSlug: _unit!.slug,
      totalSteps: _steps.length,
      scorePercent: weightedScore.round().clamp(50, 100),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_unit!.titleFr} validée avec succès !',
            style: const TextStyle(fontFamily: 'Kedebideri'),
          ),
          backgroundColor: AppColors.green,
        ),
      );
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
        appBar: AppBar(title: const Text('Alphabétisation Beriya Erfe')),
        body: AppBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.orangeAccent, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Impossible de charger cette unité.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
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

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCurrentStepWidget(),
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
                    child: Icon(Icons.volume_up_rounded, size: 16, color: AppColors.night),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (phonemeIpa.isNotEmpty && phonemeIpa != 'À_VALIDER')
            Text(
              'Son : /$phonemeIpa/',
              style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold),
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
            label: const Text('Réécouter le son', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscriminationCard(Map<String, dynamic> step) {
    final target = step['target_symbol'] as String? ?? '';
    final other = step['other_symbol'] as String? ?? '';
    final instruction = step['instruction'] as String? ?? 'Touche le bon caractère :';
    final audioUrl = step['audio_url'] as String?;

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            instruction,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
              _buildDiscriminationButton(symbol: target, isCorrect: true, audioUrl: audioUrl),
              _buildDiscriminationButton(symbol: other, isCorrect: false, audioUrl: audioUrl),
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
      onTap: () {
        if (isCorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bravo ! Son reconnu avec succès.'),
              backgroundColor: AppColors.green,
              duration: Duration(milliseconds: 700),
            ),
          );
          Future.delayed(const Duration(milliseconds: 600), _nextStep);
        } else {
          setState(() {
            _scoreRecognition = (_scoreRecognition - 0.1).clamp(0.0, 1.0);
          });
          if (audioUrl != null && audioUrl.isNotEmpty) {
            _audioPlayer.playUrl(audioUrl);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Réessaie ! Écoute bien le son.'),
              backgroundColor: Colors.amber,
              duration: Duration(milliseconds: 1000),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.night.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
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
    final instruction = step['instruction'] as String? ?? 'Trace le caractère :';

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
              symbol: symbol,
              targetStrokes: TracingEngine.getStrokesForSymbol(symbol),
              currentAttempt: _tracingAttempt,
              totalAttemptsRequired: 2,
              onTraceCompleted: (result) {
                if (result.isSuccess) {
                  if (_tracingAttempt >= 2) {
                    Future.delayed(const Duration(milliseconds: 700), _nextStep);
                  } else {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() {
                          _tracingAttempt++;
                          _scoreTracing = (_scoreTracing + 0.1).clamp(0.0, 1.0);
                        });
                      }
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFusionCard(Map<String, dynamic> step) {
    final components = (step['components'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
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
            Future.delayed(const Duration(milliseconds: 1200), _nextStep);
          },
        ),
      ),
    );
  }

  Widget _buildWordDecodingCard(Map<String, dynamic> step) {
    final word = step['word'] as String? ?? '';
    final latin = step['latin_transcription'] as String? ?? '';
    final translation = step['french_translation'] as String? ?? '';
    final oralPrompt = step['oral_prompt'] as String? ?? 'Voici ton mot Beriya !';
    final audioUrl = step['audio_url'] as String?;

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            oralPrompt,
            style: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold),
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
            child: const Icon(Icons.public_rounded, color: AppColors.gold, size: 70),
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
    final instruction = step['instruction'] as String? ??
        'Écris le mot "${latin.isNotEmpty ? latin : targetWord}" au clavier :';
    final keys = (step['keyboard_keys'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
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
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                color: _typedText == targetWord ? AppColors.green : AppColors.gold,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _typedText.isEmpty ? '_  _' : _typedText,
              style: TextStyle(
                fontFamily: _typedText.isEmpty ? null : 'Kedebideri',
                fontSize: 40,
                color: _typedText == targetWord ? AppColors.green : AppColors.gold,
                letterSpacing: 8,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BeriyaKeyboard(
            scaffoldedKeys: keys,
            onInsert: (char) {
              setState(() {
                _typedText += char;
              });
              if (_typedText == targetWord) {
                Future.delayed(const Duration(milliseconds: 600), _nextStep);
              }
            },
            onBackspace: () {
              if (_typedText.isNotEmpty) {
                setState(() {
                  _typedText = Utf16Safe.dropLast(_typedText);
                  _scoreEncoding = (_scoreEncoding - 0.05).clamp(0.0, 1.0);
                });
              }
            },
            onSpace: () {},
            onClear: () {
              setState(() {
                _typedText = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard(Map<String, dynamic> step) {
    final title = step['title'] as String? ?? 'Félicitations !';
    final message = step['message'] as String? ?? 'Tu as terminé la leçon avec succès !';
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
            style: const TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.bold),
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
            onPressed: () {
              _finishUnit();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Terminer la session'),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton.icon(
            onPressed: _currentStep > 0 ? _prevStep : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Précédent'),
          ),
          FilledButton.icon(
            onPressed: _currentStep < totalSteps - 1 ? _nextStep : _finishUnit,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(_currentStep < totalSteps - 1 ? 'Continuer' : 'Terminer'),
          ),
        ],
      ),
    );
  }
}
