import 'package:flutter/material.dart';

import '../../../core/audio/audio_url_player.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/word_model.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/widgets/content_source_badge.dart';
import '../../../shared/beriya/beriya_text_field.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final TextEditingController _searchController = TextEditingController();
  final CachedContentService _cachedContentService = CachedContentService();

  late Future<List<WordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWords();
  }

  Future<List<WordModel>> _loadWords({String? search}) {
    return _cachedContentService.loadWords(search: search);
  }
  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _reload({String? search}) async {
    setState(() {
      _future = _loadWords(search: search);
    });
  }

  String _translationForLocale(WordModel word, String lang) {
    if (lang == 'ar' && word.translationAr.isNotEmpty) {
      return word.translationAr;
    }

    if (lang == 'en' && word.translationEn.isNotEmpty) {
      return word.translationEn;
    }

    if (word.translationFr.isNotEmpty) {
      return word.translationFr;
    }

    if (word.frenchTranslation.isNotEmpty) {
      return word.frenchTranslation;
    }

    if (word.englishTranslation.isNotEmpty) {
      return word.englishTranslation;
    }

    if (word.arabicTranslation.isNotEmpty) {
      return word.arabicTranslation;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.vocabulary),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _reload(search: _searchController.text),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      BeriyaTextField(
                        controller: _searchController,
                        hint: loc.searchVocabulary,
                        textInputAction: TextInputAction.search,
                        prefixIcon: const Icon(Icons.search_rounded),
                        initialMode: BeriyaInputMode.system,
                        onChanged: (value) => _reload(search: value),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _reload(
                            search: _searchController.text,
                          ),
                          icon: const Icon(Icons.search_rounded),
                          label: Text(loc.search),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<WordModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return GlassCard(
                        child: Text(loc.loading),
                      );
                    }

                    if (snapshot.hasError) {
                      return GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.errorLoading,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            ContentSourceBadge(
                              source: ContentSourceState.instance.getSource(CacheKeys.words),
                            ),
                            const SizedBox(height: 10),
                            Text(loc.errorLoading),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => _reload(
                                search: _searchController.text,
                              ),
                              child: Text(loc.retry),
                            ),
                          ],
                        ),
                      );
                    }

                    final words = snapshot.data ?? [];

                    if (words.isEmpty) {
                      return Column(
                        children: [
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.vocabulary,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 10),
                                ContentSourceBadge(
                                  source: ContentSourceState.instance.getSource(
                                    CacheKeys.words,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          GlassCard(
                            child: Text(loc.noWords),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.vocabulary,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 10),
                              ContentSourceBadge(
                                source: ContentSourceState.instance.getSource(
                                  CacheKeys.words,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (final word in words) ...[
                          _WordCard(
                            word: word,
                            translation: _translationForLocale(word, lang),
                            fallbackTranslation: loc.translationMissing,
                            listenLabel: loc.listen,
                            onPlay: () => _audioPlayer.playUrl(word.audioUrl),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final WordModel word;
  final String translation;
  final String fallbackTranslation;
  final String listenLabel;
  final VoidCallback onPlay;

  const _WordCard({
    required this.word,
    required this.translation,
    required this.fallbackTranslation,
    required this.listenLabel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.beriyaText,
            style: AppTextStyles.beriyaMedium,
          ),
          const SizedBox(height: 8),
          Text(
            translation.isNotEmpty ? translation : fallbackTranslation,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (word.latinTranscription.isNotEmpty)
            Text('Latin: ${word.latinTranscription}'),
          if (word.arabicTranscription.isNotEmpty)
            Text('AR: ${word.arabicTranscription}'),
          if (word.categoryFr.isNotEmpty)
            Text('Catégorie: ${word.categoryFr}'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: word.audioUrl == null ? null : onPlay,
            icon: const Icon(Icons.volume_up_rounded),
            label: Text(listenLabel),
          ),
        ],
      ),
    );
  }
}