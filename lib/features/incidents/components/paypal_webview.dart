import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaypalWebView extends StatefulWidget {
  final String approveUrl;
  final String returnUrl;
  final String cancelUrl;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const PaypalWebView({
    super.key,
    required this.approveUrl,
    required this.returnUrl,
    required this.cancelUrl,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaypalWebView> createState() => _PaypalWebViewState();
}

class _PaypalWebViewState extends State<PaypalWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _callbackTriggered = false;

  void _triggerSuccess() {
    if (_callbackTriggered) return;
    _callbackTriggered = true;
    widget.onSuccess();
    Navigator.of(context).pop();
  }

  void _triggerCancel() {
    if (_callbackTriggered) return;
    _callbackTriggered = true;
    widget.onCancel();
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            
            // Si llegamos a la URL de éxito, disparamos el callback y cerramos
            if (url.startsWith(widget.returnUrl)) {
              _triggerSuccess();
            }
            
            // Si llegamos a la URL de cancelación
            if (url.startsWith(widget.cancelUrl)) {
              _triggerCancel();
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(widget.returnUrl)) {
              _triggerSuccess();
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(widget.cancelUrl)) {
              _triggerCancel();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approveUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayPal Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Cerrar manualmente = cancelar el pago (no se marca como pagado)
            _triggerCancel();
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
