class NotificationModel {
  final String id;
  final String userId;
  final String? incidentId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? paymentStatus;

  NotificationModel({
    required this.id,
    required this.userId,
    this.incidentId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.sentAt,
    this.readAt,
    this.paymentStatus,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      incidentId: json['incident_id'],
      type: (json['type'] as String).toUpperCase(),
      title: json['title'],
      body: json['body'],
      isRead: json['is_read'],
      sentAt: DateTime.parse(json['sent_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      paymentStatus: json['payment_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'incident_id': incidentId,
      'type': type,
      'title': title,
      'body': body,
      'is_read': isRead,
      'sent_at': sentAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'payment_status': paymentStatus,
    };
  }
}
