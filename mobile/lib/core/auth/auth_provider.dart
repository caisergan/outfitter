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
    final token = await _storage.read();
    state = token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: FormData.fromMap({
        'username': email,
        'password': password,
      }),
    );
    await _storage.write(response.data['access_token'] as String);
    state = AuthStatus.authenticated;
  }

  Future<void> signup(String email, String password) async {
    final response = await _dio.post(ApiEndpoints.signup, data: {
      'email': email,
      'password': password,
    });
    await _storage.write(response.data['access_token'] as String);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    await _storage.clear();
    state = AuthStatus.unauthenticated;
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthStatus>((ref) {
  return AuthNotifier(
    ref.read(dioProvider),
    ref.read(tokenStorageProvider),
  );
});
