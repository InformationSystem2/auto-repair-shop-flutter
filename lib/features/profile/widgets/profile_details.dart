import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/user.dart';
import '../../../shared/widgets/ui.dart';

/// Dumb Widget — Cuadrícula de datos de contacto y lista de roles
class ProfileDetails extends StatelessWidget {
  final User user;

  const ProfileDetails({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Información de contacto ─────────────────────────────────────────
        const AppSectionTitle('Información de contacto'),
        AppCard(
          child: Column(
            children: [
              _InfoRow(context, Icons.mail_outline_rounded, 'Correo electrónico', user.email),
              Divider(height: 28, color: cs.outline.withOpacity(0.5)),
              _InfoRow(context, Icons.phone_outlined, 'Teléfono',
                  user.phone?.isNotEmpty == true ? user.phone! : 'Sin registrar'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Roles ────────────────────────────────────────────────────────────
        const AppSectionTitle('Roles asignados'),
        if (user.roles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('Sin roles asignados',
                style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.45), fontSize: 14)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.roles
                .map((r) => AppBadge(r.displayName, variant: AppBadgeVariant.primary))
                .toList(),
          ),

        const SizedBox(height: 24),

        // ── Cuenta ───────────────────────────────────────────────────────────
        const AppSectionTitle('Cuenta'),
        AppCard(
          child: Column(
            children: [
              _InfoRow(context, Icons.calendar_today_outlined, 'Miembro desde',
                  _formatDate(user.createdAt)),
              Divider(height: 28, color: cs.outline.withOpacity(0.5)),
              _InfoRow(context, Icons.update_rounded, 'Última actualización',
                  _formatDate(user.updatedAt)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _InfoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withOpacity(0.4),
                      letterSpacing: 0.7)),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(rawDate);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }
}
