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
import '../../core/config/dio_client.dart';
import '../../core/storage/local_storage.dart';
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

  // Servicio completado SIN pagar: bloquea solicitar otro hasta pagar
  Incident? _pendingPaymentIncident;

  // Solicitud guardada offline a la espera de internet
  bool _pendingOffline = false;

  @override
  void initState() {
    super.initState();
    _loadPendingState();
    _checkActiveIncident();
    _loadInitial();
    _acquireLocation();
    // Poll every 5s to detect when workshop completes the service
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pendingOffline) {
        // Mientras haya una solicitud pendiente, reintentar enviarla en cuanto
        // vuelva el internet (limpia el flag automáticamente al confirmarse).
        _loadPendingState();
      } else {
        _checkActiveIncident();
      }
    });
  }

  Future<void> _loadPendingState() async {
    // Con internet, intentar procesar la solicitud pendiente: sube sus archivos
    // de evidencia y luego envía el request-help. Limpia el flag al confirmarse.
    if (await DioClient.instance.hasNetwork()) {
      final incident = await IncidentService().syncPendingOffline();
      if (!mounted) return;
      if (incident != null) {
        setState(() {
          _pendingOffline = false;
          _activeIncident = incident;
          _lastKnownIncidentId = incident.id;
          _checkingActive = false;
        });
        _showSnack('Tu solicitud guardada se envió correctamente.');
        return;
      }
    }
    final pending = await LocalStorage.hasPendingIncident();
    if (mounted) setState(() => _pendingOffline = pending);
  }

  Future<void> _cancelPendingOffline() async {
    // Borrar los archivos locales de evidencia de la solicitud descartada
    final pending = await LocalStorage.getPendingIncident();
    if (pending != null) {
      for (final raw in (pending['evidences'] as List? ?? [])) {
        final lp = (raw as Map)['local_path'] as String?;
        if (lp != null) {
          try {
            await File(lp).delete();
          } catch (_) {}
        }
      }
    }
    await DioClient.instance.cancelPendingIncident();
    if (!mounted) return;
    setState(() => _pendingOffline = false);
    _showSnack('Solicitud pendiente cancelada');
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

    // Sin incidente activo → ¿hay un servicio completado sin pagar?
    // Si lo hay, bloquea el formulario y obliga a pagar primero.
    if (active == null) {
      final unpaid = await IncidentService().getPendingPaymentIncident();
      if (!mounted) return;
      if (unpaid != null) {
        setState(() {
          _activeIncident = null;
          _pendingPaymentIncident = unpaid;
          _lastKnownIncidentId = unpaid.id;
          _checkingActive = false;
        });
        return;
      }
    }

    setState(() {
      _lastKnownIncidentId = active?.id ?? _lastKnownIncidentId;
      _activeIncident = active;
      _pendingPaymentIncident = active != null ? null : _pendingPaymentIncident;
      _checkingActive = false;
    });
  }

  Future<void> _payPending() async {
    final incident = _pendingPaymentIncident;
    if (incident == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaymentScreen(incident: incident)),
    );
    // Al volver del flujo de pago, re-verificar (si pagó, se libera el bloqueo)
    if (mounted) {
      setState(() => _checkingActive = true);
      await _checkActiveIncident();
    }
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

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }

      if (pos == null) {
        throw Exception('Location not available');
      }

      if (!mounted) return;
      setState(() {
        _lat = pos!.latitude;
        _lng = pos!.longitude;
        _locationReady = true;
      });
      try {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      } catch (_) {
        // Ignorar si el mapa no está montado aún
      }
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

  Future<void> _addEvidence(File file, String type) async {
    setState(() => _isUploading = true);

    final online = await DioClient.instance.hasNetwork();

    // Con conexión: subir de inmediato al backend (la IA lo analiza allí).
    if (online) {
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
      return;
    }

    // Sin conexión: copiar el archivo a un directorio persistente y guardar su
    // ruta local. Se subirá y analizará cuando vuelva el internet.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = file.path.contains('.') ? file.path.split('.').last : 'dat';
      final dest =
          '${dir.path}/offline_ev_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final saved = await file.copy(dest);
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _evidences.add(EvidenceData(type: type, localPath: saved.path));
      });
      _showSnack(type == 'image'
          ? 'Imagen guardada — se subirá al volver el internet'
          : 'Audio guardado — se subirá al volver el internet');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showSnack('Error al guardar archivo', isError: true);
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      await _addEvidence(File(photo.path), 'image');
    } catch (e) {
      _showSnack('Error al capturar foto', isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      await _addEvidence(File(image.path), 'image');
    } catch (e) {
      _showSnack('Error al seleccionar imagen', isError: true);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _addEvidence(File(path), 'audio');
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
    // Bloqueo anti-duplicados: si ya hay una solicitud guardada esperando
    // internet, no se permite crear otra (evita múltiples servicios al
    // recuperar la conexión).
    if (_pendingOffline || await LocalStorage.hasPendingIncident()) {
      if (mounted) setState(() => _pendingOffline = true);
      _showSnack(
        'Ya tienes una solicitud pendiente por enviar. Espera a que se envíe.',
        isError: true,
      );
      return;
    }

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
    final desc = hasText ? _descController.text.trim() : null;

    final online = await DioClient.instance.hasNetwork();

    // ── Sin conexión: guardar la solicitud COMPLETA (incluidas las rutas
    // locales de imágenes/audio) para subirla y procesarla al volver internet.
    if (!online) {
      await LocalStorage.savePendingIncident({
        'description': desc,
        'vehicle_id': _selectedVehicle!.id,
        'latitude': submitLat,
        'longitude': submitLng,
        'evidences': _evidences.map((e) => e.toStorageJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _pendingOffline = true;
      });
      _showSnack(
        'Sin conexión: tu solicitud y sus archivos se guardaron y se enviarán '
        'automáticamente cuando vuelva el internet.',
      );
      return;
    }

    // ── En línea: asegurar que toda evidencia esté subida (puede haber alguna
    // adjuntada offline antes de recuperar la conexión).
    final List<EvidenceData> resolved = [];
    for (final ev in _evidences) {
      if (ev.isUploaded) {
        resolved.add(ev);
        continue;
      }
      if (ev.localPath != null) {
        final up = await _incidentService.uploadEvidence(File(ev.localPath!));
        if (up.success && up.fileUrl != null) {
          resolved.add(EvidenceData(
              type: up.evidenceType ?? ev.type, fileUrl: up.fileUrl!));
        } else {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          _showSnack('Error al subir una evidencia. Intenta de nuevo.',
              isError: true);
          return;
        }
      }
    }

    final payload = IncidentCreate(
      description: desc,
      vehicleId: _selectedVehicle!.id,
      latitude: submitLat,
      longitude: submitLng,
      evidences: resolved,
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
      return;
    }

    // Error real del servidor estando en línea
    _showSnack(result.message, isError: true);
    // Puede ser el bloqueo por pago pendiente (409): re-verificar para mostrar
    // la pantalla de pago en lugar del formulario.
    _checkActiveIncident();
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

    // Una solicitud guardada offline bloquea el formulario hasta que se envíe
    if (_pendingOffline) {
      return _PendingOfflineView(
        cs: cs,
        onCancel: _cancelPendingOffline,
        onRefresh: _loadPendingState,
      );
    }

    // Show loading while checking for active incident
    if (_checkingActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auxilio')),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    // Servicio completado sin pagar → bloquear el formulario hasta pagar
    if (_pendingPaymentIncident != null) {
      return _PendingPaymentView(
        incident: _pendingPaymentIncident!,
        onPay: _payPending,
        cs: cs,
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
                onRemove: (index) async {
                  final ev = _evidences[index];
                  // Borrar la copia local si la evidencia se guardó offline
                  if (ev.localPath != null) {
                    try {
                      await File(ev.localPath!).delete();
                    } catch (_) {}
                  }
                  if (mounted) setState(() => _evidences.removeAt(index));
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

class _PendingPaymentView extends StatelessWidget {
  final Incident incident;
  final Future<void> Function() onPay;
  final ColorScheme cs;

  const _PendingPaymentView({
    required this.incident,
    required this.onPay,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago pendiente')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Color(0xFFF59E0B), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Tienes un pago pendiente',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu último servicio fue completado pero aún no lo has pagado. '
                'Debes completar el pago antes de solicitar otro auxilio.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Total a pagar',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 4),
                    Text(
                      'BOB ${incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
                      style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => onPay(),
                  icon: const Icon(Icons.payment_rounded),
                  label: Text('Pagar ahora',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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

class _PendingOfflineView extends StatelessWidget {
  final ColorScheme cs;
  final Future<void> Function() onCancel;
  final Future<void> Function() onRefresh;

  const _PendingOfflineView({
    required this.cs,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar Auxilio')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    color: Color(0xFFF59E0B), size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Solicitud guardada sin conexión',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu solicitud de auxilio se enviará automáticamente cuando '
                'vuelva el internet. No puedes crear otra hasta que esta se envíe.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar envío ahora'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancelar solicitud'),
                        content: const Text(
                            '¿Descartar la solicitud guardada? No se enviará al recuperar el internet.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sí, descartar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await onCancel();
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  label: Text('Descartar solicitud',
                      style: TextStyle(color: cs.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

            if (incident.status != 'IN_PROGRESS') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Cancelar auxilio?'),
                        content: const Text('¿Estás seguro de que deseas cancelar la solicitud de asistencia? El taller y el técnico asignado serán liberados.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('No, mantener'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Sí, cancelar'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      final res = await IncidentService().cancelIncident(incident.id);
                      
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Close loading
                      
                      if (res.success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res.message)),
                        );
                        onRefresh();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res.message), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: Text(
                    'Cancelar solicitud de auxilio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

