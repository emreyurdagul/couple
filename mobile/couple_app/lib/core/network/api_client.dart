import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../features/auth/state/auth_controller.dart';

/// Auth gerektirmeyen istekler (login/register/refresh).
final rawApiClientProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.httpConnectTimeout,
    receiveTimeout: AppConfig.httpReceiveTimeout,
    contentType: 'application/json',
  ));
});

/// Tüm authorize edilmiş istekler. Access token'ı otomatik ekler;
/// 401 alınca tek seferlik refresh dener, başarılıysa isteği tekrar oynatır.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: AppConfig.httpConnectTimeout,
    receiveTimeout: AppConfig.httpReceiveTimeout,
    contentType: 'application/json',
  ));
  dio.interceptors.add(_AuthInterceptor(ref, dio));
  return dio;
});

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref, this._dio);
  final Ref _ref;
  final Dio _dio;

  String? _currentAccessToken() {
    final state = _ref.read(authControllerProvider);
    return state is AuthSignedIn ? state.session.accessToken : null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _currentAccessToken();
    if (token != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['_retried'] == true;
    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final refreshed =
        await _ref.read(authControllerProvider.notifier).refresh();
    if (!refreshed) return handler.next(err);

    final token = _currentAccessToken();
    if (token == null) return handler.next(err);

    final newOptions = err.requestOptions
      ..headers['Authorization'] = 'Bearer $token'
      ..extra['_retried'] = true;
    try {
      final retry = await _dio.fetch<dynamic>(newOptions);
      handler.resolve(retry);
    } catch (e) {
      handler.next(err);
    }
  }
}
