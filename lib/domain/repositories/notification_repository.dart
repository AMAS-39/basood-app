import '../../core/utils/pagination.dart';
import '../entities/notification_entity.dart';

class NotificationQuery {
  final bool? isRead;
  final String? orderBy;
  final bool? isAscending;
  final int? page;
  final int? pageSize;

  const NotificationQuery({
    this.isRead,
    this.orderBy,
    this.isAscending,
    this.page,
    this.pageSize,
  });

  Map<String, dynamic> toQueryParameters() {
    return {
      if (isRead != null) 'IsRead': isRead,
      if (orderBy != null && orderBy!.isNotEmpty) 'OrderBy': orderBy,
      if (isAscending != null) 'IsAscending': isAscending,
      if (page != null) 'Page': page,
      if (pageSize != null) 'PageSize': pageSize,
    };
  }
}

abstract class NotificationRepository {
  Future<PaginationResult<NotificationEntity>> listNotifications({
    NotificationQuery? query,
  });

  Future<void> markAsRead(String id);
}
