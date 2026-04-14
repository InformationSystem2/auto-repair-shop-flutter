import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';
import '../models/user.dart';

class UserService {
  final _dio = DioClient.instance.dio;

  /// PUT /users/{id} — actualiza perfil del usuario autenticado
  Future<({bool success, String message, User? user})> update(
      String id, Map<String, dynamic> payload) async {
    try {
      final response =
          await _dio.put('${AppConfig.usersEndpoint}/$id', data: payload);
      final user = User.fromJson(response.data as Map<String, dynamic>);
      return (success: true, message: 'Perfil actualizado', user: user);
    } on DioException catch (e) {
      return (success: false, message: _extractError(e), user: null);
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error al actualizar perfil';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
