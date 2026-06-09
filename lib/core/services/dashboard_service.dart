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

  Future<({bool success, String message, TechnicianDashboardData? data})>
      getTechnicianStats() async {
    try {
      final response =
          await _dio.get('${AppConfig.apiUrl}/api/dashboard/technician');
      final data = TechnicianDashboardData.fromJson(
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

class ActiveIncidentItem {
  final String id;
  final String? offerId;
  final String clientName;
  final String? aiCategory;
  final String? aiPriority;
  final String status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  ActiveIncidentItem({
    required this.id,
    this.offerId,
    required this.clientName,
    this.aiCategory,
    this.aiPriority,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  factory ActiveIncidentItem.fromJson(Map<String, dynamic> j) => ActiveIncidentItem(
        id: j['id'] as String,
        offerId: j['offer_id'] as String?,
        clientName: j['client_name'] as String? ?? 'Cliente',
        aiCategory: j['ai_category'] as String?,
        aiPriority: j['ai_priority'] as String?,
        status: j['status'] as String? ?? 'assigned',
        createdAt: DateTime.parse(j['created_at'] as String),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );
}

class RecentCompletedItem {
  final String id;
  final String clientName;
  final String? aiCategory;
  final double amount;
  final int? ratingScore;
  final DateTime completedAt;

  RecentCompletedItem({
    required this.id,
    required this.clientName,
    this.aiCategory,
    required this.amount,
    this.ratingScore,
    required this.completedAt,
  });

  factory RecentCompletedItem.fromJson(Map<String, dynamic> j) => RecentCompletedItem(
        id: j['id'] as String,
        clientName: j['client_name'] as String? ?? 'Cliente',
        aiCategory: j['ai_category'] as String?,
        amount: (j['amount'] as num).toDouble(),
        ratingScore: j['rating_score'] as int?,
        completedAt: DateTime.parse(j['completed_at'] as String),
      );
}

class TechnicianDashboardData {
  final int assignedCount;
  final int inProgressCount;
  final int completedToday;
  final int completedTotal;
  final double avgRating;
  final double productivity;
  final bool isAvailable;
  final String workshopName;
  final List<ActiveIncidentItem> activeIncidents;
  final List<RecentCompletedItem> recentCompleted;

  TechnicianDashboardData({
    required this.assignedCount,
    required this.inProgressCount,
    required this.completedToday,
    required this.completedTotal,
    required this.avgRating,
    required this.productivity,
    required this.isAvailable,
    required this.workshopName,
    required this.activeIncidents,
    required this.recentCompleted,
  });

  factory TechnicianDashboardData.fromJson(Map<String, dynamic> j) =>
      TechnicianDashboardData(
        assignedCount: (j['assigned_count'] as num).toInt(),
        inProgressCount: (j['in_progress_count'] as num).toInt(),
        completedToday: (j['completed_today'] as num).toInt(),
        completedTotal: (j['completed_total'] as num).toInt(),
        avgRating: (j['avg_rating'] as num).toDouble(),
        productivity: (j['productivity'] as num).toDouble(),
        isAvailable: j['is_available'] as bool? ?? true,
        workshopName: j['workshop_name'] as String? ?? 'Taller',
        activeIncidents: (j['active_incidents'] as List<dynamic>? ?? [])
            .map((e) => ActiveIncidentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentCompleted: (j['recent_completed'] as List<dynamic>? ?? [])
            .map((e) => RecentCompletedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
