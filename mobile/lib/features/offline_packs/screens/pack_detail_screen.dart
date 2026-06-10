import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/local_pack_model.dart';

class PackDetailScreen extends StatefulWidget {
  final LocalPackModel pack;

  const PackDetailScreen({
    super.key,
    required this.pack,
  });

  @override
  State<PackDetailScreen> createState() => _PackDetailScreenState();
}

class _PackDetailScreenState extends State<PackDetailScreen> {
  int _selectedIndex = 0;

  List<_PackTab> _tabs(AppLocalizations loc) {
    return [
      _PackTab(loc.themes, Icons.category_rounded, widget.pack.themes),
      _PackTab(loc.units, Icons.school_rounded, widget.pack.units),
      _PackTab(loc.characters, Icons.text_fields_rounded, widget.pack.characters),
      _PackTab(loc.words, Icons.menu_book_rounded, widget.pack.words),
      _PackTab(loc.lessons, Icons.play_lesson_rounded, widget.pack.lessons),
      _PackTab(loc.quizzes, Icons.quiz_rounded, widget.pack.quizzes),
    ];
  }

  String _localizedTitle(Map<String, dynamic> item, String lang) {
    if (lang == 'ar') {
      return item['title_ar']?.toString() ??
          item['name']?.toString() ??
          item['slug']?.toString() ??
          '';
    }

    if (lang == 'en') {
      return item['title_en']?.toString() ??
          item['name']?.toString() ??
          item['slug']?.toString() ??
          '';
    }

    return item['title_fr']?.toString() ??
        item['name']?.toString() ??
        item['slug']?.toString() ??
        item['beriya_text']?.toString() ??
        item['symbol']?.toString() ??
        '';
  }

  String _subtitle(Map<String, dynamic> item, String lang) {
    if (item['latin_transcription'] != null) {
      return item['latin_transcription'].toString();
    }

    if (item['french_translation'] != null && lang == 'fr') {
      return item['french_translation'].toString();
    }

    if (item['english_translation'] != null && lang == 'en') {
      return item['english_translation'].toString();
    }

    if (item['arabic_translation'] != null && lang == 'ar') {
      return item['arabic_translation'].toString();
    }

    if (item['slug'] != null) {
      return item['slug'].toString();
    }

    if (item['question_type'] != null) {
      return item['question_type'].toString();
    }

    return 'ID: ${item['id'] ?? '-'}';
  }

  bool _looksBeriya(Map<String, dynamic> item) {
    return item.containsKey('symbol') || item.containsKey('beriya_text');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final tabs = _tabs(loc);
    final current = tabs[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.titleForLang(lang)),
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
                      loc.packContent,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text('${loc.packVersion}: ${widget.pack.version}'),
                    Text('${loc.packItems}: ${widget.pack.itemsCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = index == _selectedIndex;

                    return ChoiceChip(
                      selected: selected,
                      avatar: Icon(tab.icon, size: 18),
                      label: Text('${tab.title} (${tab.items.length})'),
                      onSelected: (_) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (current.items.isEmpty)
                GlassCard(
                  child: Text(loc.noPacks),
                )
              else
                for (final raw in current.items) ...[
                  if (raw is Map<String, dynamic>)
                    _PackItemCard(
                      title: _localizedTitle(raw, lang),
                      subtitle: _subtitle(raw, lang),
                      isBeriya: _looksBeriya(raw),
                      raw: raw,
                    ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PackItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isBeriya;
  final Map<String, dynamic> raw;

  const _PackItemCard({
    required this.title,
    required this.subtitle,
    required this.isBeriya,
    required this.raw,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.isEmpty ? 'ID: ${raw['id'] ?? '-'}' : title;

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              raw['symbol']?.toString() ??
                  raw['beriya_text']?.toString() ??
                  '#',
              style: isBeriya
                  ? AppTextStyles.beriyaSmall.copyWith(fontSize: 26)
                  : const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: isBeriya
                      ? AppTextStyles.beriyaSmall.copyWith(fontSize: 24)
                      : const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTab {
  final String title;
  final IconData icon;
  final List<dynamic> items;

  const _PackTab(
    this.title,
    this.icon,
    this.items,
  );
}