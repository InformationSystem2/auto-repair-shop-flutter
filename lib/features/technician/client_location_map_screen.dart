import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/dashboard_service.dart';
import '../../core/config/dio_client.dart';

class ClientLocationMapScreen extends StatefulWidget {
  final ActiveIncidentItem incident;

  const ClientLocationMapScreen({super.key, required this.incident});

  @override
  State<ClientLocationMapScreen> createState() => _ClientLocationMapScreenState();
}

class _ClientLocationMapScreenState extends State<ClientLocationMapScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  LatLng? _technicianPosition;
  bool _loadingTechPosition = true;
  List<LatLng> _routePoints = [];

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

    _loadTechnicianPosition();
  }

  Future<void> _fetchRoute(LatLng techPos) async {
    if (!_hasClientCoords) return;
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${techPos.longitude},${techPos.latitude};'
          '${_clientPosition.longitude},${_clientPosition.latitude}'
          '?overview=full&geometries=geojson';
      
      final dio = DioClient.instance.dio;
      final response = await dio.get(url);
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final coordinates = geometry['coordinates'] as List<dynamic>?;
            if (coordinates != null) {
              final pts = coordinates.map((pt) {
                final list = pt as List<dynamic>;
                return LatLng(list[1].toDouble(), list[0].toDouble());
              }).toList();
              if (mounted) {
                setState(() {
                  _routePoints = pts;
                });
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTechnicianPosition() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (hasPermission) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          final techPos = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _technicianPosition = techPos;
            _loadingTechPosition = false;
          });
          _fetchRoute(techPos);
        }
      } else {
        if (mounted) {
          setState(() => _loadingTechPosition = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTechPosition = false);
      }
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  LatLng get _clientPosition {
    if (widget.incident.latitude != null && widget.incident.longitude != null) {
      return LatLng(widget.incident.latitude!, widget.incident.longitude!);
    }
    return const LatLng(-17.7833, -63.1833); // Santa Cruz default
  }

  bool get _hasClientCoords =>
      widget.incident.latitude != null && widget.incident.longitude != null;

  double? _distanceKm() {
    if (_technicianPosition == null || !_hasClientCoords) return null;
    const dist = Distance();
    return dist.as(
      LengthUnit.Kilometer,
      _technicianPosition!,
      _clientPosition,
    );
  }

  void _centerOnClient() {
    _mapController.move(_clientPosition, 15);
  }

  void _centerOnTechnician() {
    if (_technicianPosition != null) {
      _mapController.move(_technicianPosition!, 15);
    }
  }

  void _fitBothMarkers() {
    if (_technicianPosition != null && _hasClientCoords) {
      final bounds = LatLngBounds.fromPoints([
        _clientPosition,
        _technicianPosition!,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        title: Text(
          'Ubicación del Cliente',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _clientPosition,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.auto_repair_shop',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Client marker
                  if (_hasClientCoords)
                    Marker(
                      point: _clientPosition,
                      width: 44,
                      height: 44,
                      child: _ClientMarker(cs: cs),
                    ),
                  // Technician (self) marker
                  if (_technicianPosition != null)
                    Marker(
                      point: _technicianPosition!,
                      width: 56,
                      height: 56,
                      child: _TechnicianSelfMarker(
                        pulseAnim: _pulseAnim,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Quick-action FABs
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: Column(
              children: [
                _MapFab(
                  icon: Icons.person_pin_circle_rounded,
                  color: cs.error,
                  tooltip: 'Centrar en cliente',
                  onTap: _centerOnClient,
                ),
                const SizedBox(height: 8),
                if (_technicianPosition != null) ...[
                  _MapFab(
                    icon: Icons.my_location_rounded,
                    color: const Color(0xFF10B981),
                    tooltip: 'Mi ubicación',
                    onTap: _centerOnTechnician,
                  ),
                  const SizedBox(height: 8),
                  _MapFab(
                    icon: Icons.zoom_out_map_rounded,
                    color: cs.primary,
                    tooltip: 'Ver ambos',
                    onTap: _fitBothMarkers,
                  ),
                ],
              ],
            ),
          ),

          // Bottom info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ClientInfoCard(
              incident: widget.incident,
              technicianPosition: _technicianPosition,
              distanceKm: _distanceKm(),
              loadingTechPosition: _loadingTechPosition,
              cs: cs,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map FAB ─────────────────────────────────────────────────────────────────

class _MapFab extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MapFab({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

// ─── Client Marker ───────────────────────────────────────────────────────────

class _ClientMarker extends StatelessWidget {
  final ColorScheme cs;
  const _ClientMarker({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.error,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: cs.error.withOpacity(0.4), blurRadius: 8)
            ],
          ),
          child: const Icon(Icons.person_pin_rounded,
              color: Colors.white, size: 18),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _MarkerTailPainter(cs.error),
        ),
      ],
    );
  }
}

// ─── Technician Self Marker ──────────────────────────────────────────────────

class _TechnicianSelfMarker extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _TechnicianSelfMarker({required this.pulseAnim});

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
                width: 36,
                height: 36,
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
                child: const Icon(Icons.build_rounded,
                    color: Colors.white, size: 18),
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

// ─── Marker Tail Painter ─────────────────────────────────────────────────────

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

// ─── Client Info Card ────────────────────────────────────────────────────────

class _ClientInfoCard extends StatelessWidget {
  final ActiveIncidentItem incident;
  final LatLng? technicianPosition;
  final double? distanceKm;
  final bool loadingTechPosition;
  final ColorScheme cs;
  final bool isDark;

  const _ClientInfoCard({
    required this.incident,
    required this.technicianPosition,
    required this.distanceKm,
    required this.loadingTechPosition,
    required this.cs,
    required this.isDark,
  });

  String _translateCategory(String? cat) {
    if (cat == null) return 'General';
    const map = {
      'battery': 'Batería',
      'tire': 'Llantas',
      'engine': 'Motor',
      'towing': 'Remolque',
      'ac': 'Aire Acondicionado',
      'general': 'General',
      'transmission': 'Transmisión',
      'locksmith': 'Cerrajería',
    };
    return map[cat.toLowerCase()] ?? cat;
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords =
        incident.latitude != null && incident.longitude != null;

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
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_pin_circle_rounded,
                    color: cs.error, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.clientName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      _translateCategory(incident.aiCategory),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (distanceKm != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      distanceKm! < 1
                          ? '${(distanceKm! * 1000).toStringAsFixed(0)} m'
                          : '${distanceKm!.toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      'de distancia',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: cs.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Coordinates
          if (hasCoords) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoPill(
                    label: 'Lat',
                    value: incident.latitude!.toStringAsFixed(5),
                    cs: cs,
                  ),
                  _InfoPill(
                    label: 'Lng',
                    value: incident.longitude!.toStringAsFixed(5),
                    cs: cs,
                  ),
                  _InfoPill(
                    label: 'Prioridad',
                    value: incident.aiPriority ?? 'MEDIUM',
                    cs: cs,
                  ),
                ],
              ),
            ),
          ],

          if (!hasCoords) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'El cliente no tiene ubicación registrada.',
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
}

// ─── Info Pill ───────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _InfoPill(
      {required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                color: cs.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w600)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: cs.onSurface,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
