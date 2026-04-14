import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/vehicle.dart';
import '../../../shared/widgets/ui.dart';

// Valores válidos según los Enum del backend
const _transmissionOptions = ['manual', 'automatic'];
const _fuelOptions = ['gasoline', 'diesel', 'electric', 'hybrid'];

const _transmissionLabels = {
  'manual': 'Manual',
  'automatic': 'Automática',
};
const _fuelLabels = {
  'gasoline': 'Gasolina',
  'diesel': 'Diésel',
  'electric': 'Eléctrico',
  'hybrid': 'Híbrido',
};

/// Dumb Widget — Bottom Sheet para crear o editar un vehículo
class VehicleFormSheet extends StatefulWidget {
  final Vehicle? vehicle; // null = crear, notNull = editar
  final String clientId;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const VehicleFormSheet({
    super.key,
    this.vehicle,
    required this.clientId,
    required this.onSave,
  });

  @override
  State<VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _makeCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _vinCtrl;

  String? _transmissionType;
  String? _fuelType;

  bool _isSaving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _makeCtrl = TextEditingController(text: v?.make ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _plateCtrl = TextEditingController(text: v?.licensePlate ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');
    _vinCtrl = TextEditingController(text: v?.vin ?? '');
    _yearCtrl = TextEditingController(
      text: v != null ? v.year.toString() : DateTime.now().year.toString(),
    );
    _transmissionType = v?.transmissionType;
    _fuelType = v?.fuelType;
  }

  @override
  void dispose() {
    for (final c in [_makeCtrl, _modelCtrl, _plateCtrl, _colorCtrl, _yearCtrl, _vinCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'make': _makeCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'license_plate': _plateCtrl.text.trim().toUpperCase(),
      'year': int.parse(_yearCtrl.text.trim()),
      if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
      if (_vinCtrl.text.trim().isNotEmpty) 'vin': _vinCtrl.text.trim(),
      if (_transmissionType != null) 'transmission_type': _transmissionType,
      if (_fuelType != null) 'fuel_type': _fuelType,
      if (!_isEditing) 'client_id': widget.clientId,
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

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                      color: cs.primary, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Editar vehículo' : 'Registrar vehículo',
                    style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Marca · Modelo ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _makeCtrl,
                      label: 'Marca',
                      hint: 'Toyota',
                      prefixIcon: Icons.directions_car_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _modelCtrl,
                      label: 'Modelo',
                      hint: 'Corolla',
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Placa · Año ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _plateCtrl,
                      label: 'Placa',
                      hint: 'ABCD-123',
                      prefixIcon: Icons.confirmation_number_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _yearCtrl,
                      label: 'Año',
                      hint: '2020',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final year = int.tryParse(v);
                        if (year == null || year < 1900 || year > 2100) return 'Año inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Color ───────────────────────────────────────────────────────
              AppTextField(
                controller: _colorCtrl,
                label: 'Color (opcional)',
                hint: 'Blanco',
                prefixIcon: Icons.palette_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // ── VIN ─────────────────────────────────────────────────────────
              AppTextField(
                controller: _vinCtrl,
                label: 'VIN (opcional)',
                hint: '1HGBH41JXMN109186',
                prefixIcon: Icons.qr_code_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 17) {
                    return 'El VIN debe tener 17 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Tipo de transmisión ─────────────────────────────────────────
              _buildDropdown(
                cs: cs,
                label: 'Transmisión (opcional)',
                icon: Icons.settings_outlined,
                value: _transmissionType,
                options: _transmissionOptions,
                labels: _transmissionLabels,
                onChanged: (v) => setState(() => _transmissionType = v),
              ),
              const SizedBox(height: 16),

              // ── Tipo de combustible ─────────────────────────────────────────
              _buildDropdown(
                cs: cs,
                label: 'Combustible (opcional)',
                icon: Icons.local_gas_station_outlined,
                value: _fuelType,
                options: _fuelOptions,
                labels: _fuelLabels,
                onChanged: (v) => setState(() => _fuelType = v),
              ),
              const SizedBox(height: 32),

              // ── Botones ─────────────────────────────────────────────────────
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
                      text: _isEditing ? 'Guardar' : 'Registrar',
                      isLoading: _isSaving,
                      onPressed: _save,
                      icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
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

  Widget _buildDropdown({
    required ColorScheme cs,
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required Map<String, String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.25)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
          prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        dropdownColor: cs.surface,
        borderRadius: BorderRadius.circular(14),
        style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('Sin especificar', style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.45))),
          ),
          ...options.map((opt) => DropdownMenuItem<String>(
                value: opt,
                child: Text(labels[opt] ?? opt),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
