import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;
  

  
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

  // Check if token is expired - disabled for non-expiring tokens
  Future<bool> isTokenExpired() async {
    // Tokens don't expire
    return false;
  }

  // Check if token needs refresh - disabled for non-expiring tokens
  Future<bool> needsRefresh() async {
    // Tokens don't expire, so never need refresh
    return false;
  }

  // Schedule token refresh - disabled for non-expiring tokens
  void _scheduleTokenRefresh(DateTime? expiry) {
    _refreshTimer?.cancel();
    // Tokens don't expire, so no refresh scheduling needed
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

  // Check if token is valid (exists)
  Future<bool> isTokenValid() async {
    final token = await getToken();
    return token != null;
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