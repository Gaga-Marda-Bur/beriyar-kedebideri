import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/api/backend_bootstrap_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => context.read<AppState>().checkBackend(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Center(
                        child: Text(
                          'BK',
                          style: TextStyle(
                            color: AppColors.night,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.appName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            loc.appTagline,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  loc.welcomeTitle,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 24),
                const GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '𖺠 𖺡 𖺢 𖺣 𖺤',
                        style: AppTextStyles.beriyaLarge,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Test affichage Beriya Erfe',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.welcomeSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 26),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.backendStatus,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            state.isBackendConnected
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: state.isBackendConnected
                                ? AppColors.gold
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            state.isCheckingBackend
                                ? '...'
                                : state.isBackendConnected
                                    ? loc.connected
                                    : loc.notConnected,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: state.isCheckingBackend
                            ? null
                            : () => context.read<AppState>().checkBackend(),
                        child: Text(loc.retry),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/alphabet'),
                  icon: const Icon(Icons.abc_rounded),
                  label: Text(loc.alphabet),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/vocabulary'),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(loc.vocabulary),
                ),
                const SizedBox(height: 20),
                FutureBuilder<BackendBootstrapSummary>(
                  future: BackendBootstrapService().loadSummary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const GlassCard(
                        child: Text('Chargement du contenu Django...'),
                      );
                    }

                    if (snapshot.hasError) {
                      return GlassCard(
                        child: Text(
                          'Erreur chargement contenu: ${snapshot.error}',
                        ),
                      );
                    }

                    final summary = snapshot.data;

                    if (summary == null) {
                      return const GlassCard(
                        child: Text('Aucune donnée chargée.'),
                      );
                    }

                    return GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contenu Django',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text('Caractères: ${summary.charactersCount}'),
                          Text('Mots: ${summary.wordsCount}'),
                          Text('Thèmes: ${summary.themesCount}'),
                          Text('Unités: ${summary.unitsCount}'),
                          Text('Leçons: ${summary.lessonsCount}'),
                          Text('Quiz: ${summary.quizzesCount}'),
                          Text('No Ena: ${summary.noEnaCount}'),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(loc.startLearning),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}