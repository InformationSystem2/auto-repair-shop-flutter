/// Refleja VehicleResponseDTO del backend FastAPI
class Vehicle {
  final String id;
  final String clientId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? color;
  final String? transmissionType;
  final String? fuelType;
  final String? vin;
  final bool isActive;

  Vehicle({
    required this.id,
    required this.clientId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.color,
    this.transmissionType,
    this.fuelType,
    this.vin,
    required this.isActive,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        clientId: json['client_id'] as String,
        make: json['make'] as String,
        model: json['model'] as String,
        year: json['year'] as int,
        licensePlate: json['license_plate'] as String,
        color: json['color'] as String?,
        transmissionType: json['transmission_type'] as String?,
        fuelType: json['fuel_type'] as String?,
        vin: json['vin'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_id': clientId,
        'make': make,
        'model': model,
        'year': year,
        'license_plate': licensePlate,
        'color': color,
        'transmission_type': transmissionType,
        'fuel_type': fuelType,
        'vin': vin,
        'is_active': isActive,
      };

  String get displayName => '$make $model ($year)';
  String get subtitle => '$licensePlate${color != null ? ' • $color' : ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ─── Create ──────────────────────────────────────────────────────────────────

class VehicleCreate {
  final String clientId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;
  final String? color;
  final String? transmissionType;
  final String? fuelType;
  final String? vin;

  VehicleCreate({
    required this.clientId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
    this.color,
    this.transmissionType,
    this.fuelType,
    this.vin,
  });

  Map<String, dynamic> toJson() => {
        'client_id': clientId,
        'make': make,
        'model': model,
        'year': year,
        'license_plate': licensePlate,
        if (color != null && color!.isNotEmpty) 'color': color,
        if (transmissionType != null) 'transmission_type': transmissionType,
        if (fuelType != null) 'fuel_type': fuelType,
        if (vin != null && vin!.isNotEmpty) 'vin': vin,
      };
}

// ─── Update ──────────────────────────────────────────────────────────────────

class VehicleUpdate {
  final String? make;
  final String? model;
  final int? year;
  final String? licensePlate;
  final String? color;
  final String? transmissionType;
  final String? fuelType;
  final String? vin;
  final bool? isActive;

  VehicleUpdate({
    this.make,
    this.model,
    this.year,
    this.licensePlate,
    this.color,
    this.transmissionType,
    this.fuelType,
    this.vin,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        if (make != null) 'make': make,
        if (model != null) 'model': model,
        if (year != null) 'year': year,
        if (licensePlate != null) 'license_plate': licensePlate,
        if (color != null) 'color': color,
        if (transmissionType != null) 'transmission_type': transmissionType,
        if (fuelType != null) 'fuel_type': fuelType,
        if (vin != null) 'vin': vin,
        if (isActive != null) 'is_active': isActive,
      };
}
