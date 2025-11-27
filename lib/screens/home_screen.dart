import 'dart:async';
import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../widgets/tajstars_gift_modal.dart';
import '../widgets/tajify_top_bar.dart';
import 'camera_recording_screen.dart';
import 'channel_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

class _VideoSkeleton extends StatelessWidget {
  const _VideoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[800]!,
                Colors.grey[700]!,
                Colors.grey[800]!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserInfoSkeleton extends StatelessWidget {
  const _UserInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar skeleton
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 8),
        // Username skeleton
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Action buttons skeleton
        Row(
          children: List.generate(6, (index) => [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),
          ]).expand((x) => x).toList()..removeLast(),
        ),
      ],
    );
  }
}

class _DescriptionSkeleton extends StatelessWidget {
  const _DescriptionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(minHeight: 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: MediaQuery.of(context).size.width * 0.82,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video skeleton
        Expanded(
          child: Stack(
            children: [
              const _VideoSkeleton(),
              // Description skeleton at bottom
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _DescriptionSkeleton(),
              ),
            ],
          ),
        ),
        // User info skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: _UserInfoSkeleton(),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Add API service
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  int? _currentUserId;
  Map<String, dynamic>? _currentUserProfile;
  
  // Real data from backend
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  static const int? _feedPageSize = null;
  int _currentFeedPage = 1;
  bool _isFetchingMore = false;
  bool _hasMorePosts = true;
  bool _isBackgroundPrefetching = false;
  
  // Video controllers for real posts
  final List<VideoPlayerController?> _videoControllers = [];
  final Set<int> _initializingVideoControllers = {};
  final Map<int, Duration> _resumePositions = {};

  // Interaction states for real posts
  List<bool> _liked = [];
  List<int> _likeCounts = [];
  List<bool> _saved = [];
  List<int> _saveCounts = [];
  List<int> _commentCounts = [];
  List<bool> _following = [];
  List<bool> _followLoading = [];
  
  // Loading states for interactions
  List<bool> _likeLoading = [];
  List<bool> _saveLoading = [];
  
  // Comments state
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;
  final TextEditingController _commentController = TextEditingController();
  int? _editingCommentId;
  final Map<int, TextEditingController> _editControllers = {};
  
  // Comment replies state
  Map<int, List<Map<String, dynamic>>> _commentReplies = {};
  Map<int, bool> _repliesLoading = {};
  Map<int, bool> _showReplies = {};
  Map<int, bool> _showReplyInput = {};
  Map<int, TextEditingController> _replyControllers = {};
  int? _editingReplyId;
  final Map<int, TextEditingController> _replyEditControllers = {};
  
  // Comment likes state
  Map<int, bool> _commentLiked = {};
  Map<int, int> _commentLikeCounts = {};
  Map<int, bool> _commentLikeLoading = {};
  
  // Notification state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  
  // Messages state
  int _messagesUnreadCount = 0;
  StreamSubscription? _messagesCountSubscription;

  void _toggleLike(int index) {
    if (_likeLoading[index] || index >= _posts.length) return;
    
    setState(() {
      _likeLoading[index] = true;
    });
    
    final postId = _posts[index]['id'];
    _apiService.toggleLike(postId).then((response) {
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _liked[index] = data['liked'] ?? false;
          _likeCounts[index] = data['like_count'] ?? 0;
          _likeLoading[index] = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _likeLoading[index] = false;
        });
      }
      print('Error toggling like: $e');
    });
  }

  void _toggleSave(int index) {
    if (_saveLoading[index] || index >= _posts.length) return;
    
    setState(() {
      _saveLoading[index] = true;
    });
    
    final postId = _posts[index]['id'];
    _apiService.toggleSave(postId).then((response) {
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _saved[index] = data['saved'] ?? false;
          _saveLoading[index] = false;
        });
        // Refresh save count
        _loadInteractionCounts(index);
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _saveLoading[index] = false;
        });
      }
      print('Error toggling save: $e');
    });
  }

  void _share(int index) {
    if (index >= _posts.length) return;
    
    final post = _posts[index];
    final mediaUrl = post['media_files']?[0]?['file_path'] ?? '';
    
    if (mediaUrl.isNotEmpty) {
      Share.share(mediaUrl);
    } else {
      Share.share('Check out this post on Tajify!');
    }
  }

  Future<void> _loadPersonalizedFeed({bool loadMore = false, bool silentLoadMore = false}) async {
    if (loadMore) {
      if (_isFetchingMore || !_hasMorePosts || _isLoading) return;
    } else {
      if (_isLoading) return;
      _hasMorePosts = true;
      _currentFeedPage = 1;
      _currentPage = 0;
      _disposeAllVideoControllers();
    }

    if (loadMore) {
      if (silentLoadMore) {
        _isFetchingMore = true;
      } else {
        setState(() {
          _isFetchingMore = true;
        });
      }
    } else {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }
    
    final targetPage = loadMore ? _currentFeedPage + 1 : 1;
    
    try {
      final response = await _apiService.getPersonalizedFeed(
        limit: _feedPageSize,
        page: targetPage,
      );
      
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        List<dynamic> postsList = [];
        bool hasNextPage = false;
        if (data is Map<String, dynamic>) {
          final dynamic rawPosts = data['posts'] ?? data['data'] ?? [];
          if (rawPosts is Map<String, dynamic> && rawPosts['data'] is List) {
            postsList = rawPosts['data'] as List<dynamic>;
            final nextPageUrl = rawPosts['next_page_url'] ?? rawPosts['nextPageUrl'] ?? rawPosts['nextPage'];
            hasNextPage = nextPageUrl != null;
            final currentPage = rawPosts['current_page'] ?? rawPosts['currentPage'];
            final lastPage = rawPosts['last_page'] ?? rawPosts['lastPage'];
            if (!hasNextPage && currentPage is int && lastPage is int) {
              hasNextPage = currentPage < lastPage;
            }
          } else if (rawPosts is List) {
            postsList = rawPosts;
            hasNextPage = false;
          }
        }
        final posts = postsList
            .whereType<Map<String, dynamic>>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
        
        if (loadMore) {
          final startIndex = _posts.length;
          setState(() {
            _posts.addAll(posts);
            _liked.addAll(List.generate(posts.length, (_) => false));
            _likeCounts.addAll(List.generate(posts.length, (_) => 0));
            _saved.addAll(List.generate(posts.length, (_) => false));
            _saveCounts.addAll(List.generate(posts.length, (_) => 0));
            _commentCounts.addAll(List.generate(posts.length, (_) => 0));
            _likeLoading.addAll(List.generate(posts.length, (_) => false));
            _saveLoading.addAll(List.generate(posts.length, (_) => false));
            _videoControllers.addAll(List.generate(posts.length, (_) => null));
            _following.addAll(List.generate(posts.length, (_) => false));
            _followLoading.addAll(List.generate(posts.length, (_) => false));
            _currentFeedPage = targetPage;
            _hasMorePosts = hasNextPage;
            for (int offset = 0; offset < posts.length; offset++) {
              final idx = startIndex + offset;
              _applyInitialInteractionState(idx, _posts[idx]);
            }
          });
          
          _prepareVideoControllers(_currentPage);
          
          for (int i = startIndex; i < _posts.length; i++) {
            await _loadInteractionCounts(i);
          }
        } else {
          setState(() {
            _posts = posts;
            _isLoading = false;
            _hasError = false;
            _errorMessage = '';
            _liked = List.generate(posts.length, (_) => false);
            _likeCounts = List.generate(posts.length, (_) => 0);
            _saved = List.generate(posts.length, (_) => false);
            _saveCounts = List.generate(posts.length, (_) => 0);
            _commentCounts = List.generate(posts.length, (_) => 0);
            _likeLoading = List.generate(posts.length, (_) => false);
            _saveLoading = List.generate(posts.length, (_) => false);
            _videoControllers.addAll(List.generate(posts.length, (_) => null));
            _following = List.generate(posts.length, (_) => false);
            _followLoading = List.generate(posts.length, (_) => false);
            _currentFeedPage = 1;
            _hasMorePosts = hasNextPage;
            _currentPage = 0;
            for (int i = 0; i < posts.length; i++) {
              _applyInitialInteractionState(i, posts[i]);
            }
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
          
          _prepareVideoControllers(0);
          
          for (int i = 0; i < posts.length; i++) {
            await _loadInteractionCounts(i);
          }
          
          _loadRemainingPostsInBackground();
        }
      } else {
        final message = response.data['message']?.toString() ?? 'Unknown error';
        if (mounted) {
          setState(() {
            if (loadMore) {
              _errorMessage = message;
              _hasMorePosts = false;
            } else {
              _hasError = true;
              _errorMessage = message;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _errorMessage = e.toString();
          } else {
            _hasError = true;
            _errorMessage = 'Failed to load feed: $e';
          }
        });
      }
    } finally {
      if (loadMore) {
        if (silentLoadMore) {
          _isFetchingMore = false;
        } else {
          if (mounted) {
            setState(() {
              _isFetchingMore = false;
            });
          } else {
            _isFetchingMore = false;
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        } else {
          _isLoading = false;
        }
      }
    }
  }

  // Load interaction counts for a specific post
  Future<void> _loadInteractionCounts(int index) async {
    if (index >= _posts.length) return;
    
    print('[DEBUG] Loading interaction counts for post $index');
    
    try {
      final postId = _posts[index]['id'];
      print('[DEBUG] Post ID: $postId');
      
      final response = await _apiService.getInteractionCounts(postId);
      
      print('[DEBUG] Interaction counts response for post $index:');
      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response data: ${response.data}');
      
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        final counts = data['counts'];
        final userInteractions = data['user_interactions'];
        
        print('[DEBUG] Counts for post $index: $counts');
        print('[DEBUG] User interactions for post $index: $userInteractions');
        print('[DEBUG] User interactions keys: ${userInteractions?.keys.toList()}');
        
        setState(() {
          _likeCounts[index] = counts['likes'] ?? 0;
          _saveCounts[index] = counts['saves'] ?? 0;
          _commentCounts[index] = counts['comments'] ?? 0;
          _liked[index] = userInteractions['liked'] ?? false;
          _saved[index] = userInteractions['saved'] ?? false;
          // Also set follow status if available
          if (userInteractions != null && userInteractions.containsKey('following')) {
            _following[index] = _toBool(userInteractions['following']) ?? false;
            print('[DEBUG] Set _following[$index] from API: ${_following[index]}');
          }
        });
        
        print('[DEBUG] Updated interaction states for post $index:');
        print('[DEBUG] - Likes: ${_likeCounts[index]}');
        print('[DEBUG] - Saves: ${_saveCounts[index]}');
        print('[DEBUG] - Comments: ${_commentCounts[index]}');
        print('[DEBUG] - Liked: ${_liked[index]}');
        print('[DEBUG] - Saved: ${_saved[index]}');
      } else {
        print('[DEBUG] Failed to load interaction counts for post $index:');
        print('[DEBUG] Success flag: ${response.data['success']}');
        print('[DEBUG] Error message: ${response.data['message']}');
      }
    } catch (e) {
      print('[DEBUG] Error loading interaction counts for post $index: $e');
    }
  }

  Future<void> _loadRemainingPostsInBackground() async {
    if (_isBackgroundPrefetching || !_hasMorePosts) return;
    _isBackgroundPrefetching = true;
    try {
      while (mounted && _hasMorePosts) {
        await _loadPersonalizedFeed(loadMore: true, silentLoadMore: true);
      }
    } finally {
      _isBackgroundPrefetching = false;
    }
  }

  void _disposeAllVideoControllers() {
    for (final controller in _videoControllers) {
      controller?.dispose();
    }
    _videoControllers.clear();
    _initializingVideoControllers.clear();
  }

  Future<void> _initializeVideoController(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (_videoControllers.length <= index) return;
    if (_videoControllers[index] != null) return;
    if (_initializingVideoControllers.contains(index)) return;

    final mediaFiles = _posts[index]['media_files'] as List<dynamic>?;
    if (mediaFiles == null || mediaFiles.isEmpty) return;

    final mediaFile = mediaFiles.first;
    final filePath = mediaFile['file_path'] as String?;
    final fileType = mediaFile['file_type'] as String?;

    if (filePath == null || fileType != 'video') return;

    _initializingVideoControllers.add(index);
    final controller = VideoPlayerController.network(filePath);
    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    bool controllerAttached = false;
    try {
      await controller.initialize();
      controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      if (_videoControllers.length > index) {
        setState(() {
          _videoControllers[index] = controller;
        });
        controllerAttached = true;
      }
      if (controllerAttached) {
        final resumePosition = _resumePositions[index];
        if (resumePosition != null &&
            resumePosition >= Duration.zero &&
            resumePosition < controller.value.duration) {
          controller.seekTo(resumePosition);
        }
        if (index == _currentPage) {
          controller.play();
          _resumePositions.remove(index);
        } else {
          controller.pause();
        }
      } else {
        controller.dispose();
      }
    } catch (e) {
      controller.dispose();
      print('Error initializing video controller for post $index: $e');
    } finally {
      _initializingVideoControllers.remove(index);
    }
  }

  void _disposeVideoController(int index) {
    if (index < 0 || index >= _videoControllers.length) return;
    final controller = _videoControllers[index];
    controller?.dispose();
    if (_videoControllers.length > index) {
      _videoControllers[index] = null;
    }
    _initializingVideoControllers.remove(index);
    _resumePositions.remove(index);
  }

  void _prepareVideoControllers(int centerIndex) {
    if (_posts.isEmpty) return;
    final int start = (centerIndex - 1).clamp(0, _posts.length - 1).toInt();
    final int end = (centerIndex + 1).clamp(0, _posts.length - 1).toInt();

    for (int i = start; i <= end; i++) {
      _initializeVideoController(i);
    }

    for (int i = 0; i < _videoControllers.length; i++) {
      if (i < start || i > end) {
        if (_videoControllers[i] != null) {
          _disposeVideoController(i);
        }
      }
    }
  }

  void _seekVideo(int index, Duration offset) {
    if (index < 0 || index >= _videoControllers.length) return;
    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) return;

    final currentPosition = controller.value.position;
    final duration = controller.value.duration;
    final newPosition = currentPosition + offset;
    
    // Clamp the position manually
    Duration clampedPosition;
    if (newPosition < Duration.zero) {
      clampedPosition = Duration.zero;
    } else if (newPosition > duration) {
      clampedPosition = duration;
    } else {
      clampedPosition = newPosition;
    }
    
    controller.seekTo(clampedPosition);
  }

  void _toggleVideoPlayback(int index) {
    if (index < 0 || index >= _videoControllers.length) return;
    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      if (controller.value.isPlaying) {
        _resumePositions[index] = controller.value.position;
        controller.pause();
      } else {
        final resumePosition = _resumePositions[index];
        if (resumePosition != null &&
            resumePosition >= Duration.zero &&
            resumePosition < controller.value.duration) {
          controller.seekTo(resumePosition);
        }
        controller.play();
        _resumePositions.remove(index);
      }
    });
  }

  Future<void> _checkFollowStatus(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (index >= _following.length) return;
    if (_followLoading[index]) return;

    final currentPost = _posts[index];
    final user = currentPost['user'];
    if (user is! Map<String, dynamic>) return;
    final username = user['username']?.toString();
    if (username == null || username.isEmpty) return;

    try {
      final response = await _apiService.checkFollowStatus(username);
      if (mounted && response.data['success'] == true) {
        final data = response.data['data'];
        final isFollowing = data['following'] ?? false;
        setState(() {
          _following[index] = isFollowing;
        });
        print('[DEBUG] Loaded follow status for index $index from API: $isFollowing');
      }
    } catch (e) {
      print('[DEBUG] Error checking follow status for index $index: $e');
    }
  }

  void _toggleFollowUser(int index) {
    if (index < 0 || index >= _posts.length) return;
    if (index >= _followLoading.length || index >= _following.length) return;
    if (_followLoading[index]) return;

    final currentPost = _posts[index];
    final user = currentPost['user'];
    if (user is! Map<String, dynamic>) return;
    final userId = _extractUserId(user);
    if (userId == null) return;

    final previous = _following[index];

    setState(() {
      _followLoading[index] = true;
      _following[index] = !previous;
    });

    _apiService.toggleFollowUser(userId).then((response) {
      if (!mounted) return;
      if (response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _following[index] = data['following'] ?? _following[index];
          _followLoading[index] = false;
        });
      } else {
        setState(() {
          _following[index] = previous;
          _followLoading[index] = false;
        });
      }
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _following[index] = previous;
        _followLoading[index] = false;
      });
    });
  }

  void _showTajStarsGift(BuildContext context) {
    if (_currentPage >= _posts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a post before sending TajStars.')),
      );
      return;
    }

    final post = _posts[_currentPage];
    final user = post['user'];
    if (user is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load creator info for gifting.')),
      );
      return;
    }

    final receiverId = _extractUserId(user);
    final postId = _toInt(post['id']);
    if (receiverId == null || postId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gifting data missing for this post.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => TajStarsGiftModal(
        postId: postId,
        receiverId: receiverId,
        receiverName: _getUserDisplayName(user),
        receiverAvatar: _getProfileImageUrl(user, post),
        postThumbnail: _getPostThumbnail(post),
      ),
    ).then((result) {
      if (!mounted || result == null) return;
      if (result is Map<String, dynamic>) {
        final giftName = result['giftName']?.toString();
        final giftValue = result['giftValue'];
        if (giftName != null) {
          final valueText = giftValue is num ? ' (${giftValue.toStringAsFixed(0)} TajStars)' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sent $giftName$valueText'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<void> _openCreateVideoFlow() async {
    // Navigate to create content screen
    context.go('/create');
  }

  void _goToChannelForUpload() {
    context.push('/channel', extra: {'openCreateModalOnStart': true});
  }

  // Quick logout function
  Future<void> _quickLogout() async {
    try {
      // Clear the token from secure storage
      await _apiService.clearToken();
      
      // Navigate to login screen
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      // Still navigate to login even if token clearing fails
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _applyInitialInteractionState(int index, Map<String, dynamic> post) {
    if (index >= _likeCounts.length ||
        index >= _saveCounts.length ||
        index >= _commentCounts.length ||
        index >= _liked.length ||
        index >= _saved.length ||
        index >= _following.length) {
      return;
    }
    _likeCounts[index] = _extractCountFromPost(post, const ['likes', 'like_count', 'likeCount', 'likes_count']);
    _commentCounts[index] = _extractCountFromPost(post, const ['comments', 'comment_count', 'commentCount', 'comments_count']);
    _saveCounts[index] = _extractCountFromPost(post, const ['saves', 'save_count', 'saveCount', 'bookmarks', 'saves_count']);
    _liked[index] = _extractBoolFromPost(post, const ['liked', 'is_liked', 'has_liked']);
    _saved[index] = _extractBoolFromPost(post, const ['saved', 'is_saved', 'bookmarked', 'has_saved']);
    _following[index] = _extractBoolFromPost(post, const ['is_following', 'following', 'isFollowing']);
  }

  int _extractCountFromPost(Map<String, dynamic> post, List<String> keys) {
    for (final key in keys) {
      final value = _toInt(post[key]);
      if (value != null) return value;
    }
    const nestedMaps = [
      'counts',
      'stats',
      'metrics',
      'interactions',
      'interaction_counts',
      'engagement',
    ];
    for (final mapKey in nestedMaps) {
      final value = _extractCountFromMap(post[mapKey], keys);
      if (value != null) return value;
    }
    return 0;
  }

  int? _extractCountFromMap(dynamic source, List<String> keys) {
    if (source is Map) {
      for (final key in keys) {
        final value = _toInt(source[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool _extractBoolFromPost(Map<String, dynamic> post, List<String> keys) {
    for (final key in keys) {
      final value = _toBool(post[key]);
      if (value != null) return value;
    }
    const nestedMaps = [
      'user_interactions',
      'interactions',
      'meta',
    ];
    for (final mapKey in nestedMaps) {
      final map = post[mapKey];
      if (map is Map<String, dynamic>) {
        for (final key in keys) {
          final value = _toBool(map[key]);
          if (value != null) return value;
        }
      }
    }
    return false;
  }

  int? _extractUserId(Map<String, dynamic>? user) {
    final id = user?['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  bool _canModifyContent(Map<String, dynamic>? user) {
    final ownerId = _extractUserId(user);
    if (ownerId == null || _currentUserId == null) return false;
    return ownerId == _currentUserId;
  }

  bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  String? _getProfileImageUrl(Map<String, dynamic>? user, [Map<String, dynamic>? post]) {
    if (user == null) return null;
    const candidateKeys = [
      'profile_photo_url',
      'profilePhotoUrl',
      'profile_avatar',
      'profileAvatar',
      'profile_avatar_url',
      'profileAvatarUrl',
      'avatar_url',
      'avatar',
      'photo',
      'profile_image',
      'profileImage',
      'image',
      'picture',
      'user_avatar',
      'userAvatar',
      'user_profile_photo_url',
      'profilePhoto',
      'profilePic',
    ];
    for (final key in candidateKeys) {
      final value = user[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      if (value is Map && value['url'] is String && (value['url'] as String).isNotEmpty) {
        return value['url'] as String;
      }
    }
    if (post != null) {
      for (final key in candidateKeys) {
        final rootValue = post[key];
        if (rootValue is String && rootValue.isNotEmpty) {
          return rootValue;
        }
        if (rootValue is Map && rootValue['url'] is String && (rootValue['url'] as String).isNotEmpty) {
          return rootValue['url'] as String;
        }
      }
    }
    return null;
  }

  String _getUserInitial(Map<String, dynamic>? user) {
    final name = user?['name']?.toString();
    final username = user?['username']?.toString();
    final source = (name != null && name.isNotEmpty)
        ? name
        : (username != null && username.isNotEmpty ? username : null);
    return source != null ? source.substring(0, 1).toUpperCase() : 'U';
  }

  String _getUserDisplayName(Map<String, dynamic>? user) {
    if (user == null) return 'Unknown User';
    final name = user['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    final username = user['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    return 'Unknown User';
  }

  String? _getPostThumbnail(Map<String, dynamic>? post) {
    if (post == null) return null;
    final mediaFiles = post['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final firstMedia = mediaFiles.first;
      if (firstMedia is Map) {
        final candidates = [
          firstMedia['thumbnail_url'],
          firstMedia['thumbnail'],
          firstMedia['preview'],
          firstMedia['file_path'],
          firstMedia['url'],
        ];
        for (final candidate in candidates) {
          if (candidate is String && candidate.isNotEmpty) {
            return candidate;
          }
        }
      }
    }
    const fallbackKeys = [
      'thumbnail_url',
      'thumbnail',
      'cover_image',
      'cover',
      'preview_image',
    ];
    for (final key in fallbackKeys) {
      final value = post[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Widget _buildFollowButton(int index, Map<String, dynamic>? user) {
    if (index < 0 || index >= _following.length || index >= _followLoading.length) {
      return const SizedBox.shrink();
    }
    final userId = _extractUserId(user);
    if (userId == null) return const SizedBox.shrink();

    // Check if we need to load follow status from API
    // Only check if we haven't loaded it yet (cached value is still false and we haven't checked)
    if (index < _posts.length && !_followLoading[index]) {
      final post = _posts[index];
      final postUser = post['user'];
      if (postUser is Map<String, dynamic>) {
        final username = postUser['username']?.toString();
        // Check if follow status is in post data first
        bool foundInPost = false;
        const followKeys = ['is_following', 'following', 'isFollowing'];
        
        // Check root level
        for (final key in followKeys) {
          if (post.containsKey(key)) {
            final value = _toBool(post[key]);
            if (value != null) {
              if (index < _following.length && _following[index] != value) {
                setState(() {
                  _following[index] = value;
                });
              }
              foundInPost = true;
              break;
            }
          }
        }
        
        // Check user_interactions if available
        if (!foundInPost) {
          final interactions = post['user_interactions'];
          if (interactions is Map<String, dynamic> && interactions.containsKey('following')) {
            final value = _toBool(interactions['following']);
            if (value != null && index < _following.length && _following[index] != value) {
              setState(() {
                _following[index] = value;
              });
              foundInPost = true;
            }
          }
        }
        
        // If not found in post and username is available, check from API
        if (!foundInPost && username != null && username.isNotEmpty) {
          // Only check if we haven't set it yet (still false from initialization)
          // This prevents multiple API calls
          _checkFollowStatus(index);
        }
      }
    }

    final isFollowing = index < _following.length ? _following[index] : false;
    final isLoading = _followLoading[index];

    return GestureDetector(
      onTap: isLoading ? null : () => _toggleFollowUser(index),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isFollowing ? const Color(0xFF1DB954) : Colors.amber,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(4.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Icon(
                isFollowing ? Icons.check : Icons.add,
                size: 14,
                color: Colors.black,
              ),
      ),
    );
  }

  Widget _buildUserAvatar(Map<String, dynamic>? user, {double radius = 20}) {
    final avatarUrl = _getProfileImageUrl(user);
    final letter = _getUserInitial(user);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius > 18 ? 14 : 12,
              ),
            )
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _loadCurrentUser();
    
    // Load personalized feed
    _loadPersonalizedFeed();
    
    // Load notification unread count
    _loadNotificationUnreadCount();
    
    // Set up periodic refresh for notification count
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotificationUnreadCount();
    });
    
    // Initialize Firebase and load messages count
    _initializeFirebaseAndLoadMessagesCount();
  }
  
  Future<void> _initializeFirebaseAndLoadMessagesCount() async {
    try {
      await FirebaseService.initialize();
      await FirebaseService.initializeAuth();
      
      if (_currentUserId != null && FirebaseService.isInitialized) {
        _messagesCountSubscription = FirebaseService.getUnreadCountStream(_currentUserId!)
            .listen((count) {
          if (mounted) {
            setState(() {
              _messagesUnreadCount = count;
            });
          }
        }, onError: (error) {
          print('[MESSAGES] Error loading unread count: $error');
        });
      }
    } catch (e) {
      print('[MESSAGES] Error initializing Firebase: $e');
    }
  }
  
  Future<void> _loadNotificationUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _notificationUnreadCount = response.data['data']['unread_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Silently fail - notifications are not critical
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      if (mounted) {
        setState(() {
          _currentUserId = parsedId;
        });
      } else {
        _currentUserId = parsedId;
      }
      
      // Load user profile
      if (_currentUserId != null) {
        _loadUserProfile();
      }
    } catch (e) {
      print('[ERROR] Failed to load current user id: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _apiService.getProfile();
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _currentUserProfile = response.data['data'];
          });
        }
      }
    } catch (e) {
      print('[ERROR] Failed to load user profile: $e');
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    _controller.dispose();
    _pageController.dispose();
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    for (final controller in _editControllers.values) {
      controller.dispose();
    }
    for (final controller in _replyEditControllers.values) {
      controller.dispose();
    }
    
    // Dispose video controllers
    _disposeAllVideoControllers();
    
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      // Clear comments when switching posts
      _comments = [];
      _commentsLoading = false;
      _commentReplies.clear();
      _showReplies.clear();
      _showReplyInput.clear();
      _replyControllers.clear();
      _editingCommentId = null;
      _editControllers.clear();
      _editingReplyId = null;
      _replyEditControllers.clear();
      // Clear comment controller
      _commentController.clear();
      // Pause all videos except the current
      for (int i = 0; i < _videoControllers.length; i++) {
        if (_videoControllers[i] != null) {
          if (i == index) {
            if (_videoControllers[i]!.value.isInitialized) {
              _videoControllers[i]!.play();
              _resumePositions.remove(i);
            }
          } else {
            if (_videoControllers[i]!.value.isInitialized) {
              _resumePositions[i] = _videoControllers[i]!.value.position;
            }
            _videoControllers[i]!.pause();
          }
        }
      }
    });

    _prepareVideoControllers(index);

    if (_posts.isNotEmpty && _hasMorePosts && !_isFetchingMore && index >= (_posts.length - 3)) {
      _loadPersonalizedFeed(loadMore: true);
    }
  }

  Future<void> _loadComments([StateSetter? modalSetState]) async {
    if (_commentsLoading) return;
    
    // Set loading state immediately and clear comments
    setState(() {
      _commentsLoading = true;
      _comments = []; // Clear existing comments while loading
    });
    
    // Also update modal if callback provided
    modalSetState?.call(() {});
    
    try {
      final postId = _posts[_currentPage]['id'];
      final response = await _apiService.getComments(postId);
      
      if (response.data['success']) {
        final comments = List<Map<String, dynamic>>.from(response.data['data']['data'] ?? []);
        
        // Process comments to extract replies and likes
        for (var comment in comments) {
          final commentId = _toInt(comment['id']) ?? (comment['id'] is int ? comment['id'] as int : null);
          if (commentId == null) continue;
          
          final replies = comment['replies'] ?? [];
          
          // Store replies for this comment
          if (replies.isNotEmpty) {
            _commentReplies[commentId] = List<Map<String, dynamic>>.from(replies);
            // Extract like data for replies
            for (var reply in replies) {
              final replyId = _toInt(reply['id']) ?? (reply['id'] is int ? reply['id'] as int : null);
              if (replyId != null) {
                _commentLiked[replyId] = reply['is_liked'] == true || reply['is_liked'] == 1;
                _commentLikeCounts[replyId] = _toInt(reply['likes_count']) ?? 0;
              }
            }
          }
          
          // Add replies count to comment
          comment['replies_count'] = replies.length;
          
          // Extract like data for comment
          _commentLiked[commentId] = comment['is_liked'] == true || comment['is_liked'] == 1;
          _commentLikeCounts[commentId] = _toInt(comment['likes_count']) ?? 0;
        }
        
        // Update comments and UI
        setState(() {
          _comments = comments;
          _commentsLoading = false;
        });
        
        // Also update modal if callback provided
        modalSetState?.call(() {});
        
        print('[DEBUG] Comments loaded: ${_comments.length}, Loading: $_commentsLoading');
      } else {
        setState(() {
          _comments = [];
          _commentsLoading = false;
        });
        modalSetState?.call(() {});
      }
    } catch (e) {
      setState(() {
        _comments = [];
        _commentsLoading = false;
      });
      modalSetState?.call(() {});
    }
  }

  Future<void> _addComment([StateSetter? modalSetState]) async {
    if (_commentController.text.trim().isEmpty) return;
    
    final content = _commentController.text.trim();
    _commentController.clear();
    
    try {
      final postId = _posts[_currentPage]['id'];
      final response = await _apiService.addComment(postId, content);
      
      if (mounted && response.data['success']) {
        // Refresh comments to show the new comment
        await _loadComments(modalSetState);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Comment replies methods
  Future<void> _loadCommentReplies(int commentId, [StateSetter? modalSetState]) async {
    if (_repliesLoading[commentId] == true) return;
    
    // Set loading state immediately
    void setLoadingTrue() {
      _repliesLoading[commentId] = true;
    }
    modalSetState?.call(() => setLoadingTrue());
    if (mounted) setState(setLoadingTrue);
    
    try {
      final postId = _posts[_currentPage]['id'];
      print('[DEBUG] _loadCommentReplies => fetching replies for comment $commentId (post $postId)');
      final response = await _apiService.getCommentReplies(commentId);
      
      if (response.data['success']) {
        final replies = List<Map<String, dynamic>>.from(response.data['data']['data']);
        
        // Extract like data for replies
        for (var reply in replies) {
          final replyId = _toInt(reply['id']) ?? (reply['id'] is int ? reply['id'] as int : null);
          if (replyId != null) {
            _commentLiked[replyId] = reply['is_liked'] == true || reply['is_liked'] == 1;
            _commentLikeCounts[replyId] = _toInt(reply['likes_count']) ?? 0;
          }
        }
        
        void setSuccess() {
          _commentReplies[commentId] = replies;
          _repliesLoading[commentId] = false;
          print('[DEBUG] _loadCommentReplies => success comment $commentId, replies: ${replies.length}');
        }
        modalSetState?.call(() => setSuccess());
        if (mounted) setState(setSuccess);
      }
    } catch (e) {
      print('[ERROR] Error loading comment replies: $e');
      void setError() {
        _repliesLoading[commentId] = false;
        print('[DEBUG] _loadCommentReplies => error comment $commentId');
      }
      modalSetState?.call(() => setError());
      if (mounted) setState(setError);
    }
  }

  void _toggleReplies(int commentId, [StateSetter? modalSetState]) {
    final newValue = !(_showReplies[commentId] ?? false);
    _showReplies[commentId] = newValue;
    print('[DEBUG] _toggleReplies => commentId: $commentId, showReplies: $newValue');

    modalSetState?.call(() {});
    if (mounted) setState(() {});

    if (newValue && !_commentReplies.containsKey(commentId)) {
      _loadCommentReplies(commentId, modalSetState);
    }
  }

  void _toggleReplyInput(int commentId, [StateSetter? modalSetState]) {
    final newValue = !(_showReplyInput[commentId] ?? false);
    _showReplyInput[commentId] = newValue;
    print('[DEBUG] _toggleReplyInput => commentId: $commentId, showInput: $newValue');

    modalSetState?.call(() {});
    if (mounted) setState(() {});
  }

  TextEditingController _getReplyController(int commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  TextEditingController _getReplyEditController(int replyId, String initialValue) {
    if (!_replyEditControllers.containsKey(replyId)) {
      _replyEditControllers[replyId] = TextEditingController(text: initialValue);
    }
    return _replyEditControllers[replyId]!;
  }

  TextEditingController _getEditController(int commentId, String initialValue) {
    if (!_editControllers.containsKey(commentId)) {
      _editControllers[commentId] = TextEditingController(text: initialValue);
    }
    return _editControllers[commentId]!;
  }

  Future<void> _updateComment(int commentId, [StateSetter? modalSetState]) async {
    final controller = _editControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final updatedText = controller.text.trim();
    try {
      final response = await _apiService.updateComment(commentId, updatedText);
      if (response.data['success']) {
        void apply() {
          final index = _comments.indexWhere((c) => c['id'] == commentId);
          if (index != -1) {
            _comments[index]['content'] = updatedText;
          }
          _editingCommentId = null;
          _editControllers.remove(commentId);
        }
        modalSetState?.call(() => apply());
        if (mounted) setState(apply);
      }
    } catch (e) {
      print('[ERROR] Error updating comment $commentId: $e');
    }
  }

  Future<void> _deleteComment(int commentId, [StateSetter? modalSetState]) async {
    try {
      final response = await _apiService.deleteComment(commentId);
      if (response.data['success']) {
        void apply() {
          _comments.removeWhere((c) => c['id'] == commentId);
          _commentReplies.remove(commentId);
          _showReplies.remove(commentId);
          _showReplyInput.remove(commentId);
          _editControllers.remove(commentId);
          if (_editingCommentId == commentId) {
            _editingCommentId = null;
          }
          if (_currentPage < _commentCounts.length) {
            _commentCounts[_currentPage] =
                (_commentCounts[_currentPage] - 1).clamp(0, 1 << 30);
          }
        }
        modalSetState?.call(() => apply());
        if (mounted) setState(apply);
      }
    } catch (e) {
      print('[ERROR] Error deleting comment $commentId: $e');
    }
  }

  Future<void> _toggleCommentLike(int commentId, [StateSetter? modalSetState]) async {
    if (_commentLikeLoading[commentId] == true) return;
    
    final wasLiked = _commentLiked[commentId] ?? false;
    final currentCount = _commentLikeCounts[commentId] ?? 0;
    
    // Optimistic update
    void optimisticUpdate() {
      _commentLikeLoading[commentId] = true;
      _commentLiked[commentId] = !wasLiked;
      _commentLikeCounts[commentId] = (currentCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    }
    modalSetState?.call(() => optimisticUpdate());
    if (mounted) setState(optimisticUpdate);
    
    try {
      final response = await _apiService.toggleCommentLike(commentId);
      if (response.data['success']) {
        // Update with server response if available
        if (response.data['data'] != null) {
          final data = response.data['data'];
          void serverUpdate() {
            _commentLiked[commentId] = data['liked'] == true || data['liked'] == 1;
            _commentLikeCounts[commentId] = _toInt(data['like_count']) ?? currentCount;
            _commentLikeLoading[commentId] = false;
          }
          modalSetState?.call(() => serverUpdate());
          if (mounted) setState(serverUpdate);
        } else {
          _commentLikeLoading[commentId] = false;
          modalSetState?.call(() {});
          if (mounted) setState(() {});
        }
      } else {
        // Revert on failure
        void revert() {
          _commentLiked[commentId] = wasLiked;
          _commentLikeCounts[commentId] = currentCount;
          _commentLikeLoading[commentId] = false;
        }
        modalSetState?.call(() => revert());
        if (mounted) setState(revert);
      }
    } catch (e) {
      // Revert on error
      void revert() {
        _commentLiked[commentId] = wasLiked;
        _commentLikeCounts[commentId] = currentCount;
        _commentLikeLoading[commentId] = false;
      }
      modalSetState?.call(() => revert());
      if (mounted) setState(revert);
    }
  }

  Future<void> _updateReply(int replyId, int parentCommentId, [StateSetter? modalSetState]) async {
    final controller = _replyEditControllers[replyId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final updatedText = controller.text.trim();
    try {
      final response = await _apiService.updateComment(replyId, updatedText);
      if (response.data['success']) {
        void apply() {
          final repliesList = _commentReplies[parentCommentId];
          if (repliesList != null) {
            final index = repliesList.indexWhere((reply) => reply['id'] == replyId);
            if (index != -1) {
              repliesList[index]['content'] = updatedText;
            }
          }
          _editingReplyId = null;
          _replyEditControllers.remove(replyId);
        }
        modalSetState?.call(() => apply());
        if (mounted) setState(apply);
      }
    } catch (e) {
      print('[ERROR] Error updating reply $replyId: $e');
    }
  }

  Future<void> _deleteReply(int replyId, int parentCommentId, [StateSetter? modalSetState]) async {
    try {
      final response = await _apiService.deleteComment(replyId);
      if (response.data['success']) {
        void apply() {
          final repliesList = _commentReplies[parentCommentId];
          if (repliesList != null) {
            repliesList.removeWhere((reply) => reply['id'] == replyId);
          }
          final commentIndex = _comments.indexWhere((comment) => comment['id'] == parentCommentId);
          if (commentIndex != -1) {
            final currentCount = _toInt(_comments[commentIndex]['replies_count']) ?? 0;
            _comments[commentIndex]['replies_count'] = (currentCount - 1).clamp(0, 1 << 30);
          }
          if (_editingReplyId == replyId) {
            _editingReplyId = null;
          }
          _replyEditControllers.remove(replyId);
        }
        modalSetState?.call(() => apply());
        if (mounted) setState(apply);
      }
    } catch (e) {
      print('[ERROR] Error deleting reply $replyId: $e');
    }
  }

  Future<void> _addCommentReply(int commentId, [StateSetter? modalSetState]) async {
    final controller = _getReplyController(commentId);
    if (controller.text.trim().isEmpty) return;
    
    final content = controller.text.trim();
    controller.clear();
    
    try {
      final postId = _posts[_currentPage]['id'];
      final response = await _apiService.addCommentReply(postId, content, commentId);
      
      if (response.data['success']) {
        await _loadCommentReplies(commentId, modalSetState);
        void hideInput() {
          _showReplyInput[commentId] = false;
        }
        modalSetState?.call(() => hideInput());
        if (mounted) setState(hideInput);
      }
    } catch (e) {
      print('[ERROR] Error adding comment reply: $e');
    }
  }

  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return 'Just now';
    
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Just now';
    }
  }


      void _showComments() {
    final bool hasInitialComments =
        _currentPage < _commentCounts.length && _commentCounts[_currentPage] > 0;
    bool hasScheduledLoad = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  if (hasInitialComments && !hasScheduledLoad) {
                    hasScheduledLoad = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!_commentsLoading) {
                        _loadComments(setModalState);
                      }
                    });
                  }

                  Widget commentsBody;
                  if (!hasInitialComments) {
                    commentsBody = _buildNoCommentsState();
                  } else if (_commentsLoading) {
                    commentsBody = _buildCommentsLoadingSkeleton(context, scrollController);
                  } else if (_comments.isEmpty) {
                    commentsBody = _buildNoCommentsState();
                  } else {
                    commentsBody = ListView.builder(
                      controller: scrollController,
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                                  final comment = _comments[i];
                                  final int? parsedCommentId = _toInt(comment['id']) ??
                                      (comment['id'] is int ? comment['id'] as int : null);
                                  if (parsedCommentId == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final commentId = parsedCommentId;
                                  final replies = _commentReplies[commentId] ?? [];
                                  final showReplies = _showReplies[commentId] ?? false;
                                  final int repliesCount = _toInt(comment['replies_count']) ??
                                      replies.length;
                                  final Map<String, dynamic>? commentUser =
                                      comment['user'] is Map<String, dynamic>
                                          ? comment['user'] as Map<String, dynamic>
                                          : null;
                                  final bool canModifyComment = _canModifyContent(commentUser);
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: _buildUserAvatar(
                                          commentUser,
                                          radius: 20,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                commentUser?['name']?.toString() ?? 'Unknown User',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            if (canModifyComment)
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                                                color: Colors.black87,
                                                onSelected: (value) {
                                                  if (value == 'edit') {
                                                    setModalState(() {
                                                      _editingCommentId = commentId;
                                                      _editControllers[commentId] =
                                                          TextEditingController(text: comment['content']?.toString() ?? '');
                                                    });
                                                  } else if (value == 'delete') {
                                                    _deleteComment(commentId, setModalState);
                                                  }
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text(
                                                      'Edit',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (_editingCommentId == commentId)
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  TextField(
                                                    controller: _getEditController(
                                                      commentId,
                                                      comment['content']?.toString() ?? '',
                                                    ),
                                                    style: const TextStyle(color: Colors.white),
                                                    decoration: InputDecoration(
                                                      hintText: 'Edit comment...',
                                                      hintStyle: const TextStyle(color: Colors.white54),
                                                      filled: true,
                                                      fillColor: Colors.white10,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      TextButton(
                                                        onPressed: () => _updateComment(commentId, setModalState),
                                                        child: const Text('Save'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          setModalState(() {
                                                            _editingCommentId = null;
                                                            _editControllers.remove(commentId);
                                                          });
                                                        },
                                                        child: const Text('Cancel'),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            else
                                              Text(
                                                comment['content']?.toString() ?? '',
                                                style: const TextStyle(color: Colors.white70),
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  _formatCommentTime(comment['created_at']),
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                                const SizedBox(width: 12),
                                                GestureDetector(
                                                  onTap: _commentLikeLoading[commentId] == true ? null : () => _toggleCommentLike(commentId, setModalState),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      _commentLikeLoading[commentId] == true
                                                          ? const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                                              ),
                                                            )
                                                          : Icon(
                                                              _commentLiked[commentId] == true ? Icons.favorite : Icons.favorite_border,
                                                              size: 16,
                                                              color: _commentLiked[commentId] == true ? Colors.red : Colors.white54,
                                                            ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${_commentLikeCounts[commentId] ?? 0}',
                                                        style: TextStyle(
                                                          color: _commentLiked[commentId] == true ? Colors.red : Colors.white54,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (repliesCount > 0 || (_commentReplies[commentId]?.isNotEmpty ?? false)) ...[
                                                  const SizedBox(width: 12),
                                                  GestureDetector(
                                                    onTap: () => _toggleReplies(commentId, setModalState),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          showReplies ? 'Hide' : 'Show',
                                                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${repliesCount} ${repliesCount == 1 ? 'reply' : 'replies'}',
                                                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.reply, color: Colors.white54, size: 20),
                                          onPressed: () => _toggleReplyInput(commentId, setModalState),
                                        ),
                                      ),
                                      // Reply input field
                                      if (_showReplyInput[commentId] ?? false)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 60, right: 16, bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _getReplyController(commentId),
                                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                                  decoration: InputDecoration(
                                                    hintText: "Reply to ${commentUser?['name'] ?? 'this comment'}...",
                                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                                    filled: true,
                                                    fillColor: Colors.white10,
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                      borderSide: BorderSide.none,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.send, color: Colors.amber, size: 20),
                                                onPressed: () => _addCommentReply(commentId, setModalState),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Replies section
                                      if (showReplies && replies.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(left: 60, right: 16, top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Column(
                                            children: replies.map((reply) {
                                              final int? replyId = _toInt(reply['id']) ??
                                                  (reply['id'] is int ? reply['id'] as int : null);
                                              final Map<String, dynamic>? replyUser =
                                                  reply['user'] is Map<String, dynamic>
                                                      ? reply['user'] as Map<String, dynamic>
                                                      : null;
                                              final bool canModifyReply = _canModifyContent(replyUser);
                                              final bool isEditingReply =
                                                  replyId != null && _editingReplyId == replyId;
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildUserAvatar(
                                                      replyUser,
                                                      radius: 16,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        replyUser?['name']?.toString() ?? 'Unknown User',
                                                                        style: const TextStyle(
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.w500,
                                                                          fontSize: 13,
                                                                        ),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    Text(
                                                                      _formatCommentTime(reply['created_at']),
                                                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                                    ),
                                                                    if (replyId != null) ...[
                                                                      const SizedBox(width: 8),
                                                                      GestureDetector(
                                                                        onTap: _commentLikeLoading[replyId] == true ? null : () => _toggleCommentLike(replyId, setModalState),
                                                                        child: Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            _commentLikeLoading[replyId] == true
                                                                                ? const SizedBox(
                                                                                    width: 10,
                                                                                    height: 10,
                                                                                    child: CircularProgressIndicator(
                                                                                      strokeWidth: 1.5,
                                                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                                                                    ),
                                                                                  )
                                                                                : Icon(
                                                                                    _commentLiked[replyId] == true ? Icons.favorite : Icons.favorite_border,
                                                                                    size: 14,
                                                                                    color: _commentLiked[replyId] == true ? Colors.red : Colors.white54,
                                                                                  ),
                                                                            const SizedBox(width: 3),
                                                                            Text(
                                                                              '${_commentLikeCounts[replyId] ?? 0}',
                                                                              style: TextStyle(
                                                                                color: _commentLiked[replyId] == true ? Colors.red : Colors.white54,
                                                                                fontSize: 11,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                              if (canModifyReply && replyId != null)
                                                                PopupMenuButton<String>(
                                                                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
                                                                  color: Colors.black87,
                                                                  onSelected: (value) {
                                                                    final ensuredReplyId = replyId;
                                                                    if (value == 'edit') {
                                                                      setModalState(() {
                                                                        _editingReplyId = ensuredReplyId;
                                                                        _replyEditControllers[ensuredReplyId] =
                                                                            TextEditingController(text: reply['content']?.toString() ?? '');
                                                                      });
                                                                    } else if (value == 'delete') {
                                                                      _deleteReply(ensuredReplyId, commentId, setModalState);
                                                                    }
                                                                  },
                                                                  itemBuilder: (context) => const [
                                                                    PopupMenuItem(
                                                                      value: 'edit',
                                                                      child: Text(
                                                                        'Edit',
                                                                        style: TextStyle(color: Colors.white),
                                                                      ),
                                                                    ),
                                                                    PopupMenuItem(
                                                                      value: 'delete',
                                                                      child: Text(
                                                                        'Delete',
                                                                        style: TextStyle(color: Colors.white),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          if (isEditingReply)
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                TextField(
                                                                  controller: _getReplyEditController(
                                                                    replyId,
                                                                    reply['content']?.toString() ?? '',
                                                                  ),
                                                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                                                  decoration: InputDecoration(
                                                                    hintText: 'Edit reply...',
                                                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                                                    filled: true,
                                                                    fillColor: Colors.white10,
                                                                    border: OutlineInputBorder(
                                                                      borderRadius: BorderRadius.circular(12),
                                                                      borderSide: BorderSide.none,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 6),
                                                                Row(
                                                                  children: [
                                                                    TextButton(
                                                                      onPressed: () => _updateReply(replyId, commentId, setModalState),
                                                                      child: const Text('Save'),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed: () {
                                                                        setModalState(() {
                                                                          _editingReplyId = null;
                                                                          _replyEditControllers.remove(replyId);
                                                                        });
                                                                      },
                                                                      child: const Text('Cancel'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            )
                                                          else
                                                            Text(
                                                              reply['content']?.toString() ?? '',
                                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      // Loading indicator for replies
                                      if (showReplies && _repliesLoading[commentId] == true)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 60, right: 16),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                      },
                    );
                  }

                  return Column(
                    children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Text('Comments (${_commentCounts[_currentPage]})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Expanded(child: commentsBody),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _addComment(setModalState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.amber),
                          onPressed: () => _addComment(setModalState),
                        ),
                      ],
                    ),
                  ),
                ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoCommentsState() {
    return const Center(
      child: Text(
        'No comments yet. Be the first to comment!',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  Widget _buildCommentsLoadingSkeleton(BuildContext context, ScrollController controller) {
    return ListView.builder(
      controller: controller,
      itemCount: 8,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActivePost = _currentPage < _posts.length;
    Map<String, dynamic>? currentPost;
    Map<String, dynamic>? currentPostUser;
    if (hasActivePost) {
      currentPost = _posts[_currentPage];
      final candidate = currentPost['user'];
      if (candidate is Map<String, dynamic>) {
        currentPostUser = candidate;
      }
    }
    final avatarUrl = hasActivePost ? _getProfileImageUrl(currentPostUser, currentPost) : null;
    final displayLetter = hasActivePost ? _getUserInitial(currentPostUser) : 'U';
    final displayName = hasActivePost ? _getUserDisplayName(currentPostUser) : 'Loading...';

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: SafeArea(
                    child: Column(
                      children: [
            TajifyTopBar(
              onSearch: () => context.push('/search'),
              onNotifications: () {
                context.push('/notifications').then((_) {
                  _loadNotificationUnreadCount();
                });
              },
              onMessages: () {
                context.push('/messages').then((_) {
                  _initializeFirebaseAndLoadMessagesCount();
                });
              },
              onAdd: _openCreateVideoFlow,
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserProfile?['profile_avatar']?.toString(),
              displayLetter: _currentUserProfile?['name'] != null &&
                      _currentUserProfile!['name'].toString().isNotEmpty
                  ? _currentUserProfile!['name'].toString()[0].toUpperCase()
                  : 'U',
            ),
            // Tabs
            // Main Feed Section (Side-flip PageView)
            Expanded(
              child: _isLoading
                  ? const _FeedSkeleton()
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Failed to load feed',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPersonalizedFeed,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _posts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No posts available',
                                    style: TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadPersonalizedFeed,
                                    child: const Text('Refresh Feed'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Debug: $_errorMessage',
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                PageView.builder(
                                  controller: _pageController,
                                  scrollDirection: Axis.vertical,
                                  itemCount: _posts.length,
                                  onPageChanged: _onPageChanged,
                                  itemBuilder: (context, index) {
                                    final post = _posts[index];
                                    final videoController = index < _videoControllers.length
                                        ? _videoControllers[index]
                                        : null;
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 0.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                      } else if (_currentPage == index) {
                        value = 0.0;
                      } else {
                        value = _currentPage - index.toDouble();
                      }
                      value = value.clamp(-1.0, 1.0);
                      // 3D flip effect
                      final double rotationY = value * 1.2; // radians
                      final double opacity = (1 - value.abs()).clamp(0.0, 1.0);
                                    
                      Widget mediaWidget;
                                    final mediaFiles = post['media_files'] as List<dynamic>?;
                                    
                                    if (mediaFiles != null && mediaFiles.isNotEmpty) {
                                      final mediaFile = mediaFiles[0];
                                      final filePath = mediaFile['file_path'] as String?;
                                      final fileType = mediaFile['file_type'] as String?;
                                      
                                      if (fileType == 'video' && filePath != null) {
                                        if (videoController == null) {
                                          _initializeVideoController(index);
                                        }
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: (videoController == null)
                              ? Container(color: Colors.black)
                              : (videoController.value.hasError
                                  ? Container(
                                      color: Colors.black,
                                                      child: const Center(
                                child: Text(
                                          'Video failed to load',
                                          style: TextStyle(color: Colors.red, fontSize: 16),
                                        ),
                                      ),
                                    )
                                  : (videoController.value.isInitialized
                                      ? LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Stack(
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _toggleVideoPlayback(index),
                                                  onDoubleTapDown: (details) {
                                                    final screenWidth = MediaQuery.of(context).size.width;
                                                    final tapX = details.globalPosition.dx;
                                                    if (tapX < screenWidth / 2) {
                                                      // Left side - seek backward 10 seconds
                                                      _seekVideo(index, const Duration(seconds: -10));
                                                    } else {
                                                      // Right side - seek forward 10 seconds
                                                      _seekVideo(index, const Duration(seconds: 10));
                                                    }
                                                  },
                                                  child: Center(
                                                    child: FittedBox(
                                                      fit: BoxFit.contain,
                                                      child: SizedBox(
                                                        width: videoController.value.size.width,
                                                        height: videoController.value.size.height,
                                                        child: VideoPlayer(videoController),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (!videoController.value.isPlaying)
                                                  Center(
                                                    child: GestureDetector(
                                                      onTap: () => _toggleVideoPlayback(index),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.black45,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.play_arrow,
                                                          color: Colors.white,
                                                          size: 64,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        )
                                      : const _VideoSkeleton())),
                        );
                                      } else if (fileType == 'image' && filePath != null) {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                                            filePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.black,
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                              ),
                            ),
                                        );
                                      } else {
                                        mediaWidget = ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Container(
                                            color: Colors.black,
                                            child: const Center(child: Icon(Icons.media_bluetooth_off, color: Colors.white54)),
                                          ),
                                        );
                                      }
                                    } else {
                                      mediaWidget = ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          color: Colors.black,
                                          child: const Center(child: Icon(Icons.media_bluetooth_off, color: Colors.white54)),
                          ),
                        );
                      }
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(rotationY),
                        child: Opacity(
                          opacity: opacity,
                          child: Stack(
                            children: [
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: mediaWidget,
                              ),
                              // Video description at the bottom
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _VideoDescriptionBar(
                                  description: _currentPage < _posts.length 
                                      ? _posts[_currentPage]['description']?.toString()
                                      : null,
                                ),
                              ),
                        ],
                    ),
                  ),
                      );
                    },
                  );
                },
                    ),
                              ],
                            )
                  ),
            // User info & actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  GestureDetector(
                    onTap: () {
                      final username = currentPostUser?['username']?.toString();
                      if (username != null && username.isNotEmpty) {
                        context.go('/user/$username');
                      }
                    },
                    child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                displayLetter,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: _buildFollowButton(_currentPage, currentPostUser),
                      ),
                    ],
                    ),
                  ),
                            const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final username = currentPostUser?['username']?.toString();
                    if (username != null && username.isNotEmpty) {
                      context.go('/user/$username');
                    }
                  },
                  child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.28,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      ),
                    ),
                  ),
                ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _toggleLike(_currentPage) : null,
                    child: _iconStatColumn(
                      _currentPage < _posts.length && _liked[_currentPage] ? Icons.favorite : Icons.favorite_border,
                      _currentPage < _posts.length ? _formatCount(_likeCounts[_currentPage]) : '0',
                      color: _currentPage < _posts.length && _liked[_currentPage] ? Colors.amber : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showComments,
                    child: _iconStatColumn(
                      Icons.message_outlined, 
                      _currentPage < _posts.length ? _formatCount(_commentCounts[_currentPage]) : '0'
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _toggleSave(_currentPage) : null,
                    child: _iconStatColumn(
                      _currentPage < _posts.length && _saved[_currentPage] ? Icons.bookmark : Icons.bookmark_border,
                      _currentPage < _posts.length ? _formatCount(_saveCounts[_currentPage]) : '0',
                      color: _currentPage < _posts.length && _saved[_currentPage] ? Colors.amber : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showTajStarsGift(context),
                    child: _iconStatColumn(Icons.card_giftcard, 'Gift'),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _share(_currentPage) : null,
                    child: _iconStatColumn(Icons.share_outlined, 'Share'),
                  ),
                ],
              ),
            ),
            // Bottom nav buttons
            BottomNavigationBar(
              backgroundColor: const Color(0xFF232323),
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_outlined),
                  label: 'Connect',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.live_tv_outlined),
                  label: 'Channel',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  label: 'Market',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_graph_outlined),
                  label: 'Earn',
                ),
              ],
              currentIndex: 0, // Valid index, but all tabs look unselected
              onTap: (int index) {
                if (index == 0) {
                  context.go('/connect');
                } else if (index == 1) {
                  context.go('/channel');
                } else if (index == 2) {
                  context.go('/market');
                } else if (index == 3) {
                  context.go('/earn');
                }
                // Add navigation for other tabs as needed
              },
                  ),
                ],
              ),
            ),
          );
  }

  Widget _iconStatColumn(IconData icon, String stat, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 1),
        Text(stat, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}


class _VideoDescriptionBar extends StatefulWidget {
  final String? description;
  const _VideoDescriptionBar({this.description});

  @override
  State<_VideoDescriptionBar> createState() => _VideoDescriptionBarState();
}

class _VideoDescriptionBarState extends State<_VideoDescriptionBar> {
  bool _expanded = false;
  bool _textOverflows = false;
  final GlobalKey _textKey = GlobalKey();
  final String _fallbackDescription = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
  }

  void _checkTextOverflow() {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: widget.description ?? _fallbackDescription,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: renderBox.size.width);
      setState(() {
        _textOverflows = textPainter.didExceedMaxLines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxLines = _expanded ? 5 : 1;
    final overflow = _expanded ? TextOverflow.visible : TextOverflow.ellipsis;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(minHeight: 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              key: _textKey,
              widget.description ?? _fallbackDescription,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
          if (_textOverflows || _expanded)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  _expanded ? 'see less' : 'see more',
                  style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarouselImageSlider extends StatefulWidget {
  final List<String> images;
  const _CarouselImageSlider({required this.images});

  @override
  State<_CarouselImageSlider> createState() => _CarouselImageSliderState();
}

class _CarouselImageSliderState extends State<_CarouselImageSlider> {
  int _current = 0;
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _current = i),
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, i) => Image.network(
            widget.images[i],
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black,
              child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
            ),
          ),
        ),
        // Media count badge at top right
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 4),
        Text(
                  '${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _current ? Colors.amber : Colors.white24,
              ),
            )),
          ),
        ),
      ],
    );
  }
}

class _TajStarsGiftModal extends StatefulWidget {
  final int postId;
  final int receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final String? postThumbnail;

  const _TajStarsGiftModal({
    required this.postId,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    this.postThumbnail,
  });

  @override
  State<_TajStarsGiftModal> createState() => _TajStarsGiftModalState();
}

class _TajStarsGiftModalState extends State<_TajStarsGiftModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();

  bool _loadingGifts = false;
  bool _walletLoading = false;
  bool _sendingGift = false;
  bool _showCelebration = false;
  bool _isAnonymous = false;
  String? _errorMessage;
  String? _walletError;
  String? _successMessage;
  double? _walletBalance;
  List<Map<String, dynamic>> _availableGifts = [];
  Map<String, dynamic>? _selectedGift;
  int _giftQuantity = 1;

  final List<int> _quantityPresets = [1, 5, 10];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    _loadGiftCatalog();
    _loadWalletBalance();
  }

  Future<void> _loadGiftCatalog() async {
    setState(() {
      _loadingGifts = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getGifts();
      final payload = response.data;
      final gifts = _normalizeGiftPayload(payload);
      if (mounted) {
        setState(() {
          _availableGifts = gifts;
          if (gifts.isNotEmpty) {
            _selectedGift ??= gifts.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableGifts = [];
          _errorMessage = 'Unable to load gifts. Pull to refresh.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingGifts = false;
        });
      }
    }
  }

  Future<void> _loadWalletBalance() async {
    setState(() {
      _walletLoading = true;
      _walletError = null;
    });
    try {
      final response = await _apiService.getWallet();
      final balance = _extractWalletBalance(response.data);
      if (mounted) {
        setState(() {
          _walletBalance = balance;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletError = 'Unable to fetch wallet balance';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _walletLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _normalizeGiftPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((gift) => Map<String, dynamic>.from(gift))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      if (payload['data'] is List) {
        return (payload['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList();
      }
      if (payload['gifts'] is List) {
        return (payload['gifts'] as List)
            .whereType<Map<String, dynamic>>()
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList();
      }
    }
    return [];
  }

  double? _extractWalletBalance(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final root = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : payload;
      final walletData = root['wallet'] is Map<String, dynamic>
          ? root['wallet'] as Map<String, dynamic>
          : root;
      final dynamic value = walletData['tajstarsCoins'] ??
          walletData['tajstars_balance'] ??
          walletData['coins'] ??
          walletData['tajstars'];
      return _parseDouble(value);
    }
    if (payload is num) return payload.toDouble();
    return null;
  }

  double _calculateTotalCost() {
    final price = _selectedGift != null
        ? _parseDouble(_selectedGift!['price']) ?? 0
        : 0;
    return price * _giftQuantity.toDouble();
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;
    final giftId = _parseInt(_selectedGift!['id']);
    if (giftId == null) {
      setState(() => _errorMessage = 'Invalid gift selection.');
      return;
    }

    final totalCost = _calculateTotalCost();

    setState(() {
      _sendingGift = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.sendGift(
        giftId: giftId,
        receiverId: widget.receiverId,
        postId: widget.postId,
        quantity: _giftQuantity,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        isAnonymous: _isAnonymous,
      );

      final payload = response.data;
      final success = payload is Map<String, dynamic>
          ? (payload['success'] != false)
          : true;
      if (!success) {
        final message = payload['message'] ?? 'Unable to send gift.';
        setState(() {
          _errorMessage = message.toString();
        });
        return;
      }

      final remainingBalance = payload['data']?['remaining_balance'] ??
          payload['remaining_balance'];
      if (mounted) {
        setState(() {
          _walletBalance =
              _parseDouble(remainingBalance) ?? _walletBalance ?? 0.0;
        });
      }

      _playCelebration(totalCost);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send gift. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingGift = false;
        });
      }
    }
  }

  void _playCelebration(double giftValue) {
    setState(() {
      _showCelebration = true;
      _successMessage =
          'Sent ${_selectedGift?['name'] ?? 'gift'} (${giftValue.toStringAsFixed(0)} TajStars)';
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pop({
        'giftName': _selectedGift?['name'] ?? 'TajStars',
        'giftValue': giftValue,
      });
    });
  }

  Future<void> _refreshGiftData() async {
    await Future.wait([
      _loadGiftCatalog(),
      _loadWalletBalance(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _calculateTotalCost();
    final hasSufficientBalance = _walletBalance == null ||
        (_walletBalance ?? 0) >= totalCost;

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.purple.withOpacity(0.35),
                Colors.blue.withOpacity(0.18),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    _buildHandleBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshGiftData,
                        color: Colors.amber,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 16),
                            _buildWalletSummary(),
                            if (_walletError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _walletError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SlideTransition(
                              position: _slideAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildGiftGrid(),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildQuantitySelector(),
                            const SizedBox(height: 16),
                            _buildMessageField(),
                            const SizedBox(height: 24),
                            if (!hasSufficientBalance && _walletBalance != null)
                              _buildBalanceWarning(totalCost),
                            _buildSendButton(
                              totalCost,
                              hasSufficientBalance,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _loadGiftCatalog,
                                child: const Text(
                                  'Reload gifts',
                                  style: TextStyle(color: Colors.amber),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showCelebration) _buildCelebrationOverlay(),
      ],
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.amber, Colors.orange],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromARGB(180, 255, 215, 0),
                        Color.fromARGB(0, 255, 215, 0),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.amber,
                    size: 56,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Send TajStars',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Show ${widget.receiverName} some love ✨',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.receiverAvatar != null
                      ? NetworkImage(widget.receiverAvatar!)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: widget.receiverAvatar == null
                      ? Text(
                          widget.receiverName.isNotEmpty
                              ? widget.receiverName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Every TajStar boosts their earnings',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.postThumbnail != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.postThumbnail!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child:
                            const Icon(Icons.play_arrow, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSummary() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(0.25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.blue],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.savings_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletLoading
                      ? 'Fetching balance...'
                      : '${(_walletBalance ?? 0).toStringAsFixed(0)} TajStars',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Available balance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _walletLoading ? null : _loadWalletBalance,
            icon: Icon(
              Icons.refresh,
              color: _walletLoading ? Colors.grey : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    if (_loadingGifts) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    if (_availableGifts.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.card_giftcard, color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          const Text(
            'No gifts available right now.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _availableGifts.length,
      itemBuilder: (context, index) {
        final gift = _availableGifts[index];
        final isSelected = identical(gift, _selectedGift);
        final rarity = gift['rarity']?.toString() ?? 'common';
        final price = _parseDouble(gift['price']) ?? 0;
        return GestureDetector(
          onTap: () => setState(() => _selectedGift = gift),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.amber
                    : Colors.white.withOpacity(0.15),
                width: isSelected ? 2.5 : 1,
              ),
              color: isSelected
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.04),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        rarity.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.workspace_premium,
                      color: isSelected ? Colors.amber : Colors.white54,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  gift['name']?.toString() ?? 'Mystery Gift',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(0)} TajStars',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _quantityPresets.map((value) {
            final selected = _giftQuantity == value;
            return ChoiceChip(
              label: Text('$value'),
              selected: selected,
              onSelected: (_) => setState(() => _giftQuantity = value),
              selectedColor: Colors.amber,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white,
              ),
              backgroundColor: Colors.white.withOpacity(0.1),
            );
          }).toList(),
        ),
        Slider(
          value: _giftQuantity.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          activeColor: Colors.amber,
          label: '$_giftQuantity',
          onChanged: (value) => setState(() {
            _giftQuantity = value.round().clamp(1, 50);
          }),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message (optional)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLength: 120,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: Colors.white54),
            hintText: 'Send a note with your gift...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: _isAnonymous,
              activeColor: Colors.amber,
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value ?? false;
                });
              },
            ),
            const Text(
              'Send anonymously',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceWarning(double totalCost) {
    final deficit = totalCost - (_walletBalance ?? 0);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You need ${deficit.toStringAsFixed(0)} more TajStars to send this gift.',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(double totalCost, bool hasBalance) {
    final buttonEnabled =
        _selectedGift != null && !_sendingGift && hasBalance;
    final label = _selectedGift == null
        ? 'Select a gift'
        : hasBalance
            ? 'Send ${_selectedGift?['name'] ?? 'Gift'}'
            : 'Insufficient balance';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: buttonEnabled
            ? const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              )
            : null,
        color: buttonEnabled ? null : Colors.white.withOpacity(0.15),
      ),
      child: ElevatedButton(
        onPressed: buttonEnabled ? _sendGift : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _sendingGift
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_selectedGift != null && hasBalance) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${totalCost.toStringAsFixed(0)} TajStars',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _showCelebration ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _successMessage ?? 'Gift Sent!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}