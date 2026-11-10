import 'package:flutter/material.dart';

import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bk_learning_node.dart';
import '../../../core/widgets/content_source_badge.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../offline_packs/screens/offline_packs_screen.dart';
import '../../progress/models/unit_progress_local_model.dart';
import '../../progress/services/unit_progress_local_storage.dart';
import '../models/learning_theme_model.dart';
import '../srs/local_srs_service.dart';
import '../srs/srs_item_model.dart';
import 'learning_core_unit_screen.dart';
import 'srs_review_session_screen.dart';
import 'unit_detail_screen.dart';

/// Choix explicite du parcours pédagogique (Lot 4B.4) :
/// - [trackA] : « Je parle Beřiya, j'apprends l'Erfe » (Chemin audio-first guidé avec `BkLearningNode` et SRS).
/// - [trackB] : « J'apprends le Beřiya et l'Erfe » (Catalogue thématique complet préservé sans verrouillage imposé).
enum BkLearningTrack {
  trackA,
  trackB,
}

class LearningPathScreen extends StatefulWidget {
  final CachedContentService? contentService;
  final UnitProgressLocalStorage? progressStorage;
  final LocalSrsService? srsService;
  final List<LearningThemeModel>? initialThemes;
  final BkLearningTrack initialTrack;

  const LearningPathScreen({
    super.key,
    this.contentService,
    this.progressStorage,
    this.srsService,
    this.initialThemes,
    this.initialTrack = BkLearningTrack.trackA,
  });

  /// Détermine de façon déterministe l'état `BkLearningNodeStatus` d'une unité
  /// à partir des progressions existantes (`UnitProgressLocalModel`) et des échéances SRS.
  static BkLearningNodeStatus resolveNodeStatus({
    required UnitProgressLocalModel? progress,
    required int dueSrsCount,
    required bool isFirstUnit,
    required bool previousUnitCompleted,
  }) {
    final isCompleted = progress?.completed == true;
    final isStarted = progress != null &&
        !isCompleted &&
        (progress.currentStep > 0 ||
            progress.quizzesAnswered > 0 ||
            progress.lessonsSeen > 0 ||
            progress.status == 'in_progress' ||
            progress.status == 'started');

    if (dueSrsCount > 0 && (isCompleted || isStarted)) {
      return BkLearningNodeStatus.reviewDue;
    }
    if (isCompleted) {
      return BkLearningNodeStatus.completed;
    }
    if (isStarted) {
      return BkLearningNodeStatus.inProgress;
    }
    if (dueSrsCount > 0) {
      return BkLearningNodeStatus.reviewDue;
    }
    if (isFirstUnit || previousUnitCompleted) {
      return BkLearningNodeStatus.available;
    }
    return BkLearningNodeStatus.locked;
  }

  /// Calcule le ratio de progression (`0.0` à `1.0`) pour l'anneau `BkLearningNode`.
  static double resolveNodeProgress(UnitProgressLocalModel? progress) {
    if (progress == null) return 0.0;
    if (progress.completed) return 1.0;
    if (progress.totalSteps > 0) {
      return (progress.currentStep / progress.totalSteps).clamp(0.0, 1.0);
    }
    if (progress.bestScorePercent > 0) {
      return (progress.bestScorePercent / 100.0).clamp(0.0, 0.95);
    }
    return 0.0;
  }

  /// Extrait le premier caractère Unicode Erfe (`U+16EA0`..`U+16EDF`) s'il est présent
  /// dans le titre ou la description de l'unité.
  static String? extractErfeSymbol(String text) {
    final match = RegExp(
      r'[\u{16EA0}-\u{16EDF}]',
      unicode: true,
    ).firstMatch(text);
    return match?.group(0);
  }

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  late final CachedContentService _cachedContentService;
  late final UnitProgressLocalStorage _progressStorage;
  late final LocalSrsService _srsService;

  late Future<List<LearningThemeModel>> _future;
  late BkLearningTrack _selectedTrack;

  Map<String, UnitProgressLocalModel> _progressMap = {};
  List<SrsItemRecord> _allSrsItems = const [];
  List<SrsItemRecord> _dueSrsItems = const [];
  Map<String, List<SrsItemRecord>> _dueSrsByUnit = const {};

  @override
  void initState() {
    super.initState();
    _cachedContentService = widget.contentService ?? CachedContentService();
    _progressStorage = widget.progressStorage ?? UnitProgressLocalStorage();
    _srsService = widget.srsService ?? LocalSrsService();
    _selectedTrack = widget.initialTrack;
    _future = _loadThemes();
    _loadProgressAndSrs();
  }

  Future<void> _loadProgressAndSrs() async {
    try {
      final list = await _progressStorage.getAllProgress();
      final allSrs = await _srsService.loadAll();
      final dueSrs = await _srsService.getDueItems(includeDifficult: true);
      final groupedDue = <String, List<SrsItemRecord>>{};
      for (final item in dueSrs) {
        groupedDue.putIfAbsent(item.unitSlug, () => <SrsItemRecord>[]).add(item);
      }
      if (mounted) {
        setState(() {
          _progressMap = {for (final p in list) p.unitSlug: p};
          _allSrsItems = allSrs;
          _dueSrsItems = dueSrs;
          _dueSrsByUnit = groupedDue;
        });
      }
    } catch (_) {}
  }

  Future<void> _reload() async {
    await _loadProgressAndSrs();
    if (!mounted) return;
    setState(() {
      _future = _loadThemes();
    });
  }

  Future<List<LearningThemeModel>> _loadThemes() {
    if (widget.initialThemes != null) {
      return Future.value(widget.initialThemes!);
    }
    return _cachedContentService.loadThemes();
  }

  String _localized(
    String lang,
    String fr,
    String en,
    String ar,
  ) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  void _openOfflinePacks() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const OfflinePacksScreen(),
          ),
        )
        .then((_) => _reload());
  }

  Future<void> _openSrsReview(List<SrsItemRecord> items) async {
    if (items.isEmpty) return;
    final distractors = <String>{
      for (final r in _allSrsItems)
        if (r.erfeText.trim().isNotEmpty) r.erfeText.trim(),
      '𖺠',
      '𖺡',
      '𖺣',
      '𖺵',
    }.toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SrsReviewSessionScreen(
          items: items,
          srsService: _srsService,
          distractorPool: distractors,
        ),
      ),
    );
    if (mounted) {
      await _loadProgressAndSrs();
    }
  }

  void _openUnitAudioFirst(String unitSlug) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningCoreUnitScreen(
          unitSlug: unitSlug,
          contentService: _cachedContentService,
          srsService: _srsService,
        ),
      ),
    ).then((_) => _loadProgressAndSrs());
  }

  void _openUnitDetail(String unitSlug) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnitDetailScreen(
          unitSlug: unitSlug,
        ),
      ),
    ).then((_) => _loadProgressAndSrs());
  }

  List<_ResolvedUnitNode> _resolveAllUnits(List<LearningThemeModel> themes) {
    final flat = <_ResolvedUnitNode>[];
    var globalIndex = 0;
    var previousCompleted = true;

    for (final theme in themes) {
      for (final unit in theme.units) {
        final progress = _progressMap[unit.slug];
        final dueList = _dueSrsByUnit[unit.slug] ?? const <SrsItemRecord>[];
        final status = LearningPathScreen.resolveNodeStatus(
          progress: progress,
          dueSrsCount: dueList.length,
          isFirstUnit: globalIndex == 0,
          previousUnitCompleted: previousCompleted,
        );
        final nodeProgress = LearningPathScreen.resolveNodeProgress(progress);
        final erfeSymbol = LearningPathScreen.extractErfeSymbol(
              '${unit.titleFr} ${unit.descriptionFr}',
            ) ??
            (globalIndex == 0 ? '𖺡' : null);

        flat.add(
          _ResolvedUnitNode(
            theme: theme,
            unit: unit,
            globalIndex: globalIndex,
            status: status,
            progressRatio: nodeProgress,
            progressModel: progress,
            dueSrsItems: dueList,
            erfeSymbol: erfeSymbol,
          ),
        );

        previousCompleted = progress?.completed == true;
        globalIndex++;
      }
    }
    return flat;
  }

  _ResolvedUnitNode? _findRecommendedNode(List<_ResolvedUnitNode> nodes) {
    if (nodes.isEmpty) return null;
    for (final n in nodes) {
      if (n.status == BkLearningNodeStatus.inProgress) return n;
    }
    for (final n in nodes) {
      if (n.status == BkLearningNodeStatus.reviewDue) return n;
    }
    for (final n in nodes) {
      if (n.status == BkLearningNodeStatus.available) return n;
    }
    return nodes.first;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final palette = BkThemePalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        title: Text(loc.learningPath),
        actions: [
          IconButton(
            key: const ValueKey('learning-path-offline-packs-action'),
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: loc.offlinePacks,
            onPressed: _openOfflinePacks,
          ),
        ],
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
                              source: ContentSourceState.instance.getSource(
                                CacheKeys.themes,
                              ),
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
                      _buildTrackSelectorCard(palette, lang),
                      const SizedBox(height: 16),
                      _buildOfflinePacksBanner(palette, loc, lang),
                      const SizedBox(height: 16),
                      GlassCard(child: Text(loc.noThemes)),
                    ],
                  );
                }

                final resolvedNodes = _resolveAllUnits(themes);
                final completedCount = resolvedNodes
                    .where((n) => n.progressModel?.completed == true)
                    .length;
                final masteredSrsCount = _allSrsItems
                    .where((i) => !i.isDifficult && i.successCount > 0)
                    .length;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. En-tête + indicateurs de réussite discrets
                      _buildHeaderSummaryCard(
                        loc: loc,
                        lang: lang,
                        palette: palette,
                        completedUnits: completedCount,
                        totalUnits: resolvedNodes.length,
                        masteredSrsCount: masteredSrsCount,
                      ),
                      const SizedBox(height: 16),

                      // 2. Sélecteur explicite Parcours A / Parcours B
                      _buildTrackSelectorCard(palette, lang),
                      const SizedBox(height: 16),

                      // 3. Bandeau de révision espacée SRS (compteur + accès direct)
                      _buildSrsReviewBanner(palette, lang),
                      const SizedBox(height: 16),

                      // 4. Accès permanent aux packs installés hors ligne
                      _buildOfflinePacksBanner(palette, loc, lang),
                      const SizedBox(height: 20),

                      // 5. Contenu selon le parcours choisi
                      if (_selectedTrack == BkLearningTrack.trackA)
                        ..._buildTrackAContent(
                          themes: themes,
                          resolvedNodes: resolvedNodes,
                          palette: palette,
                          lang: lang,
                          loc: loc,
                        )
                      else
                        ..._buildTrackBContent(
                          themes: themes,
                          palette: palette,
                          lang: lang,
                          loc: loc,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSummaryCard({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
    required int completedUnits,
    required int totalUnits,
    required int masteredSrsCount,
  }) {
    return GlassCard(
      key: const ValueKey('discreet-progress-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                loc.learningPath,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ContentSourceBadge(
                  source: ContentSourceState.instance.getSource(
                    CacheKeys.themes,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loc.learningPathSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DiscreetMetricBadge(
                icon: Icons.check_circle_outline_rounded,
                label: _localized(
                  lang,
                  '$completedUnits / $totalUnits unités validées',
                  '$completedUnits / $totalUnits units completed',
                  '$completedUnits / $totalUnits وحدات مكتملة',
                ),
                palette: palette,
              ),
              _DiscreetMetricBadge(
                icon: Icons.hearing_rounded,
                label: _localized(
                  lang,
                  '$masteredSrsCount élément(s) mémorisé(s)',
                  '$masteredSrsCount item(s) memorized',
                  '$masteredSrsCount عنصر محفوظ',
                ),
                palette: palette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSelectorCard(BkThemePalette palette, String lang) {
    final isTrackA = _selectedTrack == BkLearningTrack.trackA;

    return GlassCard(
      key: const ValueKey('learning-track-selector'),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localized(
              lang,
              'Choisissez votre parcours',
              'Choose your learning track',
              'اختر مسار التعلّم',
            ),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttonA = _TrackOptionButton(
                buttonKey: const ValueKey('track-selector-a'),
                selected: isTrackA,
                badge: 'PARCOURS A',
                title: _localized(
                  lang,
                  'Je parle Beřiya, j\'apprends l\'Erfe',
                  'I speak Beřiya, learning Erfe',
                  'أتحدث البيريا وأتعلم الإرفي',
                ),
                subtitle: _localized(
                  lang,
                  'Audio-first & écriture Erfe',
                  'Audio-first & Erfe script',
                  'سمعي وكتابة إرفي',
                ),
                icon: Icons.headphones_rounded,
                palette: palette,
                onTap: () {
                  if (_selectedTrack != BkLearningTrack.trackA) {
                    setState(() => _selectedTrack = BkLearningTrack.trackA);
                  }
                },
              );
              final buttonB = _TrackOptionButton(
                buttonKey: const ValueKey('track-selector-b'),
                selected: !isTrackA,
                badge: 'PARCOURS B',
                title: _localized(
                  lang,
                  'J\'apprends le Beřiya et l\'Erfe',
                  'Learning Beřiya and Erfe',
                  'أتعلم البيريا والإرفي',
                ),
                subtitle: _localized(
                  lang,
                  'Thèmes, lexique & leçons',
                  'Themes, vocabulary & lessons',
                  'مواضيع ومفردات ودروس',
                ),
                icon: Icons.menu_book_rounded,
                palette: palette,
                onTap: () {
                  if (_selectedTrack != BkLearningTrack.trackB) {
                    setState(() => _selectedTrack = BkLearningTrack.trackB);
                  }
                },
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttonA,
                    const SizedBox(height: AppTokens.spaceSm),
                    buttonB,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: buttonA),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(child: buttonB),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSrsReviewBanner(BkThemePalette palette, String lang) {
    final dueCount = _dueSrsItems.length;
    final hasDue = dueCount > 0;

    return GlassCard(
      key: const ValueKey('learning-path-srs-banner'),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasDue
                      ? palette.statusEncouragement.withValues(alpha: 0.16)
                      : palette.surfaceElevated,
                  border: Border.all(
                    color: hasDue
                        ? palette.statusEncouragement
                        : palette.border,
                  ),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: hasDue
                      ? palette.statusEncouragement
                      : palette.accentGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key: const ValueKey('learning-path-srs-count'),
                      hasDue
                          ? _localized(
                              lang,
                              '$dueCount élément(s) à réviser',
                              '$dueCount item(s) due for review',
                              '$dueCount عنصر للمراجعة',
                            )
                          : _localized(
                              lang,
                              '0 élément à réviser maintenant',
                              '0 items due for review right now',
                              'لا توجد عناصر للمراجعة الآن',
                            ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDue
                          ? _localized(
                              lang,
                              'Consolidez la correspondance son Beřiya → écriture Erfe.',
                              'Strengthen sound-to-Erfe script memory.',
                              'عزّز الربط بين الصوت وكتابة الإرفي.',
                            )
                          : _localized(
                              lang,
                              'Vos révisions espacées sont à jour.',
                              'Your spaced repetition reviews are up to date.',
                              'مراجعاتك المتباعدة محدّثة.',
                            ),
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.minTouchTarget,
              ),
              child: FilledButton.tonalIcon(
                key: const ValueKey('learning-path-srs-review-button'),
                onPressed: hasDue ? () => _openSrsReview(_dueSrsItems) : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  _localized(lang, 'Réviser', 'Review', 'مراجعة'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePacksBanner(
    BkThemePalette palette,
    AppLocalizations loc,
    String lang,
  ) {
    return GlassCard(
      key: const ValueKey('learning-path-offline-packs-card'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.offline_pin_rounded,
                color: palette.accentGold,
                size: 22,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  _localized(
                    lang,
                    'Packs hors ligne : accédez aux leçons et audios téléchargés',
                    'Offline packs: access downloaded lessons and audio',
                    'الحزم دون اتصال: الوصول إلى الدروس والصوتيات المحمّلة',
                  ),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.minTouchTarget,
              ),
              child: OutlinedButton.icon(
                key: const ValueKey('learning-path-offline-packs-button'),
                onPressed: _openOfflinePacks,
                icon: const Icon(Icons.folder_special_rounded, size: 18),
                label: Text(loc.offlinePacks),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTrackAContent({
    required List<LearningThemeModel> themes,
    required List<_ResolvedUnitNode> resolvedNodes,
    required BkThemePalette palette,
    required String lang,
    required AppLocalizations loc,
  }) {
    final recommended = _findRecommendedNode(resolvedNodes);
    final widgets = <Widget>[];

    if (recommended != null) {
      widgets.add(
        _buildRecommendedActivityCard(
          node: recommended,
          palette: palette,
          lang: lang,
        ),
      );
      widgets.add(const SizedBox(height: 20));
    }

    // Regroupement par thème tout en affichant les nœuds BkLearningNode connectés
    for (final theme in themes) {
      final themeNodes = resolvedNodes
          .where((n) => n.theme.slug == theme.slug || n.theme.id == theme.id)
          .toList();
      if (themeNodes.isEmpty) continue;

      widgets.add(
        GlassCard(
          key: ValueKey('track-a-theme-${theme.slug}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _localized(
                      lang,
                      theme.titleFr,
                      theme.titleEn,
                      theme.titleAr,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  _SmallPill(
                    text: '${themeNodes.length} unités',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _localized(
                  lang,
                  theme.descriptionFr,
                  theme.descriptionEn,
                  theme.descriptionAr,
                ),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < themeNodes.length; i++) ...[
                _buildTrackANodeRow(
                  node: themeNodes[i],
                  isRecommended:
                      recommended?.unit.slug == themeNodes[i].unit.slug,
                  isLastInTheme: i == themeNodes.length - 1,
                  palette: palette,
                  lang: lang,
                  loc: loc,
                ),
              ],
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildRecommendedActivityCard({
    required _ResolvedUnitNode node,
    required BkThemePalette palette,
    required String lang,
  }) {
    final unitTitle = _localized(
      lang,
      node.unit.titleFr,
      node.unit.titleEn,
      node.unit.titleAr,
    );
    final isReviewPriority = node.status == BkLearningNodeStatus.reviewDue &&
        node.dueSrsItems.isNotEmpty;

    final badgeText = switch (node.status) {
      BkLearningNodeStatus.inProgress => _localized(
          lang,
          'REPRENDRE LA SÉANCE',
          'RESUME SESSION',
          'استئناف الجلسة',
        ),
      BkLearningNodeStatus.reviewDue => _localized(
          lang,
          'RÉVISION RECOMMANDÉE',
          'RECOMMENDED REVIEW',
          'مراجعة موصى بها',
        ),
      BkLearningNodeStatus.completed => _localized(
          lang,
          'CONSOLIDER L\'UNITÉ',
          'PRACTICE UNIT',
          'تعزيز الوحدة',
        ),
      _ => _localized(
          lang,
          'PROCHAINE ACTIVITÉ RECOMMANDÉE',
          'NEXT RECOMMENDED ACTIVITY',
          'النشاط الموصى به التالي',
        ),
    };

    final actionLabel = switch (node.status) {
      BkLearningNodeStatus.inProgress => _localized(
          lang,
          'Continuer la séance audio-first',
          'Continue audio-first session',
          'متابعة الجلسة السمعية',
        ),
      BkLearningNodeStatus.reviewDue => _localized(
          lang,
          'Lancer la révision (${node.dueSrsItems.length})',
          'Start review (${node.dueSrsItems.length})',
          'بدء المراجعة (${node.dueSrsItems.length})',
        ),
      _ => _localized(
          lang,
          'Démarrer la séance audio-first',
          'Start audio-first session',
          'بدء الجلسة السمعية',
        ),
    };

    return GlassCard(
      key: const ValueKey('recommended-next-activity-card'),
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.accentGold,
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: palette.accentGoldForeground,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(
                Icons.headphones_rounded,
                color: palette.accentGold,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            unitTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'Kedebideri',
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _localized(
              lang,
              'Écoute authentique, reconnaissance visuelle, lecture et composition au clavier Erfe.',
              'Authentic listening, visual recognition, reading and Erfe keyboard composition.',
              'استماع أصيل، تعرّف بصري، قراءة وكتابة بلوحة الإرفي.',
            ),
            style: TextStyle(
              fontSize: 13,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTokens.minTouchTarget,
              ),
              child: FilledButton.icon(
                key: const ValueKey('recommended-activity-cta'),
                onPressed: () {
                  if (isReviewPriority) {
                    _openSrsReview(node.dueSrsItems);
                  } else {
                    _openUnitAudioFirst(node.unit.slug);
                  }
                },
                icon: Icon(
                  isReviewPriority
                      ? Icons.autorenew_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackANodeRow({
    required _ResolvedUnitNode node,
    required bool isRecommended,
    required bool isLastInTheme,
    required BkThemePalette palette,
    required String lang,
    required AppLocalizations loc,
  }) {
    final unit = node.unit;
    final unitTitle = _localized(
      lang,
      unit.titleFr,
      unit.titleEn,
      unit.titleAr,
    );
    final unitDesc = _localized(
      lang,
      unit.descriptionFr,
      unit.descriptionEn,
      unit.descriptionAr,
    );
    final isLocked = node.status == BkLearningNodeStatus.locked;
    final dueCount = node.dueSrsItems.length;
    final bestScore = node.progressModel?.bestScorePercent;

    final statusLabel = switch (node.status) {
      BkLearningNodeStatus.locked => _localized(
          lang,
          'Verrouillé',
          'Locked',
          'مغلق',
        ),
      BkLearningNodeStatus.available => _localized(
          lang,
          'Disponible',
          'Available',
          'متاح',
        ),
      BkLearningNodeStatus.inProgress => _localized(
          lang,
          'En cours',
          'In progress',
          'قيد التقدّم',
        ),
      BkLearningNodeStatus.completed => _localized(
          lang,
          'Terminé',
          'Completed',
          'مكتمل',
        ),
      BkLearningNodeStatus.reviewDue => _localized(
          lang,
          'À réviser ($dueCount)',
          'Review due ($dueCount)',
          'للمراجعة ($dueCount)',
        ),
    };

    return IntrinsicHeight(
      key: ValueKey('path-unit-row-${unit.slug}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonne gauche : BkLearningNode + connecteur vertical
          SizedBox(
            width: 96,
            child: Column(
              children: [
                BkLearningNode(
                  key: ValueKey('learning-node-${unit.slug}'),
                  title: 'Unité ${node.globalIndex + 1}',
                  subtitle: statusLabel,
                  erfeSymbol: node.erfeSymbol,
                  status: node.status,
                  progress: node.progressRatio,
                  size: 64,
                  onTap: isLocked ? null : () => _openUnitAudioFirst(unit.slug),
                ),
                if (!isLastInTheme)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: node.status == BkLearningNodeStatus.completed
                            ? palette.accentGold
                            : palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),

          // Colonne droite : Carte détaillée de l'étape
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLastInTheme ? 0 : 18),
              child: Container(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(
                    color: isRecommended
                        ? palette.accentGold
                        : (node.status == BkLearningNodeStatus.reviewDue
                              ? palette.statusEncouragement
                              : palette.border),
                    width: isRecommended ? 2.0 : 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusBadgePill(
                          status: node.status,
                          label: statusLabel,
                          palette: palette,
                        ),
                        if (isRecommended)
                          Container(
                            key: ValueKey('recommended-badge-${unit.slug}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accentGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusPill,
                              ),
                            ),
                            child: Text(
                              _localized(
                                lang,
                                'Recommandé',
                                'Recommended',
                                'موصى به',
                              ),
                              style: TextStyle(
                                color: palette.accentGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (bestScore != null && bestScore > 0)
                          Text(
                            '$bestScore%',
                            style: TextStyle(
                              color: palette.accentGold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      unitTitle,
                      style: TextStyle(
                        fontFamily: 'Kedebideri',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLocked
                            ? palette.textSecondary
                            : palette.textPrimary,
                      ),
                    ),
                    if (unitDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        unitDesc,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallPill(
                          text: '${unit.charactersCount} ${loc.characters}',
                          palette: palette,
                        ),
                        _SmallPill(
                          text: '${unit.wordsCount} ${loc.words}',
                          palette: palette,
                        ),
                        _SmallPill(
                          text: '${unit.estimatedMinutes} ${loc.minutes}',
                          palette: palette,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppTokens.minTouchTarget,
                          ),
                          child: FilledButton.icon(
                            key: ValueKey('unit-primary-action-${unit.slug}'),
                            onPressed: isLocked
                                ? null
                                : () => _openUnitAudioFirst(unit.slug),
                            icon: Icon(
                              isLocked
                                  ? Icons.lock_outline_rounded
                                  : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(
                              switch (node.status) {
                                BkLearningNodeStatus.locked => _localized(
                                    lang,
                                    'Verrouillé',
                                    'Locked',
                                    'مغلق',
                                  ),
                                BkLearningNodeStatus.inProgress => _localized(
                                    lang,
                                    'Continuer',
                                    'Continue',
                                    'متابعة',
                                  ),
                                BkLearningNodeStatus.completed => _localized(
                                    lang,
                                    'Rejouer',
                                    'Practice again',
                                    'إعادة',
                                  ),
                                _ => _localized(
                                    lang,
                                    'Apprendre',
                                    'Learn',
                                    'تعلّم',
                                  ),
                              },
                            ),
                          ),
                        ),
                        if (!isLocked)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppTokens.minTouchTarget,
                            ),
                            child: OutlinedButton(
                              key: ValueKey('unit-detail-action-${unit.slug}'),
                              onPressed: () => _openUnitDetail(unit.slug),
                              child: Text(loc.openUnit),
                            ),
                          ),
                        if (dueCount > 0)
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppTokens.minTouchTarget,
                            ),
                            child: OutlinedButton.icon(
                              key: ValueKey('unit-srs-action-${unit.slug}'),
                              onPressed: () =>
                                  _openSrsReview(node.dueSrsItems),
                              icon: Icon(
                                Icons.autorenew_rounded,
                                size: 18,
                                color: palette.statusEncouragement,
                              ),
                              label: Text(
                                _localized(
                                  lang,
                                  'Réviser ($dueCount)',
                                  'Review ($dueCount)',
                                  'مراجعة ($dueCount)',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parcours B (« J'apprends le Beřiya et l'Erfe ») :
  /// Préserve intégralement l'accès thématique libre aux fiches d'unités, leçons
  /// et quiz classiques sans imposer le verrouillage séquentiel du Parcours A.
  List<Widget> _buildTrackBContent({
    required List<LearningThemeModel> themes,
    required BkThemePalette palette,
    required String lang,
    required AppLocalizations loc,
  }) {
    final widgets = <Widget>[
      GlassCard(
        key: const ValueKey('track-b-overview-card'),
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Row(
          children: [
            Icon(
              Icons.explore_rounded,
              color: palette.accentGold,
              size: 26,
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Text(
                _localized(
                  lang,
                  'Parcours B : explorez librement toutes les unités thématiques, le vocabulaire trilingue, les leçons et les quiz.',
                  'Track B: freely explore all thematic units, trilingual vocabulary, lessons and quizzes.',
                  'المسار ب: استكشف بحرية جميع الوحدات والمفردات والدروس والاختبارات.',
                ),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];

    for (final theme in themes) {
      widgets.add(
        GlassCard(
          key: ValueKey('track-b-theme-${theme.slug}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _localized(
                  lang,
                  theme.titleFr,
                  theme.titleEn,
                  theme.titleAr,
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _localized(
                  lang,
                  theme.descriptionFr,
                  theme.descriptionEn,
                  theme.descriptionAr,
                ),
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallPill(text: theme.level, palette: palette),
                  _SmallPill(
                    text: '${theme.unitsCount} unités',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final unit in theme.units) ...[
                _TrackBUnitTile(
                  unitSlug: unit.slug,
                  title: _localized(
                    lang,
                    unit.titleFr,
                    unit.titleEn,
                    unit.titleAr,
                  ),
                  description: _localized(
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
                  palette: palette,
                  onTap: () => _openUnitDetail(unit.slug),
                  onStartActive: () => _openUnitAudioFirst(unit.slug),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }
}

class _ResolvedUnitNode {
  final LearningThemeModel theme;
  final LearningUnitCompactModel unit;
  final int globalIndex;
  final BkLearningNodeStatus status;
  final double progressRatio;
  final UnitProgressLocalModel? progressModel;
  final List<SrsItemRecord> dueSrsItems;
  final String? erfeSymbol;

  const _ResolvedUnitNode({
    required this.theme,
    required this.unit,
    required this.globalIndex,
    required this.status,
    required this.progressRatio,
    required this.progressModel,
    required this.dueSrsItems,
    required this.erfeSymbol,
  });
}

class _DiscreetMetricBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final BkThemePalette palette;

  const _DiscreetMetricBadge({
    required this.icon,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.accentGold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackOptionButton extends StatelessWidget {
  final Key buttonKey;
  final bool selected;
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final BkThemePalette palette;
  final VoidCallback onTap;

  const _TrackOptionButton({
    required this.buttonKey,
    required this.selected,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$badge : $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              decoration: BoxDecoration(
                color: selected ? palette.surfaceElevated : palette.surface,
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: selected ? palette.accentGold : palette.border,
                  width: selected ? 2.0 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: selected
                            ? palette.accentGold
                            : palette.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? palette.accentGold
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: palette.accentGold,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.latinCaption.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadgePill extends StatelessWidget {
  final BkLearningNodeStatus status;
  final String label;
  final BkThemePalette palette;

  const _StatusBadgePill({
    required this.status,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = switch (status) {
      BkLearningNodeStatus.locked => palette.textSecondary,
      BkLearningNodeStatus.available => palette.textPrimary,
      BkLearningNodeStatus.inProgress => palette.accentGold,
      BkLearningNodeStatus.completed => palette.statusSuccess,
      BkLearningNodeStatus.reviewDue => palette.statusEncouragement,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final String text;
  final BkThemePalette palette;

  const _SmallPill({
    required this.text,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrackBUnitTile extends StatelessWidget {
  final String unitSlug;
  final String title;
  final String description;
  final int charactersCount;
  final int wordsCount;
  final int estimatedMinutes;
  final bool isCompleted;
  final int? scorePercent;
  final BkThemePalette palette;
  final VoidCallback onTap;
  final VoidCallback? onStartActive;

  const _TrackBUnitTile({
    required this.unitSlug,
    required this.title,
    required this.description,
    required this.charactersCount,
    required this.wordsCount,
    required this.estimatedMinutes,
    this.isCompleted = false,
    this.scorePercent,
    required this.palette,
    required this.onTap,
    this.onStartActive,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return InkWell(
      key: ValueKey('track-b-unit-$unitSlug'),
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted ? palette.accentGold : palette.border,
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
                          color: palette.textPrimary,
                        ),
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.accentGold, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: palette.accentGold,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${scorePercent ?? 100}%',
                          style: TextStyle(
                            color: palette.accentGold,
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
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallPill(
                  text: '$charactersCount ${loc.characters}',
                  palette: palette,
                ),
                _SmallPill(
                  text: '$wordsCount ${loc.words}',
                  palette: palette,
                ),
                _SmallPill(
                  text: '$estimatedMinutes ${loc.minutes}',
                  palette: palette,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  child: OutlinedButton(
                    key: ValueKey('track-b-open-detail-$unitSlug'),
                    onPressed: onTap,
                    child: Text(loc.openUnit),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.minTouchTarget,
                  ),
                  child: FilledButton.icon(
                    key: ValueKey('track-b-start-active-$unitSlug'),
                    onPressed: onStartActive ?? onTap,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      isCompleted ? 'Rejouer' : 'Apprendre',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
