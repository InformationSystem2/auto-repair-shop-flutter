import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Equivalent to Angular's `label[appLabel]` — uppercase section title
class AppSectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsets? padding;

  const AppSectionTitle(this.text, {super.key, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding ?? const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withOpacity(0.45),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
