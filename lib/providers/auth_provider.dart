import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _token;
  String? _errorMessage;
  bool _isRefreshing = false;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isUser => _user?.isUser ?? false;
  bool get isRefreshing => _isRefreshing;

  AuthProvider() {
    _initializeAuth();
  }

  // Initialize authentication state
  Future<void> _initializeAuth() async {
    try {
      setStatus(AuthStatus.loading);
      
      // Check if token exists
      final token = await _storageService.getAuthToken();
      if (token != null) {
        _token = token;
        
        // Verify token by fetching user profile
        await _fetchUserProfile();
      } else {
        setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
    }
  }

  // Set authentication status
  void setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  // Set error message
  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Fetch user profile
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _authService.getProfile();
      
      if (response['success']) {
        _user = UserModel.fromJson(response['data']);
        setStatus(AuthStatus.authenticated);
      } else {
        // Token is invalid, clear auth data
        await _clearAuthData();
        setStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      // Token is invalid or network error
      await _clearAuthData();
      setStatus(AuthStatus.unauthenticated);
    }
  }

  // Login with email and password
  Future<bool> loginWithEmail(String email, String password) async {
    try {
      print('=== AUTH PROVIDER LOGIN DEBUG ===');
      print('Starting login with email: $email');
      
      setStatus(AuthStatus.loading);
      clearError();

      final response = await _authService.login(email: email, password: password);
      
      print('Login response: $response');
      
      if (response['success']) {
        print('Login successful, setting up user data');
        _token = response['data']['token'];
        _user = UserModel.fromJson(response['data']['user']);
        
        await _storageService.saveAuthToken(_token!);
        await _storageService.saveUserData(response['data']['user']);
        
        setStatus(AuthStatus.authenticated);
        print('Login completed successfully');
        return true;
      } else {
        print('Login failed: ${response['message']}');
        _errorMessage = response['message'] ?? 'Login failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      print('Login exception: $e');
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Login with phone and password
  Future<bool> loginWithPhone(String phone, String password) async {
    try {
      print('=== AUTH PROVIDER PHONE LOGIN DEBUG ===');
      print('Starting login with phone: $phone');
      
      setStatus(AuthStatus.loading);
      clearError();

      final response = await _authService.phoneLogin(phone: phone, password: password);
      
      print('Phone login response: $response');
      
      if (response['success']) {
        print('Phone login successful, setting up user data');
        _token = response['data']['token'];
        _user = UserModel.fromJson(response['data']['user']);
        
        await _storageService.saveAuthToken(_token!);
        await _storageService.saveUserData(response['data']['user']);
        
        setStatus(AuthStatus.authenticated);
        print('Phone login completed successfully');
        return true;
      } else {
        print('Phone login failed: ${response['message']}');
        _errorMessage = response['message'] ?? 'Login failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      print('Phone login exception: $e');
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Social login
  Future<bool> socialLogin(Map<String, dynamic> socialData) async {
    try {
      setStatus(AuthStatus.loading);
      clearError();

      Map<String, dynamic> response;
      
      // Determine which social login to use based on the data provided
      if (socialData.containsKey('google_id')) {
        response = await _authService.googleLogin(
          googleId: socialData['google_id'],
          email: socialData['email'],
          name: socialData['name'],
          profilePicture: socialData['profile_picture'],
        );
      } else if (socialData.containsKey('facebook_id')) {
        response = await _authService.facebookLogin(
          facebookId: socialData['facebook_id'],
          email: socialData['email'],
          name: socialData['name'],
          profilePicture: socialData['profile_picture'],
        );
      } else if (socialData.containsKey('apple_id')) {
        response = await _authService.appleLogin(
          appleId: socialData['apple_id'],
          email: socialData['email'],
          name: socialData['name'],
        );
      } else {
        throw Exception('Invalid social login data');
      }
      
      if (response['success']) {
        _token = response['data']['token'];
        _user = UserModel.fromJson(response['data']['user']);
        
        await _storageService.saveAuthToken(_token!);
        await _storageService.saveUserData(response['data']['user']);
        
        setStatus(AuthStatus.authenticated);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Social login failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Register user
  Future<bool> register(Map<String, dynamic> userData) async {
    try {
      setStatus(AuthStatus.loading);
      clearError();

      final response = await _authService.register(
        name: userData['name'],
        username: userData['username'],
        email: userData['email'],
        phone: userData['phone'],
        dateOfBirth: userData['dateOfBirth'],
        password: userData['password'],
        passwordConfirmation: userData['passwordConfirmation'],
        profilePicture: userData['profilePicture'],
      );
      
      if (response['success']) {
        // Registration successful, but user needs to verify OTP
        setStatus(AuthStatus.unauthenticated);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Registration failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Verify OTP
  Future<bool> verifyOtp(String email, String? phone, String otp, String purpose) async {
    try {
      setStatus(AuthStatus.loading);
      clearError();

      final response = await _authService.verifyOtp(
        email: email,
        phone: phone,
        otp: otp,
      );
      
      if (response['success']) {
        if (purpose == 'registration') {
          // After successful registration verification, user is logged in
          _token = response['data']['token'];
          _user = UserModel.fromJson(response['data']['user']);
          
          await _storageService.saveAuthToken(_token!);
          await _storageService.saveUserData(response['data']['user']);
          
          setStatus(AuthStatus.authenticated);
        }
        return true;
      } else {
        _errorMessage = response['message'] ?? 'OTP verification failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Send OTP
  Future<bool> sendOtp(String email, String? phone) async {
    try {
      clearError();

      final response = await _authService.sendOtp(email: email, phone: phone);
      
      if (response['success']) {
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to send OTP';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Resend OTP
  Future<bool> resendOtp(String email, String? phone) async {
    try {
      clearError();

      final response = await _authService.resendOtp(email: email, phone: phone);
      
      if (response['success']) {
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to resend OTP';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Forgot password
  Future<bool> forgotPassword(String email, String? phone) async {
    try {
      clearError();

      final response = await _authService.forgotPassword(email: email, phone: phone);
      
      if (response['success']) {
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to send reset instructions';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email, String? phone, String otp, String password, String passwordConfirmation) async {
    try {
      setStatus(AuthStatus.loading);
      clearError();

      final response = await _authService.resetPassword(
        email: email,
        phone: phone,
        otp: otp,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      
      if (response['success']) {
        setStatus(AuthStatus.unauthenticated);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Password reset failed';
        setStatus(AuthStatus.error);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Refresh token
  Future<bool> refreshToken() async {
    if (_isRefreshing) return false;
    
    try {
      _isRefreshing = true;
      notifyListeners();

      // Try to fetch user profile to verify token
      await _fetchUserProfile();
      
      _isRefreshing = false;
      notifyListeners();
      return isAuthenticated;
    } catch (e) {
      _isRefreshing = false;
      notifyListeners();
      
      // Token is invalid, logout
      await logout();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> userData) async {
    try {
      clearError();

      // This would typically call an API to update the user profile
      // For now, we'll just update the local user model
      if (_user != null) {
        _user = _user!.copyWith(
          name: userData['name'] ?? _user!.name,
          username: userData['username'] ?? _user!.username,
          phone: userData['phone'] ?? _user!.phone,
          dateOfBirth: userData['dateOfBirth'] ?? _user!.dateOfBirth,
          profilePicture: userData['profilePicture'] ?? _user!.profilePicture,
        );
        
        await _storageService.saveUserData(_user!.toJson());
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      setStatus(AuthStatus.error);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Call logout API if user is authenticated
      if (isAuthenticated) {
        await _authService.logout();
      }
    } catch (e) {
      // Ignore logout API errors
    }

    await _clearAuthData();
    setStatus(AuthStatus.unauthenticated);
  }

  // Clear all authentication data
  Future<void> _clearAuthData() async {
    _user = null;
    _token = null;
    _errorMessage = null;
    await _storageService.clearAllData();
  }

  // Check if user is authenticated on app start
  Future<void> checkAuthStatus() async {
    await _initializeAuth();
  }

  // Get user display name
  String get userDisplayName {
    return _user?.name ?? 'User';
  }

  // Get user email
  String get userEmail {
    return _user?.email ?? '';
  }

  // Get user profile picture
  String? get userProfilePicture {
    return _user?.profilePicture;
  }

  // Check if email is verified
  bool get isEmailVerified {
    return _user?.isEmailVerified ?? false;
  }

  // Check if phone is verified
  bool get isPhoneVerified {
    return _user?.isPhoneVerified ?? false;
  }
} 