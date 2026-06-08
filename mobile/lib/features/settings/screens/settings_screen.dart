import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/sync/sync_manager.dart';

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
    return RadioListTile<String>(
      value: code,
      groupValue: context.watch<AppState>().locale.languageCode,
      onChanged: (value) {
        if (value != null) {
          context.read<AppState>().setLocale(value);
        }
      },
      title: Text(title),
      selected: selected,
    );
  }
}