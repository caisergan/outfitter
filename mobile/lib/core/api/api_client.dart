import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import 'api_endpoints.dart';

typedef UnauthorizedCallback = void Function();

const _retriedRequestKey = 'auth_retried';

bool _isAuthRoute(String path) {
  return path == ApiEndpoints.login ||
      path == ApiEndpoints.signup ||
      path == ApiEndpoints.authRefresh;
}

String _normalizedPath(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Uri.parse(path).path;
  }
  return path;
}

Future<Map<String, dynamic>> _requestRefreshedTokens({
  required String baseUrl,
  required String refreshToken,
}) async {
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final response = await refreshDio.post(
    ApiEndpoints.authRefresh,
    data: {'refresh_token': refreshToken},
  );
  return Map<String, dynamic>.from(response.data as Map);
}

Dio createDio(
  String baseUrl,
  TokenStorage tokenStorage, {
  UnauthorizedCallback? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Completer<Map<String, dynamic>>? refreshCompleter;

  Future<Map<String, dynamic>> refreshTokens() async {
    if (refreshCompleter != null) {
      return refreshCompleter!.future;
    }

    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw DioException(
        requestOptions: RequestOptions(path: ApiEndpoints.authRefresh),
        response: Response(
          requestOptions: RequestOptions(path: ApiEndpoints.authRefresh),
          statusCode: 401,
          data: {'detail': 'Missing refresh token'},
        ),
      );
    }

    final completer = Completer<Map<String, dynamic>>();
    refreshCompleter = completer;
    try {
      final tokens = await _requestRefreshedTokens(
        baseUrl: baseUrl,
        refreshToken: refreshToken,
      );
      await tokenStorage.writeTokens(
        accessToken: tokens['access_token'] as String,
        refreshToken: tokens['refresh_token'] as String,
      );
      completer.complete(tokens);
      return tokens;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      refreshCompleter = null;
    }
  }

  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = _normalizedPath(options.path);
        if (!_isAuthRoute(path)) {
          final token = await tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        final requestOptions = error.requestOptions;
        final path = _normalizedPath(requestOptions.path);
        final hasRetried = requestOptions.extra[_retriedRequestKey] == true;

        if (response?.statusCode != 401 || _isAuthRoute(path)) {
          handler.next(error);
          return;
        }

        if (hasRetried) {
          await tokenStorage.clear();
          onUnauthorized?.call();
          handler.next(error);
          return;
        }

        try {
          final tokens = await refreshTokens();
          final retriedRequest = requestOptions.copyWith(
            headers: {
              ...requestOptions.headers,
              'Authorization': 'Bearer ${tokens['access_token']}',
            },
            extra: {
              ...requestOptions.extra,
              _retriedRequestKey: true,
            },
          );
          final retryResponse = await dio.fetch<dynamic>(retriedRequest);
          handler.resolve(retryResponse);
        } catch (_) {
          await tokenStorage.clear();
          onUnauthorized?.call();
          handler.next(error);
        }
      },
    ),
  );

  return dio;
}

final unauthorizedEventProvider = StateProvider<int>((_) => 0);

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
  return createDio(
    baseUrl,
    tokenStorage,
    onUnauthorized: () {
      ref.read(unauthorizedEventProvider.notifier).state++;
    },
  );
});
