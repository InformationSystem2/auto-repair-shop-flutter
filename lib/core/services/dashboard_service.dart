import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

class SpendByVehicle {
  final String vehicleId;
  final String make;
  final String model;
  final String plate;
  final double amount;

  const SpendByVehicle({
    required this.vehicleId,
    required this.make,
    required this.model,
    required this.plate,
    required this.amount,
  });

  factory SpendByVehicle.fromJson(Map<String, dynamic> j) => SpendByVehicle(
        vehicleId: j['vehicle_id'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        plate: j['plate'] as String,
        amount: (j['amount'] as num).toDouble(),
      );

  String get displayName => '$make $model';
}

class SpendByCategory {
  final String category;
  final double amount;

  const SpendByCategory({required this.category, required this.amount});

  factory SpendByCategory.fromJson(Map<String, dynamic> j) => SpendByCategory(
        category: j['category'] as String,
        amount: (j['amount'] as num).toDouble(),
      );

  String get label {
    const map = {
      'battery': 'Batería',
      'tire': 'Llantas',
      'engine': 'Motor',
      'towing': 'Remolque',
      'ac': 'A/C',
      'general': 'General',
      'transmission': 'Transmisión',
      'locksmith': 'Cerrajería',
    };
    return map[category] ?? category;
  }
}

class ServiceHistoryItem {
  final String id;
  final DateTime createdAt;
  final String workshopName;
  final String? aiCategory;
  final double amount;
  final int? ratingScore;

  const ServiceHistoryItem({
    required this.id,
    required this.createdAt,
    required this.workshopName,
    this.aiCategory,
    required this.amount,
    this.ratingScore,
  });

  factory ServiceHistoryItem.fromJson(Map<String, dynamic> j) =>
      ServiceHistoryItem(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        workshopName: j['workshop_name'] as String,
        aiCategory: j['ai_category'] as String?,
        amount: (j['amount'] as num).toDouble(),
        ratingScore: j['rating_score'] as int?,
      );
}

class ClientDashboardData {
  final double totalSpent;
  final int serviceCount;
  final int vehicleCount;
  final List<SpendByVehicle> spendingByVehicle;
  final List<SpendByCategory> spendingByCategory;
  final List<ServiceHistoryItem> serviceHistory;

  const ClientDashboardData({
    required this.totalSpent,
    required this.serviceCount,
    required this.vehicleCount,
    required this.spendingByVehicle,
    required this.spendingByCategory,
    required this.serviceHistory,
  });

  factory ClientDashboardData.fromJson(Map<String, dynamic> j) =>
      ClientDashboardData(
        totalSpent: (j['total_spent'] as num).toDouble(),
        serviceCount: (j['service_count'] as num).toInt(),
        vehicleCount: (j['vehicle_count'] as num).toInt(),
        spendingByVehicle: (j['spending_by_vehicle'] as List<dynamic>)
            .map((e) => SpendByVehicle.fromJson(e as Map<String, dynamic>))
            .toList(),
        spendingByCategory: (j['spending_by_category'] as List<dynamic>)
            .map((e) => SpendByCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        serviceHistory: (j['service_history'] as List<dynamic>)
            .map((e) => ServiceHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardService {
  final _dio = DioClient.instance.dio;

  Future<({bool success, String message, ClientDashboardData? data})>
      getClientStats() async {
    try {
      final response =
          await _dio.get('${AppConfig.apiUrl}/api/dashboard/client');
      final data = ClientDashboardData.fromJson(
          response.data as Map<String, dynamic>);
      return (success: true, message: '', data: data);
    } on DioException catch (e) {
      return (
        success: false,
        message: _extractError(e),
        data: null,
      );
    }
  }

  String _extractError(DioException e) {
    try {
      final d = e.response?.data;
      if (d is Map && d.containsKey('detail')) return d['detail'].toString();
      return 'Error al cargar el dashboard';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
