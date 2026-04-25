import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../storage/local_storage.dart';

class VehiclesProvider extends ChangeNotifier {
  final _vehicleService = VehicleService();

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  List<Vehicle> get vehicles => _vehicles;
  List<Vehicle> get activeVehicles => _vehicles.where((v) => v.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasVehicles => _vehicles.isNotEmpty;

  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _vehicleService.getMyVehicles();
    
    if (result.success) {
      _vehicles = result.vehicles;
    } else {
      _error = result.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _vehicles = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
