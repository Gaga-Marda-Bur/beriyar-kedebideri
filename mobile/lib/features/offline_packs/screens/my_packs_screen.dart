import 'package:flutter/material.dart';

import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/local_pack_model.dart';
import '../services/local_pack_reader_service.dart';
import 'pack_detail_screen.dart';
import '../../../core/cache/memory_content_cache.dart';
import '../../../core/cache/content_source.dart';
import '../../../core/theme/app_colors.dart';

class MyPacksScreen extends StatefulWidget {
  const MyPacksScreen({super.key});

  @override
  State<MyPacksScreen> createState() => _MyPacksScreenState();
}

class _MyPacksScreenState extends State<MyPacksScreen> {
  final LocalPackReaderService _readerService = LocalPackReaderService();

  late Future<List<LocalPackModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _readerService.listInstalledPacks();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _readerService.listInstalledPacks();
    });
  }

  Future<void> _deletePack(LocalPackModel pack) async {
    final loc = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.deletePack),
          content: Text(loc.deletePackConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.deletePack),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _readerService.deletePack(
      slug: pack.slug,
      version: pack.version,
    );
    MemoryContentCache.instance.clear();
    ContentSourceState.instance.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.packDeleted)),
    );

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myDownloads),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<LocalPackModel>>(
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
                            const SizedBox(height: 8),
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

                final packs = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.myDownloads,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(loc.myDownloadsSubtitle),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(loc.cacheAndPackNotice),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (packs.isEmpty)
                      GlassCard(
                        child: Text(loc.noPacks),
                      )
                    else
                      for (final pack in packs) ...[
                        _InstalledPackCard(
                          pack: pack,
                          lang: lang,
                          onOpen: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PackDetailScreen(pack: pack),
                              ),
                            ).then((_) => _reload());
                          },
                          onDelete: () => _deletePack(pack),
                        ),
                        const SizedBox(height: 14),
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

class _InstalledPackCard extends StatelessWidget {
  final LocalPackModel pack;
  final String lang;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _InstalledPackCard({
    required this.pack,
    required this.lang,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pack.titleForLang(lang),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${loc.packVersion}: ${pack.version}')),
              Chip(label: Text('${loc.packItems}: ${pack.itemsCount}')),
              Chip(label: Text('${loc.characters}: ${pack.characters.length}')),
              Chip(label: Text('${loc.words}: ${pack.words.length}')),
              Chip(label: Text('${loc.lessons}: ${pack.lessons.length}')),
              Chip(label: Text('${loc.quizzes}: ${pack.quizzes.length}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.storage_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${loc.packSize}: ${pack.formattedSize}'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${loc.downloadDate}: ${pack.formattedDownloadedAt}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${loc.localPath}: ${pack.localPath}',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(loc.openPack),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded),
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}