import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/vehicle.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui.dart';

/// Dumb Widget — tarjeta de un vehículo con acciones editar/eliminar
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícono de vehículo ──────────────────────────────────────────────
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.directions_car_rounded, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 16),

          // ── Información ────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildBadge(cs, vehicle.licensePlate, Icons.confirmation_number_outlined),
                    if (vehicle.color != null)
                      _buildBadge(cs, vehicle.color!, Icons.palette_outlined),
                    if (vehicle.transmissionType != null)
                      _buildBadge(
                        cs,
                        vehicle.transmissionType == 'manual' ? 'Manual' : 'Automática',
                        Icons.settings_outlined,
                      ),
                    if (vehicle.fuelType != null)
                      _buildBadge(
                        cs,
                        _fuelLabel(vehicle.fuelType!),
                        Icons.local_gas_station_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Acciones ───────────────────────────────────────────────────────
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: cs.onSurface.withOpacity(0.5), size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: cs.surfaceContainerHighest,
            elevation: 8,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: cs.onSurface),
                  const SizedBox(width: 10),
                  Text('Editar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Text('Eliminar', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fuelLabel(String fuel) {
    const labels = {'gasoline': 'Gasolina', 'diesel': 'Diésel', 'electric': 'Eléctrico', 'hybrid': 'Híbrido'};
    return labels[fuel] ?? fuel;
  }

  Widget _buildBadge(ColorScheme cs, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.outline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
