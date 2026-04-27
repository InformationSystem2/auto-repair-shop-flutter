import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/incident.dart';
import '../../core/services/rating_service.dart';

class RatingScreen extends StatefulWidget {
  final String incidentId;
  const RatingScreen({super.key, required this.incidentId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _score = 5;
  int _timeScore = 5;
  int _qualityScore = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  final _ratingService = RatingService();

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final success = await _ratingService.postRating(
      incidentId: widget.incidentId,
      score: _score,
      responseTimeScore: _timeScore,
      qualityScore: _qualityScore,
      comment: _commentController.text.isEmpty ? null : _commentController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar la calificación')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar Servicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cómo fue tu experiencia?', 
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 32),
            _buildStarPicker('Puntuación General', _score, (v) => setState(() => _score = v), cs),
            _buildStarPicker('Tiempo de Respuesta', _timeScore, (v) => setState(() => _timeScore = v), cs),
            _buildStarPicker('Calidad del Trabajo', _qualityScore, (v) => setState(() => _qualityScore = v), cs),
            const SizedBox(height: 24),
            Text('Comentarios (opcional)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Cuéntanos más sobre el servicio...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar Calificación', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
              child: const Center(child: Text('Omitir por ahora')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarPicker(String label, int current, Function(int) onSelect, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.7))),
          Row(
            children: List.generate(5, (index) {
              final val = index + 1;
              return IconButton(
                icon: Icon(
                  val <= current ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: val <= current ? const Color(0xFFFBBF24) : cs.onSurface.withOpacity(0.2),
                  size: 32,
                ),
                onPressed: () => onSelect(val),
              );
            }),
          ),
        ],
      ),
    );
  }
}
