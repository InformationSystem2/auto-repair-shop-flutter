import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../storage/local_storage.dart';
import 'env.dart';

class DioClient {
  late final Dio _dio;
  bool _isOffline = false;
  final _offlineQueueKey = 'offline_requests_queue';

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

    // Interceptor: inyecta JWT automáticamente y detecta/encola peticiones offline
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await LocalStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Si es una petición mutativa (POST, PUT, DELETE, PATCH)
        final isMutation = ['POST', 'PUT', 'DELETE', 'PATCH'].contains(options.method.toUpperCase());
        if (isMutation) {
          final hasNetwork = await _checkNetwork();
          if (!hasNetwork) {
            _isOffline = true;
            // Encolar petición mutativa localmente
            await _enqueueRequest(options);
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Sin conexión a Internet. La operación fue guardada y se enviará cuando se recupere la conexión.',
                type: DioExceptionType.connectionError,
              ),
            );
          } else if (_isOffline) {
            _isOffline = false;
            // Si volvemos a tener red, procesar cola pendiente de manera asíncrona
            _syncOfflineQueue();
          }
        }

        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.type == DioExceptionType.connectionError) {
          _isOffline = true;
        }
        handler.next(e);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
      logPrint: (o) => print('[DIO] $o'),
    ));

    // Intentar sincronizar al inicio
    _syncOfflineQueue();
  }

  static final DioClient _instance = DioClient._();
  static DioClient get instance => _instance;

  Dio get dio => _dio;

  void setAuthToken(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  void clearAuthToken() => _dio.options.headers.remove('Authorization');

  Future<bool> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Expuesto para que las pantallas detecten el estado de conexión antes de
  /// intentar una operación mutativa.
  Future<bool> hasNetwork() => _checkNetwork();

  /// Fuerza un intento de sincronización de la cola offline (p. ej. al volver
  /// a primer plano la pantalla de solicitud).
  Future<void> syncNow() => _syncOfflineQueue();

  /// Descarta la solicitud de auxilio pendiente: la quita de la cola offline y
  /// libera el bloqueo. Útil si el usuario decide cancelarla antes de enviarse.
  Future<void> cancelPendingIncident() async {
    try {
      final prefs = await LocalStorage.getPrefs();
      final List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
      final filtered = queue.where((rawReq) {
        try {
          final req = json.decode(rawReq) as Map<String, dynamic>;
          return !(req['path'] as String).contains('request-help');
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_offlineQueueKey, filtered);
    } catch (_) {}
    await LocalStorage.clearPendingIncident();
  }

  Future<void> _enqueueRequest(RequestOptions options) async {
    try {
      final prefs = await LocalStorage.getPrefs();
      final List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
      
      // Evitar duplicar peticiones al mismo endpoint con la misma intención/cuerpo mientras está offline
      bool alreadyExists = false;
      for (final rawReq in queue) {
        try {
          final req = json.decode(rawReq) as Map<String, dynamic>;
          if (req['path'] == options.path && req['method'] == options.method) {
            // Si el endpoint coincide, validamos si la data también es idéntica
            final rawData1 = json.encode(req['data']);
            final rawData2 = json.encode(options.data);
            if (rawData1 == rawData2) {
              alreadyExists = true;
              break;
            }
          }
        } catch (_) {}
      }

      if (alreadyExists) {
        print('[OfflineQueue] Petición duplicada omitida para evitar re-envíos: ${options.path}');
        return;
      }

      final reqMap = {
        'path': options.path,
        'method': options.method,
        'data': options.data,
        'queryParameters': options.queryParameters,
        'headers': {'Authorization': options.headers['Authorization']},
        'timestamp': DateTime.now().toIso8601String(),
      };

      queue.add(json.encode(reqMap));
      await prefs.setStringList(_offlineQueueKey, queue);
      print('[OfflineQueue] Petición encolada con éxito: ${options.path}');
    } catch (e) {
      print('[OfflineQueue] Error encolando: $e');
    }
  }

  Future<void> _syncOfflineQueue() async {
    final hasNetwork = await _checkNetwork();
    if (!hasNetwork) return;

    try {
      final prefs = await LocalStorage.getPrefs();
      final List<String> queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.isEmpty) return;

      print('[OfflineQueue] Sincronizando ${queue.length} peticiones pendientes...');
      final List<String> unresolved = [];

      for (final rawReq in queue) {
        try {
          final req = json.decode(rawReq) as Map<String, dynamic>;
          final headers = Map<String, dynamic>.from(req['headers'] as Map? ?? {});
          
          await _dio.request<dynamic>(
            req['path'] as String,
            data: req['data'],
            queryParameters: req['queryParameters'] as Map<String, dynamic>?,
            options: Options(
              method: req['method'] as String,
              headers: headers,
            ),
          );
          print('[OfflineQueue] Sincronizada con éxito: ${req['path']}');
          // Si la solicitud de auxilio pendiente ya se envió, liberar el bloqueo
          // que impedía crear otra mientras estaba offline.
          if ((req['path'] as String).contains('request-help')) {
            await LocalStorage.clearPendingIncident();
          }
        } catch (e) {
          print('[OfflineQueue] Falló reintentar petición. Se mantiene en la cola.');
          unresolved.add(rawReq);
        }
      }

      await prefs.setStringList(_offlineQueueKey, unresolved);
    } catch (_) {}
  }
}
