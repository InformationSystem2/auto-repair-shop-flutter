class Incident {
  final String id;
  final String status;
  final String? aiCategory;
  final String? aiPriority;
  final double? aiConfidence;
  final String? aiSummary;
  final int? estimatedArrivalMin;
  final DateTime createdAt;
  final String message;

  Incident({
    required this.id,
    required this.status,
    this.aiCategory,
    this.aiPriority,
    this.aiConfidence,
    this.aiSummary,
    this.estimatedArrivalMin,
    required this.createdAt,
    required this.message,
  });

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as String,
        status: (json['status'] as String).toUpperCase(),
        aiCategory: json['ai_category'] as String?,
        aiPriority: json['ai_priority'] as String?,
        aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
        aiSummary: json['ai_summary'] as String?,
        estimatedArrivalMin: json['estimated_arrival_min'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        message: json['message'] as String? ?? '',
      );
}

class EvidenceData {
  final String type;
  final String fileUrl;
  final String? transcription;

  const EvidenceData({
    required this.type,
    required this.fileUrl,
    this.transcription,
  });

  Map<String, dynamic> toJson() => {
        'evidence_type': type,
        'file_url': fileUrl,
        if (transcription != null) 'transcription': transcription,
      };
}

class IncidentCreate {
  final String description;
  final String vehicleId;
  final double latitude;
  final double longitude;
  final List<EvidenceData> evidences;

  const IncidentCreate({
    required this.description,
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    this.evidences = const [],
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'vehicle_id': vehicleId,
        'latitude': latitude,
        'longitude': longitude,
        'evidences': evidences.map((e) => e.toJson()).toList(),
      };
}
