import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_state.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';

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