import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isCodeSent = false;
  String _sentEmail = '';
  String? _devCode;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRecoveryCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.forgotPassword(
      _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      _showError(result.message);
      return;
    }

    setState(() {
      _isCodeSent = true;
      _sentEmail = _emailCtrl.text.trim();
      _devCode = result.code;
      if (_devCode != null) {
        _codeCtrl.text = _devCode!;
      }
    });
    _showSuccess(result.message);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.resetPassword(
      _sentEmail,
      _codeCtrl.text.trim(),
      _newPasswordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      _showError(result.message);
      return;
    }

    _showSuccess(result.message);
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _backToEmail() {
    setState(() {
      _isCodeSent = false;
      _codeCtrl.clear();
      _newPasswordCtrl.clear();
      _devCode = null;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF0F4FF), const Color(0xFFFAFAFE)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 72),
                    _buildHeader(cs),
                    const SizedBox(height: 48),
                    if (!_isCodeSent) _buildEmailForm(cs),
                    if (_isCodeSent) _buildCodeForm(cs),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back_rounded,
                      color: cs.onSurface.withOpacity(0.6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.lock_reset_rounded,
              size: 30, color: AppColors.accent),
        ),
        const SizedBox(height: 20),
        Text(
          _isCodeSent ? 'Restablecer Contraseña' : 'Recuperar Contraseña',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isCodeSent
              ? 'Ingresa el código y tu nueva contraseña'
              : 'Te enviaremos un código a tu correo',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailForm(ColorScheme cs) {
    return Column(
      children: [
        AppTextField(
          controller: _emailCtrl,
          label: 'Correo Electrónico',
          hint: 'correo@ejemplo.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
            if (!v.contains('@')) return 'Correo inválido';
            return null;
          },
        ),
        const SizedBox(height: 28),
        AppButton(
          text: 'Enviar Código',
          onPressed: _sendRecoveryCode,
          isLoading: _isLoading,
          icon: Icons.send_rounded,
        ),
      ],
    );
  }

  Widget _buildCodeForm(ColorScheme cs) {
    return Column(
      children: [
        if (_devCode != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.2)),
            ),
            child: Text(
              'DEV: $_devCode',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        AppTextField(
          controller: _codeCtrl,
          label: 'Código de Verificación',
          hint: '000000',
          prefixIcon: Icons.verified_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Ingresa el código';
            if (v.trim().length != 6) return 'Debe tener 6 dígitos';
            return null;
          },
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _newPasswordCtrl,
          label: 'Nueva Contraseña',
          hint: 'Mínimo 8 caracteres',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Ingresa tu nueva contraseña';
            if (v.length < 8) return 'Mínimo 8 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _backToEmail,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: cs.outline.withOpacity(0.3)),
                ),
                child: Text(
                  'Volver',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                text: 'Restablecer',
                onPressed: _resetPassword,
                isLoading: _isLoading,
                icon: Icons.check_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
