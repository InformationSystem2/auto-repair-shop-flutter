import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, outline, destructive, ghost }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
  });

  const AppButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.destructive({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = cs.primary;

    Color bg, fg;
    BorderSide? side;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = accent;
        fg = Colors.white;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = accent;
        side = BorderSide(color: accent, width: 2);
      case AppButtonVariant.destructive:
        bg = AppColors.danger;
        fg = Colors.white;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = accent;
    }

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(text,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: fg,
                  )),
            ],
          );

    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: variant == AppButtonVariant.primary ? (isDark ? 0 : 2) : 0,
          shadowColor: accent.withOpacity(0.3),
          side: side,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: cs.outline.withOpacity(0.3),
          disabledForegroundColor: cs.onSurface.withOpacity(0.4),
        ),
        child: child,
      ),
    );

    if (!fullWidth) {
      return btn;
    }
    return SizedBox(width: double.infinity, child: btn);
  }
}
