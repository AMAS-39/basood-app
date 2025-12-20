import 'package:dio/dio.dart';

import '../../core/config/api_endpoints.dart';

class NotificationRemoteDS {
  final Dio dio;
  NotificationRemoteDS(this.dio);

  Future<Response> listNotifications({Map<String, dynamic>? query}) {
    return dio.get(BasoodEndpoints.notification.getAll, queryParameters: query);
  }

  Future<Response> markAsRead(String id) {
    return dio.put(BasoodEndpoints.notification.markAsRead(id));
  }
}
