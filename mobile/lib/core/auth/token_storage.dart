import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _legacyAccessKey = 'auth_token';
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  final _storage = const FlutterSecureStorage();

  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _accessKey);
    if (token != null) return token;

    final legacyToken = await _storage.read(key: _legacyAccessKey);
    if (legacyToken != null) {
      await _storage.write(key: _accessKey, value: legacyToken);
      await _storage.delete(key: _legacyAccessKey);
    }
    return legacyToken;
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.delete(key: _legacyAccessKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _legacyAccessKey);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());
