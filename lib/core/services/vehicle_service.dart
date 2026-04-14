import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';
import '../models/vehicle.dart';

class VehicleService {
  final _dio = DioClient.instance.dio;

  /// GET /vehicles/my — vehículos del cliente autenticado
  Future<({bool success, String message, List<Vehicle> vehicles})>
      getMyVehicles() async {
    try {
      final response =
          await _dio.get('${AppConfig.vehiclesEndpoint}/');
      final list = (response.data as List<dynamic>)
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList();
      return (success: true, message: '', vehicles: list);
    } on DioException catch (e) {
      return (
        success: false,
        message: _extractError(e),
        vehicles: <Vehicle>[]
      );
    }
  }

  /// POST /vehicles — crear vehículo
  Future<({bool success, String message, Vehicle? vehicle})> create(
      VehicleCreate payload) async {
    try {
      final response = await _dio.post(
        '${AppConfig.vehiclesEndpoint}/',
        data: payload.toJson(),
      );
      final v = Vehicle.fromJson(response.data as Map<String, dynamic>);
      return (success: true, message: 'Vehículo registrado', vehicle: v);
    } on DioException catch (e) {
      return (success: false, message: _extractError(e), vehicle: null);
    }
  }

  /// PUT /vehicles/{id} — editar vehículo
  Future<({bool success, String message, Vehicle? vehicle})> update(
      String id, VehicleUpdate payload) async {
    try {
      final response = await _dio.put(
        '${AppConfig.vehiclesEndpoint}/$id',
        data: payload.toJson(),
      );
      final v = Vehicle.fromJson(response.data as Map<String, dynamic>);
      return (success: true, message: 'Vehículo actualizado', vehicle: v);
    } on DioException catch (e) {
      return (success: false, message: _extractError(e), vehicle: null);
    }
  }

  /// DELETE /vehicles/{id}
  Future<({bool success, String message})> delete(String id) async {
    try {
      await _dio.delete('${AppConfig.vehiclesEndpoint}/$id');
      return (success: true, message: 'Vehículo eliminado');
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
      return 'Error en la operación';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
