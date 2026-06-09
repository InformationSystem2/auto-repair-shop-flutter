class Incident {
  final String id;
  final String status;
  final String? description;
  final String? aiCategory;
  final String? aiPriority;
  final double? aiConfidence;
  final String? aiSummary;
  final int? estimatedArrivalMin;
  final double? totalCost;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final String message;
  final List<Map<String, dynamic>> evidenceUrls;
  final String? workshopName;
  final String? technicianName;
  final Map<String, dynamic>? rating;
  final Map<String, dynamic>? vehicle;

  final String? paymentStatus;

  Incident({
    required this.id,
    required this.status,
    this.description,
    this.aiCategory,
    this.aiPriority,
    this.aiConfidence,
    this.aiSummary,
    this.estimatedArrivalMin,
    this.totalCost,
    this.lat,
    this.lng,
    required this.createdAt,
    required this.message,
    this.evidenceUrls = const [],
    this.workshopName,
    this.technicianName,
    this.rating,
    this.vehicle,
    this.paymentStatus,
  });

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as String,
        status: (json['status'] as String).toUpperCase(),
        description: json['description'] as String?,
        aiCategory: json['ai_category'] as String?,
        aiPriority: json['ai_priority'] as String?,
        aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
        aiSummary: json['ai_summary'] as String?,
        estimatedArrivalMin: json['estimated_arrival_min'] as int?,
        totalCost: (json['total_cost'] as num?)?.toDouble(),
        lat: (json['latitude'] as num?)?.toDouble(),
        lng: (json['longitude'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        message: json['message'] as String? ?? '',
        evidenceUrls: (json['evidence_urls'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        workshopName: json['workshop_name'] as String?,
        technicianName: json['technician_name'] as String?,
        rating: json['rating'] as Map<String, dynamic>?,
        vehicle: json['vehicle'] as Map<String, dynamic>?,
        paymentStatus: json['payment_status'] as String?,
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
  final String? description;
  final String vehicleId;
  final double latitude;
  final double longitude;
  final List<EvidenceData> evidences;

  const IncidentCreate({
    this.description,
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    this.evidences = const [],
  });

  Map<String, dynamic> toJson() => {
        if (description != null && description!.trim().isNotEmpty)
          'description': description,
        'vehicle_id': vehicleId,
        'latitude': latitude,
        'longitude': longitude,
        'evidences': evidences.map((e) => e.toJson()).toList(),
      };
}
