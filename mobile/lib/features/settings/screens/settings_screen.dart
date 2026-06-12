import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/cache/online_content_cache_service.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/backend_status_service.dart';
import '../../../core/cache/memory_content_cache.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/api/api_config.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
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
                    Text(
                      loc.language,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _LanguageTile(
                      title: loc.french,
                      code: 'fr',
                      selected: state.locale.languageCode == 'fr',
                    ),
                    _LanguageTile(
                      title: loc.english,
                      code: 'en',
                      selected: state.locale.languageCode == 'en',
                    ),
                    _LanguageTile(
                      title: loc.arabic,
                      code: 'ar',
                      selected: state.locale.languageCode == 'ar',
                    ),
                  ],
                ),
              ),
              if (AppEnvironment.showDevTools) ...[
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dev tools',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text('Flavor: ${AppEnvironment.flavor.name}'),
                      const SizedBox(height: 8),
                      Text('API flavor: ${ApiConfig.flavorName}'),
                      const SizedBox(height: 8),
                      Text('API base URL: ${ApiConfig.baseUrl}'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          BackendStatusService.resetCache();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Backend status cache reset'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reset backend cache'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.sync,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'UnitProgressLocalModel → Django UnitProgress',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);

                          final result = await SyncManager().syncAll();

                          if (!context.mounted) return;

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? '${loc.syncSuccess} • ${loc.syncedItems}: ${result.progressSyncedCount}'
                                    : '${loc.syncFailed}: ${result.errorMessage ?? ''}',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(loc.syncNow),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await OnlineContentCacheService().clearAll();
                          MemoryContentCache.instance.clear();
                          ContentSourceState.instance.clear();

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(loc.cacheCleared),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: Text(loc.clearCache),
                      ),
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

class _LanguageTile extends StatelessWidget {
  final String title;
  final String code;
  final bool selected;

  const _LanguageTile({
    required this.title,
    required this.code,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.read<AppState>().setLocale(code),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}