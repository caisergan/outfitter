import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/playground_models.dart';

/// Thrown when the backend rejects a generate request because the user has
/// hit their daily playground cap (HTTP 429 with code DAILY_LIMIT_REACHED).
class PlaygroundCapException implements Exception {
  final int used;
  final int limit;
  final DateTime? resetAt;
  const PlaygroundCapException({
    required this.used,
    required this.limit,
    this.resetAt,
  });

  @override
  String toString() =>
      'PlaygroundCapException(used=$used, limit=$limit, resetAt=$resetAt)';
}

/// Generic playground error surfaced as a string for snackbars / inline copy.
class PlaygroundException implements Exception {
  final String message;
  const PlaygroundException(this.message);
  @override
  String toString() => message;
}

class PlaygroundRepository {
  final Dio _dio;
  PlaygroundRepository(this._dio);

  Future<PlaygroundSystemPrompt> getActiveSystemPrompt() async {
    final res = await _dio.get(ApiEndpoints.playgroundSystemPrompt);
    return PlaygroundSystemPrompt.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<PlaygroundTemplate>> listTemplates({
    bool includeInactive = false,
  }) async {
    final res = await _dio.get(
      ApiEndpoints.playgroundTemplates,
      queryParameters: {if (includeInactive) 'include_inactive': true},
    );
    return (res.data as List)
        .map((e) => PlaygroundTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PlaygroundPersona>> listPersonas({
    String? gender,
    bool includeInactive = false,
  }) async {
    final res = await _dio.get(
      ApiEndpoints.playgroundPersonas,
      queryParameters: {
        if (gender != null) 'gender': gender,
        if (includeInactive) 'include_inactive': true,
      },
    );
    return (res.data as List)
        .map((e) => PlaygroundPersona.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<GenerateResponse> generate(GenerateRequest req) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.playgroundGenerate,
        data: req.toJson(),
        // gpt-image-2 takes 30-60s typical, sometimes longer; the global Dio
        // receiveTimeout is 30s so we override it here. Matches the backend
        // proxy ceiling (CodexImageService._PROXY_TIMEOUT = 300s).
        options: Options(receiveTimeout: const Duration(minutes: 5)),
      );
      return GenerateResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // The backend's 429 detail is structured:
      //   { ok: false, error: { code, limit, used, reset_at } }
      // surface a typed exception so callers can render a clear cap message.
      if (e.response?.statusCode == 429) {
        final detail = e.response?.data;
        if (detail is Map &&
            detail['error'] is Map &&
            detail['error']['code'] == 'DAILY_LIMIT_REACHED') {
          final err = detail['error'] as Map;
          throw PlaygroundCapException(
            used: (err['used'] as num?)?.toInt() ?? 0,
            limit: (err['limit'] as num?)?.toInt() ?? 5,
            resetAt: err['reset_at'] is String
                ? DateTime.tryParse(err['reset_at'] as String)
                : null,
          );
        }
      }
      throw PlaygroundException(
        e.response?.data?.toString() ?? e.message ?? 'Generation failed',
      );
    }
  }

  Future<PlaygroundRunsPage> listRuns({int limit = 10, String? cursor}) async {
    final res = await _dio.get(
      ApiEndpoints.playgroundRuns,
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return PlaygroundRunsPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PlaygroundRun> getRun(String runId) async {
    final res = await _dio.get(ApiEndpoints.playgroundRun(runId));
    return PlaygroundRun.fromJson(res.data as Map<String, dynamic>);
  }
}

final playgroundRepositoryProvider = Provider<PlaygroundRepository>(
  (ref) => PlaygroundRepository(ref.read(dioProvider)),
);
