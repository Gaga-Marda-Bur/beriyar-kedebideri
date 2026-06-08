import '../../features/progress/services/unit_progress_local_storage.dart';
import '../../features/progress/services/unit_progress_sync_service.dart';

class SyncSummary {
  final bool success;
  final int progressSyncedCount;
  final int errorCount;
  final String? errorMessage;

  const SyncSummary({
    required this.success,
    required this.progressSyncedCount,
    required this.errorCount,
    required this.errorMessage,
  });
}

class SyncManager {
  final UnitProgressLocalStorage _progressStorage;
  final UnitProgressSyncService _progressSyncService;

  SyncManager({
    UnitProgressLocalStorage? progressStorage,
    UnitProgressSyncService? progressSyncService,
  })  : _progressStorage = progressStorage ?? UnitProgressLocalStorage(),
        _progressSyncService = progressSyncService ?? UnitProgressSyncService();

  Future<SyncSummary> syncAll() async {
    try {
      final allProgress = await _progressStorage.getAllProgress();
      final result = await _progressSyncService.syncProgressList(allProgress);

      return SyncSummary(
        success: result.errorCount == 0,
        progressSyncedCount: result.syncedCount,
        errorCount: result.errorCount,
        errorMessage: result.errorCount == 0 ? null : result.errors.toString(),
      );
    } catch (error) {
      return SyncSummary(
        success: false,
        progressSyncedCount: 0,
        errorCount: 1,
        errorMessage: error.toString(),
      );
    }
  }
}