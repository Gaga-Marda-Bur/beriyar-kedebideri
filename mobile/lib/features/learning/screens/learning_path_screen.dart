import 'package:flutter/material.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/learning_theme_model.dart';
import 'unit_detail_screen.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/widgets/content_source_badge.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  final CachedContentService _cachedContentService = CachedContentService();

  late Future<List<LearningThemeModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadThemes();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadThemes();
    });
  }

  Future<List<LearningThemeModel>> _loadThemes() {
    return _cachedContentService.loadThemes();
  }

  String _titleForLocale(
    String lang,
    String fr,
    String en,
    String ar,
  ) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  String _descriptionForLocale(
    String lang,
    String fr,
    String en,
    String ar,
  ) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.learningPath),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<LearningThemeModel>>(
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
                              source: ContentSourceState.instance.getSource(CacheKeys.themes),
                            ),
                            const SizedBox(height: 10),
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

                final themes = snapshot.data ?? [];

                if (themes.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      GlassCard(child: Text(loc.noThemes)),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.learningPath,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.learningPathSubtitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final theme in themes) ...[
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleForLocale(
                                lang,
                                theme.titleFr,
                                theme.titleEn,
                                theme.titleAr,
                              ),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _descriptionForLocale(
                                lang,
                                theme.descriptionFr,
                                theme.descriptionEn,
                                theme.descriptionAr,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SmallPill(text: theme.level),
                                _SmallPill(text: '${theme.unitsCount} unités'),
                              ],
                            ),
                            const SizedBox(height: 18),
                            for (final unit in theme.units) ...[
                              _UnitTile(
                                title: _titleForLocale(
                                  lang,
                                  unit.titleFr,
                                  unit.titleEn,
                                  unit.titleAr,
                                ),
                                description: _descriptionForLocale(
                                  lang,
                                  unit.descriptionFr,
                                  unit.descriptionEn,
                                  unit.descriptionAr,
                                ),
                                charactersCount: unit.charactersCount,
                                wordsCount: unit.wordsCount,
                                estimatedMinutes: unit.estimatedMinutes,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UnitDetailScreen(
                                        unitSlug: unit.slug,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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

class _SmallPill extends StatelessWidget {
  final String text;

  const _SmallPill({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _UnitTile extends StatelessWidget {
  final String title;
  final String description;
  final int charactersCount;
  final int wordsCount;
  final int estimatedMinutes;
  final VoidCallback onTap;

  const _UnitTile({
    required this.title,
    required this.description,
    required this.charactersCount,
    required this.wordsCount,
    required this.estimatedMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('$charactersCount ${loc.characters}')),
                Chip(label: Text('$wordsCount ${loc.words}')),
                Chip(label: Text('$estimatedMinutes ${loc.minutes}')),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onTap,
                child: Text(loc.openUnit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}