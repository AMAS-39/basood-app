import '../../core/utils/pagination.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_ds.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDS ds;
  NotificationRepositoryImpl(this.ds);

  NotificationEntity _mapNotification(Map<String, dynamic> json) {
    final createdValue =
        json['createdAt'] ??
        json['createdDate'] ??
        json['timestamp'] ??
        json['date'];
    final rawIsRead =
        json['isRead'] ?? json['read'] ?? json['is_read'] ?? json['status'];

    return NotificationEntity(
      id: json['id']?.toString() ?? '',
      title:
          json['title']?.toString() ??
          json['subject']?.toString() ??
          'Notification',
      message:
          json['message']?.toString() ??
          json['body']?.toString() ??
          json['content']?.toString() ??
          '',
      isRead: _parseBool(rawIsRead),
      createdAt:
          DateTime.tryParse(createdValue?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'read';
    }
    return false;
  }

  bool _resolveHasMore(Map<String, dynamic> data) {
    final hasMore = data['hasMore'];
    if (hasMore is bool) return hasMore;

    final pageIndex = data['page'] ?? data['pageNumber'];
    final totalPages = data['totalPages'] ?? data['pagesCount'];
    if (pageIndex != null && totalPages != null) {
      final current = int.tryParse(pageIndex.toString()) ?? 0;
      final total = int.tryParse(totalPages.toString()) ?? 0;
      return current < total;
    }

    final pageSize = data['pageSize'] ?? data['limit'];
    final totalCount = data['totalCount'] ?? data['total'];
    if (pageIndex != null && pageSize != null && totalCount != null) {
      final current = int.tryParse(pageIndex.toString()) ?? 1;
      final size = int.tryParse(pageSize.toString()) ?? 0;
      final total = int.tryParse(totalCount.toString()) ?? 0;
      return current * size < total;
    }

    final nextCursor = data['nextCursor'] ?? data['next'];
    return nextCursor != null;
  }

  List<Map<String, dynamic>> _extractItems(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .cast<Map<String, dynamic>>()
          .toList();
    }

    if (data is Map) {
      final mapData = data.cast<String, dynamic>();
      final candidates = [
        mapData['items'],
        mapData['data'],
        mapData['results'],
        mapData['list'],
      ];

      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate
              .whereType<Map>()
              .map(
                (e) => e.map((key, value) => MapEntry(key.toString(), value)),
              )
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }
    }

    return const [];
  }

  @override
  Future<PaginationResult<NotificationEntity>> listNotifications({
    NotificationQuery? query,
  }) async {
    final response = await ds.listNotifications(
      query: query?.toQueryParameters(),
    );
    final data = response.data;

    final items = _extractItems(data);
    bool hasMore = false;
    String? nextCursor;

    if (data is Map<String, dynamic>) {
      hasMore = _resolveHasMore(data);
      final next = data['nextCursor'] ?? data['next'];
      if (next != null) {
        nextCursor = next.toString();
      }
    }

    return PaginationResult(
      items: items.map(_mapNotification).toList(),
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    await ds.markAsRead(id);
  }
}
