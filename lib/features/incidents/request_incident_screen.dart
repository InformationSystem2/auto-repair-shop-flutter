import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import '../../core/providers/vehicles_provider.dart';
import '../../core/models/incident.dart';
import '../../core/models/vehicle.dart';
import '../../core/services/incident_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/empty_state.dart';
import 'incident_status_screen.dart';
import 'technician_tracking_screen.dart';
import 'payment_screen.dart';

class RequestIncidentScreen extends StatefulWidget {
  const RequestIncidentScreen({super.key});

  @override
  State<RequestIncidentScreen> createState() => _RequestIncidentScreenState();
}

class _RequestIncidentScreenState extends State<RequestIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _mapController = MapController();
  final _incidentService = IncidentService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  Vehicle? _selectedVehicle;
  bool _isSubmitting = false;
  bool _locationReady = false;
  bool _isRecording = false;
  bool _isUploading = false;
  double? _lat;
  double? _lng;

  final List<EvidenceData> _evidences = [];

  // Active incident tracking
  Incident? _activeIncident;
  bool _checkingActive = true;
  Timer? _pollTimer;
  String? _lastKnownIncidentId;

  @override
  void initState() {
    super.initState();
    _checkActiveIncident();
    _loadInitial();
    _acquireLocation();
    // Poll every 5s to detect when workshop completes the service
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkActiveIncident();
    });
  }

  Future<void> _checkActiveIncident() async {
    final active = await IncidentService().getMyActiveIncident();
    if (!mounted) return;

    // Incident existed before and now getMyActiveIncident returns null
    // → it may have COMPLETED. Fetch it directly to confirm.
    if (active == null && _lastKnownIncidentId != null) {
      final finished = await IncidentService().getIncident(_lastKnownIncidentId!);
      if (!mounted) return;
      if (finished != null && finished.status == 'COMPLETED') {
        _pollTimer?.cancel();
        setState(() {
          _activeIncident = null;
          _checkingActive = false;
          _lastKnownIncidentId = null;
        });
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PaymentScreen(incident: finished)),
        ).then((_) {
          // After payment flow, refresh to clear any stale state
          if (mounted) _checkActiveIncident();
        });
        return;
      }
    }

    setState(() {
      _lastKnownIncidentId = active?.id ?? _lastKnownIncidentId;
      _activeIncident = active;
      _checkingActive = false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _descController.dispose();
    _mapController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _acquireLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showSnack('Permiso de ubicación denegado permanentemente', isError: true);
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _locationReady = true;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (e) {
      if (mounted) {
        _showSnack('No se pudo obtener la ubicación', isError: true);
      }
    }
  }

  Future<void> _loadInitial() async {
    final provider = context.read<VehiclesProvider>();
    if (!provider.hasVehicles) {
      await provider.loadVehicles();
    }
    if (mounted && provider.activeVehicles.isNotEmpty) {
      setState(() {
        _selectedVehicle = provider.activeVehicles.first;
      });
    }
  }

  Future<void> _uploadAndAdd(File file, String type) async {
    setState(() => _isUploading = true);
    final result = await _incidentService.uploadEvidence(file);
    if (!mounted) return;
    setState(() => _isUploading = false);
    if (result.success && result.fileUrl != null) {
      setState(() {
        _evidences.add(EvidenceData(
          type: result.evidenceType ?? type,
          fileUrl: result.fileUrl!,
        ));
      });
      _showSnack(type == 'image' ? 'Imagen agregada' : 'Audio agregado');
    } else {
      _showSnack('Error al subir archivo', isError: true);
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      await _uploadAndAdd(File(photo.path), 'image');
    } catch (e) {
      _showSnack('Error al capturar foto', isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      await _uploadAndAdd(File(image.path), 'image');
    } catch (e) {
      _showSnack('Error al seleccionar imagen', isError: true);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _uploadAndAdd(File(path), 'audio');
      }
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showSnack('Permiso de micrófono denegado', isError: true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      setState(() => _isRecording = true);
    }
  }


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      _showSnack('Selecciona un vehículo', isError: true);
      return;
    }
    if (_lat == null || _lng == null) {
      _showSnack('Esperando ubicación GPS...', isError: true);
      return;
    }

    final hasText = _descController.text.trim().isNotEmpty;
    final hasEvidence = _evidences.isNotEmpty;
    if (!hasText && !hasEvidence) {
      _showSnack('Agrega al menos una descripción, imagen o audio', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final mapCenter = _mapController.camera.center;
    final submitLat = mapCenter.latitude;
    final submitLng = mapCenter.longitude;

    final payload = IncidentCreate(
      description: hasText ? _descController.text.trim() : null,
      vehicleId: _selectedVehicle!.id,
      latitude: submitLat,
      longitude: submitLng,
      evidences: _evidences,
    );

    final result = await _incidentService.requestHelp(payload);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (result.success && result.incident != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentStatusScreen(incident: result.incident!),
        ),
      );
    } else {
      _showSnack(result.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? cs.error : const Color(0xFF22C55E),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<VehiclesProvider>();
    final vehicles = provider.activeVehicles;

    // Show loading while checking for active incident
    if (_checkingActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auxilio')),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    // If there's an active incident, show its status instead of the form
    if (_activeIncident != null) {
      return _ActiveIncidentView(
        incident: _activeIncident!,
        onRefresh: _checkActiveIncident,
        cs: cs,
      );
    }

    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitar Auxilio')),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (provider.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitar Auxilio')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error al cargar',
          subtitle: provider.error!,
          onAction: () => provider.loadVehicles(),
          actionText: 'Reintentar',
        ),
      );
    }

    if (vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitar Auxilio')),
        body: EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Sin vehículos',
          subtitle: 'Registra al menos un vehículo antes de solicitar auxilio.',
          onAction: () => Navigator.of(context).pop(),
          actionText: 'Volver',
        ),
      );
    }

    // Asegurar que haya un vehículo válido seleccionado
    if (vehicles.isNotEmpty) {
      if (_selectedVehicle == null || !vehicles.contains(_selectedVehicle)) {
        _selectedVehicle = vehicles.first;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar Auxilio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EmergencyBanner(cs: cs),
              const SizedBox(height: 24),
              _SectionLabel(text: 'Vehículo', cs: cs),
              const SizedBox(height: 8),
              _VehicleDropdown(
                vehicles: vehicles,
                selected: _selectedVehicle,
                cs: cs,
                onChanged: (v) => setState(() => _selectedVehicle = v),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _descController,
                label: 'Descripción del problema (opcional)',
                hint: 'Ej: Mi auto no enciende, hay humo del motor...',
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 20),
              _SectionLabel(text: 'Evidencias (opcional)', cs: cs),
              const SizedBox(height: 8),
              _EvidenceWidget(
                evidences: _evidences,
                onAddPhoto: _capturePhoto,
                onAddGallery: _pickImage,
                onToggleAudio: _toggleRecording,
                onRemove: (index) {
                  setState(() => _evidences.removeAt(index));
                },
                isRecording: _isRecording,
                isUploading: _isUploading,
                cs: cs,
              ),
              const SizedBox(height: 20),
              _SectionLabel(text: 'Tu ubicación', cs: cs),
              const SizedBox(height: 8),
              _LocationMapWidget(
                mapController: _mapController,
                lat: _lat,
                lng: _lng,
                locationReady: _locationReady,
                cs: cs,
                onRetry: _acquireLocation,
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Pedir Auxilio',
                icon: Icons.sos_rounded,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Un técnico será enviado a tu ubicación',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _EmergencyBanner extends StatelessWidget {
  final ColorScheme cs;
  const _EmergencyBanner({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFDC2626), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitud de Emergencia',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                Text(
                  'Envía texto, imagen o audio — al menos uno es requerido.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFDC2626).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withOpacity(0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _VehicleDropdown extends StatelessWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selected;
  final ColorScheme cs;
  final void Function(Vehicle?) onChanged;

  const _VehicleDropdown({
    required this.vehicles,
    required this.selected,
    required this.cs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Vehicle>(
      value: selected,
      isExpanded: true,
      decoration: InputDecoration(
        fillColor: cs.surfaceContainerHigh,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Icons.directions_car_rounded,
            color: cs.onSurface.withOpacity(0.45), size: 20),
      ),
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: cs.onSurface,
      ),
      dropdownColor: cs.surfaceContainerHigh,
      items: vehicles
          .map((v) => DropdownMenuItem(
                value: v,
                child: Text(
                  '${v.displayName} • ${v.licensePlate}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Selecciona un vehículo' : null,
    );
  }
}

class _EvidenceWidget extends StatelessWidget {
  final List<EvidenceData> evidences;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddGallery;
  final VoidCallback onToggleAudio;
  final Function(int) onRemove;
  final bool isRecording;
  final bool isUploading;
  final ColorScheme cs;

  const _EvidenceWidget({
    required this.evidences,
    required this.onAddPhoto,
    required this.onAddGallery,
    required this.onToggleAudio,
    required this.onRemove,
    required this.isRecording,
    required this.isUploading,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _EvidenceButton(
              icon: Icons.camera_alt_rounded,
              label: 'Foto',
              onPressed: onAddPhoto,
              cs: cs,
            ),
            _EvidenceButton(
              icon: Icons.image_rounded,
              label: 'Galería',
              onPressed: onAddGallery,
              cs: cs,
            ),
            _EvidenceButton(
              icon: isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              label: isRecording ? 'Detener' : 'Audio',
              onPressed: onToggleAudio,
              cs: cs,
              isActive: isRecording,
            ),
          ],
        ),
        if (isUploading) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              ),
              const SizedBox(width: 8),
              Text('Subiendo...', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface)),
            ],
          ),
        ],
        if (evidences.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${evidences.length} evidencia${evidences.length > 1 ? 's' : ''} agregada${evidences.length > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(evidences.length, (i) {
                    final isAudio = evidences[i].type == 'audio';
                    return Chip(
                      avatar: Icon(
                        isAudio ? Icons.audiotrack_rounded : Icons.image_rounded,
                        size: 16,
                      ),
                      label: Text(isAudio ? 'Audio ${i + 1}' : 'Foto ${i + 1}'),
                      onDeleted: () => onRemove(i),
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      labelStyle: GoogleFonts.inter(fontSize: 11),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidenceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ColorScheme cs;
  final bool isActive;

  const _EvidenceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.cs,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? cs.error : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: isActive ? Colors.white : cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMapWidget extends StatefulWidget {
  final MapController mapController;
  final double? lat;
  final double? lng;
  final bool locationReady;
  final ColorScheme cs;
  final VoidCallback onRetry;

  const _LocationMapWidget({
    required this.mapController,
    required this.lat,
    required this.lng,
    required this.locationReady,
    required this.cs,
    required this.onRetry,
  });

  @override
  State<_LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<_LocationMapWidget> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.lat != null && widget.lng != null
        ? LatLng(widget.lat!, widget.lng!)
        : const LatLng(-17.7863, -63.1812);
  }

  void _updateLocationFromMap() {
    final center = widget.mapController.camera.center;
    setState(() => _selectedLocation = center);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            FlutterMap(
              mapController: widget.mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: widget.locationReady ? 15 : 12,
                onMapEvent: (event) {
                  if (widget.locationReady && event is MapEventMove) {
                    _updateLocationFromMap();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.auto_repair_shop',
                ),
                const CurrentLocationLayer(),
              ],
            ),
            Center(
              child: Icon(Icons.location_on_rounded,
                  color: widget.cs.error, size: 32),
            ),
            if (!widget.locationReady)
              Container(
                color: widget.cs.surface.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: widget.cs.primary),
                      const SizedBox(height: 10),
                      Text(
                        'Obteniendo ubicación GPS...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: widget.cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.locationReady)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.cs.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded,
                          color: widget.cs.primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: widget.cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!widget.locationReady)
              Positioned(
                bottom: 8,
                right: 8,
                child: TextButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Reintentar',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ),
            if (widget.locationReady)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.cs.primary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Toca para editar',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.cs.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Active Incident View ─────────────────────────────────────────────────────

class _ActiveIncidentView extends StatelessWidget {
  final Incident incident;
  final VoidCallback onRefresh;
  final ColorScheme cs;

  const _ActiveIncidentView({
    required this.incident,
    required this.onRefresh,
    required this.cs,
  });

  bool get _isInTransit =>
      incident.status == 'ASSIGNED' || incident.status == 'IN_PROGRESS';

  String get _statusLabel {
    const labels = {
      'PENDING': 'Pendiente',
      'ANALYZING': 'Analizando con IA...',
      'PENDING_INFO': 'Información requerida',
      'MATCHED': 'Taller asignado',
      'ASSIGNED': 'Técnico en camino',
      'IN_PROGRESS': 'En proceso',
    };
    return labels[incident.status] ?? incident.status;
  }

  Color get _statusColor {
    switch (incident.status) {
      case 'ASSIGNED':
      case 'IN_PROGRESS':
        return const Color(0xFF10B981);
      case 'MATCHED':
        return const Color(0xFF6366F1);
      case 'PENDING_INFO':
        return const Color(0xFFD97706);
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicio Activo'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRefresh,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  if (incident.status == 'PENDING' || incident.status == 'ANALYZING')
                    CircularProgressIndicator(color: _statusColor, strokeWidth: 3)
                  else
                    Icon(
                      _isInTransit
                          ? Icons.directions_car_rounded
                          : Icons.hourglass_top_rounded,
                      size: 48,
                      color: _statusColor,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _isInTransit ? '¡Tu técnico está en camino!' : 'Solicitud en curso',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700, color: _statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: _statusColor.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Workshop + Technician card
            if (incident.workshopName != null || incident.technicianName != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x4D6366F1),
                        blurRadius: 16,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'SERVICIO ASIGNADO',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 1),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (incident.workshopName != null) ...[
                      Row(children: [
                        const Icon(Icons.store_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Taller',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              Text(incident.workshopName!,
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ]),
                    ],
                    if (incident.workshopName != null &&
                        incident.technicianName != null)
                      const SizedBox(height: 12),
                    if (incident.technicianName != null) ...[
                      Row(children: [
                        const Icon(Icons.engineering_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Técnico',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              Text(incident.technicianName!,
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ]),
                    ],
                    if (incident.estimatedArrivalMin != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.timer_rounded,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tiempo estimado',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white54,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              Text('${incident.estimatedArrivalMin} minutos',
                                  style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                            ]),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Go to map button (only when technician is in transit)
            if (_isInTransit) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TechnicianTrackingScreen(
                        incidentId: incident.id,
                        clientLat: incident.lat,
                        clientLng: incident.lng,
                        technicianName: incident.technicianName,
                        workshopName: incident.workshopName,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.location_on_rounded),
                  label: Text(
                    'Ver técnico en el mapa',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // View detail button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => IncidentStatusScreen(incident: incident),
                    ))
                    .then((_) => onRefresh()),
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(
                  'Ver detalle del servicio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

