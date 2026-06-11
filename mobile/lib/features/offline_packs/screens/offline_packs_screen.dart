import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/lesson_pack_model.dart';
import '../models/local_pack_model.dart';
import '../services/local_pack_reader_service.dart';
import '../services/offline_pack_api_service.dart';
import '../services/offline_pack_download_service.dart';
import 'my_packs_screen.dart';

class OfflinePacksScreen extends StatefulWidget {
  const OfflinePacksScreen({super.key});

  @override
  State<OfflinePacksScreen> createState() => _OfflinePacksScreenState();
}

class _OfflinePacksScreenState extends State<OfflinePacksScreen> {
  final OfflinePackApiService _apiService = OfflinePackApiService();
  final OfflinePackDownloadService _downloadService = OfflinePackDownloadService();
  final LocalPackReaderService _readerService = LocalPackReaderService();

  late Future<_OfflinePacksData> _future;

  final Set<String> _installing = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OfflinePacksData> _load() async {
    final onlinePacks = await _apiService.fetchPacks();
    final installedPacks = await _readerService.listInstalledPacks();

    return _OfflinePacksData(
      onlinePacks: onlinePacks,
      installedPacks: installedPacks,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _downloadPack(LessonPackModel pack) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _installing.add(pack.slug);
    });

    try {
      await _downloadService.downloadAndExtract(pack);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(loc.downloadSuccess)),
      );

      await _reload();
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('${loc.downloadFailed}: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _installing.remove(pack.slug);
        });
      }
    }
  }

  bool _isInstalled(LessonPackModel pack, List<LocalPackModel> installed) {
    return installed.any(
      (local) => local.slug == pack.slug && local.version == pack.version,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.offlinePacks),
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<_OfflinePacksData>(
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

                final data = snapshot.data!;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.offlinePacks,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.offlinePacksSubtitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyPacksScreen(),
                            ),
                          ).then((_) => _reload());
                        },
                        icon: const Icon(Icons.folder_copy_rounded),
                        label: Text(loc.myDownloads),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      loc.installedPacks,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),

                    if (data.installedPacks.isEmpty)
                      GlassCard(
                        child: Text(loc.noPacks),
                      )
                    else
                      for (final local in data.installedPacks) ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                local.titleForLang(lang),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      '${loc.packVersion}: ${local.version}',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      '${loc.packItems}: ${local.itemsCount}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Path: ${local.localPath}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                    const SizedBox(height: 22),
                    Text(
                      loc.availablePacks,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),

                    if (data.onlinePacks.isEmpty)
                      GlassCard(
                        child: Text(loc.noPacks),
                      )
                    else
                      for (final pack in data.onlinePacks) ...[
                        _OnlinePackCard(
                          pack: pack,
                          lang: lang,
                          installed: _isInstalled(pack, data.installedPacks),
                          installing: _installing.contains(pack.slug),
                          onDownload: () => _downloadPack(pack),
                        ),
                        const SizedBox(height: 12),
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

class _OnlinePackCard extends StatelessWidget {
  final LessonPackModel pack;
  final String lang;
  final bool installed;
  final bool installing;
  final VoidCallback onDownload;

  const _OnlinePackCard({
    required this.pack,
    required this.lang,
    required this.installed,
    required this.installing,
    required this.onDownload,
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
          if (pack.descriptionForLang(lang).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(pack.descriptionForLang(lang)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(pack.level)),
              Chip(label: Text('${loc.packVersion}: ${pack.version}')),
              Chip(label: Text('${loc.packItems}: ${pack.itemsCount}')),
              Chip(label: Text('${loc.packSize}: ${pack.sizeMb} MB')),
              if (pack.isFeatured)
                Chip(
                  label: Text(loc.featured),
                  backgroundColor: AppColors.gold.withValues(alpha: 0.20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: installed
                  ? AppColors.gold.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: installed
                    ? AppColors.gold.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              installed ? loc.installedPack : loc.notInstalledPack,
              style: TextStyle(
                color: installed ? AppColors.gold : AppColors.mutedWhite,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: installed || installing || !pack.isDownloadable
                  ? null
                  : onDownload,
              icon: installing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      installed
                          ? Icons.check_circle_rounded
                          : Icons.download_rounded,
                    ),
              label: Text(
                installing
                    ? loc.installing
                    : installed
                        ? loc.downloaded
                        : loc.download,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflinePacksData {
  final List<LessonPackModel> onlinePacks;
  final List<LocalPackModel> installedPacks;

  const _OfflinePacksData({
    required this.onlinePacks,
    required this.installedPacks,
  });
}