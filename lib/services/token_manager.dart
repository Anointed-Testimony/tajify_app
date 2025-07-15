import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;
  
  // Token expiry threshold (refresh 5 minutes before expiry)
  static const Duration _refreshThreshold = Duration(minutes: 5);
  
  // Singleton pattern
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  // Get current token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Save token with expiry
  Future<void> saveToken(String token, {DateTime? expiry}) async {
    await _storage.write(key: _tokenKey, value: token);
    
    if (expiry != null) {
      await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());
    }
    
    _scheduleTokenRefresh(expiry);
  }

  // Save refresh token
  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // Get token expiry
  Future<DateTime?> getTokenExpiry() async {
    final expiryString = await _storage.read(key: _tokenExpiryKey);
    if (expiryString != null) {
      return DateTime.parse(expiryString);
    }
    return null;
  }

  // Check if token is expired
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    
    return DateTime.now().isAfter(expiry);
  }

  // Check if token needs refresh
  Future<bool> needsRefresh() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    
    final timeUntilExpiry = expiry.difference(DateTime.now());
    return timeUntilExpiry <= _refreshThreshold;
  }

  // Schedule token refresh
  void _scheduleTokenRefresh(DateTime? expiry) {
    _refreshTimer?.cancel();
    
    if (expiry != null) {
      final timeUntilRefresh = expiry.difference(DateTime.now()) - _refreshThreshold;
      
      if (timeUntilRefresh.isNegative) {
        // Token is already expired or close to expiry, refresh immediately
        _refreshToken();
      } else {
        // Schedule refresh
        _refreshTimer = Timer(timeUntilRefresh, _refreshToken);
      }
    }
  }

  // Refresh token
  Future<void> _refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        // No refresh token available, user needs to login again
        await clearTokens();
        return;
      }

      // Call refresh token API
      // This would typically make an API call to refresh the token
      // For now, we'll just clear the tokens and let the user login again
      await clearTokens();
    } catch (e) {
      // Refresh failed, clear tokens
      await clearTokens();
    }
  }

  // Clear all tokens
  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _tokenExpiryKey);
    
    _refreshTimer?.cancel();
  }

  // Parse JWT token to get expiry
  DateTime? _parseTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      
      final expiry = payloadMap['exp'];
      if (expiry != null) {
        return DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      }
    } catch (e) {
      // Token parsing failed
    }
    return null;
  }

  // Save token and automatically parse expiry from JWT
  Future<void> saveTokenWithAutoExpiry(String token) async {
    final expiry = _parseTokenExpiry(token);
    await saveToken(token, expiry: expiry);
  }

  // Initialize token manager
  Future<void> initialize() async {
    final token = await getToken();
    if (token != null) {
      final expiry = await getTokenExpiry();
      if (expiry != null) {
        _scheduleTokenRefresh(expiry);
      }
    }
  }

  // Dispose
  void dispose() {
    _refreshTimer?.cancel();
  }

  // Check if token is valid (not expired and exists)
  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null) return false;
    
    return !await isTokenExpired();
  }

  // Get token info for debugging
  Future<Map<String, dynamic>> getTokenInfo() async {
    final token = await getToken();
    final expiry = await getTokenExpiry();
    final refreshToken = await getRefreshToken();
    
    return {
      'hasToken': token != null,
      'tokenLength': token?.length ?? 0,
      'expiry': expiry?.toIso8601String(),
      'isExpired': await isTokenExpired(),
      'needsRefresh': await needsRefresh(),
      'hasRefreshToken': refreshToken != null,
    };
  }
} 