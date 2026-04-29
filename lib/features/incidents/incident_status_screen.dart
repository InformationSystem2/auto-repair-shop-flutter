import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/models/incident.dart';
import '../../core/services/incident_service.dart';
import 'payment_screen.dart';
import 'technician_tracking_screen.dart';

class IncidentStatusScreen extends StatefulWidget {
  final Incident incident;

  const IncidentStatusScreen({super.key, required this.incident});

  @override
  State<IncidentStatusScreen> createState() => _IncidentStatusScreenState();
}

class _IncidentStatusScreenState extends State<IncidentStatusScreen> {
  late Incident _currentIncident;
  Timer? _timer;
  bool _isChecking = false;
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _navigatedToTracking = false;

  @override
  void initState() {
    super.initState();
    _currentIncident = widget.incident;
    _startPolling();
    // If already assigned when screen opens, go to tracking
    if (_currentIncident.status == 'ASSIGNED' || _currentIncident.status == 'IN_PROGRESS') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToTracking());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 5 seconds if the incident is not in a final state
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isChecking) {
        _checkStatus();
      }
    });
  }

  Future<void> _checkStatus() async {
    // If status is final, stop polling
    if (['COMPLETED', 'CANCELLED', 'NO_OFFERS', 'ERROR']
        .contains(_currentIncident.status)) {
      _timer?.cancel();
      return;
    }

    setState(() => _isChecking = true);
    final updatedIncident =
        await IncidentService().getIncident(_currentIncident.id);

    if (updatedIncident != null && mounted) {
      final prevStatus = _currentIncident.status;
      setState(() {
        _currentIncident = updatedIncident;
        _isChecking = false;
      });

      if (_currentIncident.status == 'COMPLETED') {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentScreen(incident: _currentIncident),
          ),
        );
        return;
      }

      // Auto-redirect to tracking when technician gets assigned
      if (!_navigatedToTracking &&
          prevStatus != 'ASSIGNED' && prevStatus != 'IN_PROGRESS' &&
          (_currentIncident.status == 'ASSIGNED' || _currentIncident.status == 'IN_PROGRESS')) {
        _goToTracking();
      }
    } else {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado del Auxilio'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isChecking)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusBanner(status: _currentIncident.status, cs: cs),
              const SizedBox(height: 24),
              
              if (_currentIncident.status == 'PENDING_INFO' || _currentIncident.status == 'ERROR')
                _PendingInfoAction(
                  cs: cs,
                  onUpload: _handleExtraEvidence,
                  isError: _currentIncident.status == 'ERROR',
                ),

              _InfoCard(
                title: 'Información del incidente',
                cs: cs,
                children: [
                  _InfoRow(
                    label: 'ID',
                    value: _currentIncident.id.substring(0, 8).toUpperCase(),
                    cs: cs,
                  ),
                  _InfoRow(
                    label: 'Estado',
                    value: _statusLabel(_currentIncident.status),
                    cs: cs,
                  ),
                  if (_currentIncident.estimatedArrivalMin != null)
                    _InfoRow(
                      label: 'Tiempo estimado',
                      value: '${_currentIncident.estimatedArrivalMin} minutos',
                      cs: cs,
                      valueColor: cs.primary,
                    ),
                ],
              ),
              if (_currentIncident.aiCategory != null ||
                  _currentIncident.aiPriority != null) ...[
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Análisis de IA',
                  cs: cs,
                  children: [
                    if (_currentIncident.aiCategory != null)
                      _InfoRow(
                        label: 'Categoría',
                        value: _currentIncident.aiCategory!,
                        cs: cs,
                      ),
                    if (_currentIncident.aiPriority != null)
                      _InfoRow(
                        label: 'Prioridad',
                        value: _currentIncident.aiPriority!,
                        cs: cs,
                        valueColor: _priorityColor(_currentIncident.aiPriority!, cs),
                      ),
                    if (_currentIncident.aiConfidence != null)
                      _InfoRow(
                        label: 'Confianza',
                        value:
                            '${(_currentIncident.aiConfidence! * 100).toStringAsFixed(0)}%',
                        cs: cs,
                      ),
                    if (_currentIncident.aiSummary != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Resumen',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withOpacity(0.55),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentIncident.aiSummary!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              
              if (_currentIncident.evidenceUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Evidencias Recibidas',
                  cs: cs,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentIncident.evidenceUrls.map((e) {
                        final isAudio = e['type'] == 'audio';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAudio ? Icons.mic_rounded : Icons.image_rounded,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAudio ? 'Audio' : 'Imagen',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
              if (_currentIncident.status == 'ASSIGNED' ||
                  _currentIncident.status == 'IN_PROGRESS') ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_car_rounded,
                              color: Color(0xFF6366F1), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Técnico en camino',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                      if (_currentIncident.estimatedArrivalMin != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_currentIncident.estimatedArrivalMin}',
                              style: GoogleFonts.inter(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF6366F1),
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'min\nestimados',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF6366F1).withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Workshop + Technician assignment card
              if (_currentIncident.workshopName != null || _currentIncident.technicianName != null) ...[
                const SizedBox(height: 16),
                _AssignmentCard(incident: _currentIncident, cs: cs),
              ],

              const SizedBox(height: 32),

              // Track button when in transit
              if (_currentIncident.status == 'ASSIGNED' || _currentIncident.status == 'IN_PROGRESS') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToTracking,
                    icon: const Icon(Icons.location_on_rounded),
                    label: Text(
                      'Ver técnico en tiempo real',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    '/home', (route) => false,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Ir al inicio',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToTracking() {
    if (!mounted || _navigatedToTracking) return;
    _navigatedToTracking = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TechnicianTrackingScreen(
          incidentId: _currentIncident.id,
          clientLat: _currentIncident.lat,
          clientLng: _currentIncident.lng,
          technicianName: _currentIncident.technicianName,
          workshopName: _currentIncident.workshopName,
        ),
      ),
    );
  }

  Future<void> _handleExtraEvidence() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _EvidenceTypeSheet(
        onSelected: (type) {
          Navigator.pop(context);
          if (type == 'image') _pickImage();
          if (type == 'audio') _showAudioRecordingSheet();
          if (type == 'text') _showTextDialog();
        },
      ),
    );
  }

  void _showAudioRecordingSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _AudioRecordingSheet(
          isRecording: _isRecording,
          onToggle: () async {
            if (_isRecording) {
              final path = await _audioRecorder.stop();
              setState(() => _isRecording = false);
              setSheetState(() => _isRecording = false);
              if (path != null) {
                Navigator.pop(context);
                _uploadFile(File(path), 'audio');
              }
            } else {
              final hasPermission = await _audioRecorder.hasPermission();
              if (!hasPermission) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permiso de micrófono denegado'), backgroundColor: Colors.red),
                );
                return;
              }
              final dir = await getTemporaryDirectory();
              final filePath = '${dir.path}/extra_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
              await _audioRecorder.start(const RecordConfig(), path: filePath);
              setState(() => _isRecording = true);
              setSheetState(() => _isRecording = true);
            }
          },
          onCancel: () async {
            if (_isRecording) await _audioRecorder.stop();
            setState(() => _isRecording = false);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    _uploadFile(File(image.path), 'image');
  }

  Future<void> _showTextDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información Adicional'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe con más detalle lo que sucede para que la IA pueda ayudarte.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Ej: El motor hace un ruido metálico al acelerar...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            child: const Text('Enviar Detalles'),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      _sendExtraInfo([EvidenceData(type: 'text', fileUrl: '', transcription: text)]);
    }
  }

  Future<void> _uploadFile(File file, String type) async {
    setState(() => _isChecking = true);
    try {
      final service = IncidentService();
      final uploadResult = await service.uploadEvidence(file);
      if (uploadResult.success && uploadResult.fileUrl != null) {
        _sendExtraInfo([EvidenceData(type: type, fileUrl: uploadResult.fileUrl!)]);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _sendExtraInfo(List<EvidenceData> evidences) async {
    setState(() => _isChecking = true);
    try {
      final success = await IncidentService().addExtraEvidence(_currentIncident.id, evidences);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información enviada. Re-analizando...')),
        );
        _checkStatus();
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  String _statusLabel(String status) {
    const labels = {
      'PENDING': 'Pendiente',
      'ANALYZING': 'Analizando...',
      'PENDING_INFO': 'Más información requerida',
      'MATCHED': 'Taller asignado',
      'ASSIGNED': 'Técnico en camino',
      'IN_PROGRESS': 'En proceso',
      'COMPLETED': 'Completado',
      'CANCELLED': 'Cancelado',
      'NO_OFFERS': 'Sin talleres disponibles',
      'ERROR': 'Error',
    };
    return labels[status] ?? status;
  }

  Color _priorityColor(String priority, ColorScheme cs) {
    switch (priority) {
      case 'CRITICAL':
        return const Color(0xFFDC2626);
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MEDIUM':
        return const Color(0xFFD97706);
      default:
        return cs.onSurface;
    }
  }
}

class _PendingInfoAction extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onUpload;
  final bool isError;

  const _PendingInfoAction({
    required this.cs,
    required this.onUpload,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFDC2626) : Colors.amber;
    final bgColor = color.withOpacity(0.1);
    final borderColor = color.withOpacity(0.5);
    final textColor = isError ? color : Colors.amber.shade900;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isError 
                    ? 'Hubo un error en el análisis, pero puedes intentar subir más fotos para ayudar a la IA.'
                    : 'La IA necesita más detalles para ayudarte mejor.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Agregar más detalles'),
              style: TextButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceTypeSheet extends StatelessWidget {
  final Function(String) onSelected;

  const _EvidenceTypeSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Qué deseas agregar?',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          _TypeTile(
            icon: Icons.camera_alt_rounded,
            label: 'Enviar Foto',
            subtitle: 'Muestra el problema visualmente',
            onTap: () => onSelected('image'),
            cs: cs,
          ),
          const SizedBox(height: 12),
          _TypeTile(
            icon: Icons.mic_rounded,
            label: 'Enviar Audio',
            subtitle: 'Explica el ruido o situación',
            onTap: () => onSelected('audio'),
            cs: cs,
          ),
          const SizedBox(height: 12),
          _TypeTile(
            icon: Icons.text_fields_rounded,
            label: 'Escribir Texto',
            subtitle: 'Detalla lo que sucede',
            onTap: () => onSelected('text'),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

class _AudioRecordingSheet extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onToggle;
  final VoidCallback onCancel;

  const _AudioRecordingSheet({
    required this.isRecording,
    required this.onToggle,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRecording ? 'Grabando audio...' : 'Listo para grabar',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            isRecording ? 'Pulsa el botón para detener y enviar' : 'Pulsa el micrófono para empezar',
            style: GoogleFonts.inter(color: cs.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isRecording ? Colors.red : cs.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? Colors.red : cs.primary).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: onCancel,
            child: Text('Cancelar', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final ColorScheme cs;

  const _StatusBanner({required this.status, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isAnalyzing = status == 'ANALYZING' || status == 'PENDING';
    final isOk = ['MATCHED', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED']
        .contains(status);
    final isError =
        status == 'ERROR' || status == 'NO_OFFERS' || status == 'CANCELLED';
    final isPendingInfo = status == 'PENDING_INFO';

    final color = isError
        ? const Color(0xFFDC2626)
        : isOk
            ? const Color(0xFF16A34A)
            : isPendingInfo
                ? Colors.amber.shade800
                : cs.primary;

    final icon = isError
        ? Icons.error_outline_rounded
        : isOk
            ? Icons.check_circle_outline_rounded
            : isPendingInfo
                ? Icons.warning_amber_rounded
                : Icons.hourglass_top_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          if (isAnalyzing)
            CircularProgressIndicator(color: color, strokeWidth: 3)
          else
            Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            isAnalyzing
                ? 'Solicitud enviada'
                : isOk
                    ? '¡Auxilio en camino!'
                    : isPendingInfo
                        ? 'Acción requerida'
                        : 'Atención requerida',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isAnalyzing
                ? 'Estamos analizando tu solicitud con IA...'
                : isOk
                    ? 'Un técnico fue asignado a tu caso'
                    : isPendingInfo
                        ? 'La IA necesita más información del problema'
                        : 'No pudimos procesar tu solicitud',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final ColorScheme cs;

  const _InfoCard(
      {required this.title, required this.children, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.55),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final Color? valueColor;

  const _InfoRow(
      {required this.label,
      required this.value,
      required this.cs,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Incident incident;
  final ColorScheme cs;
  const _AssignmentCard({required this.incident, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Color(0x4D6366F1), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Servicio asignado',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.white70, letterSpacing: 1)),
          ]),
          const SizedBox(height: 16),
          if (incident.workshopName != null)
            _AssignRow(icon: Icons.store_rounded, label: 'Taller', value: incident.workshopName!),
          if (incident.workshopName != null && incident.technicianName != null) const SizedBox(height: 10),
          if (incident.technicianName != null)
            _AssignRow(icon: Icons.engineering_rounded, label: 'Técnico', value: incident.technicianName!),
          if (incident.estimatedArrivalMin != null) ...[
            const SizedBox(height: 10),
            _AssignRow(icon: Icons.timer_rounded, label: 'Tiempo estimado',
                value: '${incident.estimatedArrivalMin} minutos'),
          ],
        ],
      ),
    );
  }
}

class _AssignRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _AssignRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54,
            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        Text(value, style: GoogleFonts.inter(fontSize: 15, color: Colors.white,
            fontWeight: FontWeight.w800)),
      ]),
    ]);
  }
}
