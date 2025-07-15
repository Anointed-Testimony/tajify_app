import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.135.39:8000/api';
  static const String storageKey = 'auth_token';
  
  late Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Request interceptor to add auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.read(key: storageKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired or invalid
          await _secureStorage.delete(key: storageKey);
          // You can add navigation to login screen here
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      print('=== API POST DEBUG ===');
      print('Making POST request to: $baseUrl$path');
      print('Request data: $data');
      print('Query parameters: $queryParameters');
      
      final response = await _dio.post(path, data: data, queryParameters: queryParameters);
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      print('=====================');
      
      return response;
    } on DioException catch (e) {
      print('POST Error: ${e.message}');
      print('Error type: ${e.type}');
      print('Error response: ${e.response?.data}');
      print('Error status: ${e.response?.statusCode}');
      throw _handleDioError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.put(path, data: data, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.delete(path, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response> postFormData(String path, FormData formData) async {
    try {
      print('=== API SERVICE DEBUG ===');
      print('Making POST request to: $baseUrl$path');
      print('FormData fields: ${formData.fields}');
      print('FormData files: ${formData.files.length} files');
      
      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      print('=======================');
      
      return response;
    } on DioException catch (e) {
      print('API Error: ${e.message}');
      print('Error type: ${e.type}');
      print('Error response: ${e.response?.data}');
      print('Error status: ${e.response?.statusCode}');
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        
        if (responseData is Map<String, dynamic>) {
          final message = responseData['message'] ?? 'An error occurred';
          return Exception(message);
        }
        
        switch (statusCode) {
          case 400:
            return Exception('Bad request. Please check your input.');
          case 401:
            return Exception('Unauthorized. Please login again.');
          case 403:
            return Exception('Forbidden. You don\'t have permission to access this resource.');
          case 404:
            return Exception('Resource not found.');
          case 422:
            return Exception('Validation failed. Please check your input.');
          case 500:
            return Exception('Server error. Please try again later.');
          default:
            return Exception('An error occurred. Please try again.');
        }
      
      case DioExceptionType.cancel:
        return Exception('Request was cancelled.');
      
      case DioExceptionType.connectionError:
        return Exception('No internet connection. Please check your network.');
      
      default:
        return Exception('An unexpected error occurred.');
    }
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: storageKey, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: storageKey);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: storageKey);
  }

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
  }
} 