import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://apitajv1.digitalentshub.net/api';
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

  Future<Response> createBlog({
    required String title,
    required String content,
    String? excerpt,
    List<String>? tags,
    bool isPublished = true,
    File? coverImage,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('title', title));
    formData.fields.add(MapEntry('content', content));
    if (excerpt != null && excerpt.isNotEmpty) {
      formData.fields.add(MapEntry('excerpt', excerpt));
    }
    if (tags != null && tags.isNotEmpty) {
      for (final tag in tags) {
        formData.fields.add(MapEntry('tags[]', tag));
      }
    }
    formData.fields.add(MapEntry('is_published', isPublished ? '1' : '0'));
    if (coverImage != null) {
      formData.files.add(
        MapEntry('cover_image', await MultipartFile.fromFile(coverImage.path)),
      );
    }
    return await postFormData('/blogs', formData);
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

  Future<Response> getPosts({String? postType, int? page, int? limit, int? userId}) async {
    final queryParams = <String, dynamic>{};
    if (postType != null) queryParams['post_type'] = postType;
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;
    if (userId != null) queryParams['user_id'] = userId;
    
    return await get('/posts', queryParameters: queryParams);
  }

  Future<Response> getTubeShortPosts({int? page, int? limit}) async {
    return await getPosts(postType: 'tube_short', page: page, limit: limit);
  }

  Future<Response> getTubeMaxPosts({int? page, int? limit}) async {
    return await getPosts(postType: 'tube_max', page: page, limit: limit);
  }

  Future<Response> getTubePrimePosts({int? page, int? limit}) async {
    return await getPosts(postType: 'tube_prime', page: page, limit: limit);
  }

  Future<Response> getBlogPosts({int? page, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;
    
    return await get('/blogs', queryParameters: queryParams);
  }

  Future<Response> getBlog(String uuid) async {
    return await get('/blogs/$uuid');
  }

  Future<Response> toggleBlogLike(String uuid) async {
    return await post('/blogs/$uuid/like');
  }

  // Search methods
  Future<Response> search(String query, {String? type}) async {
    final queryParams = <String, dynamic>{
      'q': query,
    };
    if (type != null) queryParams['type'] = type;
    
    return await get('/search', queryParameters: queryParams);
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

  Future<Response> deletePost(int postId) async {
    return await delete('/posts/$postId');
  }

  Future<Response> toggleFollowUser(int userId) async {
    return await post('/follow/toggle', data: {
      'user_id': userId,
    });
  }

  Future<Response> getFollowers(String username) async {
    return await get('/follow/$username/followers');
  }

  Future<Response> getFollowing(String username) async {
    return await get('/follow/$username/following');
  }

  Future<Response> checkFollowStatus(String username) async {
    return await get('/follow/$username/status');
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

  Future<Response> toggleCommentLike(int commentId) async {
    return await post('/comments/$commentId/like');
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

  Future<Response> getWallet() async {
    return await get('/wallet');
  }

  Future<Response> getWalletStats() async {
    return await get('/wallet/stats');
  }

  Future<Response> getEarningCenter() async {
    return await get('/wallet/earning-center');
  }

  Future<Response> getRecentEarnings({int limit = 10}) async {
    return await get(
      '/wallet/recent-earnings',
      queryParameters: {'limit': limit},
    );
  }

  Future<Response> getWalletTransactions({
    String? currency,
    String? type,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (currency != null && currency.isNotEmpty) {
      params['currency'] = currency;
    }
    if (type != null && type.isNotEmpty) {
      params['type'] = type;
    }
    return await get('/wallet/transactions', queryParameters: params);
  }

  Future<Response> getTajstarsBalance() async {
    return await get('/wallet/tajstars-balance');
  }

  Future<Response> generateLiveToken({
    String? channelName,
    int? ttl,
  }) async {
    final payload = <String, dynamic>{};
    if (channelName != null && channelName.isNotEmpty) {
      payload['channel_name'] = channelName;
    }
    if (ttl != null) {
      payload['ttl'] = ttl;
    }

    return await post(
      '/live/token',
      data: payload.isEmpty ? {} : payload,
    );
  }

  Future<Response> startLiveSession({
    required String channelName,
    required int uid,
    String? title,
    String? description,
  }) async {
    return await post(
      '/live/session/start',
      data: {
        'channel_name': channelName,
        'uid': uid,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      },
    );
  }

  Future<Response> endLiveSession({
    required String channelName,
  }) async {
    return await post(
      '/live/session/end',
      data: {
        'channel_name': channelName,
      },
    );
  }

  Future<Response> getActiveLiveSessions({
    int limit = 20,
    int offset = 0,
  }) async {
    return await get(
      '/live/sessions',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
  }

  Future<Response> getLiveSession(String channelName) async {
    return await get('/live/session/$channelName');
  }

  Future<Response> generateViewerToken({
    required String channelName,
    int? uid,
  }) async {
    return await post(
      '/live/viewer/token',
      data: {
        'channel_name': channelName,
        if (uid != null) 'uid': uid,
      },
    );
  }

  Future<Response> updateViewerCount({
    required String channelName,
    required bool increment,
  }) async {
    return await post(
      '/live/viewer/count',
      data: {
        'channel_name': channelName,
        'increment': increment,
      },
    );
  }

  Future<Response> initializeWalletFunding({
    required String currency,
    required double amount,
    required String paymentMethod,
  }) async {
    return await post(
      '/wallet/funding/initialize',
      data: {
        'currency': currency,
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
  }

  Future<Response> getWalletBanks() async {
    return await get('/wallet/banks');
  }

  Future<Response> validateBankAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    return await post(
      '/wallet/validate-account',
      data: {
        'account_number': accountNumber,
        'bank_code': bankCode,
      },
    );
  }

  Future<Response> createWithdrawal({
    required double amount,
    required String currencyType,
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    return await post(
      '/wallet/create-withdrawal',
      data: {
        'amount': amount,
        'currency_type': currencyType,
        'bank_code': bankCode,
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_name': accountName,
      },
    );
  }

  Future<Response> getTajiPrice() async {
    return await get('/taji/price');
  }

  Future<Response> getMarketItems({
    String? category,
    String? search,
    bool? isPaid,
    int? page,
    int? perPage,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (isPaid != null) queryParams['is_paid'] = isPaid ? 'true' : 'false';
    if (page != null) queryParams['page'] = page;
    if (perPage != null) queryParams['per_page'] = perPage;
    return await get('/market', queryParameters: queryParams.isEmpty ? null : queryParams);
  }

  Future<Response> getMarketItem(String uuid) async {
    return await get('/market/$uuid');
  }

  Future<Response> createMarketItem(Map<String, dynamic> data) async {
    return await post('/market', data: data);
  }

  Future<Response> updateMarketItem(String uuid, Map<String, dynamic> data) async {
    return await put('/market/$uuid', data: data);
  }

  Future<Response> deleteMarketItem(String uuid) async {
    return await delete('/market/$uuid');
  }

  Future<Response> toggleMarketItemLike(String uuid) async {
    return await post('/market/$uuid/like');
  }

  Future<Response> getUserMarketItems({
    String? category,
    bool? isActive,
    int? page,
    int? perPage,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (isActive != null) queryParams['is_active'] = isActive ? 'true' : 'false';
    if (page != null) queryParams['page'] = page;
    if (perPage != null) queryParams['per_page'] = perPage;
    return await get('/market/my-items', queryParameters: queryParams.isEmpty ? null : queryParams);
  }

  Future<Response> convertTajstarsToNaira(Map<String, dynamic> data) async {
    return await post('/wallet/convert-tajstars-to-naira', data: data);
  }

  Future<Response> convertTajstarsToUsdt(Map<String, dynamic> data) async {
    return await post('/wallet/convert-tajstars-to-usdt', data: data);
  }

  Future<Response> convertUsdtToTajstars(Map<String, dynamic> data) async {
    return await post('/wallet/convert-usdt-to-tajstars', data: data);
  }

  Future<Response> getGiftPacks() async {
    return await get('/wallet/packs');
  }

  Future<Response> initializeWalletPayment({
    required int packId,
    required String currency,
    required String email,
  }) async {
    final data = {
      'pack_id': packId,
      'currency': currency,
      'email': email,
    };
    return await post('/wallet/initialize-payment', data: data);
  }

  Future<Response> verifyWalletPayment(String reference) async {
    return await post('/wallet/verify-payment', data: {'reference': reference});
  }

  Future<Response> generateCryptoDepositAddress({
    required double tajiAmount,
    required String cryptoType,
    required String network,
  }) async {
    return await post('/wallet/funding/taji/crypto/generate-address', data: {
      'taji_amount': tajiAmount,
      'crypto_type': cryptoType,
      'network': network,
    });
  }

  Future<Response> generateUsdtCryptoDepositAddress({
    required double usdtAmount,
    required String cryptoType,
    required String network,
  }) async {
    return await post('/wallet/funding/usdt/crypto/generate-address', data: {
      'usdt_amount': usdtAmount,
      'crypto_type': cryptoType,
      'network': network,
    });
  }

  Future<Response> checkCryptoPaymentStatus(String paymentReference) async {
    print('🔵 [API DEBUG] checkCryptoPaymentStatus called');
    print('🔵 [API DEBUG] Payment reference: $paymentReference');
    
    // Determine endpoint based on payment reference
    final isUsdt = paymentReference.startsWith('CRYPTO_USDT_');
    final endpoint = isUsdt 
        ? '/wallet/funding/usdt/crypto/check-payment'
        : '/wallet/funding/taji/crypto/check-payment';
    print('🔵 [API DEBUG] Endpoint: $endpoint');
    
    try {
      final response = await post(endpoint, data: {
        'payment_reference': paymentReference,
      });
      
      print('✅ [API DEBUG] checkCryptoPaymentStatus response received');
      print('🔵 [API DEBUG] Response status: ${response.statusCode}');
      print('🔵 [API DEBUG] Response data: ${response.data}');
      
      return response;
    } catch (e) {
      print('❌ [API DEBUG] checkCryptoPaymentStatus error');
      print('❌ [API DEBUG] Error type: ${e.runtimeType}');
      print('❌ [API DEBUG] Error message: $e');
      if (e is DioException) {
        print('❌ [API DEBUG] DioException type: ${e.type}');
        print('❌ [API DEBUG] DioException message: ${e.message}');
        print('❌ [API DEBUG] DioException request path: ${e.requestOptions.path}');
        print('❌ [API DEBUG] DioException request data: ${e.requestOptions.data}');
        print('❌ [API DEBUG] DioException response status: ${e.response?.statusCode}');
        print('❌ [API DEBUG] DioException response data: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<Response> processCryptoPayment(String paymentReference) async {
    print('🔵 [API DEBUG] processCryptoPayment called');
    print('🔵 [API DEBUG] Payment reference: $paymentReference');
    
    // Determine endpoint based on payment reference
    final isUsdt = paymentReference.startsWith('CRYPTO_USDT_');
    final endpoint = isUsdt 
        ? '/wallet/funding/usdt/crypto/process-payment'
        : '/wallet/funding/taji/crypto/process-payment';
    print('🔵 [API DEBUG] Endpoint: $endpoint');
    
    try {
      final response = await post(endpoint, data: {
        'payment_reference': paymentReference,
      });
      
      print('✅ [API DEBUG] processCryptoPayment response received');
      print('🔵 [API DEBUG] Response status: ${response.statusCode}');
      print('🔵 [API DEBUG] Response data: ${response.data}');
      
      return response;
    } catch (e) {
      print('❌ [API DEBUG] processCryptoPayment error');
      print('❌ [API DEBUG] Error type: ${e.runtimeType}');
      print('❌ [API DEBUG] Error message: $e');
      if (e is DioException) {
        print('❌ [API DEBUG] DioException type: ${e.type}');
        print('❌ [API DEBUG] DioException message: ${e.message}');
        print('❌ [API DEBUG] DioException request path: ${e.requestOptions.path}');
        print('❌ [API DEBUG] DioException request data: ${e.requestOptions.data}');
        print('❌ [API DEBUG] DioException response status: ${e.response?.statusCode}');
        print('❌ [API DEBUG] DioException response data: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<Response> fundTajiViaUsdt(double tajiAmount) async {
    print('🔵 [API DEBUG] fundTajiViaUsdt called');
    print('🔵 [API DEBUG] TAJI amount: $tajiAmount');
    print('🔵 [API DEBUG] Endpoint: /wallet/funding/taji-via-usdt');
    print('🔵 [API DEBUG] Request data: {\'taji_amount\': $tajiAmount}');
    
    try {
      final response = await post('/wallet/funding/taji-via-usdt', data: {
        'taji_amount': tajiAmount,
      });
      
      print('✅ [API DEBUG] fundTajiViaUsdt response received');
      print('🔵 [API DEBUG] Response status: ${response.statusCode}');
      print('🔵 [API DEBUG] Response data: ${response.data}');
      
      return response;
    } catch (e) {
      print('❌ [API DEBUG] fundTajiViaUsdt error');
      print('❌ [API DEBUG] Error type: ${e.runtimeType}');
      print('❌ [API DEBUG] Error message: $e');
      if (e is DioException) {
        print('❌ [API DEBUG] DioException type: ${e.type}');
        print('❌ [API DEBUG] DioException message: ${e.message}');
        print('❌ [API DEBUG] DioException request path: ${e.requestOptions.path}');
        print('❌ [API DEBUG] DioException request data: ${e.requestOptions.data}');
        print('❌ [API DEBUG] DioException response status: ${e.response?.statusCode}');
        print('❌ [API DEBUG] DioException response data: ${e.response?.data}');
      }
      rethrow;
    }
  }

  Future<Response> connectWallet(String walletAddress) async {
    return await post('/wallet/connect', data: {'wallet_address': walletAddress});
  }

  Future<Response> getTajiBalanceFromWallet(String walletAddress) async {
    // Using public BSC RPC endpoint to query blockchain directly
    // TAJI token contract: 0xF1b6059dbC8B44Ca90C5D2bE77e0cBea3b1965fe
    // TAJI has 8 decimals
    const String tajiTokenAddress = '0xF1b6059dbC8B44Ca90C5D2bE77e0cBea3b1965fe';
    const String bscRpcUrl = 'https://bsc-dataseed1.binance.org/';
    
    // ERC20 balanceOf function signature: 0x70a08231
    // balanceOf(address) -> bytes4(keccak256("balanceOf(address)")) = 0x70a08231
    // Encode the function call: 0x70a08231 + padded address (32 bytes)
    final String functionSelector = '0x70a08231';
    final String paddedAddress = walletAddress.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final String data = functionSelector + paddedAddress;
    
    // Create a public Dio instance for BSC RPC
    final publicDio = Dio(BaseOptions(
      baseUrl: bscRpcUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    
    try {
      // Make eth_call to get balance
      final rpcResponse = await publicDio.post('', data: {
        'jsonrpc': '2.0',
        'method': 'eth_call',
        'params': [
          {
            'to': tajiTokenAddress,
            'data': data,
          },
          'latest'
        ],
        'id': 1,
      });
      
      // Parse the response
      double balance = 0.0;
      if (rpcResponse.data['result'] != null && rpcResponse.data['result'] != '0x') {
        final balanceHex = rpcResponse.data['result'] as String;
        // Convert hex to BigInt, then divide by 10^8 (TAJI has 8 decimals)
        final balanceBigInt = BigInt.parse(balanceHex.replaceFirst('0x', ''), radix: 16);
        balance = balanceBigInt.toDouble() / 100000000; // 10^8
      }
      
      // Return in the same format as expected
      return Response(
        data: {
          'success': true,
          'data': {
            'balance': balance.toString(),
            'walletAddress': walletAddress,
            'tokenAddress': tajiTokenAddress,
            'symbol': 'TAJI'
          }
        },
        statusCode: 200,
        requestOptions: RequestOptions(
          path: bscRpcUrl,
          method: 'POST',
        ),
      );
    } catch (e) {
      // If RPC fails, try backup RPC endpoints
      final backupRpcUrls = [
        'https://bsc-dataseed.binance.org/',
        'https://bsc-dataseed1.defibit.io/',
        'https://bsc-dataseed1.ninicoin.io/',
      ];
      
      for (final rpcUrl in backupRpcUrls) {
        try {
          final backupDio = Dio(BaseOptions(
            baseUrl: rpcUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ));
          
          final rpcResponse = await backupDio.post('', data: {
            'jsonrpc': '2.0',
            'method': 'eth_call',
            'params': [
              {
                'to': tajiTokenAddress,
                'data': data,
              },
              'latest'
            ],
            'id': 1,
          });
          
          double balance = 0.0;
          if (rpcResponse.data['result'] != null && rpcResponse.data['result'] != '0x') {
            final balanceHex = rpcResponse.data['result'] as String;
            final balanceBigInt = BigInt.parse(balanceHex.replaceFirst('0x', ''), radix: 16);
            balance = balanceBigInt.toDouble() / 100000000;
          }
          
          return Response(
            data: {
              'success': true,
              'data': {
                'balance': balance.toString(),
                'walletAddress': walletAddress,
                'tokenAddress': tajiTokenAddress,
                'symbol': 'TAJI'
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(
              path: rpcUrl,
              method: 'POST',
            ),
          );
        } catch (_) {
          continue;
        }
      }
      
      // If all RPC endpoints fail, return 0 balance
      return Response(
        data: {
          'success': true,
          'data': {
            'balance': '0',
            'walletAddress': walletAddress,
            'tokenAddress': tajiTokenAddress,
            'symbol': 'TAJI'
          }
        },
        statusCode: 200,
        requestOptions: RequestOptions(
          path: bscRpcUrl,
          method: 'POST',
        ),
      );
    }
  }

  Future<Response> getGifts({
    String? category,
    String? rarity,
    String? sort,
    String? order,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (rarity != null && rarity.isNotEmpty) queryParams['rarity'] = rarity;
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;
    if (order != null && order.isNotEmpty) queryParams['order'] = order;
    return await get('/gifts', queryParameters: queryParams.isEmpty ? null : queryParams);
  }

  Future<Response> sendGift({
    required int giftId,
    required int receiverId,
    required int postId,
    int quantity = 1,
    String? message,
    bool isAnonymous = false,
  }) async {
    final data = <String, dynamic>{
      'gift_id': giftId,
      'receiver_id': receiverId,
      'post_id': postId,
      'quantity': quantity,
      'message': message,
      'is_anonymous': isAnonymous,
    }..removeWhere((key, value) => value == null);
    return await post('/gifts/send', data: data);
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

  // Notification methods
  Future<Response> getNotifications({int? limit, String? type}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (type != null) queryParams['type'] = type;
    
    return await get('/notifications', queryParameters: queryParams);
  }

  Future<Response> getUnreadCount() async {
    return await get('/notifications/unread-count');
  }

  Future<Response> markNotificationAsRead(int notificationId) async {
    return await post('/notifications/mark-read', data: {
      'notification_id': notificationId,
    });
  }

  Future<Response> markAllNotificationsAsRead() async {
    return await post('/notifications/mark-all-read');
  }

  Future<Response> deleteNotification(int notificationId) async {
    // Backend uses DELETE method but expects notification_id in request body
    try {
      final token = await getToken();
      final response = await _dio.delete(
        '/notifications/delete',
        data: {'notification_id': notificationId},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      return response;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  // Direct Messages methods
  Future<Response> getConversations() async {
    return await get('/direct-messages');
  }

  Future<Response> getMessages(int userId) async {
    return await get('/direct-messages/$userId/messages');
  }

  Future<Response> sendMessage(int userId, {String? content, File? media}) async {
    if (media != null) {
      // Determine media type from file extension (like web does)
      String? mediaType;
      final fileName = media.path.toLowerCase();
      if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || 
          fileName.endsWith('.png') || fileName.endsWith('.gif')) {
        mediaType = 'image';
      } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov') || 
                 fileName.endsWith('.avi')) {
        mediaType = 'video';
      } else if (fileName.endsWith('.mp3') || fileName.endsWith('.wav')) {
        mediaType = 'audio';
      } else {
        mediaType = 'file';
      }
      
      final formData = FormData.fromMap({
        if (content != null && content.isNotEmpty) 'content': content,
        'media': await MultipartFile.fromFile(media.path),
        'media_type': mediaType,
      });
      return await postFormData('/direct-messages/$userId/send', formData);
    } else {
      return await post('/direct-messages/$userId/send', data: {
        if (content != null && content.isNotEmpty) 'content': content,
      });
    }
  }

  Future<Response> searchUsersForMessages(String query) async {
    return await get('/direct-messages/search-users', queryParameters: {
      'q': query,
    });
  }

  // Profile methods
  Future<Response> getProfile() async {
    return await get('/profile');
  }

  Future<Response> updateProfile({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? bio,
    String? dateOfBirth,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (bio != null) data['bio'] = bio;
    if (dateOfBirth != null) data['date_of_birth'] = dateOfBirth;
    
    return await put('/profile', data: data);
  }

  Future<Response> uploadAvatar(File avatarFile) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(avatarFile.path),
    });
    return await postFormData('/profile/avatar', formData);
  }

  Future<Response> getProfileStats() async {
    return await get('/profile/stats');
  }

  Future<Response> getUserProfile(int userId) async {
    return await get('/users/$userId');
  }

  // Community methods
  Future<Response> getCommunity(String uuid) async {
    return await get('/communities/$uuid');
  }

  Future<Response> getCommunityMembers(String uuid) async {
    return await get('/communities/$uuid/members');
  }

  Future<Response> getCommunityMessages(String uuid) async {
    return await get('/communities/$uuid/messages');
  }

  Future<Response> sendCommunityMessage(String uuid, {String? content, File? media}) async {
    if (media != null) {
      // Determine media type from file extension
      String? mediaType;
      final fileName = media.path.toLowerCase();
      if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || 
          fileName.endsWith('.png') || fileName.endsWith('.gif')) {
        mediaType = 'image';
      } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov') || 
                 fileName.endsWith('.avi')) {
        mediaType = 'video';
      } else if (fileName.endsWith('.mp3') || fileName.endsWith('.wav')) {
        mediaType = 'audio';
      } else {
        mediaType = 'file';
      }
      
      final formData = FormData.fromMap({
        if (content != null && content.isNotEmpty) 'content': content,
        'media': await MultipartFile.fromFile(media.path),
        'media_type': mediaType,
      });
      return await postFormData('/communities/$uuid/messages', formData);
    } else {
      return await post('/communities/$uuid/messages', data: {
        if (content != null && content.isNotEmpty) 'content': content,
      });
    }
  }

  Future<Response> leaveCommunity(String uuid) async {
    return await post('/communities/$uuid/leave');
  }

  Future<Response> updateCommunity(String uuid, {
    String? name,
    String? description,
    String? joinPolicy,
    String? chatPolicy,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (joinPolicy != null) data['join_policy'] = joinPolicy;
    if (chatPolicy != null) data['chat_policy'] = chatPolicy;
    
    return await put('/communities/$uuid', data: data);
  }

  Future<Response> deleteCommunityMessage(String uuid, int messageId) async {
    return await delete('/communities/$uuid/messages/$messageId');
  }

  Future<Response> updateCommunityMessage(String uuid, int messageId, String content) async {
    return await put('/communities/$uuid/messages/$messageId', data: {
      'content': content,
    });
  }

  // Transfer methods
  Future<Response> validateRecipientEmail(String email) async {
    return await post('/send-usdt/validate-email', data: {
      'email': email,
    });
  }

  Future<Response> sendUsdt({
    required String recipientEmail,
    required double amount,
  }) async {
    return await post('/send-usdt/send', data: {
      'recipient_email': recipientEmail,
      'amount': amount,
    });
  }

  Future<Response> sendTaji({
    required String recipientEmail,
    required String recipientWallet,
    required double amount,
    required String senderWallet,
    String? privateKey,
  }) async {
    final data = {
      'recipient_email': recipientEmail,
      'recipient_wallet': recipientWallet,
      'amount': amount,
      'sender_wallet': senderWallet,
    };
    
    if (privateKey != null && privateKey.isNotEmpty) {
      data['private_key'] = privateKey;
    }
    
    return await post('/send-taji/send', data: data);
  }
} 