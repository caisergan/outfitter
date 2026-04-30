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
      throw PlaygroundException(_humanError(e));
    }
  }

  /// Map a Dio failure to a short, human-readable message. Avoids dumping
  /// raw HTML from gateway timeouts (Cloudflare 524, etc.) and prefers the
  /// FastAPI structured `{ detail: ... }` shape when present.
  static String _humanError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map) {
        final inner = detail['error'];
        if (inner is Map && inner['message'] is String) {
          return inner['message'] as String;
        }
      }
    }

    switch (status) {
      case 504:
      case 524:
        return 'Generation timed out at the gateway. Try again in a moment.';
      case 502:
      case 503:
        return 'Image generation service is unavailable. Try again.';
      case 500:
        return 'Image generation failed on the server. Try again.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Generation timed out. The model can take up to a minute — try again.';
    }
    return e.message ?? 'Generation failed';
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

  /// POST /generate-image (returns 202 + pending) then poll /runs/{id}
  /// every [pollInterval] until the run moves off `pending`. Returns the
  /// resolved run ([status] is `success` or `failed`).
  ///
  /// Throws [PlaygroundCapException] on 429, [PlaygroundException] on any
  /// other failure including poll timeout.
  Future<({GenerateResponse accepted, PlaygroundRun run})> generateAndAwait(
    GenerateRequest req, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration ceiling = const Duration(minutes: 3),
  }) async {
    final accepted = await generate(req);
    final deadline = DateTime.now().add(ceiling);
    PlaygroundRun? latest;
    while (DateTime.now().isBefore(deadline)) {
      latest = await getRun(accepted.runId);
      if (latest.status != 'pending') {
        return (accepted: accepted, run: latest);
      }
      await Future.delayed(pollInterval);
    }
    throw const PlaygroundException(
      'Generation is taking longer than expected. Check Recent runs.',
    );
  }
}

final playgroundRepositoryProvider = Provider<PlaygroundRepository>(
  (ref) => PlaygroundRepository(ref.read(dioProvider)),
);
