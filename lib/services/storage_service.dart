import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  // Storage keys
  static const String _authTokenKey = 'auth_token';
  static const String _userDataKey = 'user_data';
  static const String _onboardingKey = 'onboarding_completed';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastLoginMethodKey = 'last_login_method';
  static const String _socialAuthDataKey = 'social_auth_data';

  // Token management
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }

  Future<void> deleteAuthToken() async {
    await _storage.delete(key: _authTokenKey);
  }

  // User data management
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final userDataJson = jsonEncode(userData);
    await _storage.write(key: _userDataKey, value: userDataJson);
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final userDataJson = await _storage.read(key: _userDataKey);
    if (userDataJson != null) {
      try {
        final decoded = jsonDecode(userDataJson);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
        return null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: _userDataKey);
  }

  // Onboarding status
  Future<void> setOnboardingCompleted(bool completed) async {
    await _storage.write(key: _onboardingKey, value: completed.toString());
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: _onboardingKey);
    return value == 'true';
  }

  // Biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // Last login method
  Future<void> setLastLoginMethod(String method) async {
    await _storage.write(key: _lastLoginMethodKey, value: method);
  }

  Future<String?> getLastLoginMethod() async {
    return await _storage.read(key: _lastLoginMethodKey);
  }

  // Social authentication data
  Future<void> saveSocialAuthData(String provider, Map<String, dynamic> data) async {
    final key = '${_socialAuthDataKey}_$provider';
    final dataJson = jsonEncode(data);
    await _storage.write(key: key, value: dataJson);
  }

  Future<Map<String, dynamic>?> getSocialAuthData(String provider) async {
    final key = '${_socialAuthDataKey}_$provider';
    final dataJson = await _storage.read(key: key);
    if (dataJson != null) {
      try {
        final decoded = jsonDecode(dataJson);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
        return null;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> deleteSocialAuthData(String provider) async {
    final key = '${_socialAuthDataKey}_$provider';
    await _storage.delete(key: key);
  }

  // Clear all data
  Future<void> clearAllData() async {
    await _storage.deleteAll();
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Get user ID from stored data
  Future<String?> getUserId() async {
    final userData = await getUserData();
    return userData?['id']?.toString();
  }

  // Get user email from stored data
  Future<String?> getUserEmail() async {
    final userData = await getUserData();
    return userData?['email']?.toString();
  }

  // Get user name from stored data
  Future<String?> getUserName() async {
    final userData = await getUserData();
    return userData?['name']?.toString();
  }

  // Get user profile picture from stored data
  Future<String?> getUserProfilePicture() async {
    final userData = await getUserData();
    return userData?['profile_picture']?.toString();
  }

  // Get user type from stored data
  Future<String?> getUserType() async {
    final userData = await getUserData();
    return userData?['user_type']?.toString();
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    final userType = await getUserType();
    return userType == 'admin';
  }

  // Logout - clear all auth related data
  Future<void> logout() async {
    await deleteAuthToken();
    await deleteUserData();
    await setLastLoginMethod('');
  }
} 