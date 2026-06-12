import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiUrl =>
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000';

  static String get wsUrl => apiUrl
      .replaceFirst('http://', 'ws://')
      .replaceFirst('https://', 'wss://');

  static String get loginEndpoint => '/api/auth/login';
  static String get meEndpoint => '/api/auth/me';
  static String get clientMeEndpoint => '/api/auth/profile';
  static String get usersEndpoint => '/api/users';
  static String get clientsEndpoint => '/api/clients';
  static String get vehiclesEndpoint => '/api/vehicles';
  static String get incidentsEndpoint => '/api/incidents';
  static String get uploadEvidenceEndpoint => '/api/incidents/upload-evidence';
  static String get fcmTokenEndpoint => '/api/auth/fcm-token';
  static String get forgotPasswordEndpoint => '/api/auth/public/forgot-password';
  static String get resetPasswordEndpoint => '/api/auth/public/reset-password';
  static String get sendVerificationCodeEndpoint => '/api/auth/public/send-verification-code';
  static String get verifyCodeEndpoint => '/api/auth/public/verify-code';
  static String get ratingsEndpoint => '/api/ratings';
  static String get paymentsEndpoint => '/api/payments';
  static String get notificationsEndpoint => '/api/notifications';
}
