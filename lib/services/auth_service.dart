import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Registration
  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String dateOfBirth,
    required String password,
    required String passwordConfirmation,
    File? profilePicture,
    String? ref,
  }) async {
    try {
      print('=== AUTH SERVICE DEBUG ===');
      print('Registering user with:');
      print('Name: $name');
      print('Username: $username');
      print('Email: $email');
      print('Phone: $phone');
      print('Date of Birth: $dateOfBirth');
      print('Password: ${password.length} characters');
      print('Password Confirmation: ${passwordConfirmation.length} characters');
      print('Profile Picture: ${profilePicture != null ? "Yes" : "No"}');
      print('Auth Type: ${email.isNotEmpty ? "email" : "phone"}');
      
      FormData formData = FormData.fromMap({
        'name': name,
        'username': username,
        'email': email,
        'phone': phone ?? '',
        'date_of_birth': dateOfBirth,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'auth_type': email.isNotEmpty ? 'email' : 'phone',
        if (ref != null && ref.isNotEmpty) 'ref': ref,
      });

      print('FormData created: ${formData.fields}');

      if (profilePicture != null) {
        formData.files.add(MapEntry(
          'profile_picture',
          await MultipartFile.fromFile(profilePicture.path),
        ));
        print('Profile picture added to form data');
      }

      print('Making API call to /auth/register...');
      final response = await _apiService.postFormData('/auth/register', formData);
      print('API Response received: ${response.data}');
      
      return response.data;
    } catch (e) {
      print('Registration error in AuthService: $e');
      rethrow;
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiService.post('/auth/login', data: {
        'login': email, // Changed from 'email' to 'login' to match backend
        'password': password,
      });
      
      final data = response.data;
      if (data['success'] && data['data']['token'] != null) {
        await _apiService.saveToken(data['data']['token']);
      }
      
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Phone Login
  Future<Map<String, dynamic>> phoneLogin({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _apiService.post('/auth/login', data: {
        'login': phone, // Changed from 'phone' to 'login' to match backend
        'password': password,
      });
      
      final data = response.data;
      if (data['success'] && data['data']['token'] != null) {
        await _apiService.saveToken(data['data']['token']);
      }
      
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Send OTP
  Future<Map<String, dynamic>> sendOtp({
    required String email,
    String? phone,
  }) async {
    try {
      final response = await _apiService.post('/auth/send-otp', data: {
        'email': email,
        'phone': phone,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Verify OTP
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    String? phone,
    required String otp,
    String? purpose,
    int? userId,
  }) async {
    try {
      print('=== VERIFY OTP DEBUG ===');
      print('Email: $email');
      print('Phone: $phone');
      print('OTP: $otp');
      print('OTP Length: ${otp.length}');
      print('User ID: $userId');
      
      // Determine type based on what's provided
      final type = email.isNotEmpty ? 'email' : 'phone';
      
      // Backend always requires user_id for OTP verification
      if (userId == null) {
        throw Exception('User ID is required for OTP verification');
      }
      
      // Build request data - backend requires user_id, code, and type
      final requestData = <String, dynamic>{
        'user_id': userId,
        'code': otp,
        'type': type,
      };
      
      print('User ID being sent: $userId');
      print('Type being sent: $type');
      print('Purpose: $purpose');
      
      print('Request Data: $requestData');
      
      final response = await _apiService.post('/auth/verify-otp', data: requestData);
      print('Verify OTP Response: ${response.data}');
      
      return response.data;
    } catch (e) {
      print('Verify OTP Error: $e');
      rethrow;
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOtp({
    required String email,
    String? phone,
  }) async {
    try {
      final response = await _apiService.post('/auth/resend-otp', data: {
        'email': email,
        'phone': phone,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Check Username Availability
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      final response = await _apiService.post('/auth/check-username', data: {
        'username': username,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Forgot Password
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
    String? phone,
  }) async {
    try {
      // Determine which identifier is provided and set the type accordingly
      final identifier = email.isNotEmpty ? email : (phone ?? '');
      final type = email.isNotEmpty ? 'email' : 'phone';
      
      final response = await _apiService.post('/auth/forgot-password', data: {
        'identifier': identifier,
        'type': type,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Reset Password
  Future<Map<String, dynamic>> resetPassword({
    required int userId,
    required String code,
    required String type,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _apiService.post('/auth/reset-password', data: {
        'user_id': userId,
        'code': code,
        'type': type,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Resend Password Reset OTP
  Future<Map<String, dynamic>> resendPasswordResetOtp({
    required String email,
    String? phone,
  }) async {
    try {
      final response = await _apiService.post('/auth/resend-password-reset-otp', data: {
        'email': email,
        'phone': phone,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get User Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _apiService.get('/auth/me');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _apiService.post('/auth/logout');
      await _apiService.deleteToken();
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Social Authentication - Google
  Future<Map<String, dynamic>> googleLogin({
    required String googleId,
    required String email,
    required String name,
    String? profilePicture,
  }) async {
    try {
      print('=== AUTH SERVICE GOOGLE LOGIN DEBUG ===');
      print('Received parameters:');
      print('Google ID: $googleId');
      print('Email: $email');
      print('Name: $name');
      print('Profile Picture: $profilePicture');
      
      final requestData = {
        'google_id': googleId,
        'email': email,
        'name': name,
        'profile_picture': profilePicture,
      };
      print('Request data to send: $requestData');
      
      print('Making API call to /auth/social/google/login...');
      final response = await _apiService.post('/auth/social/google/login', data: requestData);
      print('✅ API call completed');
      print('Raw response: ${response.data}');
      
      final data = response.data;
      print('Response data: $data');
      
      if (data['success'] && data['data']['token'] != null) {
        print('✅ Token found in response, saving token...');
        await _apiService.saveToken(data['data']['token']);
        print('✅ Token saved successfully');
      } else {
        print('❌ No token found in response or success is false');
        print('Success: ${data['success']}');
        print('Token exists: ${data['data']?['token'] != null}');
      }
      
      print('=== END AUTH SERVICE GOOGLE LOGIN DEBUG ===');
      return data;
    } catch (e) {
      print('=== AUTH SERVICE GOOGLE LOGIN ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error stack trace: ${StackTrace.current}');
      print('=== END AUTH SERVICE GOOGLE LOGIN ERROR ===');
      rethrow;
    }
  }

  // Social Authentication - Facebook
  Future<Map<String, dynamic>> facebookLogin({
    required String facebookId,
    required String email,
    required String name,
    String? profilePicture,
  }) async {
    try {
      final response = await _apiService.post('/auth/social/facebook/login', data: {
        'facebook_id': facebookId,
        'email': email,
        'name': name,
        'profile_picture': profilePicture,
      });
      
      final data = response.data;
      if (data['success'] && data['data']['token'] != null) {
        await _apiService.saveToken(data['data']['token']);
      }
      
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Social Authentication - Apple
  Future<Map<String, dynamic>> appleLogin({
    required String appleId,
    required String email,
    required String name,
    String? profilePicture,
  }) async {
    try {
      final response = await _apiService.post('/auth/social/apple/login', data: {
        'apple_id': appleId,
        'email': email,
        'name': name,
        'profile_picture': profilePicture,
      });
      
      final data = response.data;
      if (data['success'] && data['data']['token'] != null) {
        await _apiService.saveToken(data['data']['token']);
      }
      
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _apiService.getToken();
    return token != null;
  }

  // Get stored token
  Future<String?> getToken() async {
    return await _apiService.getToken();
  }

  // Clear all authentication data
  Future<void> clearAuthData() async {
    await _apiService.clearAllData();
  }
} 