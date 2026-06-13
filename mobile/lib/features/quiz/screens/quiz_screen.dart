import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/audio/audio_url_player.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/quiz_question_model.dart';
import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/widgets/content_source_badge.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final CachedContentService _cachedContentService = CachedContentService();
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();

  late Future<List<QuizQuestionModel>> _future;

  List<QuizQuestionModel> _questions = [];
  List<List<int>> _optionOrders = [];
  int _currentIndex = 0;
  int? _selectedIndex;
  int _correctCount = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _future = _loadQuizzes();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<List<QuizQuestionModel>> _loadQuizzes() async {
    final items = await _cachedContentService.loadQuizzes();

    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final random = Random();

    _optionOrders = items.map((question) {
      final order = List<int>.generate(
        question.options.length,
        (index) => index,
      );

      order.shuffle(random);

      final correctIndex = question.correctIndex;

      // Évite que la bonne réponse tombe en première position après shuffle.
      if (order.length > 1 && order.first == correctIndex) {
        final swapIndex = order.length ~/ 2;
        final temp = order[0];
        order[0] = order[swapIndex];
        order[swapIndex] = temp;
      }

      return order;
    }).toList();

    _questions = items;

    return items;
  }

  Future<void> _reload() async {
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _correctCount = 0;
      _finished = false;
      _future = _loadQuizzes();
    });
  }

  String _localized(
    String lang, {
    required String fr,
    required String en,
    required String ar,
    String fallback = '',
  }) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    if (fr.isNotEmpty) return fr;
    if (en.isNotEmpty) return en;
    if (ar.isNotEmpty) return ar;
    return fallback;
  }

  String _questionText(QuizQuestionModel question, String lang) {
    return _localized(
      lang,
      fr: question.promptTextFr,
      en: question.promptTextEn,
      ar: question.promptTextAr,
      fallback: question.promptText.isNotEmpty
          ? question.promptText
          : question.oralPrompt,
    );
  }

  String _oralPrompt(QuizQuestionModel question, String lang) {
    return _localized(
      lang,
      fr: question.oralPromptFr,
      en: question.oralPromptEn,
      ar: question.oralPromptAr,
      fallback: question.oralPrompt,
    );
  }

  String _optionText(QuizOptionModel option, String lang) {
    final text = _localized(
      lang,
      fr: option.textFrOut.isNotEmpty ? option.textFrOut : option.textFr,
      en: option.textEnOut.isNotEmpty ? option.textEnOut : option.textEn,
      ar: option.textArOut.isNotEmpty ? option.textArOut : option.textAr,
      fallback: option.text,
    );

    if (text.isNotEmpty) return text;
    if (option.characterSymbol.isNotEmpty) return option.characterSymbol;
    if (option.wordText.isNotEmpty) return option.wordText;

    return '—';
  }

  bool _isBeriyaOption(QuizOptionModel option) {
    return option.characterSymbol.isNotEmpty || option.wordText.isNotEmpty;
  }

  void _selectAnswer(int displayIndex) {
    if (_selectedIndex != null) return;

    final question = _questions[_currentIndex];
    final order = _optionOrders[_currentIndex];

    final originalIndex = order[displayIndex];
    final correctIndex = question.correctIndex;

    setState(() {
      _selectedIndex = displayIndex;

      if (originalIndex == correctIndex) {
        _correctCount++;
      }
    });
  }

  void _next() {
    if (_currentIndex >= _questions.length - 1) {
      setState(() {
        _finished = true;
      });
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedIndex = null;
    });
  }

  void _restart() {
    setState(() {
      _currentIndex = 0;
      _selectedIndex = null;
      _correctCount = 0;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.quiz),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<QuizQuestionModel>>(
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
                            ContentSourceBadge(
                              source: ContentSourceState.instance.getSource('${CacheKeys.quizzes}_all'),
                            ),
                            const SizedBox(height: 8),
                            Text(loc.errorLoading),
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

                final questions = snapshot.data ?? [];

                if (questions.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.quiz,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            ContentSourceBadge(
                              source: ContentSourceState.instance.getSource('${CacheKeys.quizzes}_all'),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Aucune question disponible pour le moment.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                if (_finished) {
                  return _QuizResultView(
                    total: _questions.length,
                    correct: _correctCount,
                    onRestart: _restart,
                  );
                }

                return _QuizQuestionView(
                  question: _questions[_currentIndex],
                  currentIndex: _currentIndex,
                  total: _questions.length,
                  selectedIndex: _selectedIndex,
                  correctCount: _correctCount,
                  optionOrder: _optionOrders[_currentIndex],
                  questionText: _questionText,
                  oralPrompt: _oralPrompt,
                  optionText: _optionText,
                  isBeriyaOption: _isBeriyaOption,
                  onSelect: _selectAnswer,
                  onNext: _next,
                  onPlayAudio: (url) => _audioPlayer.playUrl(url),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizQuestionView extends StatelessWidget {
  final QuizQuestionModel question;
  final int currentIndex;
  final int total;
  final int? selectedIndex;
  final int correctCount;
  final List<int> optionOrder;
  final String Function(QuizQuestionModel, String) questionText;
  final String Function(QuizQuestionModel, String) oralPrompt;
  final String Function(QuizOptionModel, String) optionText;
  final bool Function(QuizOptionModel) isBeriyaOption;
  final void Function(int) onSelect;
  final VoidCallback onNext;
  final void Function(String?) onPlayAudio;

  const _QuizQuestionView({
    required this.question,
    required this.currentIndex,
    required this.total,
    required this.selectedIndex,
    required this.correctCount,
    required this.questionText,
    required this.oralPrompt,
    required this.optionText,
    required this.isBeriyaOption,
    required this.onSelect,
    required this.onNext,
    required this.onPlayAudio,
    required this.optionOrder,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final progress = (currentIndex + 1) / total;
    final correctIndex = question.correctIndex;
    final hasAnswered = selectedIndex != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${currentIndex + 1}/$total',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ContentSourceBadge(
                source: ContentSourceState.instance.getSource('${CacheKeys.quizzes}_all'),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text('Score provisoire : $correctCount/$total'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.questionAudioUrl != null &&
                  question.questionAudioUrl!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onPlayAudio(question.questionAudioUrl),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Écouter la question'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (oralPrompt(question, lang).isNotEmpty) ...[
                Text(
                  oralPrompt(question, lang),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                questionText(question, lang),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (question.characterSymbol.isNotEmpty) ...[
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    question.characterSymbol,
                    style: AppTextStyles.beriyaLarge.copyWith(fontSize: 72),
                  ),
                ),
              ],
              if (question.wordText.isNotEmpty) ...[
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    question.wordText,
                    style: AppTextStyles.beriyaMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (int displayIndex = 0; displayIndex < optionOrder.length; displayIndex++) ...[
          Builder(
            builder: (context) {
              final originalIndex = optionOrder[displayIndex];
              final option = question.options[originalIndex];
              final correctDisplayIndex = optionOrder.indexOf(correctIndex);

              return _AnswerCard(
                option: option,
                text: optionText(option, lang),
                isBeriya: isBeriyaOption(option),
                isSelected: selectedIndex == displayIndex,
                hasAnswered: hasAnswered,
                isSelectedCorrect:
                    selectedIndex == displayIndex && displayIndex == correctDisplayIndex,
                onTap: () => onSelect(displayIndex),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        if (hasAnswered) ...[
          const SizedBox(height: 8),
          GlassCard(
            child: Row(
              children: [
                Icon(
                  selectedIndex == correctIndex
                      ? Icons.emoji_events_rounded
                      : Icons.info_rounded,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedIndex == correctIndex
                        ? 'Correct, très bien !'
                        : 'Pas grave, écoute encore et continue.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                currentIndex >= total - 1 ? 'Voir le résultat' : 'Question suivante',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final QuizOptionModel option;
  final String text;
  final bool isBeriya;
  final bool isSelected;
  final bool hasAnswered;
  final bool isSelectedCorrect;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.option,
    required this.text,
    required this.isBeriya,
    required this.isSelected,
    required this.hasAnswered,
    required this.isSelectedCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white.withValues(alpha: 0.18);
    IconData icon = Icons.radio_button_unchecked_rounded;

    if (hasAnswered && isSelected && isSelectedCorrect) {
      borderColor = AppColors.gold;
      icon = Icons.check_circle_rounded;
    } else if (hasAnswered && isSelected && !isSelectedCorrect) {
      borderColor = Colors.redAccent;
      icon = Icons.cancel_rounded;
    } else if (hasAnswered) {
      borderColor = Colors.white.withValues(alpha: 0.10);
      icon = Icons.radio_button_unchecked_rounded;
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: hasAnswered ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Icon(icon, color: borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: isBeriya
                      ? AppTextStyles.beriyaSmall.copyWith(fontSize: 28)
                      : const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizResultView extends StatelessWidget {
  final int total;
  final int correct;
  final VoidCallback onRestart;

  const _QuizResultView({
    required this.total,
    required this.correct,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.gold,
                size: 72,
              ),
              const SizedBox(height: 18),
              Text(
                'Révision terminée',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '$correct/$total',
                style: AppTextStyles.beriyaMedium.copyWith(
                  color: AppColors.gold,
                  fontSize: 42,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score : $percent%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recommencer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}