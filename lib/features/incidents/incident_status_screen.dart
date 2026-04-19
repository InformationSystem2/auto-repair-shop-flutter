import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/incident.dart';

class IncidentStatusScreen extends StatelessWidget {
  final Incident incident;

  const IncidentStatusScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado del Auxilio'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBanner(status: incident.status, cs: cs),
            const SizedBox(height: 24),
            _InfoCard(
              title: 'Información del incidente',
              cs: cs,
              children: [
                _InfoRow(
                  label: 'ID',
                  value: incident.id.substring(0, 8).toUpperCase(),
                  cs: cs,
                ),
                _InfoRow(
                  label: 'Estado',
                  value: _statusLabel(incident.status),
                  cs: cs,
                ),
                if (incident.estimatedArrivalMin != null)
                  _InfoRow(
                    label: 'Tiempo estimado',
                    value: '${incident.estimatedArrivalMin} minutos',
                    cs: cs,
                    valueColor: cs.primary,
                  ),
              ],
            ),
            if (incident.aiCategory != null || incident.aiPriority != null) ...[
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Análisis de IA',
                cs: cs,
                children: [
                  if (incident.aiCategory != null)
                    _InfoRow(
                      label: 'Categoría',
                      value: incident.aiCategory!,
                      cs: cs,
                    ),
                  if (incident.aiPriority != null)
                    _InfoRow(
                      label: 'Prioridad',
                      value: incident.aiPriority!,
                      cs: cs,
                      valueColor: _priorityColor(incident.aiPriority!, cs),
                    ),
                  if (incident.aiConfidence != null)
                    _InfoRow(
                      label: 'Confianza',
                      value:
                          '${(incident.aiConfidence! * 100).toStringAsFixed(0)}%',
                      cs: cs,
                    ),
                  if (incident.aiSummary != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Resumen',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.55),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident.aiSummary!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Volver al inicio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    const labels = {
      'PENDING': 'Pendiente',
      'ANALYZING': 'Analizando...',
      'PENDING_INFO': 'Más información requerida',
      'MATCHED': 'Taller asignado',
      'ASSIGNED': 'Técnico en camino',
      'IN_PROGRESS': 'En proceso',
      'COMPLETED': 'Completado',
      'CANCELLED': 'Cancelado',
      'NO_OFFERS': 'Sin talleres disponibles',
      'ERROR': 'Error',
    };
    return labels[status] ?? status;
  }

  Color _priorityColor(String priority, ColorScheme cs) {
    switch (priority) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MEDIUM':
        return const Color(0xFFD97706);
      default:
        return cs.onSurface;
    }
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final ColorScheme cs;

  const _StatusBanner({required this.status, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isAnalyzing = status == 'ANALYZING' || status == 'PENDING';
    final isOk = ['MATCHED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED']
        .contains(status);
    final isError =
        status == 'ERROR' || status == 'NO_OFFERS' || status == 'CANCELLED';

    final color = isError
        ? const Color(0xFFDC2626)
        : isOk
            ? const Color(0xFF16A34A)
            : cs.primary;

    final icon = isError
        ? Icons.error_outline_rounded
        : isOk
            ? Icons.check_circle_outline_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          if (isAnalyzing)
            CircularProgressIndicator(color: color, strokeWidth: 3)
          else
            Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            isAnalyzing
                ? 'Solicitud enviada'
                : isOk
                    ? '¡Auxilio en camino!'
                    : 'Atención requerida',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAnalyzing
                ? 'Estamos analizando tu solicitud con IA...'
                : isOk
                    ? 'Un técnico fue asignado a tu caso'
                    : 'No pudimos procesar tu solicitud',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ColorScheme cs;

  const _InfoCard(
      {required this.title, required this.children, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.55),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;

  const _InfoRow(
      {required this.label,
      required this.value,
      required this.cs,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
