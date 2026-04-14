import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

class ClientService {
  final _dio = DioClient.instance.dio;

  /// POST /clients/ — Registra un nuevo cliente completo.
  /// El backend valida que el email no exista previamente.
  Future<({bool success, String message, String? clientId, String? username})> createClient({
    required String name,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    String? address,
    String? insuranceProvider,
    String? insurancePolicyNumber,
  }) async {
    try {
      final payload = {
        'user': {
          'name': name,
          'last_name': lastName,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
        'password': password,
        if (address != null && address.isNotEmpty) 'address': address,
        if (insuranceProvider != null && insuranceProvider.isNotEmpty)
          'insurance_provider': insuranceProvider,
        if (insurancePolicyNumber != null && insurancePolicyNumber.isNotEmpty)
          'insurance_policy_number': insurancePolicyNumber,
      };

      final response = await _dio.post('${AppConfig.clientsEndpoint}/', data: payload);
      final data = response.data as Map<String, dynamic>;
      
      return (
        success: true,
        message: '¡Cuenta creada exitosamente!',
        clientId: data['id'] as String?,
        username: data['username'] as String?,
      );
    } on DioException catch (e) {
      return (success: false, message: _extractError(e), clientId: null, username: null);
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error al comunicarse con el servidor.';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
