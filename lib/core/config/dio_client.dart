import 'package:dio/dio.dart';
import '../storage/local_storage.dart';
import 'env.dart';

class DioClient {
  late final Dio _dio;

  DioClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Interceptor: inyecta JWT automáticamente desde LocalStorage
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await LocalStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        // 401 → podría limpiarse sesión aquí si se requiere
        handler.next(e);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
      logPrint: (o) => print('[DIO] $o'),
    ));
  }

  static final DioClient _instance = DioClient._();
  static DioClient get instance => _instance;

  Dio get dio => _dio;

  void setAuthToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  void clearAuthToken() => _dio.options.headers.remove('Authorization');
}
