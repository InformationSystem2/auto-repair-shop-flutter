class ApiResponse<T> {
  final int statusCode;
  final String message;
  final T? data;
  final dynamic error;

  ApiResponse({
    required this.statusCode,
    required this.message,
    this.data,
    this.error,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String get errorMessage {
    if (error is Map && (error as Map).containsKey('detail')) {
      return (error as Map)['detail'].toString();
    }
    return error?.toString() ?? message;
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? fromData,
  }) {
    return ApiResponse<T>(
      statusCode: json['statusCode'] as int? ?? 200,
      message: json['message'] as String? ?? '',
      data: fromData != null && json['data'] != null
          ? fromData(json['data'])
          : json['data'] as T?,
      error: json['error'],
    );
  }
}
