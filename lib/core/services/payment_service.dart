import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

class PaymentOrder {
  final String paymentId;
  final String orderId;
  final String approveUrl;
  final double amount;
  final String currency;

  PaymentOrder({
    required this.paymentId,
    required this.orderId,
    required this.approveUrl,
    required this.amount,
    required this.currency,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
        paymentId: json['payment_id'] as String,
        orderId: json['order_id'] as String,
        approveUrl: json['approve_url'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
      );
}

class PaymentResult {
  final String status;
  final double grossAmount;
  final String currency;
  final String? captureId;

  PaymentResult({
    required this.status,
    required this.grossAmount,
    required this.currency,
    this.captureId,
  });

  bool get isCompleted => status == 'completed';

  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
        status: json['status'] as String,
        grossAmount: (json['gross_amount'] as num).toDouble(),
        currency: json['currency'] as String,
        captureId: json['gateway_transaction_id'] as String?,
      );
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final _dio = DioClient.instance.dio;

  /// Crea una orden PayPal para el incidente dado.
  Future<PaymentOrder> createOrder(String incidentId) async {
    final resp = await _dio.post(
      '${AppConfig.baseUrl}/payments/create-order',
      data: {'incident_id': incidentId},
    );
    return PaymentOrder.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Captura el pago después de la aprobación del usuario en PayPal.
  Future<PaymentResult> captureOrder(String orderId) async {
    final resp = await _dio.post(
      '${AppConfig.baseUrl}/payments/capture/$orderId',
    );
    return PaymentResult.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Obtiene el estado de pago de un incidente.
  Future<PaymentResult?> getPaymentByIncident(String incidentId) async {
    try {
      final resp = await _dio.get(
        '${AppConfig.baseUrl}/payments/incident/$incidentId',
      );
      if (resp.data == null) return null;
      return PaymentResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
