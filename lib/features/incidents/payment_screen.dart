import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/incident.dart';

class PaymentScreen extends StatefulWidget {
  final Incident incident;

  const PaymentScreen({super.key, required this.incident});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _isPaid = false;

  void _handlePayment() async {
    setState(() => _isProcessing = true);
    // Simulación de procesamiento
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isPaid = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isPaid) {
      return _SuccessView(cs: cs);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen y Pago'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _SummaryCard(incident: widget.incident, cs: cs),
            const SizedBox(height: 32),
            _PaymentMethodCard(cs: cs),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Pagar BOB ${widget.incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Incident incident;
  final ColorScheme cs;

  const _SummaryCard({required this.incident, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Color(0xFF6366F1), size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Total a pagar',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'BOB ${incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _BillRow(label: 'Servicio Mecánico', value: 'BOB ${(incident.totalCost ?? 0).toStringAsFixed(2)}', cs: cs),
          const SizedBox(height: 12),
          _BillRow(label: 'Tasa de Servicio (Sist.)', value: 'BOB 0.00', cs: cs),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _BillRow({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final ColorScheme cs;

  const _PaymentMethodCard({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.credit_card_rounded, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visa terminada en 4242',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Vence 12/26',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.3)),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final ColorScheme cs;

  const _SuccessView({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              '¡Pago Exitoso!',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu servicio ha sido finalizado correctamente. Gracias por confiar en nosotros.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: cs.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.onSurface,
                  foregroundColor: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Volver al Inicio',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
