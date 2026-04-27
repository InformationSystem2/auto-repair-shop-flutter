import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/incident.dart';
import '../../core/services/incident_service.dart';
import '../../shared/widgets/empty_state.dart';

class IncidentDetailScreen extends StatefulWidget {
  final String incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _incidentService = IncidentService();
  Incident? _incident;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final incident = await _incidentService.getIncident(widget.incidentId);
      if (!mounted) return;
      if (incident != null) {
        setState(() {
          _incident = incident;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No se pudo cargar la información';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error inesperado: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Servicio')),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    if (_error != null || _incident == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del Servicio')),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error',
          subtitle: _error ?? 'Incidente no encontrado',
          onAction: _loadDetail,
          actionText: 'Reintentar',
        ),
      );
    }

    final incident = _incident!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Servicio #${incident.id.substring(0, 8)}',
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700),
              ),
              background: _LocationHeader(lat: incident.lat, lng: incident.lng, cs: cs),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBanner(status: incident.status, date: incident.createdAt, cs: cs),
                  const SizedBox(height: 24),
                  
                  _SectionHeader(title: 'Diagnóstico IA', icon: Icons.auto_awesome_rounded, cs: cs),
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(label: 'Categoría', value: _catLabel(incident.aiCategory), icon: Icons.category_rounded, cs: cs),
                        const Divider(height: 24, thickness: 0.5),
                        Text(
                          'Resumen IA:',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          incident.aiSummary ?? 'Sin resumen disponible.',
                          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: cs.onSurface),
                        ),
                      ],
                    ),
                    cs: cs,
                    isDark: isDark,
                  ),
                  
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Mi Reporte', icon: Icons.description_rounded, cs: cs),
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.description ?? 'Sin descripción.',
                          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: cs.onSurface),
                        ),
                        if (incident.vehicle != null) ...[
                          const Divider(height: 24, thickness: 0.5),
                          _DetailRow(
                            label: 'Vehículo',
                            value: '${incident.vehicle!['make']} ${incident.vehicle!['model']} (${incident.vehicle!['license_plate']})',
                            icon: Icons.directions_car_rounded,
                            cs: cs,
                          ),
                        ],
                      ],
                    ),
                    cs: cs,
                    isDark: isDark,
                  ),
                  
                  if (incident.evidenceUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Evidencias', icon: Icons.attachment_rounded, cs: cs),
                    const SizedBox(height: 12),
                    _EvidenceList(evidences: incident.evidenceUrls, cs: cs, isDark: isDark),
                  ],
                  
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Atención', icon: Icons.build_circle_rounded, cs: cs),
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      children: [
                        _DetailRow(label: 'Taller', value: incident.workshopName ?? 'Pendiente', icon: Icons.store_rounded, cs: cs),
                        const Divider(height: 20, thickness: 0.5),
                        _DetailRow(label: 'Técnico', value: incident.technicianName ?? 'Pendiente', icon: Icons.person_pin_rounded, cs: cs),
                        const Divider(height: 20, thickness: 0.5),
                        _DetailRow(label: 'Costo Total', value: incident.totalCost != null ? 'Bs ${incident.totalCost!.toStringAsFixed(2)}' : 'N/A', icon: Icons.payments_rounded, cs: cs),
                      ],
                    ),
                    cs: cs,
                    isDark: isDark,
                  ),
                  
                  if (incident.rating != null) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Mi Calificación', icon: Icons.star_rounded, cs: cs),
                    const SizedBox(height: 12),
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(5, (i) => Icon(
                              Icons.star_rounded,
                              size: 20,
                              color: i < (incident.rating!['score'] ?? 0) ? const Color(0xFFFBBF24) : cs.onSurface.withOpacity(0.15),
                            )),
                          ),
                          if (incident.rating!['comment'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              incident.rating!['comment'],
                              style: GoogleFonts.inter(fontSize: 14, fontStyle: FontStyle.italic, color: cs.onSurface),
                            ),
                          ],
                        ],
                      ),
                      cs: cs,
                      isDark: isDark,
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _catLabel(String? cat) {
    const map = {
      'battery': 'Batería', 'tire': 'Llantas', 'engine': 'Motor',
      'towing': 'Remolque', 'ac': 'A/C', 'general': 'General',
      'transmission': 'Transmisión', 'locksmith': 'Cerrajería',
    };
    return map[cat] ?? (cat ?? 'General');
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _LocationHeader extends StatelessWidget {
  final double? lat;
  final double? lng;
  final ColorScheme cs;
  const _LocationHeader({this.lat, this.lng, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) {
      return Container(color: cs.surfaceContainerHigh, child: const Center(child: Icon(Icons.map_rounded, size: 48)));
    }
    final pos = LatLng(lat!, lng!);
    return FlutterMap(
      options: MapOptions(
        initialCenter: pos,
        initialZoom: 15,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.auto_repair_shop',
        ),
        MarkerLayer(markers: [
          Marker(point: pos, child: Icon(Icons.location_on_rounded, color: cs.error, size: 40)),
        ]),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final DateTime date;
  final ColorScheme cs;
  const _StatusBanner({required this.status, required this.date, required this.cs});

  @override
  Widget build(BuildContext context) {
    final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado: $status',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  const _SectionHeader({required this.title, required this.icon, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface.withOpacity(0.7), letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final bool isDark;
  const _InfoCard({required this.child, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  const _DetailRow({required this.label, required this.value, required this.icon, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.4)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.45))),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ],
        ),
      ],
    );
  }
}

class _EvidenceList extends StatelessWidget {
  final List<Map<String, dynamic>> evidences;
  final ColorScheme cs;
  final bool isDark;
  const _EvidenceList({required this.evidences, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: evidences.map((ev) {
          final isAudio = ev['type'] == 'audio';
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.onSurface.withOpacity(0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isAudio)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.audiotrack_rounded, size: 32, color: Color(0xFF6366F1)),
                        const SizedBox(height: 8),
                        Text('Audio', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    Image.network(ev['url']!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded))),
                  
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse(ev['url']!)),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.bottomRight,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black.withOpacity(0.5),
                          child: const Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
