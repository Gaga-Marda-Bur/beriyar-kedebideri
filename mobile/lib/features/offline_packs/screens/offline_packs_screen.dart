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
import 'pack_detail_screen.dart';
import '../../../core/utils/app_logger.dart';

class OfflinePacksScreen extends StatefulWidget {
  final OfflinePackApiService? apiService;
  final OfflinePackDownloadService? downloadService;
  final LocalPackReaderService? readerService;

  const OfflinePacksScreen({
    super.key,
    this.apiService,
    this.downloadService,
    this.readerService,
  });

  @override
  State<OfflinePacksScreen> createState() => _OfflinePacksScreenState();
}

class _OfflinePacksScreenState extends State<OfflinePacksScreen> {
  late final OfflinePackApiService _apiService;
  late final OfflinePackDownloadService _downloadService;
  late final LocalPackReaderService _readerService;

  late Future<_OfflinePacksData> _future;

  final Set<String> _installing = {};

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? OfflinePackApiService();
    _downloadService =
        widget.downloadService ?? OfflinePackDownloadService();
    _readerService = widget.readerService ?? LocalPackReaderService();
    _future = _load();
  }

  Future<_OfflinePacksData> _load() async {
    List<LocalPackModel> installedPacks = [];
    try {
      installedPacks = await _readerService.listInstalledPacks();
    } catch (error) {
      AppLogger.warning('Failed to list installed packs: $error');
    }

    List<LessonPackModel> onlinePacks = [];
    bool isOffline = false;
    Object? onlineError;

    try {
      onlinePacks = await _apiService.fetchPacks();
    } catch (error) {
      isOffline = true;
      onlineError = error;
      AppLogger.warning('API fetchPacks failed (offline or unreachable): $error');
    }

    return _OfflinePacksData(
      onlinePacks: onlinePacks,
      installedPacks: installedPacks,
      isOffline: isOffline,
      onlineError: onlineError,
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.download_for_offline_outlined,
                              color: AppColors.gold,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.noPacks,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data.isOffline
                                        ? 'Connectez-vous à Internet pour télécharger des packs et apprendre hors ligne.'
                                        : 'Téléchargez un pack ci-dessous pour y accéder sans connexion Internet.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final local in data.installedPacks) ...[
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      local.titleForLang(lang),
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Text(
                                      loc.installedPack,
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
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
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.visibility_rounded,
                                      size: 16,
                                    ),
                                    label: Text(loc.openPack),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PackDetailScreen(pack: local),
                                        ),
                                      ).then((_) => _reload());
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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

                    if (data.isOffline)
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wifi_off_rounded, color: AppColors.gold),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Mode hors ligne — catalogue en ligne indisponible',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Les packs déjà installés ci-dessus restent pleinement utilisables sans connexion.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.tonalIcon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(loc.retry),
                            ),
                          ],
                        ),
                      )
                    else if (data.onlinePacks.isEmpty)
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
  final bool isOffline;
  final Object? onlineError;

  const _OfflinePacksData({
    required this.onlinePacks,
    required this.installedPacks,
    this.isOffline = false,
    this.onlineError,
  });
}
