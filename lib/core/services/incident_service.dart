import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';
import '../models/incident.dart';
import '../storage/local_storage.dart';

class IncidentService {
  final _dio = DioClient.instance.dio;

  Future<({bool success, String message, Incident? incident})> requestHelp(
      IncidentCreate payload) async {
    try {
      final response = await _dio.post(
        '${AppConfig.incidentsEndpoint}/request-help',
        data: payload.toJson(),
      );
      final incident =
          Incident.fromJson(response.data as Map<String, dynamic>);
      return (success: true, message: incident.message, incident: incident);
    } on DioException catch (e) {
      return (success: false, message: _extractError(e), incident: null);
    }
  }

  /// Procesa la solicitud de auxilio que quedó guardada sin conexión:
  /// 1. Sube cada archivo de evidencia que solo existe localmente → obtiene su
  ///    `file_url` del backend (donde la IA luego lo analiza).
  /// 2. Envía el `request-help` con las URLs ya resueltas.
  /// 3. En caso de éxito, borra los archivos locales y limpia el flag pendiente.
  ///
  /// Devuelve el incidente creado, o null si no hay pendiente / sigue sin red /
  /// falla (en cuyo caso se conserva la solicitud para reintentar luego).
  Future<Incident?> syncPendingOffline() async {
    final pending = await LocalStorage.getPendingIncident();
    if (pending == null) return null;

    // Sin conexión no se puede subir nada: se mantiene para el próximo intento.
    if (!await DioClient.instance.hasNetwork()) return null;

    final rawEvidences = (pending['evidences'] as List?) ?? [];
    final List<EvidenceData> resolved = [];

    for (final raw in rawEvidences) {
      final ev = EvidenceData.fromStorageJson(
          Map<String, dynamic>.from(raw as Map));

      if (ev.isUploaded) {
        resolved.add(ev);
        continue;
      }

      final localPath = ev.localPath;
      if (localPath == null) continue;
      final file = File(localPath);
      if (!await file.exists()) continue; // archivo perdido → se omite

      final up = await uploadEvidence(file);
      if (!up.success || up.fileUrl == null) {
        // Falló la subida (volvió a caer la red o error del server) → abortar
        // y conservar la solicitud completa para reintentar más tarde.
        return null;
      }
      resolved.add(EvidenceData(
        type: up.evidenceType ?? ev.type,
        fileUrl: up.fileUrl!,
      ));
    }

    final payload = IncidentCreate(
      description: pending['description'] as String?,
      vehicleId: pending['vehicle_id'] as String,
      latitude: (pending['latitude'] as num).toDouble(),
      longitude: (pending['longitude'] as num).toDouble(),
      evidences: resolved,
    );

    final result = await requestHelp(payload);
    if (result.success && result.incident != null) {
      // Limpieza: borrar copias locales y liberar el bloqueo.
      for (final raw in rawEvidences) {
        final lp = (raw as Map)['local_path'] as String?;
        if (lp != null) {
          try {
            await File(lp).delete();
          } catch (_) {}
        }
      }
      await LocalStorage.clearPendingIncident();
      return result.incident;
    }

    return null;
  }

  Future<({bool success, String? fileUrl, String? evidenceType})> uploadEvidence(
      File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await _dio.post(
        AppConfig.uploadEvidenceEndpoint,
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      return (
        success: true,
        fileUrl: data['file_url'] as String?,
        evidenceType: data['evidence_type'] as String?,
      );
    } on DioException {
      return (success: false, fileUrl: null, evidenceType: null);
    }
  }

  Future<Incident?> getIncident(String id) async {
    try {
      final response = await _dio.get('${AppConfig.incidentsEndpoint}/$id');
      return Incident.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('[IncidentService] Error loading incident: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  Future<Incident?> getMyActiveIncident() async {
    try {
      final response = await _dio.get('${AppConfig.incidentsEndpoint}/my-active');
      if (response.data == null) return null;
      return Incident.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Incidente completado pero aún SIN PAGAR del cliente (o null).
  /// Se usa para forzar el pago antes de permitir otra solicitud.
  Future<Incident?> getPendingPaymentIncident() async {
    try {
      final response =
          await _dio.get('${AppConfig.incidentsEndpoint}/pending-payment');
      if (response.data == null) return null;
      return Incident.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> addExtraEvidence(String incidentId, List<EvidenceData> evidences) async {
    try {
      await _dio.post(
        '${AppConfig.incidentsEndpoint}/$incidentId/evidence',
        data: {
          'evidences': evidences.map((e) => e.toJson()).toList(),
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<({bool success, String message})> cancelIncident(String id) async {
    try {
      final response = await _dio.post('${AppConfig.incidentsEndpoint}/$id/cancel');
      final data = response.data as Map<String, dynamic>;
      return (
        success: true,
        message: data['message'] as String? ?? 'Incidente cancelado correctamente'
      );
    } on DioException catch (e) {
      return (success: false, message: _extractError(e));
    }
  }

  Future<({bool success, String message})> completeOffer(String offerId, double cost) async {
    try {
      final response = await _dio.post(
        '${AppConfig.apiUrl}/api/offers/$offerId/complete',
        data: {'cost': cost},
      );
      final data = response.data as Map<String, dynamic>;
      return (
        success: true,
        message: data['message'] as String? ?? 'Servicio completado exitosamente'
      );
    } on DioException catch (e) {
      return (success: false, message: _extractError(e));
    }
  }

  String _extractError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
      return 'Error en la operación';
    } catch (_) {
      return e.message ?? 'Error de conexión';
    }
  }
}
