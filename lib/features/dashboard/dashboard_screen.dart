import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/vehicle.dart';
import '../../core/services/vehicle_service.dart';
import '../../core/services/dashboard_service.dart';

// Fixed color palette for vehicle bars and category donut
const _kPalette = [
  Color(0xFF6366F1), Color(0xFF22D3EE), Color(0xFFF59E0B),
  Color(0xFFF43F5E), Color(0xFF14B8A6), Color(0xFF8B5CF6),
  Color(0xFFFF7043), Color(0xFF64748B),
];

const _kCatColors = {
  'battery': Color(0xFF6366F1),
  'tire': Color(0xFF22D3EE),
  'engine': Color(0xFFF59E0B),
  'towing': Color(0xFFFF7043),
  'ac': Color(0xFF14B8A6),
  'general': Color(0xFF8B5CF6),
  'transmission': Color(0xFFF43F5E),
  'locksmith': Color(0xFF64748B),
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _vehicleService = VehicleService();
  final _dashboardService = DashboardService();

  List<Vehicle> _vehicles = [];
  bool _vehiclesLoading = true;

  ClientDashboardData? _dashData;
  bool _dashLoading = true;
  String? _dashError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadVehicles(), _loadDashboard()]);
  }

  Future<void> _loadVehicles() async {
    final result = await _vehicleService.getMyVehicles();
    if (!mounted) return;
    setState(() {
      _vehiclesLoading = false;
      if (result.success) _vehicles = result.vehicles;
    });
  }

  Future<void> _loadDashboard() async {
    setState(() => _dashLoading = true);
    final result = await _dashboardService.getClientStats();
    if (!mounted) return;
    setState(() {
      _dashLoading = false;
      if (result.success) {
        _dashData = result.data;
        _dashError = null;
      } else {
        _dashError = result.message;
      }
    });
  }

  // ── Derived display data ───────────────────────────────────────────────────

  List<_VehicleSpend> get _vehicleSpends {
    final list = _dashData?.spendingByVehicle ?? [];
    return list.asMap().entries.map((e) => _VehicleSpend(
      make: e.value.make,
      model: e.value.model,
      plate: e.value.plate,
      amount: e.value.amount,
      color: _kPalette[e.key % _kPalette.length],
    )).toList();
  }

  List<_CategorySpend> get _categorySpends {
    final list = _dashData?.spendingByCategory ?? [];
    return list.asMap().entries.map((e) => _CategorySpend(
      label: e.value.label,
      amount: e.value.amount,
      color: _kCatColors[e.value.category] ?? _kPalette[e.key % _kPalette.length],
    )).toList();
  }

  List<_ServiceRecord> get _serviceHistory {
    final list = _dashData?.serviceHistory ?? [];
    return list.map((item) {
      final d = item.createdAt;
      final dateStr = '${d.day.toString().padLeft(2, '0')} '
          '${_monthName(d.month)} ${d.year}';
      return _ServiceRecord(
        date: dateStr,
        workshop: item.workshopName,
        type: _catLabel(item.aiCategory),
        amount: item.amount,
        rating: item.ratingScore ?? 0,
        status: 'COMPLETED',
      );
    }).toList();
  }

  static String _monthName(int m) {
    const names = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return names[(m - 1).clamp(0, 11)];
  }

  static String _catLabel(String? cat) {
    const map = {
      'battery': 'Batería', 'tire': 'Llantas', 'engine': 'Motor',
      'towing': 'Remolque', 'ac': 'A/C', 'general': 'General',
      'transmission': 'Transmisión', 'locksmith': 'Cerrajería',
    };
    return map[cat] ?? (cat ?? 'General');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = _dashLoading || _vehiclesLoading;

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: _loadAll,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Mi ',
                    style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: 'Dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_dashError != null && _dashData == null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                    const SizedBox(height: 12),
                    Text(
                      _dashError!,
                      style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _loadDashboard, child: const Text('Reintentar')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _MetricRow(
                    totalSpent: _dashData?.totalSpent ?? 0,
                    servicesCount: _dashData?.serviceCount ?? 0,
                    vehicleCount: _dashData?.vehicleCount ?? _vehicles.length,
                    cs: cs,
                  ),
                  const SizedBox(height: 24),
                  if (_vehicleSpends.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Gasto por Vehículo',
                      subtitle: 'Acumulado histórico',
                      cs: cs,
                      child: _VehicleBarChart(
                        spends: _vehicleSpends,
                        total: _dashData?.totalSpent ?? 1,
                        cs: cs,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_categorySpends.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Categoría de Gastos',
                      subtitle: 'Distribución de servicios',
                      cs: cs,
                      child: _CategoryBreakdown(categories: _categorySpends, cs: cs),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: 'Mi Garaje',
                    subtitle: '${_vehicles.length} vehículo(s) registrado(s)',
                    cs: cs,
                    child: _vehicles.isEmpty
                        ? _EmptyGarage(cs: cs)
                        : Column(
                            children: _vehicles
                                .take(3)
                                .map((v) => _GarageItem(vehicle: v, cs: cs))
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Historial de Servicios',
                    subtitle: 'Últimos auxilios mecánicos',
                    cs: cs,
                    child: _serviceHistory.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Sin servicios registrados',
                                style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.4)),
                              ),
                            ),
                          )
                        : Column(
                            children: _serviceHistory
                                .map((s) => _HistoryItem(record: s, cs: cs))
                                .toList(),
                          ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Metric Row ─────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final double totalSpent;
  final int servicesCount;
  final int vehicleCount;
  final ColorScheme cs;

  const _MetricRow({
    required this.totalSpent,
    required this.servicesCount,
    required this.vehicleCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCard(
          label: 'Gastos Totales',
          value: '\$${totalSpent.toStringAsFixed(0)}',
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF6366F1),
          cs: cs,
        )),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(
          label: 'Servicios',
          value: '$servicesCount',
          icon: Icons.build_circle_outlined,
          color: const Color(0xFF22D3EE),
          cs: cs,
        )),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(
          label: 'Vehículos',
          value: '$vehicleCount',
          icon: Icons.directions_car_rounded,
          color: const Color(0xFFF59E0B),
          cs: cs,
        )),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final ColorScheme cs;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.45))),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Vehicle Bar Chart ───────────────────────────────────────────────────────

class _VehicleBarChart extends StatelessWidget {
  final List<_VehicleSpend> spends;
  final double total;
  final ColorScheme cs;

  const _VehicleBarChart({required this.spends, required this.total, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: spends.map((spend) {
        final pct = total > 0 ? spend.amount / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${spend.make} ${spend.model}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                      Text(
                        spend.plate,
                        style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
                      ),
                    ],
                  ),
                  Text(
                    '\$${spend.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: spend.color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: spend.color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(spend.color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(pct * 100).toStringAsFixed(0)}% del total',
                style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withOpacity(0.4)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Category Breakdown ──────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<_CategorySpend> categories;
  final ColorScheme cs;

  const _CategoryBreakdown({required this.categories, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = categories.fold(0.0, (sum, c) => sum + c.amount);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(painter: _DonutPainter(categories: categories, total: total)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                    ),
                    Text(
                      '\$${cat.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: cat.color),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_CategorySpend> categories;
  final double total;

  _DonutPainter({required this.categories, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -pi / 2;
    for (final cat in categories) {
      final sweep = total > 0 ? (cat.amount / total) * 2 * pi : 0.0;
      paint.color = cat.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle, sweep, false, paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Garage Item ─────────────────────────────────────────────────────────────

class _GarageItem extends StatelessWidget {
  final Vehicle vehicle;
  final ColorScheme cs;

  const _GarageItem({required this.vehicle, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_car_rounded, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                Text(
                  vehicle.subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: vehicle.isActive ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              vehicle.isActive ? 'Activo' : 'Inactivo',
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: vehicle.isActive ? Colors.green.shade700 : Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyGarage({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.directions_car_outlined, size: 40, color: cs.onSurface.withOpacity(0.25)),
            const SizedBox(height: 8),
            Text(
              'Sin vehículos registrados',
              style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Service History Item ────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  final _ServiceRecord record;
  final ColorScheme cs;

  const _HistoryItem({required this.record, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.build_rounded, color: Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.type,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                Text(
                  record.workshop,
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                ),
                Text(
                  record.date,
                  style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withOpacity(0.35)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${record.amount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: cs.onSurface),
              ),
              const SizedBox(height: 4),
              if (record.rating > 0)
                Row(
                  children: List.generate(5, (i) => Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: i < record.rating ? const Color(0xFFFBBF24) : cs.onSurface.withOpacity(0.15),
                  )),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Private display models ───────────────────────────────────────────────────

class _VehicleSpend {
  final String make;
  final String model;
  final String plate;
  final double amount;
  final Color color;

  const _VehicleSpend({
    required this.make, required this.model, required this.plate,
    required this.amount, required this.color,
  });
}

class _CategorySpend {
  final String label;
  final double amount;
  final Color color;

  const _CategorySpend({required this.label, required this.amount, required this.color});
}

class _ServiceRecord {
  final String date;
  final String workshop;
  final String type;
  final double amount;
  final int rating;
  final String status;

  const _ServiceRecord({
    required this.date, required this.workshop, required this.type,
    required this.amount, required this.rating, required this.status,
  });
}
