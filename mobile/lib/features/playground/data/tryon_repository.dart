import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';

class TryOnException implements Exception {
  final String message;
  const TryOnException(this.message);
  @override
  String toString() => 'TryOnException: $message';
}

class TryOnRepository {
  final Dio _dio;
  TryOnRepository(this._dio);

  Future<String> submitAndWait(
    Map<String, String> slots, {
    String modelPreference = 'neutral',
    String? userPhotoUrl,
  }) async {
    final submitResponse = await _dio.post(ApiEndpoints.tryonSubmit, data: {
      'slots': slots,
      'model_preference': modelPreference,
      'user_photo_url': userPhotoUrl,
    });
    final jobId = submitResponse.data['job_id'] as String;
    return _poll(jobId);
  }

  Future<String> _poll(String jobId) async {
    const maxAttempts = 15;
    const interval = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(interval);
      final response = await _dio.get(ApiEndpoints.tryonStatus(jobId));
      final status = response.data['status'] as String;

      switch (status) {
        case 'complete':
          return response.data['image_url'] as String;
        case 'failed':
          throw TryOnException(
              response.data['error'] as String? ?? 'generation_failed');
        case 'pending':
        case 'processing':
          continue;
      }
    }
    throw const TryOnException('generation_timeout');
  }
}

final tryonRepositoryProvider =
    Provider<TryOnRepository>((ref) => TryOnRepository(ref.read(dioProvider)));
