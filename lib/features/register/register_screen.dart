import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/services/client_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_notifier.dart';
import '../../shared/widgets/ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos de usuario
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // Datos de cliente
  final _addressCtrl = TextEditingController();
  final _insuranceProviderCtrl = TextEditingController();
  final _policyNumberCtrl = TextEditingController();

  final _clientService = ClientService();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
      _passwordCtrl, _confirmPasswordCtrl,
      _addressCtrl, _insuranceProviderCtrl, _policyNumberCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _clientService.createClient(
      name: _nameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      insuranceProvider: _insuranceProviderCtrl.text.trim().isEmpty ? null : _insuranceProviderCtrl.text.trim(),
      insurancePolicyNumber: _policyNumberCtrl.text.trim().isEmpty ? null : _policyNumberCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      if (!mounted) return;
      await _showSuccessDialog(result.username ?? 'No disponible');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _showSuccessDialog(String username) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Registro Exitoso!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tu cuenta ha sido creada. Este es tu nombre de usuario para iniciar sesión:',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success.withOpacity(0.5)),
              ),
              child: Text(
                username,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Guárdalo en un lugar seguro.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppButton(
              text: 'Entendido, ir al login',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.login_rounded,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = context.read<ThemeNotifier>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Crear cuenta'),
        actions: [
          IconButton(
            onPressed: notifier.toggle,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildHeader(cs, isDark),
                const SizedBox(height: 32),

                // ── Sección: Datos personales ───────────────────────────────
                _buildSection(
                  title: 'Información Personal',
                  children: [
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Nombre',
                      hint: 'Juan',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _lastNameCtrl,
                      label: 'Apellido',
                      hint: 'Pérez',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu apellido' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Teléfono (opcional)',
                      hint: '+58 412-000-0000',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Sección: Credenciales ───────────────────────────────────
                _buildSection(
                  title: 'Credenciales de Acceso',
                  children: [
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Correo electrónico',
                      hint: 'juan@email.com',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresa tu correo';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordCtrl,
                      label: 'Contraseña',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20, color: cs.onSurface.withOpacity(0.45),
                        ),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Elige una contraseña';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirmar contraseña',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20, color: cs.onSurface.withOpacity(0.45),
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (v) {
                        if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Sección: Datos del cliente ──────────────────────────────
                _buildSection(
                  title: 'Datos de Cliente (Opcionales)',
                  children: [
                    AppTextField(
                      controller: _addressCtrl,
                      label: 'Dirección',
                      hint: 'Calle Principal 123',
                      prefixIcon: Icons.location_on_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _insuranceProviderCtrl,
                      label: 'Proveedor de seguro',
                      hint: 'Seguros ABC',
                      prefixIcon: Icons.shield_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _policyNumberCtrl,
                      label: 'Número de póliza',
                      hint: 'POL-000123',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'Crear cuenta',
                  onPressed: _register,
                  isLoading: _isLoading,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.55), fontSize: 14),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Inicia sesión',
                        style: GoogleFonts.inter(
                          color: cs.primary, fontWeight: FontWeight.w700, fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent, isDark ? AppColors.accentDark : const Color(0xFF4F46E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.person_add_rounded, size: 32, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'Únete a AutoRepair',
          style: GoogleFonts.inter(
            fontSize: 24, fontWeight: FontWeight.w900,
            color: cs.onSurface, letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Regístrate para gestionar tus vehículos',
          style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.55)),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(title),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }
}
