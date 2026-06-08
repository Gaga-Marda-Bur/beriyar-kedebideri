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
import 'unit_practice_screen.dart';
import '../../progress/models/unit_progress_local_model.dart';
import '../../progress/services/unit_progress_local_storage.dart';

class UnitDetailScreen extends StatefulWidget {
  final String unitSlug;

  const UnitDetailScreen({
    super.key,
    required this.unitSlug,
  });

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  final LearningApiService _learningService = LearningApiService();
  final LessonsApiService _lessonsService = LessonsApiService();
  final QuizApiService _quizService = QuizApiService();
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();
  UnitProgressLocalModel? _localProgress;

  late Future<_UnitDetailData> _future;

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

  Future<_UnitDetailData> _load() async {
    final units = await _learningService.fetchUnits();
    final unit = units.firstWhere(
      (item) => item.slug == widget.unitSlug,
      orElse: () => throw Exception('Unit not found: ${widget.unitSlug}'),
    );
    _localProgress = await _progressStorage.getProgress(widget.unitSlug);
    final lessons = await _lessonsService.fetchLessons(unit: widget.unitSlug);
    final quizzes = await _quizService.fetchQuizzes(unit: widget.unitSlug);

    return _UnitDetailData(
      unit: unit,
      lessons: lessons,
      quizzes: quizzes,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  String _localized(String lang, String fr, String en, String ar) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  String _wordTranslation(dynamic word, String lang) {
    if (lang == 'ar' && word.translationAr.isNotEmpty) {
      return word.translationAr;
    }

    if (lang == 'en' && word.translationEn.isNotEmpty) {
      return word.translationEn;
    }

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
        title: Text(loc.unitContent),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<_UnitDetailData>(
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
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _reload,
                              child: Text(loc.retry),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final data = snapshot.data!;
                final unit = data.unit;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _localized(
                              lang,
                              unit.titleFr,
                              unit.titleEn,
                              unit.titleAr,
                            ),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _localized(
                              lang,
                              unit.descriptionFr,
                              unit.descriptionEn,
                              unit.descriptionAr,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  '${unit.characters.length} ${loc.characters}',
                                ),
                              ),
                              Chip(
                                label: Text('${unit.words.length} ${loc.words}'),
                              ),
                              Chip(
                                label: Text(
                                  '${unit.estimatedMinutes} ${loc.minutes}',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  '${loc.minimumScore} ${unit.minScoreToPass}%',
                                ),
                              ),
                            ],
                          ),
                          if (_localProgress != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _localProgress!.completed
                                  ? 'Unité terminée • meilleur score ${_localProgress!.bestScorePercent}%'
                                  : 'Progression : étape ${_localProgress!.currentStep + 1}/${_localProgress!.totalSteps}',
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UnitPracticeScreen(
                                      unitSlug: unit.slug,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(
                                _localProgress != null && !_localProgress!.completed
                                    ? 'Reprendre l’unité'
                                    : loc.startUnit,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    _SectionTitle(title: loc.characters),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unit.characters.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemBuilder: (context, index) {
                        final character = unit.characters[index];

                        return GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                character.symbol,
                                style: AppTextStyles.beriyaMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                character.latinTranscription.isNotEmpty
                                    ? character.latinTranscription
                                    : character.unicodeCode,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              IconButton(
                                onPressed: character.audioUrl == null
                                    ? null
                                    : () => _audioPlayer.playUrl(
                                          character.audioUrl,
                                        ),
                                icon: const Icon(Icons.volume_up_rounded),
                                color: AppColors.gold,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),
                    _SectionTitle(title: loc.words),
                    const SizedBox(height: 10),
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
                              _wordTranslation(word, lang),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (word.latinTranscription.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Latin: ${word.latinTranscription}'),
                            ],
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: word.audioUrl == null
                                  ? null
                                  : () => _audioPlayer.playUrl(word.audioUrl),
                              icon: const Icon(Icons.volume_up_rounded),
                              label: Text(loc.listen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 10),
                    _SectionTitle(title: loc.lessons),
                    const SizedBox(height: 10),
                    if (data.lessons.isEmpty)
                      GlassCard(child: Text(loc.noLessons))
                    else
                      for (final lesson in data.lessons) ...[
                        _LessonCard(
                          lesson: lesson,
                          lang: lang,
                          audioPlayer: _audioPlayer,
                        ),
                        const SizedBox(height: 12),
                      ],

                    const SizedBox(height: 10),
                    _SectionTitle(title: loc.quizzes),
                    const SizedBox(height: 10),
                    if (data.quizzes.isEmpty)
                      GlassCard(child: Text(loc.noQuizzes))
                    else
                      for (final quiz in data.quizzes) ...[
                        _QuizCard(quiz: quiz),
                        const SizedBox(height: 12),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final LessonModel lesson;
  final String lang;
  final AudioUrlPlayer audioPlayer;

  const _LessonCard({
    required this.lesson,
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

    return GlassCard(
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
                        ? _localized(item.titleFr, item.titleEn, item.titleAr)
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
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizQuestionModel quiz;

  const _QuizCard({
    required this.quiz,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quiz.promptText,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(quiz.questionType)),
              Chip(label: Text('${quiz.options.length} options')),
              Chip(label: Text('${quiz.points} point(s)')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}

class _UnitDetailData {
  final LearningUnitModel unit;
  final List<LessonModel> lessons;
  final List<QuizQuestionModel> quizzes;

  const _UnitDetailData({
    required this.unit,
    required this.lessons,
    required this.quizzes,
  });
}