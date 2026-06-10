import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../learning/screens/learning_path_screen.dart';
import '../../no_ena/screens/no_ena_screen.dart';
import '../../offline_packs/screens/my_packs_screen.dart';
import '../../offline_packs/screens/offline_packs_screen.dart';
import '../../quiz/screens/quiz_screen.dart';

class ContentHubScreen extends StatelessWidget {
  const ContentHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 720;

    final items = [
      _HubItem(
        title: loc.learnPath,
        subtitle: loc.learnPathSubtitle,
        icon: Icons.school_rounded,
        gradientIcon: Icons.auto_stories_rounded,
        onTap: () => _open(context, const LearningPathScreen()),
      ),
      _HubItem(
        title: loc.quiz,
        subtitle: loc.quizHubSubtitle,
        icon: Icons.quiz_rounded,
        gradientIcon: Icons.psychology_alt_rounded,
        onTap: () => _open(context, const QuizScreen()),
      ),
      _HubItem(
        title: loc.noEna,
        subtitle: loc.noEnaHubSubtitle,
        icon: Icons.auto_awesome_rounded,
        gradientIcon: Icons.play_circle_rounded,
        onTap: () => _open(context, const NoEnaScreen()),
      ),
      _HubItem(
        title: loc.offlinePacks,
        subtitle: loc.offlinePacksHubSubtitle,
        icon: Icons.download_for_offline_rounded,
        gradientIcon: Icons.cloud_download_rounded,
        onTap: () => _open(context, const OfflinePacksScreen()),
      ),
      _HubItem(
        title: loc.myDownloads,
        subtitle: loc.myDownloadsHubSubtitle,
        icon: Icons.folder_copy_rounded,
        gradientIcon: Icons.folder_open_rounded,
        onTap: () => _open(context, const MyPacksScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.contentHub),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroIcon(),
                    const SizedBox(height: 18),
                    Text(
                      loc.contentHub,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.contentHubSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isWide)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.55,
                  ),
                  itemBuilder: (context, index) {
                    return _HubCard(item: items[index]);
                  },
                )
              else
                for (final item in items) ...[
                  _HubCard(item: item),
                  const SizedBox(height: 16),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Icon(
        Icons.hub_rounded,
        color: AppColors.night,
        size: 42,
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final _HubItem item;

  const _HubCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                AppColors.gold.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      item.gradientIcon,
                      color: AppColors.gold.withValues(alpha: 0.18),
                      size: 44,
                    ),
                  ),
                  Icon(
                    item.icon,
                    color: AppColors.gold,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          loc.open,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.gold,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData gradientIcon;
  final VoidCallback onTap;

  const _HubItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientIcon,
    required this.onTap,
  });
}