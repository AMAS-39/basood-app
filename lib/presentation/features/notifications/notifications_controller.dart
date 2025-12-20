import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../../domain/entities/notification_entity.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../providers/use_case_providers.dart';

class NotificationsState {
  final bool isLoading;
  final List<NotificationEntity> notifications;
  final bool hasMore;
  final int page;
  final String? error;

  const NotificationsState({
    this.isLoading = false,
    this.notifications = const [],
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  NotificationsState copyWith({
    bool? isLoading,
    List<NotificationEntity>? notifications,
    bool? hasMore,
    int? page,
    String? error,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  static const _pageSize = 20;

  final Ref ref;
  NotificationsNotifier(this.ref) : super(const NotificationsState()) {
    fetchNotifications(refresh: true);
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    final nextPage = refresh ? 1 : state.page;
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null, page: nextPage);

    try {
      final query = NotificationQuery(
        page: nextPage,
        pageSize: _pageSize,
        orderBy: 'CreatedAt',
        isAscending: false,
      );
      final result = await ref
          .read(listNotificationsUCProvider)
          .call(query: query);

      state = state.copyWith(
        isLoading: false,
        notifications: refresh
            ? result.items
            : [...state.notifications, ...result.items],
        hasMore: result.hasMore,
        page: refresh ? 2 : state.page + 1,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await ref.read(markNotificationReadUCProvider).call(id);
      final updated = state.notifications.map<NotificationEntity>((
        notification,
      ) {
        if (notification.id == id) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {
      // ignore
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
      return NotificationsNotifier(ref);
    });
