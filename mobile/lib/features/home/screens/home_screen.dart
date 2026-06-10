import 'package:flutter/material.dart';

import '../../../core/network/backend_status_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../content_hub/screens/content_hub_screen.dart';
import '../../progress/models/unit_progress_local_model.dart';
import '../../progress/services/unit_progress_local_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BackendStatusService _backendStatusService = BackendStatusService();
  final UnitProgressLocalStorage _progressStorage = UnitProgressLocalStorage();

  late Future<bool> _backendFuture;
  late Future<List<UnitProgressLocalModel>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _backendFuture = _backendStatusService.isBackendReachable();
    _progressFuture = _progressStorage.getAllProgress();
  }

  Future<void> _reload() async {
    BackendStatusService.resetCache();

    setState(() {
      _backendFuture = _backendStatusService.isBackendReachable();
      _progressFuture = _progressStorage.getAllProgress();
    });
  }

  void _openRoute(String route) {
    Navigator.pushNamed(context, route).then((_) => _reload());
  }

  void _openHub() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ContentHubScreen(),
      ),
    ).then((_) => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _HeroHomeCard(
                  title: loc.welcomeHome,
                  subtitle: loc.homeSubtitle,
                  onStart: _openHub,
                ),
                const SizedBox(height: 18),
                FutureBuilder<bool>(
                  future: _backendFuture,
                  builder: (context, snapshot) {
                    final online = snapshot.data == true;

                    return _ConnectionStatusCard(
                      online: online,
                      loading: snapshot.connectionState ==
                          ConnectionState.waiting,
                    );
                  },
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<UnitProgressLocalModel>>(
                  future: _progressFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];

                    return _RecentProgressCard(
                      progress: items.isEmpty ? null : items.first,
                      onContinue: () {
                        if (items.isEmpty) {
                          _openRoute('/content');
                          return;
                        }

                        Navigator.pushNamed(
                          context,
                          '/unit-practice',
                          arguments: items.first.unitSlug,
                        ).then((_) => _reload());
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  loc.quickAccess,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                ),
                const SizedBox(height: 12),
                _QuickAccessGrid(
                  lang: lang,
                  onOpenRoute: _openRoute,
                  onOpenHub: _openHub,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onStart;

  const _HeroHomeCard({
    required this.title,
    required this.subtitle,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.95),
                    AppColors.gold.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.28),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.night,
                size: 50,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.hub_rounded),
              label: Text(loc.startLearning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final bool online;
  final bool loading;

  const _ConnectionStatusCard({
    required this.online,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final title = online ? loc.onlineMode : loc.offlineMode;
    final subtitle =
        online ? loc.onlineModeSubtitle : loc.offlineModeSubtitle;

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
              ),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    online
                        ? Icons.cloud_done_rounded
                        : Icons.offline_bolt_rounded,
                    color: AppColors.gold,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.connectionStatus,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentProgressCard extends StatelessWidget {
  final UnitProgressLocalModel? progress;
  final VoidCallback onContinue;

  const _RecentProgressCard({
    required this.progress,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (progress == null) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.recentProgress,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(loc.noRecentProgress),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(loc.startLearning),
            ),
          ],
        ),
      );
    }

    final totalSteps = progress!.totalSteps <= 0 ? 1 : progress!.totalSteps;
    final ratio = (progress!.currentStep / totalSteps).clamp(0.0, 1.0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.recentProgress,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            progress!.unitSlug,
            style: AppTextStyles.beriyaSmall.copyWith(
              color: AppColors.gold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text(
            '${progress!.currentStep}/${progress!.totalSteps} • ${progress!.bestScorePercent.round()}%',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(loc.continueLearning),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final String lang;
  final void Function(String route) onOpenRoute;
  final VoidCallback onOpenHub;

  const _QuickAccessGrid({
    required this.lang,
    required this.onOpenRoute,
    required this.onOpenHub,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 720 ? 4 : 2;

    final items = [
      _QuickAccessItem(
        title: loc.contentHub,
        icon: Icons.hub_rounded,
        onTap: onOpenHub,
      ),
      _QuickAccessItem(
        title: loc.alphabetShort,
        icon: Icons.text_fields_rounded,
        onTap: () => onOpenRoute('/alphabet'),
      ),
      _QuickAccessItem(
        title: loc.vocabularyShort,
        icon: Icons.menu_book_rounded,
        onTap: () => onOpenRoute('/vocabulary'),
      ),
      _QuickAccessItem(
        title: loc.settings,
        icon: Icons.settings_rounded,
        onTap: () => onOpenRoute('/settings'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: width >= 720 ? 1.45 : 1.15,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return GlassCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    color: AppColors.gold,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickAccessItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}