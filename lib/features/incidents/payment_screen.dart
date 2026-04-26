import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/models/incident.dart';
import '../../core/services/payment_service.dart';

/// URLs que PayPal usa para redirigir después del flujo de aprobación.
/// El WebView las intercepta en lugar de navegar a ellas.
const _returnUrl = 'https://auxilio-mecanico.app/payment/success';
const _cancelUrl = 'https://auxilio-mecanico.app/payment/cancel';

class PaymentScreen extends StatefulWidget {
  final Incident incident;

  const PaymentScreen({super.key, required this.incident});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _svc = PaymentService();

  bool _isLoading = false;
  bool _isPaid = false;
  String? _error;
  String? _orderId;
  bool _showWebView = false;
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_returnUrl)) {
              // PayPal aprobó — capturar el pago
              _onPayPalApproved();
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(_cancelUrl)) {
              // Usuario canceló
              setState(() => _showWebView = false);
              _showError('Pago cancelado por el usuario.');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _initiatePayPal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await _svc.createOrder(widget.incident.id);
      _orderId = order.orderId;
      _webViewController.loadRequest(Uri.parse(order.approveUrl));
      setState(() {
        _isLoading = false;
        _showWebView = true;
      });
    } catch (e) {
      _showError('No se pudo conectar con PayPal: $e');
    }
  }

  Future<void> _onPayPalApproved() async {
    setState(() {
      _showWebView = false;
      _isLoading = true;
    });
    try {
      final result = await _svc.captureOrder(_orderId!);
      if (result.isCompleted) {
        setState(() {
          _isLoading = false;
          _isPaid = true;
        });
      } else {
        _showError('El pago no pudo completarse. Estado: ${result.status}');
      }
    } catch (e) {
      _showError('Error al confirmar el pago: $e');
    }
  }

  void _showError(String msg) {
    setState(() {
      _isLoading = false;
      _error = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isPaid) return _SuccessView(cs: cs);

    if (_showWebView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('PayPal Checkout'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _showWebView = false),
          ),
        ),
        body: WebViewWidget(controller: _webViewController),
      );
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
            // Método de pago: PayPal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003087).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const _PayPalLogo(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PayPal', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(
                          'Pago seguro via PayPal Sandbox',
                          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: const Color(0xFF009CDE), size: 20),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: cs.error))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiatePayPal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009CDE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24, width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _PayPalLogo(light: true),
                          const SizedBox(width: 10),
                          Text(
                            'Pagar USD ${widget.incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Serás redirigido a PayPal para completar el pago de forma segura.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayPalLogo extends StatelessWidget {
  final bool light;
  const _PayPalLogo({this.light = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Pay',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: light ? Colors.white : const Color(0xFF003087),
            ),
          ),
          TextSpan(
            text: 'Pal',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: light ? const Color(0xFF96C8FB) : const Color(0xFF009CDE),
            ),
          ),
        ],
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
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 32),
          ),
          const SizedBox(height: 16),
          Text('Total a pagar', style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 8),
          Text(
            'USD ${incident.totalCost?.toStringAsFixed(2) ?? "0.00"}',
            style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _BillRow(label: 'Servicio Mecánico', value: 'USD ${(incident.totalCost ?? 0).toStringAsFixed(2)}', cs: cs),
          const SizedBox(height: 10),
          _BillRow(label: 'Incidente #', value: incident.id.substring(0, 8).toUpperCase(), cs: cs),
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
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.65))),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      ],
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
              decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 64),
            ),
            const SizedBox(height: 32),
            Text('¡Pago Exitoso!',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(
              'Tu pago vía PayPal fue procesado correctamente. ¡Gracias por usar Auxilio Mecánico!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: cs.onSurface.withOpacity(0.6), height: 1.5),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Volver al Inicio', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
