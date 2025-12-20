import 'package:dio/dio.dart';

typedef RefreshHandler = Future<bool> Function();

class RefreshInterceptor extends Interceptor {
  final RefreshHandler onRefresh;

  RefreshInterceptor(this.onRefresh);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final ok = await onRefresh();
      if (ok) {
        final request = err.requestOptions;
        final dio = err.requestOptions.extra['dio'] as Dio?;
        if (dio != null) {
          try {
            final response = await dio.fetch(request);
            handler.resolve(response);
            return;
          } catch (e) {
            // fallthrough to original error
          }
        }
      }
    }
    handler.next(err);
  }
}
