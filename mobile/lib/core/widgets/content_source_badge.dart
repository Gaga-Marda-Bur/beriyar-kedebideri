import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../cache/content_source.dart';
import '../theme/app_colors.dart';

class ContentSourceBadge extends StatelessWidget {
  final ContentSourceType source;

  const ContentSourceBadge({
    super.key,
    required this.source,
  });

  String _label(AppLocalizations loc) {
    switch (source) {
      case ContentSourceType.online:
        return loc.sourceOnline;
      case ContentSourceType.memory:
        return loc.sourceMemory;
      case ContentSourceType.localCache:
        return loc.sourceLocalCache;
      case ContentSourceType.offlinePack:
        return loc.sourceOfflinePack;
      case ContentSourceType.empty:
        return loc.sourceEmpty;
    }
  }

  IconData _icon() {
    switch (source) {
      case ContentSourceType.online:
        return Icons.cloud_done_rounded;
      case ContentSourceType.memory:
        return Icons.speed_rounded;
      case ContentSourceType.localCache:
        return Icons.storage_rounded;
      case ContentSourceType.offlinePack:
        return Icons.offline_bolt_rounded;
      case ContentSourceType.empty:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon(),
            size: 16,
            color: AppColors.gold,
          ),
          const SizedBox(width: 6),
          Text(
            '${loc.contentSource}: ${_label(loc)}',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}