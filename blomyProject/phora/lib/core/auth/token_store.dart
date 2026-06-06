import 'package:phora/app/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readUserId();
  Future<String?> readAuthMode();
  Future<String?> readEmail();
  Future<void> writeAccessToken(String token);
  Future<void> writeRefreshToken(String token);
  Future<void> writeUserId(String userId);
  Future<void> writeAuthMode(String mode);
  Future<void> writeEmail(String email);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static String get _envSuffix => '_$kAppEnvironmentName';
  static String get _accessTokenKey => 'access_token$_envSuffix';
  static String get _refreshTokenKey => 'refresh_token$_envSuffix';
  static String get _userIdKey => 'user_id$_envSuffix';
  static String get _authModeKey => 'auth_mode$_envSuffix';
  static String get _emailKey => 'email$_envSuffix';

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _authModeKey);
    await _storage.delete(key: _emailKey);
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<String?> readAuthMode() => _storage.read(key: _authModeKey);

  @override
  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  @override
  Future<void> writeAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<void> writeRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> writeAuthMode(String mode) {
    return _storage.write(key: _authModeKey, value: mode);
  }

  @override
  Future<void> writeEmail(String email) {
    return _storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> writeUserId(String userId) {
    return _storage.write(key: _userIdKey, value: userId);
  }
}
