import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'client_location_map_screen.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() => _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  final _dashboardService = DashboardService();
  final _incidentService = IncidentService();
  final _trackingService = LocationTrackingService();

  TechnicianDashboardData? _stats;
  bool _loading = true;
  String? _error;
  String? _sharingIncidentId;
  String _wsStatus = 'disconnected';
  StreamSubscription<String>? _wsStatusSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _wsStatusSub = _trackingService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _wsStatus = status;
          if (status == 'disconnected' || status == 'error') {
            _sharingIncidentId = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _wsStatusSub?.cancel();
    _trackingService.disconnect();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _dashboardService.getTechnicianStats();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.success) {
        _stats = result.data;
      } else {
        _error = result.message;
      }
    });
  }

  Future<void> _toggleSharing(String incidentId) async {
    if (_sharingIncidentId == incidentId) {
      await _trackingService.disconnect();
      setState(() {
        _sharingIncidentId = null;
      });
    } else {
      setState(() {
        _sharingIncidentId = incidentId;
      });
      await _trackingService.connectAsTechnician(incidentId);
    }
  }

  void _showCompleteDialog(ActiveIncidentItem incident) {
    if (incident.offerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se pudo encontrar el ID de oferta para completar el servicio.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final costCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Completar Servicio',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa el costo final del servicio en Bs para el cliente ${incident.clientName}:',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Costo Total (Bs)',
                  prefixText: 'Bs ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                final cost = double.tryParse(costCtrl.text);
                if (cost == null || cost <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Por favor, ingresa un monto válido.'),
                    backgroundColor: Colors.orange,
                  ));
                  return;
                }
                Navigator.pop(context);
                setState(() => _loading = true);
                
                // Disconnect location tracking if active
                if (_sharingIncidentId == incident.id) {
                  await _trackingService.disconnect();
                }

                final result = await _incidentService.completeOffer(incident.offerId!, cost);
                if (!mounted) return;
                
                if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.message),
                    backgroundColor: Colors.green,
                  ));
                  _loadStats();
                } else {
                  setState(() => _loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result.message),
                    backgroundColor: Colors.red,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Completar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Sección ',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface,
                ),
              ),
              TextSpan(
                text: 'Técnico',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _loadStats,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: cs.error, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadStats,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          )
                        ],
                      ),
                    ),
                  )
                : _buildContent(cs, isDark),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, bool isDark) {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Header
          _buildProfileCard(s, cs, isDark),
          const SizedBox(height: 24),

          // Stat Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Asignados',
                  s.assignedCount.toString(),
                  Icons.assignment_late_outlined,
                  Colors.amber,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'En Progreso',
                  s.inProgressCount.toString(),
                  Icons.run_circle_outlined,
                  Colors.indigo,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Hoy',
                  s.completedToday.toString(),
                  Icons.check_circle_outline_rounded,
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Active Assignments
          Text(
            'Tareas Activas',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 12),
          if (s.activeIncidents.isEmpty)
            _buildEmptyState('No tienes incidentes activos asignados.', Icons.task_alt_rounded, cs)
          else
            ...s.activeIncidents.map((inc) => _buildIncidentCard(inc, cs, isDark)),

          const SizedBox(height: 28),

          // Recent Completed
          if (s.recentCompleted.isNotEmpty) ...[
            Text(
              'Servicios Recientes',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 12),
            ...s.recentCompleted.map((inc) => _buildRecentCompletedCard(inc, cs, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(TechnicianDashboardData s, ColorScheme cs, bool isDark) {
    final initials = s.workshopName.isNotEmpty ? s.workshopName.substring(0, 2).toUpperCase() : 'TC';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: cs.primary.withOpacity(0.12),
            child: Text(
              initials,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.workshopName,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: s.isAvailable ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.isAvailable ? 'Disponible' : 'Ocupado',
                      style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rating',
                style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 2),
                  Text(
                    s.avgRating > 0 ? s.avgRating.toStringAsFixed(1) : '—',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(ActiveIncidentItem inc, ColorScheme cs, bool isDark) {
    final isSharing = _sharingIncidentId == inc.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  inc.clientName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _buildPriorityBadge(inc.aiPriority ?? 'MEDIUM'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Categoría: ${_translateCategory(inc.aiCategory)}',
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleSharing(inc.id),
                  icon: isSharing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.location_on_rounded, size: 16),
                  label: Text(
                    isSharing ? 'Compartiendo GPS...' : 'Compartir GPS',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSharing ? Colors.green : cs.primary.withOpacity(0.1),
                    foregroundColor: isSharing ? Colors.white : cs.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCompleteDialog(inc),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Completar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClientLocationMapScreen(incident: inc),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('Ver Mapa del Cliente',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCompletedCard(RecentCompletedItem inc, ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inc.clientName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  _translateCategory(inc.aiCategory),
                  style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs ${inc.amount.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: cs.primary),
              ),
              if (inc.ratingScore != null)
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    Text(
                      ' ${inc.ratingScore}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.red;
        break;
      case 'HIGH':
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange;
        break;
      case 'MEDIUM':
        bg = Colors.amber.withOpacity(0.15);
        fg = Colors.amber;
        break;
      default:
        bg = Colors.blue.withOpacity(0.15);
        fg = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: cs.onSurface.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

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
}
