import 'dart:async';

import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../data/dto/api_dto.dart';

/// Event item in the offline queue.
class OfflineQueueItem {
  const OfflineQueueItem({
    required this.idempotencyKey,
    required this.entityType,
    required this.payload,
    required this.occurredAt,
  });

  final String idempotencyKey;
  final String entityType;
  final Map<String, dynamic> payload;
  final DateTime occurredAt;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'entity_type': entityType,
        'payload': payload,
        'occurred_at': occurredAt.toIso8601String(),
      };
}

/// Offline sync manager buffering critical safety events when connectivity is lost.
class OfflineSyncManager {
  OfflineSyncManager({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  final List<OfflineQueueItem> _queue = [];
  bool _isSyncing = false;

  int get pendingCount => _queue.length;

  /// Enqueue an event for guaranteed sync.
  void enqueueEvent({
    required String idempotencyKey,
    required String entityType,
    required Map<String, dynamic> payload,
  }) {
    _queue.add(
      OfflineQueueItem(
        idempotencyKey: idempotencyKey,
        entityType: entityType,
        payload: payload,
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Flush the queue to the FastAPI backend.
  Future<int> flushQueue() async {
    if (_queue.isEmpty || _isSyncing) return 0;
    _isSyncing = true;

    final batch = List<OfflineQueueItem>.from(_queue);
    try {
      final request = OfflineBatchSyncRequest(
        events: batch
            .map((item) => SyncEventItem(
                  idempotencyKey: item.idempotencyKey,
                  entityType: item.entityType,
                  payload: item.payload,
                  occurredAt: item.occurredAt.toIso8601String(),
                ))
            .toList(),
      );

      final response = await _api.post(
        ApiConstants.syncEvents,
        body: request.toJson(),
      );

      final syncedCount = response['synced_count'] as int? ?? batch.length;
      _queue.removeWhere((item) => batch.contains(item));
      return syncedCount;
    } catch (_) {
      return 0;
    } finally {
      _isSyncing = false;
    }
  }
}
