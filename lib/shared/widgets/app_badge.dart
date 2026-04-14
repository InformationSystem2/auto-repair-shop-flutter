import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

enum AppBadgeVariant { primary, success, danger, warning, outline, secondary }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  const AppBadge(
    this.label, {
    super.key,
    this.variant = AppBadgeVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (Color bg, Color fg, Color border) = switch (variant) {
      AppBadgeVariant.primary   => (cs.primary.withOpacity(0.12), cs.primary, cs.primary.withOpacity(0.25)),
      AppBadgeVariant.success   => (AppColors.success.withOpacity(0.1), AppColors.success, AppColors.success.withOpacity(0.25)),
      AppBadgeVariant.danger    => (AppColors.danger.withOpacity(0.1), AppColors.danger, AppColors.danger.withOpacity(0.25)),
      AppBadgeVariant.warning   => (AppColors.warning.withOpacity(0.1), AppColors.warning, AppColors.warning.withOpacity(0.25)),
      AppBadgeVariant.outline   => (Colors.transparent, cs.onSurface.withOpacity(0.7), cs.outline),
      AppBadgeVariant.secondary => (cs.surfaceContainerHigh, cs.onSurface.withOpacity(0.6), cs.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
