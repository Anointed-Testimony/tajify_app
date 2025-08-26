import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.29.141:8000/api';
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
        // Remove automatic token deletion on 401 errors
        // Users should only be logged out when they manually logout
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
      print('=== API ERROR DETAILS ===');
      print('API Error: ${e.message}');
      print('Error type: ${e.type}');
      print('Error status code: ${e.response?.statusCode}');
      print('Error response data: ${e.response?.data}');
      print('Error response headers: ${e.response?.headers}');
      print('Request URL: ${e.requestOptions.uri}');
      print('Request method: ${e.requestOptions.method}');
      print('Request headers: ${e.requestOptions.headers}');
      print('=======================');
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
      print('=== API ERROR DETAILS ===');
      print('API Error: ${e.message}');
      print('Error type: ${e.type}');
      print('Error status code: ${e.response?.statusCode}');
      print('Error response data: ${e.response?.data}');
      print('Error response headers: ${e.response?.headers}');
      print('Request URL: ${e.requestOptions.uri}');
      print('Request method: ${e.requestOptions.method}');
      print('Request headers: ${e.requestOptions.headers}');
      print('=======================');
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
    try {
      return await _secureStorage.read(key: storageKey);
    } catch (e) {
      print('Error reading token: $e');
      return null;
    }
  }

  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: storageKey);
      print('Token cleared successfully');
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: storageKey);
  }

  Future<void> clearAllData() async {
    await _secureStorage.deleteAll();
  }

  // Upload-specific methods
  Future<Response> getUploadToken() async {
    return await post('/upload/get-token');
  }

  Future<Response> uploadMedia(File file, String mediaType, {String? uploadToken, double? duration}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'media_type': mediaType,
      if (uploadToken != null) 'upload_token': uploadToken,
      if (duration != null) 'duration': duration,
    });
    return await postFormData('/upload/media', formData);
  }

  Future<Response> completeUpload(int postId, List<int> mediaFileIds, {int? thumbnailMediaId}) async {
    return await post('/upload/complete', data: {
      'post_id': postId,
      'media_file_ids': mediaFileIds,
      if (thumbnailMediaId != null) 'thumbnail_media_id': thumbnailMediaId,
    });
  }

  Future<Response> createPost({
    required int postTypeId,
    String? title,
    String? description,
    bool isPrime = false,
    bool allowDuet = true,
    List<String>? hashtags,
  }) async {
    return await post('/posts', data: {
      'post_type_id': postTypeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'is_prime': isPrime,
      'allow_duet': allowDuet,
      if (hashtags != null) 'hashtags': hashtags,
    });
  }

  Future<Response> createPostWithAutoCategorization({
    required double videoDuration, // Duration in seconds
    String? title,
    String? description,
    bool isPrime = false,
    bool allowDuet = true,
    List<String>? hashtags,
  }) async {
    return await post('/posts/auto-categorize', data: {
      'video_duration': videoDuration,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'is_prime': isPrime,
      'allow_duet': allowDuet,
      if (hashtags != null) 'hashtags': hashtags,
    });
  }

  Future<Response> getPostTypes() async {
    return await get('/posts/types');
  }

  Future<Response> getPosts({String? postType, int? page}) async {
    final queryParams = <String, dynamic>{};
    if (postType != null) queryParams['post_type'] = postType;
    if (page != null) queryParams['page'] = page;
    
    return await get('/posts', queryParameters: queryParams);
  }

  Future<Response> getTubeShortPosts({int? page}) async {
    return await getPosts(postType: 'tube_short', page: page);
  }

  Future<Response> getTubeMaxPosts({int? page}) async {
    return await getPosts(postType: 'tube_max', page: page);
  }

  Future<Response> getTubePrimePosts({int? page}) async {
    return await getPosts(postType: 'tube_prime', page: page);
  }

  // Interaction methods (Like, Save, Comment)
  Future<Response> toggleLike(int postId) async {
    return await post('/posts/$postId/like');
  }

  Future<Response> toggleSave(int postId) async {
    return await post('/posts/$postId/save');
  }

  Future<Response> share(int postId) async {
    return await post('/posts/$postId/share');
  }

  Future<Response> getInteractionCounts(int postId) async {
    return await get('/interactions/posts/$postId/counts');
  }

  Future<Response> getSavedPosts({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    return await get('/interactions/saved-posts', queryParameters: queryParams);
  }

  Future<Response> getLikedPosts({int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    return await get('/interactions/liked-posts', queryParameters: queryParams);
  }

  // Comment methods
  Future<Response> getComments(int postId, {int? page}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    return await get('/posts/$postId/comments', queryParameters: queryParams);
  }

  Future<Response> addComment(int postId, String content) async {
    return await post('/posts/$postId/comments', data: {
      'content': content,
    });
  }

  Future<Response> updateComment(int commentId, String content) async {
    return await put('/comments/$commentId', data: {
      'content': content,
    });
  }

  Future<Response> deleteComment(int commentId) async {
    return await delete('/comments/$commentId');
  }

  Future<Response> getCommentReplies(int commentId, {int? page}) async {
    try {
      final token = await getToken();
      final queryParams = <String, dynamic>{};
      if (page != null) queryParams['page'] = page;
      
      final response = await _dio.get(
        '/comments/$commentId/replies',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> addCommentReply(int postId, String content, int parentCommentId) async {
    try {
      final token = await getToken();
      final response = await _dio.post(
        '/posts/$postId/comments',
        data: {
          'content': content,
          'parent_id': parentCommentId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Hashtag methods
  Future<Response> getHashtagSuggestions(String query) async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/hashtags/suggestions',
        queryParameters: {'query': query},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> searchHashtags(String query) async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/hashtags/search',
        queryParameters: {'query': query},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getTrendingHashtags() async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/hashtags/trending',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Duet methods
  Future<Response> createDuet(int postId, int duetPostId) async {
    try {
      final token = await getToken();
      final response = await _dio.post(
        '/posts/$postId/duet',
        data: {
          'duet_post_id': duetPostId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getDuetFeed(int postId) async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/posts/$postId/duet-feed',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getUserDuetFeed() async {
    try {
      final token = await getToken();
      final response = await _dio.get(
        '/posts/duet-feed',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Personalized feed methods
  Future<Response> getPersonalizedFeed({int? limit, int? page}) async {
    try {
      print('[DEBUG] API Service: Getting personalized feed...');
      print('[DEBUG] API Service: Limit: $limit, Page: $page');
      
      final token = await getToken();
      print('[DEBUG] API Service: Token obtained: ${token != null ? 'Yes' : 'No'}');
      
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (page != null) queryParams['page'] = page;
      
      print('[DEBUG] API Service: Query params: $queryParams');
      print('[DEBUG] API Service: Making request to /posts/feed/personalized');
      
      final response = await _dio.get(
        '/posts/feed/personalized',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('[DEBUG] API Service: Response received');
      print('[DEBUG] API Service: Status code: ${response.statusCode}');
      print('[DEBUG] API Service: Response data: ${response.data}');
      
      return response;
    } catch (e) {
      print('[DEBUG] API Service: Error in getPersonalizedFeed: $e');
      rethrow;
    }
  }

  Future<Response> refreshRecommendations() async {
    try {
      final token = await getToken();
      final response = await _dio.post(
        '/posts/feed/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
} 