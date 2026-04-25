import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/vehicles_provider.dart';
import '../../../core/services/vehicle_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../shared/widgets/ui.dart';
import 'widgets/vehicle_card.dart';
import 'widgets/vehicle_form_sheet.dart';
import '../../core/models/vehicle.dart';


class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _vehicleService = VehicleService();
  final _authService = AuthService();
  String? _clientId;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    _clientId = await _authService.ensureClientId();
    if (mounted) {
      context.read<VehiclesProvider>().loadVehicles();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? cs.error : const Color(0xFF22C55E), // logic success color
    ));
  }

  void _loadData() {
    context.read<VehiclesProvider>().loadVehicles();
  }

  Future<void> _openCreateSheet() async {
    if (_clientId == null || _clientId!.isEmpty) {
      _clientId = await _authService.ensureClientId();
    }

    if (!mounted) return;
    if (_clientId == null || _clientId!.isEmpty) {
      _showSnack('No se pudo identificar tu cuenta de cliente. Reintenta más tarde.', isError: true);
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleFormSheet(
        clientId: _clientId ?? '',
        onSave: (data) async {
          final payload = VehicleCreate(
            clientId: data['client_id'] ?? _clientId ?? '',
            make: data['make'],
            model: data['model'],
            licensePlate: data['license_plate'],
            year: data['year'],
            color: data['color'],
            transmissionType: data['transmission_type'],
            fuelType: data['fuel_type'],
            vin: data['vin'],
          );
          final result = await _vehicleService.create(payload);
          if (!mounted) return;
          Navigator.of(context).pop();
          if (result.success) {
            _showSnack(result.message);
            _loadData();
          } else {
            _showSnack(result.message, isError: true);
          }
        },
      ),
    );
  }

  Future<void> _openEditSheet(Vehicle vehicle) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleFormSheet(
        vehicle: vehicle,
        clientId: _clientId ?? '',
        onSave: (data) async {
          final payload = VehicleUpdate(
            make: data['make'],
            model: data['model'],
            licensePlate: data['license_plate'],
            year: data['year'],
            color: data['color'],
            transmissionType: data['transmission_type'],
            fuelType: data['fuel_type'],
            vin: data['vin'],
          );
          final result = await _vehicleService.update(vehicle.id, payload);
          if (!mounted) return;
          Navigator.of(context).pop();
          if (result.success) {
            _showSnack(result.message);
            _loadData();
          } else {
            _showSnack(result.message, isError: true);
          }
        },
      ),
    );
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    await ConfirmDialog.show(
      context: context,
      title: 'Eliminar vehículo',
      content: '¿Estás seguro que deseas eliminar ${vehicle.displayName}? Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      isDestructive: true,
      onConfirm: () async {
        final result = await _vehicleService.delete(vehicle.id);
        if (!mounted) return;
        if (result.success) {
          _showSnack(result.message);
          _loadData();
        } else {
          _showSnack(result.message, isError: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = context.read<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Vehículos'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: themeNotifier.toggle,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final provider = context.watch<VehiclesProvider>();
    final vehicles = provider.vehicles;

    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (provider.error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Error al cargar',
        subtitle: provider.error!,
        onAction: () => provider.loadVehicles(),
        actionText: 'Reintentar',
      );
    }

    if (vehicles.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'Sin vehículos registrados',
        subtitle: 'Agrega tu primer vehículo tocando el botón de abajo.',
        onAction: _openCreateSheet,
        actionText: 'Agregar vehículo',
      );
    }

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: () => provider.loadVehicles(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: vehicles.length,
        itemBuilder: (_, i) => VehicleCard(
          vehicle: vehicles[i],
          onEdit: () => _openEditSheet(vehicles[i]),
          onDelete: () => _deleteVehicle(vehicles[i]),
        ),
      ),
    );
  }
}
