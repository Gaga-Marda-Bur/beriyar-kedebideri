import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/no_ena_publication_model.dart';
import 'no_ena_detail_screen.dart';
import '../../../core/widgets/smart_image.dart';
import '../../../core/cache/cached_content_service.dart';
import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/widgets/content_source_badge.dart';

class NoEnaScreen extends StatefulWidget {
  const NoEnaScreen({super.key});

  @override
  State<NoEnaScreen> createState() => _NoEnaScreenState();
}

class _NoEnaScreenState extends State<NoEnaScreen> {
  final CachedContentService _cachedContentService = CachedContentService();
  late Future<List<NoEnaPublicationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cachedContentService.loadNoEna();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _cachedContentService.loadNoEna();
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.noEna),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<NoEnaPublicationModel>>(
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
                              source: ContentSourceState.instance.getSource(CacheKeys.noEna),
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

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      GlassCard(child: Text(loc.noNoEna)),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.noEna,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.noEnaSubtitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final item in items) ...[
                      _NoEnaCard(
                        item: item,
                        title: _localized(
                          lang,
                          item.titleFr,
                          item.titleEn,
                          item.titleAr,
                        ),
                        caption: _localized(
                          lang,
                          item.captionFr,
                          item.captionEn,
                          item.captionAr,
                        ),
                        openLabel: loc.openContent,
                        featuredLabel: loc.featured,
                        viewsLabel: loc.views,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoEnaDetailScreen(
                                publication: item,
                              ),
                            ),
                          ).then((_) => _reload());
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NoEnaCard extends StatelessWidget {
  final NoEnaPublicationModel item;
  final String title;
  final String caption;
  final String openLabel;
  final String featuredLabel;
  final String viewsLabel;
  final VoidCallback onTap;

  const _NoEnaCard({
    required this.item,
    required this.title,
    required this.caption,
    required this.openLabel,
    required this.featuredLabel,
    required this.viewsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NoEnaMediaPreview(item: item),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(item.publicationType)),
                      if (item.isFeatured)
                        Chip(
                          label: Text(featuredLabel),
                          backgroundColor: AppColors.gold.withValues(alpha: 0.20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (item.beriyaTitle.isNotEmpty) ...[
                    Text(
                      item.beriyaTitle,
                      style: AppTextStyles.beriyaSmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (caption.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Text('$viewsLabel: ${item.viewCount}'),
                      const Spacer(),
                      FilledButton(
                        onPressed: onTap,
                        child: Text(openLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEnaMediaPreview extends StatelessWidget {
  final NoEnaPublicationModel item;

  const _NoEnaMediaPreview({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.thumbnailUrl ?? item.imageUrl;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(28),
      ),
      child: Container(
        height: 220,
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              SmartImage(
                path: imageUrl,
                fit: BoxFit.cover,
                fallback: const _NoEnaFallbackIcon(),
              )
            else
              const _NoEnaFallbackIcon(),
            if (item.hasVideo)
              Center(
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.gold,
                    size: 42,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoEnaFallbackIcon extends StatelessWidget {
  const _NoEnaFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.auto_awesome_rounded,
        color: AppColors.gold,
        size: 54,
      ),
    );
  }
}