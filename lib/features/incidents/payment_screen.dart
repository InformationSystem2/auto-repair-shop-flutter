import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/incident.dart';
import '../../core/services/payment_service.dart';
import './rating_screen.dart';
import './components/paypal_webview.dart';

class PaymentScreen extends StatefulWidget {
  final Incident incident;

  const PaymentScreen({super.key, required this.incident});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _isPaid = false;

  final _paymentService = PaymentService();

  void _handlePayment() async {
    setState(() => _isProcessing = true);
    
    final result = await _paymentService.createOrder(widget.incident.id);
    
    if (!result.success || result.approveUrl == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Error al iniciar pago')),
        );
      }
      return;
    }

    if (mounted) {
      // Abrimos el WebView
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaypalWebView(
            approveUrl: result.approveUrl!,
            returnUrl: "https://auxilio-mecanico.app/payment/success",
            cancelUrl: "https://auxilio-mecanico.app/payment/cancel",
            onSuccess: () async {
              // Al detectar el retorno exitoso, capturamos la orden
              final captureResult = await _paymentService.captureOrder(result.orderId!);
              if (mounted) {
                if (captureResult.success) {
                  setState(() {
                    _isProcessing = false;
                    _isPaid = true;
                  });
                } else {
                  setState(() => _isProcessing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(captureResult.message ?? 'Error al confirmar pago')),
                  );
                }
              }
            },
            onCancel: () {
              if (mounted) {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pago cancelado por el usuario')),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isPaid) {
      return _SuccessView(cs: cs, incident: widget.incident);
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
                  'PayPal / Tarjeta',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Pago seguro vía PayPal',
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
  final Incident incident;

  const _SuccessView({required this.cs, required this.incident});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Success icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Pago Completado!',
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu servicio ha sido finalizado correctamente.\nGracias por confiar en nosotros.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Payment detail card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            color: Color(0xFF6366F1), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Comprobante de Pago',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Monto pagado',
                      value:
                          'BOB ${incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
                      cs: cs,
                      valueColor: const Color(0xFF16A34A),
                      bold: true,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Referencia',
                      value: incident.id.substring(0, 8).toUpperCase(),
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Fecha y hora',
                      value: dateStr,
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Método',
                      value: 'PayPal',
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Estado',
                      value: 'COMPLETADO',
                      cs: cs,
                      valueColor: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Rate button (primary)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => RatingScreen(incidentId: incident.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: Text(
                    'Calificar el Servicio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Go home button (secondary)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (route) => false),
                  icon: const Icon(Icons.home_rounded),
                  label: Text(
                    'Volver al inicio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.cs,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

