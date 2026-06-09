import 'package:flutter/material.dart';

import '../../../core/audio/audio_url_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/no_ena_publication_model.dart';
import '../no_ena_api_service.dart';
import '../../../core/widgets/smart_image.dart';

class NoEnaDetailScreen extends StatefulWidget {
  final NoEnaPublicationModel publication;

  const NoEnaDetailScreen({
    super.key,
    required this.publication,
  });

  @override
  State<NoEnaDetailScreen> createState() => _NoEnaDetailScreenState();
}

class _NoEnaDetailScreenState extends State<NoEnaDetailScreen> {
  final NoEnaApiService _service = NoEnaApiService();
  final AudioUrlPlayer _audioPlayer = AudioUrlPlayer();

  int? _viewCount;

  @override
  void initState() {
    super.initState();
    _viewCount = widget.publication.viewCount;
    _increaseViewCount();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _increaseViewCount() async {
    try {
      await _service.increaseViewCount(widget.publication.slug);

      if (!mounted) return;

      setState(() {
        _viewCount = (_viewCount ?? widget.publication.viewCount) + 1;
      });
    } catch (_) {
      // On ignore en silence : le contenu reste visible même si compteur échoue.
    }
  }

  String _localized(String lang, String fr, String en, String ar) {
    if (lang == 'ar' && ar.isNotEmpty) return ar;
    if (lang == 'en' && en.isNotEmpty) return en;
    return fr.isNotEmpty ? fr : en;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final item = widget.publication;

    final title = _localized(
      lang,
      item.titleFr,
      item.titleEn,
      item.titleAr,
    );

    final caption = _localized(
      lang,
      item.captionFr,
      item.captionEn,
      item.captionAr,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.noEna),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _DetailMediaFrame(item: item),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(item.publicationType)),
                        if (item.isFeatured) Chip(label: Text(loc.featured)),
                        if (item.cultureTheme.isNotEmpty)
                          Chip(label: Text(item.cultureTheme)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (item.beriyaTitle.isNotEmpty) ...[
                      Text(
                        item.beriyaTitle,
                        style: AppTextStyles.beriyaMedium,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if (item.beriyaCaption.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        item.beriyaCaption,
                        style: AppTextStyles.beriyaSmall,
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (item.hasAudio)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _audioPlayer.playUrl(item.audioUrl),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text(loc.playAudio),
                        ),
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
                      loc.relatedContent,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.visibility_rounded,
                      label: loc.views,
                      value: '${_viewCount ?? item.viewCount}',
                    ),
                    if (item.contributorName.isNotEmpty)
                      _InfoRow(
                        icon: Icons.person_rounded,
                        label: loc.contributor,
                        value: item.contributorName,
                      ),
                    if (item.cultureTheme.isNotEmpty)
                      _InfoRow(
                        icon: Icons.auto_awesome_rounded,
                        label: loc.cultureTheme,
                        value: item.cultureTheme,
                      ),
                    if (item.relatedCharacterSymbol.isNotEmpty)
                      _InfoRow(
                        icon: Icons.text_fields_rounded,
                        label: loc.relatedCharacter,
                        value: item.relatedCharacterSymbol,
                        useBeriyaFont: true,
                      ),
                    if (item.relatedWordText.isNotEmpty)
                      _InfoRow(
                        icon: Icons.menu_book_rounded,
                        label: loc.relatedWord,
                        value: item.relatedWordText,
                        useBeriyaFont: true,
                      ),
                    if (item.relatedUnitSlug.isNotEmpty)
                      _InfoRow(
                        icon: Icons.school_rounded,
                        label: loc.relatedUnit,
                        value: item.relatedUnitSlug,
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

class _DetailMediaFrame extends StatelessWidget {
  final NoEnaPublicationModel item;

  const _DetailMediaFrame({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl ?? item.thumbnailUrl;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Container(
          height: 360,
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                SmartImage(
                path: imageUrl,
                fit: BoxFit.cover,
                fallback: const _NoEnaLargeFallback(),
              )
              else
                const _NoEnaLargeFallback(),
              if (item.hasVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Video',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoEnaLargeFallback extends StatelessWidget {
  const _NoEnaLargeFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 72,
        color: AppColors.gold,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool useBeriyaFont;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.useBeriyaFont = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: useBeriyaFont
                        ? AppTextStyles.beriyaSmall.copyWith(fontSize: 22)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}