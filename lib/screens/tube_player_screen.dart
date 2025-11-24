import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajstars_gift_modal.dart';

class TubePlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  const TubePlayerScreen({required this.videos, required this.initialIndex, Key? key}) : super(key: key);

  @override
  State<TubePlayerScreen> createState() => _TubePlayerScreenState();
}

class _TubePlayerScreenState extends State<TubePlayerScreen> with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late List<VideoPlayerController?> _videoControllers;
  int _currentPage = 0;
  // Add like/save/share state per video
  late List<bool> _liked;
  late List<int> _likeCounts;
  late List<bool> _saved;
  late List<int> _saveCounts;
  late List<int> _commentCounts;
  // Add play/pause state
  late List<bool> _isPlaying;
  late List<bool> _following;
  late List<bool> _followLoading;
  
  // Add API service
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  int? _currentUserId;
  
  // Add loading states for interactions
  late List<bool> _likeLoading;
  late List<bool> _saveLoading;
  
  // Add tap animation states
  late List<bool> _likeTapped;
  late List<bool> _saveTapped;
  
  // Comments state
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;
  final TextEditingController _commentController = TextEditingController();
  int? _editingCommentId;
  int? _editingReplyId;
  Map<int, TextEditingController> _editControllers = {};
  Map<int, TextEditingController> _replyEditControllers = {};
  
  // Comment replies state
  Map<int, List<Map<String, dynamic>>> _commentReplies = {};
  Map<int, bool> _repliesLoading = {};
  Map<int, bool> _showReplies = {};
  Map<int, bool> _showReplyInput = {};
  Map<int, TextEditingController> _replyControllers = {};
  
  // Comment likes state
  Map<int, bool> _commentLiked = {};
  Map<int, int> _commentLikeCounts = {};
  Map<int, bool> _commentLikeLoading = {};
  
  // Memory management
  bool _disposed = false;
  static const int _maxControllers = 3; // Only keep 3 controllers in memory
  
  // Notification state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  
  // Messages state
  int _messagesUnreadCount = 0;
  StreamSubscription? _messagesCountSubscription;

  @override
  bool get wantKeepAlive => false; // Don't keep alive to prevent memory issues

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialize arrays
    _liked = List.generate(widget.videos.length, (_) => false);
    _likeCounts = List.generate(widget.videos.length, (_) => 0);
    _saved = List.generate(widget.videos.length, (_) => false);
    _saveCounts = List.generate(widget.videos.length, (_) => 0);
    _commentCounts = List.generate(widget.videos.length, (_) => 0);
    _isPlaying = List.generate(widget.videos.length, (_) => false);
    _following = List.generate(widget.videos.length, (_) => false);
    _followLoading = List.generate(widget.videos.length, (_) => false);
    _likeLoading = List.generate(widget.videos.length, (_) => false);
    _saveLoading = List.generate(widget.videos.length, (_) => false);
    _likeTapped = List.generate(widget.videos.length, (_) => false);
    _saveTapped = List.generate(widget.videos.length, (_) => false);
    
    // Initialize video controllers with lazy loading
    _videoControllers = List.generate(widget.videos.length, (_) => null);
    
    // Load initial video controller
    _initializeVideoController(widget.initialIndex);
    
    // Load current user ID
    _loadCurrentUserId();
    
    // Apply initial state from incoming videos
    _applyInitialInteractionState();
    _applyInitialUserState();
    
    // Load interaction counts from API
    _loadInteractionCounts();
    
    // Auto-play the initial video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && (_videoControllers[_currentPage]?.value.isInitialized ?? false)) {
        _videoControllers[_currentPage]?.play();
        _isPlaying[_currentPage] = true;
        setState(() {});
      }
    });
    
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
      
      // Get current user ID from API
      try {
        final response = await _apiService.get('/auth/me');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final userId = response.data['data']['id'] as int?;
          if (userId != null && FirebaseService.isInitialized && !_disposed) {
            _messagesCountSubscription = FirebaseService.getUnreadCountStream(userId)
                .listen((count) {
              if (mounted && !_disposed) {
                setState(() {
                  _messagesUnreadCount = count;
                });
              }
            }, onError: (error) {
              print('[MESSAGES] Error loading unread count: $error');
            });
          }
        }
      } catch (e) {
        print('[MESSAGES] Error getting user ID: $e');
      }
    } catch (e) {
      print('[MESSAGES] Error initializing Firebase: $e');
    }
  }
  
  Future<void> _loadNotificationUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted && !_disposed) {
          setState(() {
            _notificationUnreadCount = response.data['data']['unread_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Silently fail - notifications are not critical
    }
  }

  Future<void> _initializeVideoController(int index) async {
    if (_disposed || index < 0 || index >= widget.videos.length) return;
    
    // Dispose old controllers if we have too many
    _cleanupOldControllers();
    
    // Initialize the requested controller
    if (_videoControllers[index] == null) {
      try {
        final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
        if (url.isNotEmpty) {
          print('[DEBUG] Initializing video controller for index $index');
          final controller = VideoPlayerController.network(url);
          controller.setLooping(true);
          controller.setVolume(1);
          
          await controller.initialize();
          
          if (!_disposed && mounted) {
            setState(() {
              _videoControllers[index] = controller;
            });
            
            // Auto-play if this is the current page
            if (index == _currentPage) {
              controller.play();
              _isPlaying[_currentPage] = true;
            }
          } else {
            // Dispose if widget was disposed during initialization
            controller.dispose();
          }
        }
      } catch (e) {
        print('[ERROR] Error initializing video controller for index $index: $e');
      }
    }
  }

  void _cleanupOldControllers() {
    // Count active controllers
    int activeCount = 0;
    for (var controller in _videoControllers) {
      if (controller != null) activeCount++;
    }
    
    // If we have too many, dispose the oldest ones (except current and adjacent)
    if (activeCount >= _maxControllers) {
      for (int i = 0; i < _videoControllers.length; i++) {
        if (_videoControllers[i] != null && 
            i != _currentPage && 
            i != _currentPage - 1 && 
            i != _currentPage + 1) {
          print('[DEBUG] Disposing video controller for index $i');
          _videoControllers[i]?.dispose();
          _videoControllers[i] = null;
          activeCount--;
          if (activeCount < _maxControllers) break;
        }
      }
    }
  }

  Future<void> _loadInteractionCounts() async {
    if (_disposed) return;
    
    print('[DEBUG] Loading interaction counts for ${widget.videos.length} videos');
    for (int i = 0; i < widget.videos.length; i++) {
      if (_disposed) break;
      
      try {
        final postId = widget.videos[i]['id'];
        print('[DEBUG] Loading counts for video $i, postId: $postId');
        final response = await _apiService.getInteractionCounts(postId);
        print('[DEBUG] Interaction counts response for video $i: ${response.data}');
        
        if (!_disposed && response.data['success']) {
          final data = response.data['data'];
          final counts = data['counts'] ?? {};
          final userInteractions = data['user_interactions'] ?? {};
          
          print('[DEBUG] Tube Player - Loading interaction counts for video $i');
          print('[DEBUG] User interactions keys: ${userInteractions.keys.toList()}');
          print('[DEBUG] User interactions: $userInteractions');
          
          setState(() {
            _likeCounts[i] = counts['likes'] ?? 0;
            _commentCounts[i] = counts['comments'] ?? 0;
            _saveCounts[i] = counts['saves'] ?? 0;
            _liked[i] = userInteractions['liked'] ?? false;
            _saved[i] = userInteractions['saved'] ?? false;
            if (userInteractions.containsKey('following')) {
              _following[i] = _toBool(userInteractions['following']) ?? false;
              print('[DEBUG] Set _following[$i] from API: ${_following[i]}');
            } else {
              print('[DEBUG] "following" not found in userInteractions for video $i');
            }
          });
          print('[DEBUG] Updated counts for video $i - likes: ${_likeCounts[i]}, comments: ${_commentCounts[i]}, saves: ${_saveCounts[i]}, liked: ${_liked[i]}, saved: ${_saved[i]}, following: ${_following[i]}');
        }
      } catch (e) {
        print('[ERROR] Error loading interaction counts for video $i: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    print('[DEBUG] Disposing TubePlayerScreen');
    
    // Dispose all video controllers
    for (int i = 0; i < _videoControllers.length; i++) {
      if (_videoControllers[i] != null) {
        print('[DEBUG] Disposing video controller $i');
        _videoControllers[i]?.dispose();
        _videoControllers[i] = null;
      }
    }
    
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_disposed) return;
    
    setState(() {
      _currentPage = index;
    });
    
    // Pause all videos
    for (int i = 0; i < _videoControllers.length; i++) {
      if (_videoControllers[i] != null) {
        _videoControllers[i]!.pause();
        _isPlaying[i] = false;
      }
    }
    
    // Initialize and play the new video
    _initializeVideoController(index).then((_) {
      if (!_disposed && (_videoControllers[index]?.value.isInitialized ?? false)) {
        _videoControllers[index]?.play();
        _isPlaying[index] = true;
        setState(() {});
      }
    });
  }

  void _seekVideo(int index, Duration offset) {
    if (_disposed || index < 0 || index >= _videoControllers.length) return;
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

  void _toggleLike(int index) async {
    if (_disposed || _likeLoading[index]) return; // Prevent multiple calls
    
    print('[DEBUG] Toggling like for video $index');
    
    // Trigger tap animation
    setState(() {
      _likeTapped[index] = true;
    });
    
    // Reset tap animation after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_disposed) {
        setState(() {
          _likeTapped[index] = false;
        });
      }
    });
    
    // Immediate UI feedback
    final previousLiked = _liked[index];
    final previousCount = _likeCounts[index];
    
    setState(() {
      _likeLoading[index] = true;
      _liked[index] = !_liked[index]; // Toggle immediately
      _likeCounts[index] = _liked[index] ? previousCount + 1 : previousCount - 1; // Update count immediately
    });
    
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling toggleLike API for postId: $postId');
      final response = await _apiService.toggleLike(postId);
      print('[DEBUG] Toggle like response: ${response.data}');
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        
        setState(() {
          _liked[index] = data['liked'] ?? false;
          _likeCounts[index] = data['like_count'] ?? 0;
          _likeLoading[index] = false;
        });
        print('[DEBUG] Like toggled successfully - is_liked: ${_liked[index]}, count: ${_likeCounts[index]}');
      } else {
        print('[ERROR] Toggle like failed: ${response.data}');
        // Revert to previous state on error
        if (!_disposed) {
          setState(() {
            _liked[index] = previousLiked;
            _likeCounts[index] = previousCount;
            _likeLoading[index] = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error toggling like for video $index: $e');
      // Revert to previous state on error
      if (!_disposed) {
        setState(() {
          _liked[index] = previousLiked;
          _likeCounts[index] = previousCount;
          _likeLoading[index] = false;
        });
      }
    }
  }

  void _toggleSave(int index) async {
    if (_disposed || _saveLoading[index]) return; // Prevent multiple calls
    
    print('[DEBUG] Toggling save for video $index');
    
    // Trigger tap animation
    setState(() {
      _saveTapped[index] = true;
    });
    
    // Reset tap animation after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_disposed) {
        setState(() {
          _saveTapped[index] = false;
        });
      }
    });
    
    // Immediate UI feedback
    final previousSaved = _saved[index];
    final previousCount = _saveCounts[index];
    
    setState(() {
      _saveLoading[index] = true;
      _saved[index] = !_saved[index]; // Toggle immediately
      _saveCounts[index] = _saved[index] ? previousCount + 1 : previousCount - 1; // Update count immediately
    });
    
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling toggleSave API for postId: $postId');
      final response = await _apiService.toggleSave(postId);
      print('[DEBUG] Toggle save response: ${response.data}');
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        
        setState(() {
          _saved[index] = data['saved'] ?? false;
          _saveLoading[index] = false;
        });
        print('[DEBUG] Save toggled successfully - is_saved: ${_saved[index]}');
        
        // Refresh the save count from the interaction counts endpoint
        await _refreshSaveCount(index);
      } else {
        print('[ERROR] Toggle save failed: ${response.data}');
        // Revert to previous state on error
        if (!_disposed) {
          setState(() {
            _saved[index] = previousSaved;
            _saveCounts[index] = previousCount;
            _saveLoading[index] = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error toggling save for video $index: $e');
      // Revert to previous state on error
      if (!_disposed) {
        setState(() {
          _saved[index] = previousSaved;
          _saveCounts[index] = previousCount;
          _saveLoading[index] = false;
        });
      }
    }
  }

  Future<void> _refreshSaveCount(int index) async {
    if (_disposed) return;
    
    try {
      final postId = widget.videos[index]['id'];
      final response = await _apiService.getInteractionCounts(postId);
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        final counts = data['counts'] ?? {};
        
        setState(() {
          _saveCounts[index] = counts['saves'] ?? 0;
        });
        print('[DEBUG] Refreshed save count for video $index: ${_saveCounts[index]}');
      }
    } catch (e) {
      print('[ERROR] Error refreshing save count for video $index: $e');
    }
  }

  Future<void> _loadComments([StateSetter? modalSetState]) async {
    if (_disposed || _commentsLoading) return;
    
    print('[DEBUG] Loading comments for current video');
    setState(() {
      _commentsLoading = true;
      _comments = []; // Clear existing comments while loading
    });
    
    // Also update modal if callback provided
    modalSetState?.call(() {});
    
    try {
      final postId = widget.videos[_currentPage]['id'];
      print('[DEBUG] Calling getComments API for postId: $postId');
      final response = await _apiService.getComments(postId);
      print('[DEBUG] Get comments response: ${response.data}');
      
      if (!_disposed && response.data['success']) {
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
        
        setState(() {
          _comments = comments;
          _commentsLoading = false;
        });
        
        // Also update modal if callback provided
        modalSetState?.call(() {});
        
        print('[DEBUG] Loaded ${_comments.length} comments with replies');
      } else {
        print('[ERROR] Get comments failed: ${response.data}');
        if (!_disposed) {
          setState(() {
            _comments = [];
            _commentsLoading = false;
          });
          modalSetState?.call(() {});
        }
      }
    } catch (e) {
      print('[ERROR] Error loading comments: $e');
      if (!_disposed) {
        setState(() {
          _comments = [];
          _commentsLoading = false;
        });
        modalSetState?.call(() {});
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final content = _commentController.text.trim();
    _commentController.clear();
    
    try {
      final postId = widget.videos[_currentPage]['id'];
      final response = await _apiService.addComment(postId, content);
      
      if (!_disposed && response.data['success']) {
        // Refresh comments to show the new comment
        await _loadComments();
      }
    } catch (e) {
      print('[ERROR] Error adding comment: $e');
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
      print('[DEBUG] _loadCommentReplies => fetching replies for comment $commentId');
      final response = await _apiService.getCommentReplies(commentId);
      
      if (!_disposed && response.data['success']) {
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

  Future<void> _addCommentReply(int commentId, [StateSetter? modalSetState]) async {
    final controller = _getReplyController(commentId);
    if (controller.text.trim().isEmpty) return;
    
    final content = controller.text.trim();
    controller.clear();
    
    try {
      final postId = widget.videos[_currentPage]['id'];
      final response = await _apiService.addCommentReply(postId, content, commentId);
      
      if (!_disposed && response.data['success']) {
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

  TextEditingController _getReplyController(int commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }


  void _applyInitialUserState() {
    for (int i = 0; i < widget.videos.length; i++) {
      _following[i] = _extractBoolFromPost(widget.videos[i], const [
        'is_following',
        'following',
        'isFollowing',
      ]);
    }
  }

  void _applyInitialInteractionState() {
    for (int i = 0; i < widget.videos.length; i++) {
      final post = widget.videos[i];
      _likeCounts[i] = _extractCountFromPost(post, const [
        'likes',
        'like_count',
        'likeCount',
        'likes_count',
      ]);
      _commentCounts[i] = _extractCountFromPost(post, const [
        'comments',
        'comment_count',
        'commentCount',
        'comments_count',
      ]);
      _saveCounts[i] = _extractCountFromPost(post, const [
        'saves',
        'save_count',
        'saveCount',
        'bookmarks',
        'saves_count',
      ]);
      _liked[i] = _extractBoolFromPost(post, const [
        'liked',
        'is_liked',
        'has_liked',
        'liked_by_user',
      ]);
      _saved[i] = _extractBoolFromPost(post, const [
        'saved',
        'is_saved',
        'bookmarked',
        'has_saved',
      ]);
    }
  }

  Future<void> _checkFollowStatus(int index) async {
    if (_disposed) return;
    if (index < 0 || index >= widget.videos.length) return;
    if (index >= _following.length) return;
    if (_followLoading[index]) return;

    final video = widget.videos[index];
    final user = video['user'];
    if (user is! Map<String, dynamic>) return;
    final username = user['username']?.toString();
    if (username == null || username.isEmpty) return;

    try {
      final response = await _apiService.checkFollowStatus(username);
      if (!_disposed && response.data['success'] == true) {
        final data = response.data['data'];
        final isFollowing = data['following'] ?? false;
        setState(() {
          _following[index] = isFollowing;
        });
        print('[DEBUG] Tube Player - Loaded follow status for index $index from API: $isFollowing');
      }
    } catch (e) {
      print('[DEBUG] Tube Player - Error checking follow status for index $index: $e');
    }
  }

  void _toggleFollowUser(int index) {
    if (_disposed) return;
    if (index < 0 || index >= widget.videos.length) return;
    if (_followLoading[index]) return;

    final user = widget.videos[index]['user'];
    if (user is! Map<String, dynamic>) return;
    final userId = _extractUserId(user);
    if (userId == null) return;

    final previous = _following[index];
    setState(() {
      _followLoading[index] = true;
      _following[index] = !previous;
    });

    _apiService.toggleFollowUser(userId).then((response) {
      if (_disposed) return;
      setState(() {
        if (response.data['success'] == true) {
          final data = response.data['data'];
          _following[index] = data['following'] ?? _following[index];
        } else {
          _following[index] = previous;
        }
        _followLoading[index] = false;
      });
    }).catchError((_) {
      if (_disposed) return;
      setState(() {
        _following[index] = previous;
        _followLoading[index] = false;
      });
    });
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
                    commentsBody = _buildNoCommentsView();
                  } else if (_commentsLoading) {
                    commentsBody = _buildCommentsLoadingSkeleton(context, scrollController);
                  } else if (_comments.isEmpty) {
                    commentsBody = _buildNoCommentsView();
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
                                              child: GestureDetector(
                                                onTap: () {
                                                  final username = commentUser?['username']?.toString();
                                                  if (username != null && username.isNotEmpty) {
                                                    context.go('/user/$username');
                                                  }
                                                },
                                                child: Text(
                                                  commentUser?['name']?.toString() ?? 'Unknown User',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                                ),
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
                                                                      child: GestureDetector(
                                                                        onTap: () {
                                                                          final username = replyUser?['username']?.toString();
                                                                          if (username != null && username.isNotEmpty) {
                                                                            context.go('/user/$username');
                                                                          }
                                                                        },
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
                                      const Divider(color: Colors.white24, height: 1),
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
                            onSubmitted: (_) => _addComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.amber),
                          onPressed: _addComment,
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

  Widget _buildNoCommentsView() {
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

  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  void _share(int index) async {
    if (_disposed) return;
    
    print('[DEBUG] Sharing video $index');
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling share API for postId: $postId');
      await _apiService.share(postId);
      print('[DEBUG] Share API call successful');
      
      final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url);
      } else {
        Share.share('Check out this video!');
      }
    } catch (e) {
      print('[ERROR] Error sharing video $index: $e');
      // Still share even if API call fails
      final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url);
      } else {
        Share.share('Check out this video!');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_disposed) {
      return const Scaffold(
        backgroundColor: Color(0xFF232323),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }
    
    final currentVideo = widget.videos[_currentPage];
    final currentUser = currentVideo['user'] is Map<String, dynamic>
        ? currentVideo['user'] as Map<String, dynamic>
        : null;
    final displayName = _getUserDisplayName(currentUser);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF232323),
        body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const Text('Tajify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.search, color: Colors.white, size: 20),
                    onPressed: () => context.push('/search'),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
                        onPressed: () {
                          context.push('/notifications').then((_) {
                            // Refresh unread count when returning from notifications
                            _loadNotificationUnreadCount();
                          });
                        },
                      ),
                      if (_notificationUnreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: _notificationUnreadCount > 99
                                ? const Text(
                                    '99+',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : Text(
                                    _notificationUnreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        icon: const Icon(Icons.message_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          context.push('/messages').then((_) {
                            // Refresh unread count when returning from messages
                            _initializeFirebaseAndLoadMessagesCount();
                          });
                        },
                      ),
                      if (_messagesUnreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: _messagesUnreadCount > 99
                                ? const Text(
                                    '99+',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : Text(
                                    _messagesUnreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    height: 24,
                    width: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.grey[600],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Main Content (video + overlays)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: _onPageChanged,
                itemCount: widget.videos.length,
                itemBuilder: (context, index) {
                  final controller = _videoControllers[index];
                  
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
                      final double rotationY = value * 1.2; // radians
                      final double opacity = (1 - value.abs()).clamp(0.0, 1.0);
                      
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(rotationY),
                        child: Opacity(
                          opacity: opacity,
                          child: Stack(
                            children: [
                              // Video player
                              GestureDetector(
                                onTap: () {
                                  final activeController = controller;
                                  if (!_disposed &&
                                      activeController != null &&
                                      activeController.value.isInitialized) {
                                    setState(() {
                                      if (activeController.value.isPlaying) {
                                        activeController.pause();
                                        _isPlaying[index] = false;
                                      } else {
                                        activeController.play();
                                        _isPlaying[index] = true;
                                      }
                                    });
                                  }
                                },
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
                                  child: () {
                                    final activeController = controller;
                                    if (activeController != null &&
                                        activeController.value.isInitialized) {
                                      return FittedBox(
                                        fit: BoxFit.contain,
                                        child: SizedBox(
                                          width: activeController.value.size.width,
                                          height: activeController.value.size.height,
                                          child: VideoPlayer(activeController),
                                        ),
                                      );
                                    }
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                      ),
                                    );
                                  }(),
                                ),
                              ),
                              // Play/Pause icon overlay
                              if (controller?.value.isInitialized == true &&
                                  !(controller?.value.isPlaying ?? false))
                                Center(
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
                              // Back button
                              Positioned(
                                top: 20,
                                left: 20,
                                child: GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              // Video description bar
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _VideoDescriptionBar(
                                  description: widget.videos[index]['description'] ?? '',
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
            ),
            // User info & actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final username = currentUser?['username']?.toString();
                      if (username != null && username.isNotEmpty) {
                        context.go('/user/$username');
                      }
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildUserAvatar(currentUser),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: _buildFollowButton(_currentPage, currentUser),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final username = currentUser?['username']?.toString();
                      if (username != null && username.isNotEmpty) {
                        context.go('/user/$username');
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
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
                    onTap: _likeLoading[_currentPage] ? null : () => _toggleLike(_currentPage),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(
                        _likeTapped[_currentPage] ? 0.8 : 
                        _likeLoading[_currentPage] ? 0.9 : 1.0
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _likeLoading[_currentPage] ? 0.7 : 1.0,
                        child: _iconStatColumn(
                          _liked[_currentPage] ? Icons.favorite : Icons.favorite_border,
                          _formatCount(_likeCounts[_currentPage]),
                          color: _liked[_currentPage] ? Colors.amber : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showComments,
                    child: _iconStatColumn(Icons.message_outlined, _formatCount(_commentCounts[_currentPage])),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _saveLoading[_currentPage] ? null : () => _toggleSave(_currentPage),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(
                        _saveTapped[_currentPage] ? 0.8 : 
                        _saveLoading[_currentPage] ? 0.9 : 1.0
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _saveLoading[_currentPage] ? 0.7 : 1.0,
                        child: _iconStatColumn(
                          _saved[_currentPage] ? Icons.bookmark : Icons.bookmark_border,
                          _formatCount(_saveCounts[_currentPage]),
                          color: _saved[_currentPage] ? Colors.amber : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showGiftModalForCurrentVideo,
                    child: _iconStatColumn(Icons.card_giftcard, 'Gift'),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _share(_currentPage),
                    child: _iconStatColumn(Icons.share_outlined, 'Share'),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildUserAvatar(Map<String, dynamic>? user, {double radius = 22}) {
    final avatarUrl = _getProfileImageUrl(user, widget.videos[_currentPage]);
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

  Widget _buildFollowButton(int index, Map<String, dynamic>? user) {
    if (index < 0 || index >= _following.length || index >= _followLoading.length) {
      return const SizedBox.shrink();
    }
    if (user == null) {
      return const SizedBox.shrink();
    }
    final userId = _extractUserId(user);
    if (userId == null) return const SizedBox.shrink();
    
    // Check if we need to load follow status from API
    if (index < widget.videos.length && !_followLoading[index]) {
      final post = widget.videos[index];
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

  bool _extractBoolFromPost(Map<String, dynamic> post, List<String> keys) {
    for (final key in keys) {
      final value = _toBool(post[key]);
      if (value != null) return value;
    }
    final user = post['user'];
    if (user is Map<String, dynamic>) {
      for (final key in keys) {
        final value = _toBool(user[key]);
        if (value != null) return value;
      }
    }
    final interactions = post['user_interactions'];
    if (interactions is Map<String, dynamic>) {
      for (final key in keys) {
        final value = _toBool(interactions[key]);
        if (value != null) return value;
      }
    }
    return false;
  }

  int _extractCountFromPost(Map<String, dynamic>? post, List<String> keys) {
    if (post == null) return 0;
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

  String? _getProfileImageUrl(Map<String, dynamic>? user, Map<String, dynamic>? post) {
    if (user == null && post == null) return null;
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
    for (final source in [user, post]) {
      if (source is Map<String, dynamic>) {
        for (final key in candidateKeys) {
          final value = source[key];
          if (value is String && value.isNotEmpty) return value;
          if (value is Map && value['url'] is String && (value['url'] as String).isNotEmpty) {
            return value['url'] as String;
          }
        }
      }
    }
    return null;
  }

  String _getUserDisplayName(Map<String, dynamic>? user) {
    if (user == null) return 'Unknown User';
    final name = user['name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    final username = user['username']?.toString();
    if (username != null && username.isNotEmpty) return username;
    return 'Unknown User';
  }

  String _getUserInitial(Map<String, dynamic>? user) {
    final name = user?['name']?.toString();
    final username = user?['username']?.toString();
    final source = (name != null && name.isNotEmpty)
        ? name
        : (username != null && username.isNotEmpty ? username : null);
    return source != null ? source.substring(0, 1).toUpperCase() : 'U';
  }

  int? _extractUserId(Map<String, dynamic>? user) {
    final id = user?['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      setState(() {
        _currentUserId = parsedId;
      });
    } catch (e) {
      print('[TUBE PLAYER] Error loading current user ID: $e');
    }
  }

  bool _canModifyContent(Map<String, dynamic>? user) {
    final ownerId = _extractUserId(user);
    if (ownerId == null || _currentUserId == null) return false;
    return ownerId == _currentUserId;
  }


  TextEditingController _getEditController(int commentId, String initialValue) {
    if (!_editControllers.containsKey(commentId)) {
      _editControllers[commentId] = TextEditingController(text: initialValue);
    }
    return _editControllers[commentId]!;
  }

  TextEditingController _getReplyEditController(int replyId, String initialValue) {
    if (!_replyEditControllers.containsKey(replyId)) {
      _replyEditControllers[replyId] = TextEditingController(text: initialValue);
    }
    return _replyEditControllers[replyId]!;
  }

  Future<void> _updateComment(int commentId, [StateSetter? modalSetState]) async {
    final controller = _editControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final updatedText = controller.text.trim();
    try {
      final response = await _apiService.updateComment(commentId, updatedText);
      if (!_disposed && response.data['success']) {
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

  Future<void> _toggleCommentLike(int commentId, [StateSetter? modalSetState]) async {
    if (_disposed || _commentLikeLoading[commentId] == true) return;
    
    final wasLiked = _commentLiked[commentId] ?? false;
    final currentCount = _commentLikeCounts[commentId] ?? 0;
    
    // Optimistic update
    void optimisticUpdate() {
      _commentLikeLoading[commentId] = true;
      _commentLiked[commentId] = !wasLiked;
      _commentLikeCounts[commentId] = (currentCount + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    }
    modalSetState?.call(() => optimisticUpdate());
    if (!_disposed && mounted) setState(optimisticUpdate);
    
    try {
      final response = await _apiService.toggleCommentLike(commentId);
      if (!_disposed && response.data['success']) {
        // Update with server response if available
        if (response.data['data'] != null) {
          final data = response.data['data'];
          void serverUpdate() {
            _commentLiked[commentId] = data['liked'] == true || data['liked'] == 1;
            _commentLikeCounts[commentId] = _toInt(data['like_count']) ?? currentCount;
            _commentLikeLoading[commentId] = false;
          }
          modalSetState?.call(() => serverUpdate());
          if (!_disposed && mounted) setState(serverUpdate);
        } else {
          _commentLikeLoading[commentId] = false;
          modalSetState?.call(() {});
          if (!_disposed && mounted) setState(() {});
        }
      } else {
        // Revert on failure
        void revert() {
          _commentLiked[commentId] = wasLiked;
          _commentLikeCounts[commentId] = currentCount;
          _commentLikeLoading[commentId] = false;
        }
        modalSetState?.call(() => revert());
        if (!_disposed && mounted) setState(revert);
      }
    } catch (e) {
      // Revert on error
      void revert() {
        _commentLiked[commentId] = wasLiked;
        _commentLikeCounts[commentId] = currentCount;
        _commentLikeLoading[commentId] = false;
      }
      modalSetState?.call(() => revert());
      if (!_disposed && mounted) setState(revert);
    }
  }

  Future<void> _deleteComment(int commentId, [StateSetter? modalSetState]) async {
    try {
      final response = await _apiService.deleteComment(commentId);
      if (!_disposed && response.data['success']) {
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
            _commentCounts[_currentPage] = (_commentCounts[_currentPage] - 1).clamp(0, 1 << 30);
          }
        }
        modalSetState?.call(() => apply());
        if (mounted) setState(apply);
      }
    } catch (e) {
      print('[ERROR] Error deleting comment $commentId: $e');
    }
  }

  Future<void> _updateReply(int replyId, int parentCommentId, [StateSetter? modalSetState]) async {
    final controller = _replyEditControllers[replyId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final updatedText = controller.text.trim();
    try {
      final response = await _apiService.updateComment(replyId, updatedText);
      if (!_disposed && response.data['success']) {
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
      if (!_disposed && response.data['success']) {
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
          if (candidate is String && candidate.isNotEmpty) return candidate;
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
      if (value is Map && value['url'] is String && (value['url'] as String).isNotEmpty) {
        return value['url'] as String;
      }
    }
    return null;
  }

  void _showGiftModalForCurrentVideo() {
    if (_currentPage >= widget.videos.length) return;
    final post = widget.videos[_currentPage];
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
    );
  }
}

class _VideoDescriptionBar extends StatefulWidget {
  final String description;
  const _VideoDescriptionBar({required this.description});

  @override
  State<_VideoDescriptionBar> createState() => _VideoDescriptionBarState();
}

class _VideoDescriptionBarState extends State<_VideoDescriptionBar> {
  bool _expanded = false;
  bool _textOverflows = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Check for text overflow after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
  }

  void _checkTextOverflow() {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: widget.description,
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
    if (widget.description.trim().isEmpty) {
      return const SizedBox.shrink();
    }
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
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              widget.description,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              overflow: overflow,
              key: _textKey,
            ),
          ),
          if (_textOverflows)
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