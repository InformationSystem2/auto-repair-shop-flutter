import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/location_tracking_service.dart';
import '../../core/services/incident_service.dart';
import 'payment_screen.dart';

class TechnicianTrackingScreen extends StatefulWidget {
  final String incidentId;
  final double? clientLat;
  final double? clientLng;
  final String? technicianName;
  final String? workshopName;

  const TechnicianTrackingScreen({
    super.key,
    required this.incidentId,
    this.clientLat,
    this.clientLng,
    this.technicianName,
    this.workshopName,
  });

  @override
  State<TechnicianTrackingScreen> createState() => _TechnicianTrackingScreenState();
}

class _TechnicianTrackingScreenState extends State<TechnicianTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _tracking = LocationTrackingService();
  final _mapController = MapController();

  TechnicianLocation? _techLocation;
  String _connectionStatus = 'connecting';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  StreamSubscription<TechnicianLocation>? _locationSub;
  StreamSubscription<String>? _statusSub;
  Timer? _statusTimer;
  bool _redirectingToPayment = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _locationSub = _tracking.locationStream.listen((loc) {
      if (!mounted) return;
      setState(() => _techLocation = loc);
      _mapController.move(LatLng(loc.lat, loc.lng), _mapController.camera.zoom);
    });

    _statusSub = _tracking.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _connectionStatus = status);
    });

    _tracking.connectAsViewer(widget.incidentId);

    // Poll incident status every 6s to detect COMPLETED
    _statusTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _checkIncidentStatus();
    });
  }

  Future<void> _checkIncidentStatus() async {
    if (_redirectingToPayment || !mounted) return;
    final incident = await IncidentService().getIncident(widget.incidentId);
    if (!mounted || incident == null) return;
    if (incident.status == 'COMPLETED') {
      _redirectingToPayment = true;
      _statusTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(incident: incident),
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    _statusTimer?.cancel();
    _pulseController.dispose();
    _tracking.dispose();
    super.dispose();
  }

  LatLng get _initialCenter {
    if (widget.clientLat != null && widget.clientLng != null) {
      return LatLng(widget.clientLat!, widget.clientLng!);
    }
    return const LatLng(-17.7833, -63.1833); // Santa Cruz default
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            // Pop back — caller decides what to do next
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home', (route) => false);
            }
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
        title: Text(
          'Técnico en ruta',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          _StatusChip(status: _connectionStatus),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.auto_repair_shop',
              ),
              MarkerLayer(
                markers: [
                  if (widget.clientLat != null && widget.clientLng != null)
                    Marker(
                      point: LatLng(widget.clientLat!, widget.clientLng!),
                      width: 44,
                      height: 44,
                      child: _ClientMarker(cs: cs),
                    ),
                  if (_techLocation != null)
                    Marker(
                      point: LatLng(_techLocation!.lat, _techLocation!.lng),
                      width: 56,
                      height: 56,
                      child: _TechnicianMarker(
                        pulseAnim: _pulseAnim,
                        cs: cs,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Bottom info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _InfoCard(
              techLocation: _techLocation,
              technicianName: widget.technicianName,
              workshopName: widget.workshopName,
              connectionStatus: _connectionStatus,
              clientLat: widget.clientLat,
              clientLng: widget.clientLng,
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status == 'connected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withOpacity(0.85) : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnected)
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          Text(
            isConnected ? 'En vivo' : status == 'connecting' ? 'Conectando...' : 'Desconectado',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ClientMarker extends StatelessWidget {
  final ColorScheme cs;
  const _ClientMarker({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: cs.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: cs.error.withOpacity(0.4), blurRadius: 8)],
          ),
          child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 18),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _MarkerTailPainter(cs.error),
        ),
      ],
    );
  }
}

class _TechnicianMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  final ColorScheme cs;
  const _TechnicianMarker({required this.pulseAnim, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 44 * pulseAnim.value,
                height: 44 * pulseAnim.value,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.build_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _MarkerTailPainter(const Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;
  const _MarkerTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter old) => old.color != color;
}

class _InfoCard extends StatelessWidget {
  final TechnicianLocation? techLocation;
  final String? technicianName;
  final String? workshopName;
  final String connectionStatus;
  final double? clientLat;
  final double? clientLng;
  final ColorScheme cs;

  const _InfoCard({
    required this.techLocation,
    required this.technicianName,
    this.workshopName,
    required this.connectionStatus,
    required this.clientLat,
    required this.clientLng,
    required this.cs,
  });

  double? _distanceKm() {
    if (techLocation == null || clientLat == null || clientLng == null) return null;
    const dist = Distance();
    return dist.as(
      LengthUnit.Kilometer,
      LatLng(techLocation!.lat, techLocation!.lng),
      LatLng(clientLat!, clientLng!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final distance = _distanceKm();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technicianName ?? 'Técnico asignado',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
                    ),
                    Text(
                      connectionStatus == 'connected'
                          ? 'Ubicación en tiempo real'
                          : connectionStatus == 'connecting'
                              ? 'Conectando al técnico...'
                              : 'Sin señal del técnico',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: connectionStatus == 'connected'
                            ? const Color(0xFF10B981)
                            : cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      distance < 1
                          ? '${(distance * 1000).toStringAsFixed(0)} m'
                          : '${distance.toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: cs.primary),
                    ),
                    Text(
                      'de distancia',
                      style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withOpacity(0.45)),
                    ),
                  ],
                ),
            ],
          ),

          if (techLocation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoPill(
                    label: 'Lat',
                    value: techLocation!.lat.toStringAsFixed(5),
                    cs: cs,
                  ),
                  _InfoPill(
                    label: 'Lng',
                    value: techLocation!.lng.toStringAsFixed(5),
                    cs: cs,
                  ),
                  _InfoPill(
                    label: 'Actualizado',
                    value: _timeAgo(techLocation!.timestamp),
                    cs: cs,
                  ),
                ],
              ),
            ),
          ],

          if (connectionStatus != 'connected' && techLocation == null) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Cuando el técnico inicie su recorrido,\nsu ubicación aparecerá aquí.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.4),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 10) return 'Ahora';
    if (diff.inSeconds < 60) return 'Hace ${diff.inSeconds}s';
    return 'Hace ${diff.inMinutes}m';
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _InfoPill({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: cs.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600)),
        Text(value, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
