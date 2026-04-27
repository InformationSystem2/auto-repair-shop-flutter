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
              widget.onSuccess();
              Navigator.of(context).pop();
            }
            
            // Si llegamos a la URL de cancelación
            if (url.startsWith(widget.cancelUrl)) {
              widget.onCancel();
              Navigator.of(context).pop();
            }
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(widget.returnUrl)) {
              widget.onSuccess();
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith(widget.cancelUrl)) {
              widget.onCancel();
              Navigator.of(context).pop();
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
          onPressed: () => Navigator.of(context).pop(),
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
