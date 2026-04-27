import 'package:dio/dio.dart';
import '../config/dio_client.dart';
import '../config/env.dart';

class RatingService {
  final _dio = DioClient.instance.dio;

  Future<bool> postRating({
    required String incidentId,
    required int score,
    int? responseTimeScore,
    int? qualityScore,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.ratingsEndpoint,
        data: {
          'incident_id': incidentId,
          'score': score,
          'response_time_score': responseTimeScore,
          'quality_score': qualityScore,
          'comment': comment,
        },
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } on DioException catch (e) {
      print("Error posting rating: ${e.message}");
      return false;
    } catch (e) {
      print("Unexpected error: $e");
      return false;
    }
  }
}
