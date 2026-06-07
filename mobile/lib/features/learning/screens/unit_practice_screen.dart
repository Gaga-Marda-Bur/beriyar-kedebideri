import 'package:flutter/material.dart';

import '../../../core/audio/audio_url_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../lessons/lessons_api_service.dart';
import '../../lessons/models/lesson_model.dart';
import '../../quiz/models/quiz_question_model.dart';
import '../../quiz/quiz_api_service.dart';
import '../learning_api_service.dart';
import '../models/learning_unit_model.dart';

class UnitPracticeScreen extends StatefulWidget {
  final String unitSlug;

  const UnitPracticeScreen({
    super.key,
    required this.unitSlug,
  });

  @override
  State<UnitPracticeScreen> createState() => _UnitPracticeScreenState();
}

class _UnitPracticeScreenState extends State<UnitPracticeScreen> {
  final LearningApiService _learningService = LearningApiService();
  final LessonsApiService _lessonsService = LessonsApiService();
  final QuizApiService _quizService = QuizApiService();
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();

  late Future<_PracticeData> _future;

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<_PracticeData> _load() async {
    final units = await _learningService.fetchUnits();
    final unit = units.firstWhere(
      (item) => item.slug == widget.unitSlug,
      orElse: () => throw Exception('Unit not found: ${widget.unitSlug}'),
    );

    final lessons = await _lessonsService.fetchLessons(unit: widget.unitSlug);
    final quizzes = await _quizService.fetchQuizzes(unit: widget.unitSlug);

    return _PracticeData(
      unit: unit,
      lessons: lessons,
      quizzes: quizzes,
    );
  }

  void _next(int maxSteps) {
    if (_currentStep < maxSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _restart() {
    setState(() {
      _currentStep = 0;
    });
  }

  String _localized(String lang, String fr, String en, String ar) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  String _wordTranslation(dynamic word, String lang) {
    if (lang == 'ar' && word.translationAr.isNotEmpty) return word.translationAr;
    if (lang == 'en' && word.translationEn.isNotEmpty) return word.translationEn;
    return word.translationFr.isNotEmpty
        ? word.translationFr
        : word.frenchTranslation;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.practice),
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<_PracticeData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(child: Text(loc.loading)),
                  ],
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.errorLoading,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(snapshot.error.toString()),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final steps = _buildSteps(data, lang, loc);
              final totalSteps = steps.length;
              final current = steps[_currentStep];

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loc.step} ${_currentStep + 1}/$totalSteps',
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                current.title,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              if (current.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(current.subtitle),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        current.content,
                      ],
                    ),
                  ),
                  _BottomPracticeBar(
                    canGoBack: _currentStep > 0,
                    isLast: _currentStep == totalSteps - 1,
                    previousLabel: loc.previous,
                    nextLabel: loc.next,
                    finishLabel: loc.finishUnit,
                    onPrevious: _previous,
                    onNext: () => _next(totalSteps),
                    onFinish: () {
                      setState(() {
                        _currentStep = totalSteps - 1;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_PracticeStep> _buildSteps(
    _PracticeData data,
    String lang,
    AppLocalizations loc,
  ) {
    final unit = data.unit;

    return [
      _PracticeStep(
        title: _localized(lang, unit.titleFr, unit.titleEn, unit.titleAr),
        subtitle: _localized(
          lang,
          unit.descriptionFr,
          unit.descriptionEn,
          unit.descriptionAr,
        ),
        content: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.listenRepeat),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${unit.characters.length} ${loc.characters}')),
                  Chip(label: Text('${unit.words.length} ${loc.words}')),
                  Chip(label: Text('${data.lessons.length} ${loc.lessons}')),
                  Chip(label: Text('${data.quizzes.length} ${loc.quizzes}')),
                ],
              ),
            ],
          ),
        ),
      ),
      _PracticeStep(
        title: loc.reviewCharacters,
        subtitle: loc.listenRepeat,
        content: _CharactersPractice(
          unit: unit,
          audioPlayer: _audioPlayer,
        ),
      ),
      _PracticeStep(
        title: loc.reviewWords,
        subtitle: loc.listenRepeat,
        content: _WordsPractice(
          unit: unit,
          lang: lang,
          audioPlayer: _audioPlayer,
          translationResolver: _wordTranslation,
        ),
      ),
      _PracticeStep(
        title: loc.practiceLessons,
        subtitle: '',
        content: _LessonsPractice(
          lessons: data.lessons,
          lang: lang,
          audioPlayer: _audioPlayer,
        ),
      ),
      _PracticeStep(
        title: loc.practiceQuiz,
        subtitle: '',
        content: _QuizPractice(
          quizzes: data.quizzes,
          lang: lang,
          audioPlayer: _audioPlayer,
        ),
      ),
      _PracticeStep(
        title: loc.unitFinished,
        subtitle: _localized(lang, unit.titleFr, unit.titleEn, unit.titleAr),
        content: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.unitFinished,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(loc.restartUnit),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _CharactersPractice extends StatelessWidget {
  final LearningUnitModel unit;
  final AudioUrlPlayer audioPlayer;

  const _CharactersPractice({
    required this.unit,
    required this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final character in unit.characters) ...[
          GlassCard(
            child: Row(
              children: [
                Text(
                  character.symbol,
                  style: AppTextStyles.beriyaLarge,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(character.unicodeCode),
                      if (character.latinTranscription.isNotEmpty)
                        Text(character.latinTranscription),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: character.audioUrl == null
                      ? null
                      : () => audioPlayer.playUrl(character.audioUrl),
                  icon: const Icon(Icons.volume_up_rounded),
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _WordsPractice extends StatelessWidget {
  final LearningUnitModel unit;
  final String lang;
  final AudioUrlPlayer audioPlayer;
  final String Function(dynamic word, String lang) translationResolver;

  const _WordsPractice({
    required this.unit,
    required this.lang,
    required this.audioPlayer,
    required this.translationResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final word in unit.words) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.beriyaText,
                  style: AppTextStyles.beriyaMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  translationResolver(word, lang),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (word.latinTranscription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Latin: ${word.latinTranscription}'),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: word.audioUrl == null
                      ? null
                      : () => audioPlayer.playUrl(word.audioUrl),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(AppLocalizations.of(context)!.listen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LessonsPractice extends StatelessWidget {
  final List<LessonModel> lessons;
  final String lang;
  final AudioUrlPlayer audioPlayer;

  const _LessonsPractice({
    required this.lessons,
    required this.lang,
    required this.audioPlayer,
  });

  String _localized(String fr, String en, String ar) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (lessons.isEmpty) {
      return GlassCard(child: Text(loc.noLessons));
    }

    return Column(
      children: [
        for (final lesson in lessons) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localized(lesson.titleFr, lesson.titleEn, lesson.titleAr),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_localized(
                  lesson.descriptionFr,
                  lesson.descriptionEn,
                  lesson.descriptionAr,
                ).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _localized(
                      lesson.descriptionFr,
                      lesson.descriptionEn,
                      lesson.descriptionAr,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                for (final item in lesson.items) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _localized(item.titleFr, item.titleEn, item.titleAr)
                                  .isNotEmpty
                              ? _localized(
                                  item.titleFr,
                                  item.titleEn,
                                  item.titleAr,
                                )
                              : item.itemType,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _localized(
                            item.oralPromptFr,
                            item.oralPromptEn,
                            item.oralPromptAr,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: item.audioUrl == null
                              ? null
                              : () => audioPlayer.playUrl(item.audioUrl),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text(loc.listen),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuizPractice extends StatelessWidget {
  final List<QuizQuestionModel> quizzes;
  final String lang;
  final AudioUrlPlayer audioPlayer;

  const _QuizPractice({
    required this.quizzes,
    required this.lang,
    required this.audioPlayer,
  });

  String _localized(String fr, String en, String ar, String fallback) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (quizzes.isEmpty) {
      return GlassCard(child: Text(loc.noQuizzes));
    }

    return Column(
      children: [
        for (final quiz in quizzes) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localized(
                    quiz.promptTextFr,
                    quiz.promptTextEn,
                    quiz.promptTextAr,
                    quiz.promptText,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: quiz.questionAudioUrl == null
                      ? null
                      : () => audioPlayer.playUrl(quiz.questionAudioUrl),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(loc.listen),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < quiz.options.length; i++) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: i == quiz.correctIndex
                          ? AppColors.gold.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: i == quiz.correctIndex
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      quiz.options[i].characterSymbol.isNotEmpty
                          ? quiz.options[i].characterSymbol
                          : quiz.options[i].text,
                      style: quiz.options[i].characterSymbol.isNotEmpty
                          ? AppTextStyles.beriyaSmall
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BottomPracticeBar extends StatelessWidget {
  final bool canGoBack;
  final bool isLast;
  final String previousLabel;
  final String nextLabel;
  final String finishLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  const _BottomPracticeBar({
    required this.canGoBack,
    required this.isLast,
    required this.previousLabel,
    required this.nextLabel,
    required this.finishLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.dark.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: AppColors.glassBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canGoBack ? onPrevious : null,
              child: Text(previousLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: isLast ? onFinish : onNext,
              child: Text(isLast ? finishLabel : nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeStep {
  final String title;
  final String subtitle;
  final Widget content;

  const _PracticeStep({
    required this.title,
    required this.subtitle,
    required this.content,
  });
}

class _PracticeData {
  final LearningUnitModel unit;
  final List<LessonModel> lessons;
  final List<QuizQuestionModel> quizzes;

  const _PracticeData({
    required this.unit,
    required this.lessons,
    required this.quizzes,
  });
}