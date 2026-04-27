import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import 'token_storage.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthNotifier extends StateNotifier<AuthStatus> {
  final Dio _dio;
  final TokenStorage _storage;

  AuthNotifier(this._dio, this._storage) : super(AuthStatus.loading) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final accessToken = await _storage.readAccessToken();
    final refreshToken = await _storage.readRefreshToken();
    if (accessToken == null && refreshToken == null) {
      state = AuthStatus.unauthenticated;
      return;
    }

    try {
      await _dio.get(ApiEndpoints.authMe);
      state = AuthStatus.authenticated;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _storage.clear();
        state = AuthStatus.unauthenticated;
        return;
      }

      state = AuthStatus.authenticated;
    }
  }

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: FormData.fromMap({
        'username': email,
        'password': password,
      }),
    );
    await _persistTokens(response.data as Map<String, dynamic>);
    state = AuthStatus.authenticated;
  }

  Future<void> signup(String email, String password) async {
    final response = await _dio.post(ApiEndpoints.signup, data: {
      'email': email,
      'password': password,
    });
    await _persistTokens(response.data as Map<String, dynamic>);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    await _storage.clear();
    state = AuthStatus.unauthenticated;
  }

  Future<void> handleUnauthorized() async {
    await _storage.clear();
    state = AuthStatus.unauthenticated;
  }

  Future<void> _persistTokens(Map<String, dynamic> payload) {
    return _storage.writeTokens(
      accessToken: payload['access_token'] as String,
      refreshToken: payload['refresh_token'] as String,
    );
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
      final notifier = AuthNotifier(
        ref.read(dioProvider),
        ref.read(tokenStorageProvider),
      );
      ref.listen<int>(unauthorizedEventProvider, (previous, next) {
        if (previous == next) return;
        notifier.handleUnauthorized();
      });
      return notifier;
    });
