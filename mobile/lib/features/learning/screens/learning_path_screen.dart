import 'package:flutter/material.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/learning_theme_model.dart';
import '../../progress/models/unit_progress_local_model.dart';
import '../../progress/services/unit_progress_local_storage.dart';
import 'unit_detail_screen.dart';
import 'learning_core_unit_screen.dart';
import '../../../core/theme/app_colors.dart';
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
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();

  late Future<List<LearningThemeModel>> _future;
  Map<String, UnitProgressLocalModel> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _future = _loadThemes();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final list = await _progressStorage.getAllProgress();
      if (mounted) {
        setState(() {
          _progressMap = {for (final p in list) p.unitSlug: p};
        });
      }
    } catch (_) {}
  }

  Future<void> _reload() async {
    await _loadProgress();
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
                          const SizedBox(height: 10),
                            ContentSourceBadge(
                              source: ContentSourceState.instance.getSource(CacheKeys.themes),
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
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.16),
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'MÉTHODE ACTIVE V1',
                                    style: TextStyle(
                                      color: AppColors.night,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.auto_stories_rounded, color: AppColors.gold),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Unité 1 : 𖺡 (/b/), 𖺣 (/e/), 𖺵 (/t/) & « be » (𖺡𖺣)',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Kedebideri',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tracé tactile guidé, fusion syllabique glisser-déposer et encodage clavier.',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: AppColors.night,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LearningCoreUnitScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text(
                                  'Démarrer la leçon interactive',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                isCompleted: _progressMap[unit.slug]?.completed ?? false,
                                scorePercent: _progressMap[unit.slug]?.bestScorePercent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UnitDetailScreen(
                                        unitSlug: unit.slug,
                                      ),
                                    ),
                                  ).then((_) => _loadProgress());
                                },
                                onStartActive: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LearningCoreUnitScreen(
                                        unitSlug: unit.slug,
                                      ),
                                    ),
                                  ).then((_) => _loadProgress());
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
  final bool isCompleted;
  final int? scorePercent;
  final VoidCallback onTap;
  final VoidCallback? onStartActive;

  const _UnitTile({
    required this.title,
    required this.description,
    required this.charactersCount,
    required this.wordsCount,
    required this.estimatedMinutes,
    this.isCompleted = false,
    this.scorePercent,
    required this.onTap,
    this.onStartActive,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onStartActive ?? onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? AppColors.green.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? AppColors.gold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isCompleted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'Kedebideri',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${scorePercent ?? 100}%',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
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
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(loc.openUnit),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onStartActive ?? onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.night,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    isCompleted ? 'Rejouer' : 'Apprendre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}