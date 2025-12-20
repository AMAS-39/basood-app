import '../../../core/utils/pagination.dart';
import '../../../domain/entities/notification_entity.dart';
import '../../../domain/repositories/notification_repository.dart';

class ListNotificationsUC {
  final NotificationRepository repository;
  ListNotificationsUC(this.repository);

  Future<PaginationResult<NotificationEntity>> call({
    NotificationQuery? query,
  }) {
    return repository.listNotifications(query: query);
  }
}
