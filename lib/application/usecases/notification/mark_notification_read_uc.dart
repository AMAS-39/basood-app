import '../../../domain/repositories/notification_repository.dart';

class MarkNotificationReadUC {
  final NotificationRepository repository;
  MarkNotificationReadUC(this.repository);

  Future<void> call(String id) {
    return repository.markAsRead(id);
  }
}
