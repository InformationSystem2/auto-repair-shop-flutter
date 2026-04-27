import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

class PaymentService {
  final _dio = DioClient.instance.dio;

  Future<({bool success, String? orderId, String? approveUrl, String? message})> createOrder(
      String incidentId) async {
    try {
      final response = await _dio.post(
        '${AppConfig.paymentsEndpoint}/create-order',
        data: {'incident_id': incidentId},
      );
      final data = response.data as Map<String, dynamic>;
      return (
        success: true,
        orderId: data['order_id'] as String?,
        approveUrl: data['approve_url'] as String?,
        message: null
      );
    } on DioException catch (e) {
      return (
        success: false,
        orderId: null,
        approveUrl: null,
        message: _extractError(e)
      );
    }
  }

  Future<({bool success, String? message})> captureOrder(String orderId) async {
    try {
      await _dio.post('${AppConfig.paymentsEndpoint}/capture/$orderId');
      return (success: true, message: null);
    } on DioException catch (e) {
      return (success: false, message: _extractError(e));
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error en la operación de pago';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
