import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/tryon_models.dart';

/// Thrown when the backend rejects a generate request because the user has
/// hit their daily tryon cap (HTTP 429 with code DAILY_LIMIT_REACHED).
class TryOnCapException implements Exception {
  final int used;
  final int limit;
  final DateTime? resetAt;
  const TryOnCapException({
    required this.used,
    required this.limit,
    this.resetAt,
  });

  @override
  String toString() =>
      'TryOnCapException(used=$used, limit=$limit, resetAt=$resetAt)';
}

/// Generic tryon error surfaced as a string for snackbars / inline copy.
class TryOnGenerationException implements Exception {
  final String message;
  const TryOnGenerationException(this.message);
  @override
  String toString() => message;
}

class TryOnGenerationRepository {
  final Dio _dio;
  TryOnGenerationRepository(this._dio);

  Future<TryOnSystemPrompt> getActiveSystemPrompt() async {
    final res = await _dio.get(ApiEndpoints.tryonSystemPrompt);
    return TryOnSystemPrompt.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<TryOnTemplate>> listTemplates({
    bool includeInactive = false,
  }) async {
    final res = await _dio.get(
      ApiEndpoints.tryonTemplates,
      queryParameters: {if (includeInactive) 'include_inactive': true},
    );
    return (res.data as List)
        .map((e) => TryOnTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<TryOnPersona>> listPersonas({
    String? gender,
    bool includeInactive = false,
  }) async {
    final res = await _dio.get(
      ApiEndpoints.tryonPersonas,
      queryParameters: {
        if (gender != null) 'gender': gender,
        if (includeInactive) 'include_inactive': true,
      },
    );
    return (res.data as List)
        .map((e) => TryOnPersona.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<TryOnGenerateResponse> generate(TryOnGenerateRequest req) async {
    try {
      // POST returns 202 + status='pending' in <100ms now that the codex
      // call runs in the background, so the global 30s receiveTimeout is
      // plenty. The long-tail polling happens via getRun().
      final res = await _dio.post(
        ApiEndpoints.tryonGenerate,
        data: req.toJson(),
      );
      return TryOnGenerateResponse.fromJson(res.data as Map<String, dynamic>);
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
          throw TryOnCapException(
            used: (err['used'] as num?)?.toInt() ?? 0,
            limit: (err['limit'] as num?)?.toInt() ?? 5,
            resetAt: err['reset_at'] is String
                ? DateTime.tryParse(err['reset_at'] as String)
                : null,
          );
        }
      }
      throw TryOnGenerationException(_humanError(e));
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

  Future<TryOnRunsPage> listRuns({int limit = 10, String? cursor}) async {
    final res = await _dio.get(
      ApiEndpoints.tryonRuns,
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    return TryOnRunsPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TryOnRun> getRun(String runId) async {
    final res = await _dio.get(ApiEndpoints.tryonRun(runId));
    return TryOnRun.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /generate-image (returns 202 + pending) then poll /runs/{id}
  /// every [pollInterval] until the run moves off `pending`. Returns the
  /// resolved run ([status] is `success` or `failed`).
  ///
  /// Throws [TryOnCapException] on 429, [TryOnGenerationException] on any
  /// other failure including poll timeout.
  Future<({TryOnGenerateResponse accepted, TryOnRun run})> generateAndAwait(
    TryOnGenerateRequest req, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration ceiling = const Duration(minutes: 3),
  }) async {
    final accepted = await generate(req);
    final deadline = DateTime.now().add(ceiling);
    TryOnRun? latest;
    while (DateTime.now().isBefore(deadline)) {
      latest = await getRun(accepted.runId);
      if (latest.status != 'pending') {
        return (accepted: accepted, run: latest);
      }
      await Future.delayed(pollInterval);
    }
    throw const TryOnGenerationException(
      'Generation is taking longer than expected. Check Recent runs.',
    );
  }
}

final tryOnGenerationRepositoryProvider = Provider<TryOnGenerationRepository>(
  (ref) => TryOnGenerationRepository(ref.read(dioProvider)),
);
