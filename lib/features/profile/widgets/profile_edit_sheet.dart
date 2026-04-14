import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui.dart';

/// Dumb Widget — Bottom Sheet para editar datos del perfil
class ProfileEditSheet extends StatefulWidget {
  final User user;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const ProfileEditSheet({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;

  bool _isSaving = false;
  bool _changePassword = false;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _lastNameCtrl = TextEditingController(text: widget.user.lastName);
    _phoneCtrl = TextEditingController(text: widget.user.phone ?? '');
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _lastNameCtrl, _phoneCtrl, _passwordCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_changePassword && _passwordCtrl.text.isNotEmpty)
        'password': _passwordCtrl.text,
    };

    await widget.onSave(data);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_rounded, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar perfil',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text('El usuario y correo no pueden cambiarse.',
                          style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Nombre y apellido
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _nameCtrl,
                      label: 'Nombre',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _lastNameCtrl,
                      label: 'Apellido',
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _phoneCtrl,
                label: 'Teléfono (opcional)',
                hint: '+58 412-000-0000',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),

              // Toggle cambiar contraseña
              InkWell(
                onTap: () => setState(() => _changePassword = !_changePassword),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outline.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Cambiar contraseña',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                      ),
                      Switch(
                        value: _changePassword,
                        onChanged: (v) => setState(() => _changePassword = v),
                        activeColor: cs.primary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_changePassword) ...[
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'Nueva contraseña',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.done,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20, color: cs.onSurface.withOpacity(0.45),
                    ),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (!_changePassword) return null;
                    if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      text: 'Cancelar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'Guardar',
                      isLoading: _isSaving,
                      onPressed: _save,
                      icon: Icons.check_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
