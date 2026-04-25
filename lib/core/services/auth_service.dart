import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';
import '../models/user.dart';
import '../storage/local_storage.dart';

class AuthService {
  final _dio = DioClient.instance.dio;

  /// POST /auth/login → guarda token y usuario en local storage
  Future<({bool success, String message, User? user})> login(
      String username, String password) async {
    try {
      final response = await _dio.post(
        AppConfig.loginEndpoint,
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = response.data['access_token'] as String;
      DioClient.instance.setAuthToken(token);
      await LocalStorage.saveToken(token);

      // Obtener datos del usuario
      final user = await me();
      if (user != null) {
        await LocalStorage.saveUser(user, token);
      }

      // Si el usuario es cliente, obtener y guardar el client_id
      final isClient = user?.roles.any((r) => r.name == 'client') ?? false;
      if (isClient) {
        await _fetchAndSaveClientId();
      }

      return (success: true, message: 'Bienvenido', user: user);

    } on DioException catch (e) {
      final msg = _extractError(e);
      return (success: false, message: msg, user: null);
    } catch (e) {
      return (success: false, message: 'Error inesperado: $e', user: null);
    }
  }

  /// GET /auth/me → usuario autenticado actual
  Future<User?> me() async {
    try {
      final response = await _dio.get(AppConfig.meEndpoint);
      return User.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Limpia token y datos locales
  Future<void> logout() async {
    DioClient.instance.clearAuthToken();
    await LocalStorage.clearAll();
  }

  /// Valida si el token guardado sigue siendo válido
  Future<bool> validateToken() async {
    try {
      final token = await LocalStorage.getToken();
      if (token == null) return false;
      DioClient.instance.setAuthToken(token);
      final user = await me();
      return user != null;
    } catch (_) {
      return false;
    }
  }

  /// Asegura que tengamos un client_id, si no lo tenemos lo busca.
  Future<String?> ensureClientId() async {
    String? clientId = await LocalStorage.getClientId();
    if (clientId != null && clientId.isNotEmpty) return clientId;
    
    // Si no está, intentamos buscarlo en el backend
    await _fetchAndSaveClientId();
    return await LocalStorage.getClientId();
  }

  Future<void> _fetchAndSaveClientId() async {
    try {
      final response = await _dio.get(AppConfig.clientMeEndpoint);
      final clientId = (response.data as Map<String, dynamic>)['id'] as String?;
      if (clientId != null) {
        await LocalStorage.saveClientId(clientId);
      }
    } catch (_) {
      // Fallo silencioso: si el endpoint no responde el user verá error al crear vehiculo
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'].toString();
        if (data.containsKey('message')) return data['message'].toString();
      }
      return 'Error de autenticación';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
