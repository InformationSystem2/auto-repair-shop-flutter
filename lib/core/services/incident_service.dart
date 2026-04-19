import 'dart:io';
import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';
import '../models/incident.dart';

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
