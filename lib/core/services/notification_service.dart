import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

import '../../app.dart';

/// Handler para mensajes recibidos en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase ya está inicializado en main.dart
  debugPrint('[FCM] Mensaje en background: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _dio = DioClient.instance.dio;

  /// Canal de notificaciones para Android
  static const _androidChannel = AndroidNotificationChannel(
    'auto_repair_high_importance',
    'Auxilio en Camino',
    description: 'Notificaciones de tu solicitud de auxilio',
    importance: Importance.high,
    playSound: true,
  );

  /// Inicializar FCM y notificaciones locales. Llamar desde main() después de Firebase.initialize.
  Future<void> initialize() async {
    // 1. Solicitar permisos (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permiso: ${settings.authorizationStatus}');

    // 2. Configurar notificaciones locales (para mostrar push cuando la app está en primer plano)
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIOS = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: initAndroid, iOS: initIOS);
    await _localNotifications.initialize(initSettings);

    // Crear canal Android de alta importancia
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // 3. Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Listener cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
      debugPrint('[FCM] Mensaje en primer plano: ${notification?.title}');
    });

    // 5. Obtener y registrar el FCM token en el backend
    await _registerToken();

    // 6. Escuchar cambios de token (si el token se refresca)
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refrescado: $newToken');
      await _sendTokenToBackend(newToken);
    });

    // 7. Handler para cuando se toca la notificación (App abierta en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageTap(message);
    });

    // 8. Check if app was opened FROM a terminated state via a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  void _handleMessageTap(RemoteMessage message) async {
    debugPrint('[FCM] Notificación pulsada: ${message.data}');
    
    final context = _getNavigatorContext();
    if (context == null) return;

    // Según pedido del usuario, el clic en el PUSH siempre lleva al listado
    Navigator.pushNamed(context, '/notifications');
  }

  BuildContext? _getNavigatorContext() {
    return AutoRepairApp.navigatorKey.currentContext;
  }

  /// Expuesto para llamarlo manualmente después del login.
  Future<void> registerToken() => _registerToken();

  /// Obtiene el token FCM del dispositivo y lo envía al backend.
  Future<void> _registerToken() async {
    try {
      final token = Platform.isIOS
          ? await _messaging.getAPNSToken()
          : await _messaging.getToken();

      if (token != null) {
        debugPrint('[FCM] Token obtenido: $token');
        await _sendTokenToBackend(token);
      } else {
        debugPrint('[FCM] No se pudo obtener el token (normal en emulador iOS)');
      }
    } catch (e) {
      debugPrint('[FCM] Error obteniendo token: $e');
    }
  }

  /// Envía el token al endpoint POST /api/auth/fcm-token
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _dio.post(
        AppConfig.fcmTokenEndpoint,
        data: {'token': token},
      );
      debugPrint('[FCM] Token registrado en el backend ✅');
    } on DioException catch (e) {
      debugPrint('[FCM] Error registrando token en backend: ${e.message}');
    }
  }

  // --- API Methods ---

  Future<List<dynamic>> getNotifications({int limit = 50}) async {
    try {
      final response = await _dio.get(
        AppConfig.notificationsEndpoint,
        queryParameters: {'limit': limit},
      );
      return response.data;
    } catch (e) {
      debugPrint('[FCM] Error fetching notifications: $e');
      return [];
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      await _dio.patch('${AppConfig.notificationsEndpoint}/$notificationId/read');
      return true;
    } catch (e) {
      debugPrint('[FCM] Error marking notification as read: $e');
      return false;
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response =
          await _dio.get('${AppConfig.notificationsEndpoint}/unread-count');
      return response.data['unread_count'] ?? 0;
    } catch (e) {
      debugPrint('[FCM] Error getting unread count: $e');
      return 0;
    }
  }
}
