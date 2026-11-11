import 'package:flutter/material.dart';

import '../../../core/cache/cached_content_service.dart';
import '../../../core/network/backend_status_service.dart';
import '../../../core/startup/app_preload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bk_learning_node.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/beriya/utf16_safe.dart';
import '../../alphabet/screens/alphabet_screen.dart';
import '../../content_hub/screens/content_hub_screen.dart';
import '../../learning/models/learning_theme_model.dart';
import '../../learning/screens/learning_core_unit_screen.dart';
import '../../learning/screens/learning_path_screen.dart';
import '../../learning/screens/srs_review_session_screen.dart';
import '../../learning/screens/unit_detail_screen.dart';
import '../../learning/srs/local_srs_service.dart';
import '../../learning/srs/srs_item_model.dart';
import '../../offline_packs/screens/offline_packs_screen.dart';
import '../../progress/models/unit_progress_local_model.dart';
import '../../progress/services/unit_progress_local_storage.dart';
import '../../settings/screens/settings_screen.dart';
import '../../vocabulary/screens/vocabulary_screen.dart';
import '../../no_ena/screens/no_ena_screen.dart';
import '../../sticker_studio/presentation/sticker_studio_screen.dart';
import '../../editor/screens/beriya_editor_screen.dart';

/// Écran d'accueil modernisé (Lot 4B.5 — Design System Sahel Modern).
///
/// Hiérarchie visuelle priorisée :
/// 1. Parcours actif (Parcours A audio-first ou Parcours B thématique).
/// 2. Action principale « Continuer à apprendre » (reliée à la prochaine unité
///    réellement disponible selon le parcours et les progressions locales).
/// 3. Révisions SRS disponibles (compteurs réels + état vide explicite).
/// 4. Accès aux contenus téléchargés hors ligne.
/// 5. Accès secondaires (Dictionnaire, Alphabet, Leçons, Profil/Paramètres).
class HomeScreen extends StatefulWidget {
  final CachedContentService? contentService;
  final UnitProgressLocalStorage? progressStorage;
  final LocalSrsService? srsService;
  final BackendStatusService? backendStatusService;
  final List<LearningThemeModel>? initialThemes;
  final BkLearningTrack? initialTrack;
  final bool enablePreload;

  const HomeScreen({
    super.key,
    this.contentService,
    this.progressStorage,
    this.srsService,
    this.backendStatusService,
    this.initialThemes,
    this.initialTrack,
    this.enablePreload = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CachedContentService _contentService;
  late final UnitProgressLocalStorage _progressStorage;
  late final LocalSrsService _srsService;
  late final BackendStatusService _backendStatusService;

  late BkLearningTrack _selectedTrack;
  bool _online = false;
  bool _checkingNetwork = true;

  List<LearningThemeModel> _themes = const [];
  List<UnitProgressLocalModel> _progressList = const [];
  Map<String, UnitProgressLocalModel> _progressMap = const {};
  List<SrsItemRecord> _allSrsItems = const [];
  List<SrsItemRecord> _dueSrsItems = const [];
  Map<String, List<SrsItemRecord>> _dueSrsByUnit = const {};

  @override
  void initState() {
    super.initState();
    _contentService = widget.contentService ?? CachedContentService();
    _progressStorage = widget.progressStorage ?? UnitProgressLocalStorage();
    _srsService = widget.srsService ?? LocalSrsService();
    _backendStatusService =
        widget.backendStatusService ?? BackendStatusService();
    _selectedTrack = widget.initialTrack ?? BkLearningTrack.trackA;

    if (widget.initialThemes != null) {
      _themes = widget.initialThemes!;
    }

    if (widget.initialTrack != null) {
      LearningPathScreen.saveTrack(widget.initialTrack!);
    } else {
      _loadSavedTrack();
    }

    _loadLocalDataAndThemes();
    _checkBackendStatusNonBlocking();

    if (widget.enablePreload && widget.initialThemes == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppPreloadService.instance.startLightPreload();
      });
    }
  }

  Future<void> _loadSavedTrack() async {
    final saved = await LearningPathScreen.loadSavedTrack();
    if (mounted && saved != _selectedTrack) {
      setState(() => _selectedTrack = saved);
    }
  }

  void _selectTrack(BkLearningTrack track) {
    if (_selectedTrack != track) {
      setState(() => _selectedTrack = track);
    }
    LearningPathScreen.saveTrack(track);
  }

  Future<void> _loadLocalDataAndThemes() async {
    try {
      final progressList = await _progressStorage.getAllProgress();
      final allSrs = await _srsService.loadAll();
      final dueSrs = await _srsService.getDueItems(includeDifficult: true);
      final groupedDue = <String, List<SrsItemRecord>>{};
      for (final item in dueSrs) {
        groupedDue.putIfAbsent(item.unitSlug, () => <SrsItemRecord>[]).add(item);
      }

      if (mounted) {
        setState(() {
          _progressList = progressList;
          _progressMap = {for (final p in progressList) p.unitSlug: p};
          _allSrsItems = allSrs;
          _dueSrsItems = dueSrs;
          _dueSrsByUnit = groupedDue;
        });
      }
    } catch (_) {}

    if (widget.initialThemes != null) {
      return;
    }

    try {
      final loadedThemes = await _contentService.loadThemes();
      if (mounted) {
        setState(() {
          _themes = loadedThemes;
        });
      }
    } catch (_) {
      // Non-bloquant en mode hors ligne : l'accueil conserve les données locales.
    }
  }

  Future<void> _checkBackendStatusNonBlocking() async {
    if (widget.initialThemes != null && widget.backendStatusService == null) {
      if (mounted) {
        setState(() {
          _checkingNetwork = false;
        });
      }
      return;
    }
    try {
      final reachable = await _backendStatusService.isBackendReachable();
      if (mounted) {
        setState(() {
          _online = reachable;
          _checkingNetwork = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _online = false;
          _checkingNetwork = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    BackendStatusService.resetCache();
    await _loadSavedTrack();
    await _loadLocalDataAndThemes();
    await _checkBackendStatusNonBlocking();
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

  /// Résout la prochaine unité réellement disponible selon le parcours actif
  /// (`_selectedTrack`), les thèmes chargés et les progressions locales.
  _HomeNextUnitTarget? _resolveNextTarget() {
    if (_themes.isNotEmpty) {
      final flatUnits = <_HomeNextUnitTarget>[];
      var globalIndex = 0;
      var previousCompleted = true;

      for (final theme in _themes) {
        for (final unit in theme.units) {
          final progress = _progressMap[unit.slug];
          final dueCount = _dueSrsByUnit[unit.slug]?.length ?? 0;
          final status = LearningPathScreen.resolveNodeStatus(
            progress: progress,
            dueSrsCount: dueCount,
            isFirstUnit: globalIndex == 0,
            previousUnitCompleted: previousCompleted,
          );
          final ratio = LearningPathScreen.resolveNodeProgress(progress);
          final erfeSymbol = LearningPathScreen.extractErfeSymbol(
                '${unit.titleFr} ${unit.descriptionFr}',
              ) ??
              '𖺡';

          flatUnits.add(
            _HomeNextUnitTarget(
              unitSlug: unit.slug,
              unit: unit,
              theme: theme,
              status: status,
              progressModel: progress,
              progressRatio: ratio,
              dueSrsCount: dueCount,
              erfeSymbol: erfeSymbol,
            ),
          );

          previousCompleted = progress?.completed == true;
          globalIndex++;
        }
      }

      if (flatUnits.isNotEmpty) {
        if (_selectedTrack == BkLearningTrack.trackA) {
          // Parcours A : priorité aux états du chemin modernisé
          // 1. inProgress -> 2. reviewDue -> 3. available -> 4. première unité
          for (final item in flatUnits) {
            if (item.status == BkLearningNodeStatus.inProgress) return item;
          }
          for (final item in flatUnits) {
            if (item.status == BkLearningNodeStatus.reviewDue) return item;
          }
          for (final item in flatUnits) {
            if (item.status == BkLearningNodeStatus.available) return item;
          }
          return flatUnits.first;
        } else {
          // Parcours B : catalogue thématique libre (reprend la dernière unité en cours
          // ou propose la première unité du catalogue).
          for (final item in flatUnits) {
            if (item.progressModel != null && !item.progressModel!.completed) {
              return item;
            }
          }
          for (final item in flatUnits) {
            if (item.progressModel == null || !item.progressModel!.completed) {
              return item;
            }
          }
          return flatUnits.first;
        }
      }
    }

    // Repli hors ligne si aucun thème n'est encore en cache mais qu'une progression
    // locale existe déjà dans SharedPreferences.
    if (_progressList.isNotEmpty) {
      final active = _progressList.firstWhere(
        (p) => !p.completed,
        orElse: () => _progressList.first,
      );
      final status = LearningPathScreen.resolveNodeStatus(
        progress: active,
        dueSrsCount: _dueSrsByUnit[active.unitSlug]?.length ?? 0,
        isFirstUnit: true,
        previousUnitCompleted: true,
      );
      return _HomeNextUnitTarget(
        unitSlug: active.unitSlug,
        unit: null,
        theme: null,
        status: status,
        progressModel: active,
        progressRatio: LearningPathScreen.resolveNodeProgress(active),
        dueSrsCount: _dueSrsByUnit[active.unitSlug]?.length ?? 0,
        erfeSymbol: '𖺡',
      );
    }

    return null;
  }

  void _onContinueLearning(_HomeNextUnitTarget? target) {
    if (target == null) {
      _openLearningPath();
      return;
    }

    if (_selectedTrack == BkLearningTrack.trackA) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => LearningCoreUnitScreen(
                unitSlug: target.unitSlug,
                contentService: _contentService,
                srsService: _srsService,
              ),
            ),
          )
          .then((_) => _reload());
    } else {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => UnitDetailScreen(
                unitSlug: target.unitSlug,
              ),
            ),
          )
          .then((_) => _reload());
    }
  }

  Future<void> _openSrsReview() async {
    if (_dueSrsItems.isEmpty) return;
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
          items: _dueSrsItems,
          srsService: _srsService,
          distractorPool: distractors,
        ),
      ),
    );
    if (mounted) {
      await _loadLocalDataAndThemes();
    }
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

  void _openLearningPath() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => LearningPathScreen(
              contentService: _contentService,
              progressStorage: _progressStorage,
              srsService: _srsService,
              initialThemes: widget.initialThemes,
              initialTrack: _selectedTrack,
            ),
          ),
        )
        .then((_) => _reload());
  }

  void _openVocabulary() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const VocabularyScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openAlphabet() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const AlphabetScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openSettings() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openNoEna() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const NoEnaScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openStickerStudio() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const StickerStudioScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openEditor() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const BeriyaEditorScreen(),
          ),
        )
        .then((_) => _reload());
  }

  void _openHub() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const ContentHubScreen(),
          ),
        )
        .then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final palette = BkThemePalette.of(context);
    final nextTarget = _resolveNextTarget();

    return Scaffold(
      backgroundColor: palette.background,
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête identitaire Beřiyar Kedebideři + statut réseau discret
                  _buildTopHeader(
                    loc: loc,
                    lang: lang,
                    palette: palette,
                  ),
                  const SizedBox(height: 16),

                  // PRIORITÉ 1 — Parcours actuel A ou B (modifiable à tout moment)
                  _buildActiveTrackCard(
                    lang: lang,
                    palette: palette,
                  ),
                  const SizedBox(height: 16),

                  // PRIORITÉ 2 — Action principale « Continuer à apprendre »
                  _buildContinueLearningCard(
                    loc: loc,
                    lang: lang,
                    palette: palette,
                    target: nextTarget,
                  ),
                  const SizedBox(height: 16),

                  // PRIORITÉ 3 — Révisions SRS disponibles (avec état vide clair)
                  _buildSrsReviewCard(
                    lang: lang,
                    palette: palette,
                  ),
                  const SizedBox(height: 16),

                  // PRIORITÉ 4 — Accès aux contenus téléchargés hors ligne
                  _buildOfflinePacksCard(
                    loc: loc,
                    lang: lang,
                    palette: palette,
                  ),
                  const SizedBox(height: 22),

                  // PRIORITÉ 5 — Outils & Création (No Ena, Studio Sticker, Éditeur Beriya)
                  _buildToolsAndCreationSection(
                    loc: loc,
                    lang: lang,
                    palette: palette,
                  ),
                  const SizedBox(height: 22),

                  // PRIORITÉ 6 — Accès secondaires : dictionnaire, alphabet, leçons, profil
                  _buildSecondaryAccessSection(
                    loc: loc,
                    lang: lang,
                    palette: palette,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
  }) {
    final completedUnits =
        _progressList.where((p) => p.completed).length;

    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusControl),
              gradient: LinearGradient(
                colors: [
                  palette.accentGold,
                  AppTokens.goldGlow,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              '𖺡',
              style: AppTextStyles.erfeOptionText.copyWith(
                color: AppColors.night,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beřiyar Kedebideři',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  completedUnits > 0
                      ? _localized(
                          lang,
                          '$completedUnits unité(s) complétée(s)',
                          '$completedUnits unit(s) completed',
                          '$completedUnits وحدة مكتملة',
                        )
                      : loc.welcomeHome,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          _NetworkStatusPill(
            online: _online,
            checking: _checkingNetwork,
            lang: lang,
            palette: palette,
            onTapOffline: _openOfflinePacks,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrackCard({
    required String lang,
    required BkThemePalette palette,
  }) {
    final isTrackA = _selectedTrack == BkLearningTrack.trackA;

    return GlassCard(
      key: const ValueKey('home-active-track-card'),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _localized(
                  lang,
                  'PARCOURS ACTUEL',
                  'CURRENT TRACK',
                  'المسار الحالي',
                ),
                style: TextStyle(
                  color: palette.accentGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                isTrackA
                    ? _localized(
                        lang,
                        'Audio-first & écriture Erfe',
                        'Audio-first & Erfe script',
                        'سمعي وكتابة إرفي',
                      )
                    : _localized(
                        lang,
                        'Catalogue thématique complet',
                        'Full thematic catalog',
                        'الدليل الموضوعي الكامل',
                      ),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttonA = _HomeTrackSwitchButton(
                buttonKey: const ValueKey('home-track-a-button'),
                selected: isTrackA,
                badge: 'PARCOURS A',
                title: _localized(
                  lang,
                  'Je parle Beřiya, j\'apprends l\'Erfe',
                  'I speak Beřiya, learning Erfe',
                  'أتحدث البيريا وأتعلم الإرفي',
                ),
                icon: Icons.headphones_rounded,
                palette: palette,
                onTap: () => _selectTrack(BkLearningTrack.trackA),
              );

              final buttonB = _HomeTrackSwitchButton(
                buttonKey: const ValueKey('home-track-b-button'),
                selected: !isTrackA,
                badge: 'PARCOURS B',
                title: _localized(
                  lang,
                  'J\'apprends le Beřiya et l\'Erfe',
                  'Learning Beřiya and Erfe',
                  'أتعلم البيريا والإرفي',
                ),
                icon: Icons.menu_book_rounded,
                palette: palette,
                onTap: () => _selectTrack(BkLearningTrack.trackB),
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

  Widget _buildContinueLearningCard({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
    required _HomeNextUnitTarget? target,
  }) {
    final isTrackA = _selectedTrack == BkLearningTrack.trackA;
    final unitTitle = target?.unit != null
        ? _localized(
            lang,
            target!.unit!.titleFr,
            target.unit!.titleEn,
            target.unit!.titleAr,
          )
        : (target != null
            ? Utf16Safe.sanitize(target.unitSlug)
            : _localized(
                lang,
                'Première séance découverte Erfe',
                'First Erfe discovery session',
                'أول جلسة استكشاف إرفي',
              ));

    final themeTitle = target?.theme != null
        ? _localized(
            lang,
            target!.theme!.titleFr,
            target.theme!.titleEn,
            target.theme!.titleAr,
          )
        : (isTrackA
            ? _localized(
                lang,
                'Séance audio-first en 5 étapes',
                '5-step audio-first session',
                'جلسة سمعية من 5 خطوات',
              )
            : _localized(
                lang,
                'Exploration thématique libre',
                'Free thematic exploration',
                'استكشاف موضوعي حر',
              ));

    final statusLabel = target == null
        ? _localized(
            lang,
            'PRÊT À DÉMARRER',
            'READY TO START',
            'جاهز للبدء',
          )
        : switch (target.status) {
            BkLearningNodeStatus.inProgress => _localized(
                lang,
                'EN COURS • ${(target.progressRatio * 100).round()}%',
                'IN PROGRESS • ${(target.progressRatio * 100).round()}%',
                'قيد التقدم • ${(target.progressRatio * 100).round()}%',
              ),
            BkLearningNodeStatus.reviewDue => _localized(
                lang,
                'RÉVISION RECOMMANDÉE',
                'REVIEW RECOMMENDED',
                'مراجعة موصى بها',
              ),
            BkLearningNodeStatus.completed => _localized(
                lang,
                'UNITÉ VALIDÉE',
                'UNIT COMPLETED',
                'وحدة مكتملة',
              ),
            BkLearningNodeStatus.available => _localized(
                lang,
                'PROCHAINE UNITÉ DISPONIBLE',
                'NEXT AVAILABLE UNIT',
                'الوحدة المتاحة التالية',
              ),
            BkLearningNodeStatus.locked => _localized(
                lang,
                'PROCHAINE ÉTAPE',
                'NEXT STEP',
                'الخطوة التالية',
              ),
          };

    final ctaLabel = target != null &&
            (target.status == BkLearningNodeStatus.inProgress ||
                _progressList.isNotEmpty)
        ? _localized(
            lang,
            'Continuer à apprendre',
            'Continue learning',
            'متابعة التعلّم',
          )
        : _localized(
            lang,
            'Continuer à apprendre',
            'Continue learning',
            'متابعة التعلّم',
          );

    return GlassCard(
      key: const ValueKey('home-continue-learning-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  color: palette.accentGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  border: Border.all(
                    color: palette.accentGold.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: palette.accentGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                isTrackA ? 'Parcours A' : 'Parcours B',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(
                    color: palette.accentGold.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  target?.erfeSymbol ?? '𖺡',
                  style: AppTextStyles.erfeOptionText.copyWith(
                    color: palette.accentGold,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key: const ValueKey('home-continue-unit-title'),
                      unitTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      themeTitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (target != null && target.progressRatio > 0) ...[
            const SizedBox(height: AppTokens.spaceMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: LinearProgressIndicator(
                value: target.progressRatio,
                minHeight: 8,
                backgroundColor: palette.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(palette.accentGold),
              ),
            ),
          ],
          const SizedBox(height: AppTokens.spaceMd),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: FilledButton.icon(
              key: const ValueKey('home-continue-learning-cta'),
              onPressed: () => _onContinueLearning(target),
              icon: Icon(
                isTrackA
                    ? Icons.play_circle_fill_rounded
                    : Icons.menu_book_rounded,
              ),
              label: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSrsReviewCard({
    required String lang,
    required BkThemePalette palette,
  }) {
    final totalLearned = _allSrsItems.length;
    final dueCount = _dueSrsItems.length;
    final hasLearnedAnything = totalLearned > 0;
    final hasDue = dueCount > 0;

    return GlassCard(
      key: const ValueKey('home-srs-review-card'),
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
                  hasLearnedAnything
                      ? Icons.schedule_rounded
                      : Icons.auto_awesome_outlined,
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
                      key: const ValueKey('home-srs-status-title'),
                      !hasLearnedAnything
                          ? _localized(
                              lang,
                              'Répétition espacée (SRS)',
                              'Spaced repetition (SRS)',
                              'التكرار المتباعد (SRS)',
                            )
                          : (hasDue
                              ? _localized(
                                  lang,
                                  '$dueCount élément(s) à réviser',
                                  '$dueCount item(s) due for review',
                                  '$dueCount عنصر للمراجعة',
                                )
                              : _localized(
                                  lang,
                                  '0 élément à réviser maintenant',
                                  '0 items due for review now',
                                  'لا توجد عناصر للمراجعة الآن',
                                )),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!hasLearnedAnything)
                      Text(
                        key: const ValueKey('home-srs-empty-state'),
                        _localized(
                          lang,
                          'Aucun élément étudié pour le moment. Commencez une unité pour activer vos révisions audio-first.',
                          'No items studied yet. Start a unit to activate your audio-first reviews.',
                          'لم تتم دراسة أي عنصر بعد. ابدأ وحدة لتفعيل المراجعات السمعية.',
                        ),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      )
                    else
                      Text(
                        hasDue
                            ? _localized(
                                lang,
                                'Révision libre et facultative ($totalLearned élément(s) suivi(s) en mémoire).',
                                'Optional review ($totalLearned item(s) tracked in memory).',
                                'مراجعة اختيارية ($totalLearned عنصر متتبع في الذاكرة).',
                              )
                            : _localized(
                                lang,
                                'Vos $totalLearned élément(s) mémorisé(s) sont à jour.',
                                'Your $totalLearned memorized item(s) are up to date.',
                                'عناصرك المحفوظة ($totalLearned) محدّثة.',
                              ),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasDue) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppTokens.minTouchTarget,
                ),
                child: FilledButton.tonalIcon(
                  key: const ValueKey('home-srs-review-cta'),
                  onPressed: _openSrsReview,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    _localized(
                      lang,
                      'Lancer la révision ($dueCount)',
                      'Start review ($dueCount)',
                      'بدء المراجعة ($dueCount)',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflinePacksCard({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
  }) {
    return GlassCard(
      key: const ValueKey('home-offline-packs-card'),
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
                  borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                  color: palette.accentGold.withValues(alpha: 0.14),
                  border: Border.all(
                    color: palette.accentGold.withValues(alpha: 0.40),
                  ),
                ),
                child: Icon(
                  Icons.download_done_rounded,
                  color: palette.accentGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localized(
                        lang,
                        'Contenus téléchargés hors ligne',
                        'Downloaded offline content',
                        'المحتويات المحمّلة دون اتصال',
                      ),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _localized(
                        lang,
                        'Consultez et gérez vos packs audio et leçons utilisables sans réseau.',
                        'Browse and manage your audio packs and lessons available offline.',
                        'تصفّح وأدر حزم الصوت والدروس المتاحة دون إنترنت.',
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
              child: OutlinedButton.icon(
                key: const ValueKey('home-offline-packs-cta'),
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

  Widget _buildToolsAndCreationSection({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
  }) {
    final title = _localized(
      lang,
      'Outils & Création',
      'Tools & Creation',
      'أدوات وإبداع',
    );

    final tools = [
      _CreationToolItem(
        key: const ValueKey('home-tool-no-ena'),
        title: 'No Ena',
        subtitle: _localized(
          lang,
          'Publications et récits illustrés',
          'Publications and illustrated stories',
          'منشورات وقصص مصورة',
        ),
        badge: _localized(lang, 'Culture', 'Culture', 'ثقافة'),
        icon: Icons.auto_awesome_rounded,
        onTap: _openNoEna,
      ),
      _CreationToolItem(
        key: const ValueKey('home-tool-sticker-studio'),
        title: 'Studio Sticker',
        subtitle: _localized(
          lang,
          'Créer et exporter des stickers Erfe',
          'Create & export Erfe stickers',
          'تصميم وتصدير ملصقات إرفي',
        ),
        badge: _localized(lang, 'Graphisme', 'Design', 'تصميم'),
        icon: Icons.draw_rounded,
        onTap: _openStickerStudio,
      ),
      _CreationToolItem(
        key: const ValueKey('home-tool-editor'),
        title: _localized(lang, 'Éditeur Beriya', 'Beriya Editor', 'محرر بيريا'),
        subtitle: _localized(
          lang,
          'Saisie Erfe, brouillons & export PDF',
          'Erfe typing, drafts & PDF export',
          'كتابة إرفي، مسودات وتصدير PDF',
        ),
        badge: _localized(lang, 'Écriture', 'Writing', 'كتابة'),
        icon: Icons.article_rounded,
        onTap: _openEditor,
      ),
    ];

    return Column(
      key: const ValueKey('home-tools-creation-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 340;
            return Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const ValueKey('home-tools-view-all-button'),
                  onPressed: _openHub,
                  icon: const Icon(Icons.apps_rounded, size: 16),
                  label: isNarrow
                      ? const SizedBox.shrink()
                      : Text(
                          _localized(lang, 'Tout voir', 'View all', 'عرض الكل'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.accentGold,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppTokens.spaceSm),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 480;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tools.length; i++) ...[
                    _CreationToolTile(item: tools[i], palette: palette),
                    if (i < tools.length - 1)
                      const SizedBox(height: AppTokens.spaceSm),
                  ],
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CreationToolTile(
                        item: tools[0],
                        palette: palette,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: _CreationToolTile(
                        item: tools[1],
                        palette: palette,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _CreationToolTile(
                  item: tools[2],
                  palette: palette,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecondaryAccessSection({
    required AppLocalizations loc,
    required String lang,
    required BkThemePalette palette,
  }) {
    final items = [
      _SecondaryAccessItem(
        itemKey: const ValueKey('home-secondary-dictionary'),
        title: _localized(lang, 'Dictionnaire', 'Dictionary', 'القاموس'),
        subtitle: loc.vocabularyShort,
        icon: Icons.menu_book_rounded,
        onTap: _openVocabulary,
      ),
      _SecondaryAccessItem(
        itemKey: const ValueKey('home-secondary-alphabet'),
        title: loc.alphabetShort,
        subtitle: _localized(lang, 'Lettres Erfe', 'Erfe letters', 'حروف إرفي'),
        icon: Icons.text_fields_rounded,
        onTap: _openAlphabet,
      ),
      _SecondaryAccessItem(
        itemKey: const ValueKey('home-secondary-lessons'),
        title: _localized(lang, 'Leçons', 'Lessons', 'الدروس'),
        subtitle: loc.learningPath,
        icon: Icons.route_rounded,
        onTap: _openLearningPath,
      ),
      _SecondaryAccessItem(
        itemKey: const ValueKey('home-secondary-profile'),
        title: _localized(lang, 'Profil & réglages', 'Profile & settings', 'الملف والإعدادات'),
        subtitle: loc.settings,
        icon: Icons.tune_rounded,
        onTap: _openSettings,
      ),
    ];

    return Column(
      key: const ValueKey('home-secondary-access-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.quickAccess,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 340;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _SecondaryAccessTile(item: items[i], palette: palette),
                    if (i < items.length - 1)
                      const SizedBox(height: AppTokens.spaceSm),
                  ],
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryAccessTile(
                        item: items[0],
                        palette: palette,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: _SecondaryAccessTile(
                        item: items[1],
                        palette: palette,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryAccessTile(
                        item: items[2],
                        palette: palette,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: _SecondaryAccessTile(
                        item: items[3],
                        palette: palette,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HomeNextUnitTarget {
  final String unitSlug;
  final LearningUnitCompactModel? unit;
  final LearningThemeModel? theme;
  final BkLearningNodeStatus status;
  final UnitProgressLocalModel? progressModel;
  final double progressRatio;
  final int dueSrsCount;
  final String erfeSymbol;

  const _HomeNextUnitTarget({
    required this.unitSlug,
    required this.unit,
    required this.theme,
    required this.status,
    required this.progressModel,
    required this.progressRatio,
    required this.dueSrsCount,
    required this.erfeSymbol,
  });
}

class _NetworkStatusPill extends StatelessWidget {
  final bool online;
  final bool checking;
  final String lang;
  final BkThemePalette palette;
  final VoidCallback onTapOffline;

  const _NetworkStatusPill({
    required this.online,
    required this.checking,
    required this.lang,
    required this.palette,
    required this.onTapOffline,
  });

  @override
  Widget build(BuildContext context) {
    final label = checking
        ? (lang == 'en' ? 'Sync...' : (lang == 'ar' ? '...' : 'Sync...'))
        : (online
            ? (lang == 'en' ? 'Online' : (lang == 'ar' ? 'متصل' : 'En ligne'))
            : (lang == 'en' ? 'Offline' : (lang == 'ar' ? 'دون اتصال' : 'Hors ligne')));

    return Semantics(
      button: !online,
      label: label,
      child: InkWell(
        key: const ValueKey('home-network-status-pill'),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: !online ? onTapOffline : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTokens.minTouchTarget,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                color: online
                    ? palette.statusSuccess.withValues(alpha: 0.55)
                    : palette.accentGold.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  online
                      ? Icons.cloud_done_rounded
                      : Icons.offline_bolt_rounded,
                  size: 16,
                  color: online ? palette.statusSuccess : palette.accentGold,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTrackSwitchButton extends StatelessWidget {
  final Key buttonKey;
  final bool selected;
  final String badge;
  final String title;
  final IconData icon;
  final BkThemePalette palette;
  final VoidCallback onTap;

  const _HomeTrackSwitchButton({
    required this.buttonKey,
    required this.selected,
    required this.badge,
    required this.title,
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? palette.accentGold.withValues(alpha: 0.16)
                    : palette.surfaceElevated.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                border: Border.all(
                  color: selected ? palette.accentGold : palette.border,
                  width: selected ? 1.8 : 1.0,
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
                            color: selected
                                ? palette.accentGold
                                : palette.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryAccessItem {
  final Key itemKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryAccessItem({
    required this.itemKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _SecondaryAccessTile extends StatelessWidget {
  final _SecondaryAccessItem item;
  final BkThemePalette palette;

  const _SecondaryAccessTile({
    required this.item,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title} (${item.subtitle})',
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: item.itemKey,
          borderRadius: BorderRadius.circular(28),
          onTap: item.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: palette.accentGold,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

class _CreationToolItem {
  final Key key;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final VoidCallback onTap;

  const _CreationToolItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.onTap,
  });
}

class _CreationToolTile extends StatelessWidget {
  final _CreationToolItem item;
  final BkThemePalette palette;

  const _CreationToolTile({
    required this.item,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.title} - ${item.subtitle}',
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: item.key,
          borderRadius: BorderRadius.circular(28),
          onTap: item.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.accentGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: palette.accentGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      item.icon,
                      color: palette.accentGold,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.accentGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badge,
                                style: TextStyle(
                                  color: palette.accentGold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: palette.textSecondary.withValues(alpha: 0.6),
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
