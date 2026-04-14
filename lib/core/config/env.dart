import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiUrl =>
      dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000';

  static String get loginEndpoint => '/auth/login';
  static String get meEndpoint => '/auth/me';
  static String get clientMeEndpoint => '/clients/me';
  static String get usersEndpoint => '/users';
  static String get clientsEndpoint => '/clients';
  static String get vehiclesEndpoint => '/vehicles';

}
