import 'package:flutter/material.dart';

import '../../../core/audio/audio_url_player.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/word_model.dart';
import '../vocabulary_api_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../offline_packs/services/offline_content_service.dart';


class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final VocabularyApiService _service = VocabularyApiService();
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();
  final TextEditingController _searchController = TextEditingController();
  final OfflineContentService _offlineService = OfflineContentService();

  late Future<List<WordModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWords();
  }

  Future<List<WordModel>> _loadWords({String? search}) async {
    try {
      final online = await _service.fetchWords(search: search);

      if (online.isNotEmpty) {
        return online;
      }
    } catch (_) {
      // fallback offline
    }

    final offline = await _offlineService.loadWords();

    final query = search?.trim().toLowerCase() ?? '';

    if (query.isEmpty) {
      return offline;
    }

    return offline.where((word) {
      return word.beriyaText.toLowerCase().contains(query) ||
          word.latinTranscription.toLowerCase().contains(query) ||
          word.translationFr.toLowerCase().contains(query) ||
          word.translationEn.toLowerCase().contains(query) ||
          word.translationAr.toLowerCase().contains(query);
    }).toList();
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
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) => _reload(search: value),
                        decoration: InputDecoration(
                          hintText: loc.searchVocabulary,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
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
                            Text(snapshot.error.toString()),
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
                      return GlassCard(
                        child: Text(loc.noWords),
                      );
                    }

                    return Column(
                      children: [
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