import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajstars_gift_modal.dart';

class ShortsPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  final Future<List<Map<String, dynamic>>> Function(int page)? loadMoreVideos;
  final bool isEmbedded;

  const ShortsPlayerScreen({
    required this.videos,
    required this.initialIndex,
    this.loadMoreVideos,
    this.isEmbedded = false,
    Key? key
  }) : super(key: key);

  @override
  State<ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<ShortsPlayerScreen> {
  late PageController _pageController;
  final List<Map<String, dynamic>> _videos = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final List<VideoPlayerController> _pendingDispose = [];
  final Set<int> _videosLoadingWithDio = {};
  final Set<int> _cachedVideoIndices = {};
  final Set<int> _failedIndices = {};
  bool _disposed = false;
  
  int _focusedIndex = 0;
  bool _isLoadingMore = false;
  int _page = 1;
  int _fypTabIndex = 1; // 0 = Following, 1 = For You (default)

  // Interaction States
  final Set<int> _likedVideos = {};
  final Map<int, int> _likeCounts = {};
  /// User IDs (string) we have followed in this session - so all videos by this creator show "Following"
  final Set<String> _followedUserIds = {};
  
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Only add videos that have a playable URL to avoid loading/crash
    final valid = widget.videos.where((v) => _hasValidVideoUrl(v)).toList();
    _videos.addAll(valid);
    if (_videos.isEmpty) {
      _videos.addAll(widget.videos);
    }
    _focusedIndex = widget.initialIndex >= _videos.length ? 0 : widget.initialIndex;
    _pageController = PageController(initialPage: _focusedIndex);
    
    // Initialize current and adjacent only (prev, current, next) to avoid OOM
    _initializeControllerAtIndex(_focusedIndex);
    if (_focusedIndex > 0) _initializeControllerAtIndex(_focusedIndex - 1);
    if (_focusedIndex + 1 < _videos.length) _initializeControllerAtIndex(_focusedIndex + 1);

    // Initialize counts and states
    for (int i = 0; i < _videos.length; i++) {
        _initializeVideoState(i);
    }
    _loadCurrentUser();
  }

  bool _hasValidVideoUrl(Map<String, dynamic> video) {
    final mediaFiles = video['media_files'] as List?;
    if (mediaFiles != null && mediaFiles.isNotEmpty) {
      final m = mediaFiles.firstWhere(
        (e) => e is Map && (e['file_type'] == 'video' || e['file_path'] != null),
        orElse: () => mediaFiles.first,
      );
      if (m is Map) {
        final path = m['file_path'] ?? m['file_url'] ?? m['url'];
        if (path != null && path.toString().isNotEmpty) return true;
      }
    }
    final url = video['video_url'] ?? video['media_url'] ?? video['file_path'] ?? video['file_url'] ?? video['url'];
    return url != null && url.toString().isNotEmpty;
  }

  Future<void> _loadCurrentUser() async {
    try {
      final id = await _storageService.getUserId();
      if (id != null) {
        setState(() {
          _currentUserId = int.tryParse(id);
        });
      }
    } catch (e) {
      print('Error loading user ID: $e');
    }
  }

  void _initializeVideoState(int index) {
      if (index >= _videos.length) return;
      final video = _videos[index];
      
      if (video['is_liked'] == true) _likedVideos.add(index);
      _likeCounts[index] = video['likes_count'] is int ? video['likes_count'] : (int.tryParse(video['likes_count']?.toString() ?? '0') ?? 0);
      
      final user = video['user'];
      if (user != null && _isUserFollowed(user)) {
        final uid = user['id'] ?? user['_id'];
        if (uid != null) _followedUserIds.add(uid.toString());
      }
  }

  /// True if we consider this user as "followed" (from API or session). Matches web behavior.
  bool _isUserFollowed(Map<String, dynamic> user) {
    final v = user['is_following'];
    if (v == true || v == 1 || v == 'true' || v == '1') return true;
    final uid = user['id'] ?? user['_id'];
    if (uid != null && _followedUserIds.contains(uid.toString())) return true;
    return false;
  }

  Future<void> _preloadNextVideos(int startIndex) async {
    // Preload only next 1 for playback to reduce memory (fixes crash after ~3 scrolls)
    _initializeControllerAtIndex(startIndex + 1);
    // Do not cache many files in background - causes OOM on device
    if (startIndex + 2 < _videos.length) _cacheVideoFile(startIndex + 2);
  }

  Future<File?> _cacheVideoFile(int index) async {
      if (index < 0 || index >= _videos.length) return null;
      if (_cachedVideoIndices.contains(index)) return null; // Already cached/caching logic could be smarter with file check
      if (_videosLoadingWithDio.contains(index)) return null;

      _videosLoadingWithDio.add(index);
      
      try {
          final video = _videos[index];
          final mediaFiles = video['media_files'] as List?;
          String? videoUrl = (mediaFiles != null && mediaFiles.isNotEmpty)
            ? (mediaFiles.firstWhere((m) => m['file_type'] == 'video', orElse: () => mediaFiles.first)['file_path'])
            : video['video_url'];

          if (videoUrl == null) return null;
          
          if (!videoUrl.startsWith('http')) {
              // Ensure we have a valid URL. Assuming base URL is needed.
              // In production code, handle this robustly.
              videoUrl = 'https://tajify.com$videoUrl'; 
          }

          final dir = await getTemporaryDirectory();
          final fileName = videoUrl.split('/').last;
          final file = File('${dir.path}/$fileName');

          if (await file.exists()) {
             _cachedVideoIndices.add(index);
             _videosLoadingWithDio.remove(index);
             return file;
          }

          await Dio().download(videoUrl, file.path);
          _cachedVideoIndices.add(index);
          _videosLoadingWithDio.remove(index);
          return file;
      } catch (e) {
          print('Error caching video $index: $e');
          _videosLoadingWithDio.remove(index);
          return null;
      }
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= _videos.length) return;
    if (_controllers.containsKey(index)) return; // Already initialized

    final video = _videos[index];
    final mediaFiles = video['media_files'] as List?;
    String? videoUrl;
    try {
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final first = mediaFiles.firstWhere((m) => m['file_type'] == 'video', orElse: () => mediaFiles.first);
        videoUrl = first['file_path'];
      }
      videoUrl ??= video['video_url'];
    } catch (_) {
      videoUrl = video['video_url'];
    }
    if (videoUrl == null || videoUrl.toString().isEmpty) return;
    
    VideoPlayerController? controller;
    try {
      final dir = await getTemporaryDirectory();
      final fileName = videoUrl.toString().split('/').last;
      if (fileName.isEmpty) return;
      final file = File('${dir.path}/$fileName');
      
      if (await file.exists()) {
        controller = VideoPlayerController.file(file);
      } else {
        String url = videoUrl.toString();
        if (!url.startsWith('http')) url = 'https://tajify.com$url';
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _cacheVideoFile(index);
      }

      if (controller == null) return;
      _controllers[index] = controller;
      
      await controller.initialize();
      if (!mounted) return;
      controller.setLooping(true);
      if (index == _focusedIndex) {
        controller.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      print("Error initializing video at index $index: $e");
      if (controller != null) {
        try {
          controller.dispose();
        } catch (_) {}
        _controllers.remove(index);
      }
      if (mounted) {
        setState(() {
          _failedIndices.add(index);
        });
      }
    }
  }

  void _disposeControllerAtIndex(int index) {
    final controller = _controllers.remove(index);
    if (controller == null) return;
    _pendingDispose.add(controller);
    _scheduleDisposePending();
  }

  void _scheduleDisposePending() {
    if (_pendingDispose.isEmpty || _disposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      if (_pendingDispose.isEmpty) return;
      final controller = _pendingDispose.removeAt(0);
      try {
        controller.pause();
      } catch (_) {}
      try {
        controller.dispose();
      } catch (_) {}
      if (_pendingDispose.isNotEmpty) _scheduleDisposePending();
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _focusedIndex = index;
    });

    // Play current, pause others
    _controllers[index]?.play();
    if (index > 0) _controllers[index - 1]?.pause();
    if (index < _videos.length - 1) _controllers[index + 1]?.pause();

    // Keep only [index-1, index, index+1] to avoid OOM and crashes
    _initializeControllerAtIndex(index - 1);
    _initializeControllerAtIndex(index + 1);
    
    final toRemove = <int>[];
    for (final i in _controllers.keys) {
      if (i < index - 1 || i > index + 1) toRemove.add(i);
    }
    for (final i in toRemove) _disposeControllerAtIndex(i);

    // Load More Logic
    if (widget.loadMoreVideos != null && !_isLoadingMore && (_videos.length - index) < 5) {
      _loadMore();
    }
    
    // Check follow status for current video creator
    _verifyFollowStatus(index);
  }

  Future<void> _verifyFollowStatus(int index) async {
      try {
          final video = _videos[index];
          final user = video['user'];
          if (user == null) return;
          final userId = user['id'] ?? user['_id'];

          if (userId != null && _currentUserId != null && userId.toString() != _currentUserId.toString()) {
             if (user['is_following'] != true) {
                 final res = await _apiService.checkFollowStatus(user['username']);
                 if (res.statusCode == 200 && res.data['success'] == true) {
                     final isFollowing = res.data['data']['following'] ?? false;
                     if (mounted) setState(() {
                         user['is_following'] = isFollowing;
                         if (isFollowing) _followedUserIds.add(userId.toString());
                     });
                 }
             }
          }
      } catch (e) {
          // ignore
      }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final newVideos = await widget.loadMoreVideos!(_page + 1);
      final valid = newVideos.where((v) => _hasValidVideoUrl(v)).toList();
      if (valid.isNotEmpty) {
        setState(() {
          _page++;
          final startIndex = _videos.length;
          _videos.addAll(valid);
          for (int i = 0; i < valid.length; i++) {
               _initializeVideoState(startIndex + i);
          }
        });
        // Don't preload controllers here; _onPageChanged will init when user scrolls (avoids OOM)
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // --- Interaction Handlers ---

  void _toggleLike() {
    if (!mounted) return;
    final index = _focusedIndex;
    final isLiked = _likedVideos.contains(index);
    
    // Optimistic Update
    setState(() {
      if (isLiked) {
        _likedVideos.remove(index);
        _likeCounts[index] = ((_likeCounts[index] ?? 1) - 1).clamp(0, 999999999);
      } else {
        _likedVideos.add(index);
        _likeCounts[index] = (_likeCounts[index] ?? 0) + 1;
      }
    });

    final videoId = _videos[index]['id'] ?? _videos[index]['_id'];
    _apiService.toggleLike(videoId).then((response) {
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        if (data != null && mounted) {
          setState(() {
            _likeCounts[index] = data['like_count'] ?? _likeCounts[index];
            if (data['liked'] == true) _likedVideos.add(index);
            else if (data['liked'] == false) _likedVideos.remove(index);
          });
        }
      } else {
        if (mounted) setState(() {
          if (isLiked) { _likedVideos.add(index); _likeCounts[index] = (_likeCounts[index] ?? 0) + 1; }
          else { _likedVideos.remove(index); _likeCounts[index] = ((_likeCounts[index] ?? 1) - 1).clamp(0, 999999999); }
        });
      }
    }).catchError((e) {
        if (mounted) setState(() {
            if (isLiked) _likedVideos.add(index);
            else _likedVideos.remove(index);
            _likeCounts[index] = isLiked ? (_likeCounts[index]! + 1) : ((_likeCounts[index] ?? 1) - 1).clamp(0, 999999999);
         });
    });
  }

  void _toggleFollowUser() {
    final index = _focusedIndex;
    final video = _videos[index];
    final user = video['user']; 
    if (user == null) return;

    final isFollowing = user['is_following'] == true;
    final userId = user['id'] ?? user['_id'];

    if (userId == null) return;
    final userIdStr = userId.toString();
    
    setState(() {
        user['is_following'] = !isFollowing;
        if (!isFollowing) _followedUserIds.add(userIdStr);
        else _followedUserIds.remove(userIdStr);
    });

    _apiService.toggleFollowUser(userId).then((response) {
        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'];
          if (data != null && mounted) {
            setState(() {
              user['is_following'] = data['following'] == true;
              if (data['following'] == true) _followedUserIds.add(userIdStr);
              else _followedUserIds.remove(userIdStr);
            });
          }
        } else {
          if (mounted) setState(() {
            user['is_following'] = isFollowing;
            if (isFollowing) _followedUserIds.add(userIdStr);
            else _followedUserIds.remove(userIdStr);
          });
        }
    }).catchError((e) {
        if (mounted) setState(() {
            user['is_following'] = isFollowing;
            if (isFollowing) _followedUserIds.add(userIdStr);
            else _followedUserIds.remove(userIdStr);
        });
    });
  }

  /// Pause the currently focused video (e.g. when navigating to user profile).
  void pauseCurrentVideo() {
    final c = _controllers[_focusedIndex];
    if (c != null && c.value.isPlaying) c.pause();
  }
  
  void _openComments() {
      final video = _videos[_focusedIndex];
      // Pass ID as is (String or Int)
      final postId = video['id'] ?? video['_id']; 
      final commentCount = video['comments_count'] is int 
          ? video['comments_count'] 
          : int.tryParse(video['comments_count']?.toString() ?? '0') ?? 0;

      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _CommentsModal(
              postId: postId, 
              apiService: _apiService,
              commentCount: commentCount,
              onCommentAdded: () {
                if (!mounted) return;
                setState(() {
                  final v = _videos[_focusedIndex];
                  final current = v['comments_count'] is int ? v['comments_count'] as int : (int.tryParse(v['comments_count']?.toString() ?? '0') ?? 0);
                  v['comments_count'] = current + 1;
                });
              },
          )
      );
  }

  void _openGiftModal() {
      final video = _videos[_focusedIndex];
      final user = video['user'] ?? {};
      final postId = video['id'] ?? video['_id'];
      final recipientId = user['id'] ?? user['_id'];
      if (postId == null || recipientId == null) return;
      final receiverName = user['name']?.toString() ?? user['username']?.toString() ?? 'Creator';
      String? avatar = user['profile_avatar']?.toString();
      if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
        avatar = 'https://tajify.com$avatar';
      }
      String? thumb;
      final mediaFiles = video['media_files'] as List?;
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final m = mediaFiles.first;
        thumb = m['thumbnail_path'] ?? m['thumbnail_url'] ?? m['thumbnail']?.toString();
      }
      if (thumb != null && thumb.isNotEmpty && !thumb.startsWith('http')) {
        thumb = 'https://tajify.com$thumb';
      }
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: true,
          builder: (context) => TajStarsGiftModal(
              postId: postId,
              receiverId: recipientId,
              receiverName: receiverName,
              receiverAvatar: avatar,
              postThumbnail: thumb,
          )
      );
  }

  void _onShare() {
      final video = _videos[_focusedIndex];
      // Use media_files or video_url, ensure absolute path
      // Mock sharing link for now if dynamic link gen is complex
      final id = video['id'];
      Share.share('Check out this video on Tajify: https://tajify.com/video/$id');
  }

  @override
  void dispose() {
    _disposed = true;
    for (final controller in _controllers.values) {
      try {
        controller.pause();
      } catch (_) {}
      _pendingDispose.add(controller);
    }
    _controllers.clear();
    _pageController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in _pendingDispose) {
        try { c.dispose(); } catch (_) {}
      }
      _pendingDispose.clear();
    });
    super.dispose();
  }

  Widget _buildFypTab(int index, String label) {
    final isActive = _fypTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _fypTabIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEA580C) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no videos, show loading or empty
    if (_videos.isEmpty) {
        return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final failed = _failedIndices.contains(index);
              return _ShortsPageItem(
                video: _videos[index],
                controller: _controllers[index],
                isActive: index == _focusedIndex,
                isFailed: failed,
              );
            },
          ),
          
          if (!widget.isEmbedded)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Following', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(width: 20),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/tajify_icon.png',
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.music_note, color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 4),
                        Text('Tajify', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
           if (!widget.isEmbedded)
             Positioned(
                 top: 50,
                 left: 16,
                 child: IconButton(
                     icon: Icon(Icons.arrow_back, color: Colors.white),
                     onPressed: () => context.pop(),
                 ),
             ),
        ],
      ),
    );
  }
}

class _ShortsPageItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final bool isActive;
  final bool isFailed;

  const _ShortsPageItem({
    required this.video,
    required this.controller,
    required this.isActive,
    this.isFailed = false,
    Key? key,
  }) : super(key: key);
  
  @override
  State<_ShortsPageItem> createState() => _ShortsPageItemState();
}

class _ShortsPageItemState extends State<_ShortsPageItem> with SingleTickerProviderStateMixin {
  late AnimationController _diskController;

  @override
  void initState() {
      super.initState();
      _diskController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }
  
  @override 
  void dispose() {
      _diskController.dispose();
      super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.video['user'] ?? {};
    final username = user['username'] ?? 'User';
    final avatar = user['profile_avatar'];
    
    final parent = context.findAncestorStateOfType<_ShortsPlayerScreenState>()!;
    final index = parent._videos.indexOf(widget.video);
    final controller = widget.controller;
    final isActiveController = controller != null && parent._controllers[index] == controller;
    final isLiked = parent._likedVideos.contains(index);
    final likeCount = parent._likeCounts[index] ?? 0;
    final userIdStr = (user['id'] ?? user['_id']).toString();

    return Stack(
      children: [
        // Video Layer
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: widget.isFailed
              ? Container(color: Colors.black)
              : isActiveController && controller!.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                   width: controller.value.size.width,
                   height: controller.value.size.height,
                   child: VideoPlayer(controller),
                )
            )
            : Center(child: CircularProgressIndicator(color: Colors.amber)),
        ),
        
        GestureDetector(
            onTap: () {
                if (isActiveController && controller!.value.isInitialized) {
                    if (controller.value.isPlaying) {
                        controller.pause();
                    } else {
                        controller.play();
                    }
                }
            },
            child: Container(color: Colors.transparent, width: double.infinity, height: double.infinity),
        ),

        // Gradient
        Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
                height: 200,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    )
                ),
            )
        ),

        // Side Actions - compact
        Positioned(
          right: 6,
          bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                   GestureDetector(
                     onTap: () {
                        if (user['username'] != null) {
                          parent.pauseCurrentVideo();
                          context.push('/user/${user['username']}');
                        }
                     },
                     child: Container(
                         margin: EdgeInsets.only(bottom: 8),
                         decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                         child: CircleAvatar(
                             radius: 20,
                             backgroundImage: (avatar != null && avatar.isNotEmpty) 
                               ? NetworkImage(avatar.startsWith('http') ? avatar : 'https://api.tajify.com$avatar')
                               : null,
                             backgroundColor: Colors.white12,
                             child: (avatar == null || avatar.isEmpty) ? Icon(Icons.person_rounded, color: Colors.white70, size: 20) : null,
                         ),
                     ),
                   ),
                   if (parent._isUserFollowed(user))
                     Positioned(
                       bottom: 0,
                       child: Icon(Icons.chat_bubble_outline, color: Color(0xFF3B82F6), size: 20),
                     )
                   else if (parent._currentUserId == null || userIdStr != parent._currentUserId.toString())
                   Positioned(
                       bottom: 0,
                       child: GestureDetector(
                         onTap: parent._toggleFollowUser,
                         child: Container(
                             padding: EdgeInsets.all(2),
                             decoration: BoxDecoration(color: Color(0xFFEA580C), shape: BoxShape.circle),
                             child: Icon(Icons.add, color: Colors.white, size: 12),
                         ),
                       )
                   )
                ],
              ),
              SizedBox(height: 12),
              _ActionButton(icon: Icons.favorite, iconColor: isLiked ? Color(0xFFEA580C) : Colors.white, label: _formatCount(likeCount), onTap: parent._toggleLike),
              SizedBox(height: 10),
              _ActionButton(icon: Icons.message_rounded, label: widget.video['comments_count']?.toString() ?? '0', onTap: parent._openComments),
              SizedBox(height: 10),
              _GiftActionButton(onTap: parent._openGiftModal),
              SizedBox(height: 10),
              _ActionButton(icon: Icons.share_rounded, label: widget.video['shares_count']?.toString() ?? 'Share', onTap: parent._onShare),
              SizedBox(height: 16),
              RotationTransition(
                  turns: _diskController,
                  child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 6)),
                      child: Center(
                         child: CircleAvatar(
                             radius: 10,
                             backgroundImage: (avatar != null && avatar.isNotEmpty)
                                 ? NetworkImage(avatar.startsWith('http') ? avatar : 'https://api.tajify.com$avatar')
                                 : null,
                             backgroundColor: Colors.white12,
                         )
                      ),
                  ),
              )
            ],
          ),
        ),

        // Bottom caption - small font
        Positioned(
            left: 12,
            bottom: 20,
            right: 72,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text('@$username', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    SizedBox(height: 4),
                    Text(
                        widget.video['description'] ?? widget.video['title'] ?? '',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                        children: [
                            Icon(Icons.music_note, color: Colors.white70, size: 12),
                            SizedBox(width: 4),
                            Expanded(child: Text('Original Sound - $username', style: TextStyle(color: Colors.white70, fontSize: 11)))
                        ],
                    )
                ],
            ),
        )
      ],
    );
  }
  
  String _formatCount(int count) {
      if (count >= 1000000) return '${(count/1000000).toStringAsFixed(1)}M';
      if (count >= 1000) return '${(count/1000).toStringAsFixed(1)}K';
      return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
    final IconData icon;
    final String label;
    final VoidCallback onTap;
    final Color iconColor;
    
    const _ActionButton({required this.icon, required this.label, required this.onTap, this.iconColor = Colors.white});
    
    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: onTap,
            child: Column(
                children: [
                    Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: Colors.black26,
                        ),
                        child: Icon(icon, color: iconColor, size: 24), 
                    ),
                    SizedBox(height: 2),
                    Text(
                      label, 
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                    )
                ],
            )
        );
    }
}

/// Prominent gift button - single color
class _GiftActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GiftActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEA580C),
              boxShadow: [BoxShadow(color: Color(0xFFEA580C).withOpacity(0.4), blurRadius: 8)],
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 2),
          Text('Gift', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class GiftModalDialog extends StatefulWidget {
    final dynamic postId;
    final dynamic recipientId;
    final ApiService apiService;
    
    const GiftModalDialog({required this.postId, required this.recipientId, required this.apiService});
    
    @override
    State<GiftModalDialog> createState() => _GiftModalDialogState();
}

class _GiftModalDialogState extends State<GiftModalDialog> with SingleTickerProviderStateMixin {
    List<dynamic> _gifts = [];
    bool _loading = true;
    double _balance = 0.0;
    dynamic _sentGift; // For animation
    late AnimationController _animController;
    late Animation<double> _scaleAnimation;

    @override 
    void initState() {
        super.initState();
        _animController = AnimationController(vsync: this, duration: Duration(milliseconds: 800));
        _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
        _loadGifts();
        _loadBalance();
    }
    
    Future<void> _loadBalance() async {
        try {
            final response = await widget.apiService.get('/wallet/balance');
            if (response.statusCode == 200 && response.data['success'] == true) {
                if (mounted) {
                    setState(() {
                         _balance = double.tryParse((response.data['data']['balance'] ?? 0).toString()) ?? 0.0;
                    });
                }
            }
        } catch (e) {
            print("Error loading balance: $e");
        }
    }
    
    @override
    void dispose() {
        _animController.dispose();
        super.dispose();
    }
    
    Future<void> _loadGifts() async {
        try {
            final response = await widget.apiService.getGifts();
            if (response.data['success']) {
                setState(() {
                    _gifts = response.data['data'] ?? [];
                    _loading = false;
                });
            }
        } catch (e) {
            if (mounted) setState(() => _loading = false);
        }
    }

    void _sendGift(dynamic gift) async {
        setState(() => _loading = true);
        try {
            final response = await widget.apiService.sendGift(
                giftId: gift['id'],
                receiverId: widget.recipientId,
                postId: widget.postId,
            );
            
            if (response.data['success']) {
                // Determine balance update if backend sends it
                setState(() {
                    _loading = false;
                    _sentGift = gift;
                });
                _animController.forward(from: 0.0);
                
                // Close after animation
                Future.delayed(Duration(seconds: 2), () {
                    if (mounted) Navigator.pop(context);
                });
            } else {
                 throw Exception(response.data['message']);
            }
        } catch (e) {
             setState(() => _loading = false);
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send gift. Check balance.'), backgroundColor: Colors.red));
        }
    }

    @override
    Widget build(BuildContext context) {
        if (_sentGift != null) {
            return Center(
                child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Image.network(_sentGift['icon_url'], width: 150, height: 150),
                            SizedBox(height: 20),
                            Text('Sent ${_sentGift['name']}!', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold))
                        ],
                    ),
                ),
            );
        }

        return Align(
            alignment: Alignment.bottomCenter,
            child: Material(
                color: Colors.transparent,
                child: Container(
                    height: 450,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
                    ),
                    child: Column(
                        children: [
                            Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text('Send Gift (Bal: ₦${_balance.toStringAsFixed(2)})', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                        IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                                    ],
                                ),
                            ),
                            Expanded(
                                child: _loading 
                                ? Center(child: CircularProgressIndicator(color: Colors.amber))
                                : GridView.builder(
                                    padding: EdgeInsets.all(16),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 0.75, crossAxisSpacing: 10, mainAxisSpacing: 10),
                                    itemCount: _gifts.length,
                                    itemBuilder: (context, index) {
                                        final gift = _gifts[index];
                                        return GestureDetector(
                                            onTap: () => _sendGift(gift),
                                            child: Container(
                                                decoration: BoxDecoration(
                                                    color: Colors.white10, 
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.white10)
                                                ),
                                                child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Expanded(child: Padding(
                                                          padding: const EdgeInsets.all(8.0),
                                                          child: Image.network(gift['icon_url'], fit: BoxFit.contain, errorBuilder: (_,__,___) => Icon(Icons.card_giftcard, color: Colors.amber)),
                                                        )),
                                                        Text(gift['name'], style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1),
                                                        SizedBox(height: 4),
                                                        Text('₦${gift['price'] ?? gift['cost'] ?? 0}', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                                        SizedBox(height: 8),
                                                    ],
                                                ),
                                            ),
                                        );
                                    }
                                ),
                            ),
                            Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () {
                                        // Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen()));
                                        // Since we are in a refactor, simplistic message:
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Go to Wallet Screen to recharge')));
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text('Recharge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                    )
                                )
                            )
                        ],
                    ),
                ),
            ),
        );
    }
}

class _CommentsModal extends StatefulWidget {
    final dynamic postId;
    final ApiService apiService;
    final int commentCount;
    final VoidCallback? onCommentAdded;
    const _CommentsModal({required this.postId, required this.apiService, required this.commentCount, this.onCommentAdded});
    
    @override
    State<_CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<_CommentsModal> {
  List<dynamic> _comments = [];
  bool _loading = true;
  final TextEditingController _ctrl = TextEditingController();
  dynamic _replyingToCommentId;
  Map<String, dynamic>? _replyingToUser; // { username, profile_avatar } when replying
  String? _currentUserId;
  /// Comment IDs (or indices) for which replies are expanded (tap "X replies" to expand).
  final Set<dynamic> _expandedReplies = {};

  @override 
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadComments();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final res = await widget.apiService.get('auth/me');
      if (res.statusCode == 200 && res.data['success'] == true) {
        final d = res.data['data'];
        final id = d?['id'] ?? d?['_id'];
        if (mounted && id != null) setState(() => _currentUserId = id.toString());
      }
    } catch (_) {}
  }
    
  Future<void> _loadComments() async {
    try {
      final response = await widget.apiService.getComments(widget.postId, page: 1, limit: 50);
      if (response.data['success'] == true) {
        setState(() {
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _comments = data['data'] ?? [];
          } else if (data is List) {
            _comments = data;
          } else {
            _comments = [];
          }
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }
    
    void _postComment() async {
        if (_ctrl.text.trim().isEmpty) return;
        final content = _ctrl.text.trim();
        final parentId = _replyingToCommentId;
        FocusScope.of(context).unfocus();
        _ctrl.clear();
        if (mounted) setState(() {
          _replyingToCommentId = null;
          _replyingToUser = null;
        });

        try {
            final res = await widget.apiService.addComment(widget.postId, content, parentId: parentId);
            if ((res.statusCode == 200 || res.statusCode == 201) && res.data['success'] == true) {
                widget.onCommentAdded?.call();
                _loadComments();
            } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post'), backgroundColor: Colors.red));
            }
        } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment'), backgroundColor: Colors.red));
        }
    }

    @override
    Widget build(BuildContext context) {
         return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
                children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('${_comments.length} comments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Expanded(
                        child: _loading 
                        ? Center(child: CircularProgressIndicator(color: Color(0xFFEA580C)))
                        : ListView.builder(
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                                final c = _comments[index];
                                final user = c['user'];
                                String username = 'Unknown';
                                String? avatar;
                                if (user is Map) {
                                    username = user['username'] ?? user['name'] ?? 'Unknown';
                                    avatar = user['profile_avatar']?.toString();
                                }
                                final commentId = c['_id'] ?? c['id'];
                                final isGift = c['is_gift'] == true;
                                final isOwn = _currentUserId != null && (user is Map && (user['_id']?.toString() ?? user['id']?.toString()) == _currentUserId);
                                final isLiked = c['is_liked'] == true;
                                final likesCount = c['likes_count'] is int ? c['likes_count'] as int : (int.tryParse(c['likes_count']?.toString() ?? '0') ?? 0);
                                final replies = c['replies'] is List ? c['replies'] as List : <dynamic>[];
                                final repliesCount = replies.length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCommentTile(
                                      c: c,
                                      username: username,
                                      avatar: avatar,
                                      commentId: commentId,
                                      isGift: isGift,
                                      isOwn: isOwn,
                                      isLiked: isLiked,
                                      likesCount: likesCount,
                                      onProfileTap: () {
                                        if (username != 'Unknown') context.push('/user/$username');
                                      },
                                      onLike: () async {
                                        if (commentId == null) return;
                                        try {
                                          final res = await widget.apiService.toggleCommentLike(commentId.toString());
                                          if (res.statusCode == 200 && res.data['success'] == true) {
                                            final d = res.data['data'];
                                            if (mounted && d != null) setState(() {
                                              c['is_liked'] = d['liked'];
                                              c['likes_count'] = d['like_count'];
                                            });
                                          }
                                        } catch (_) {}
                                      },
                                      onReply: () => setState(() {
                                        _replyingToCommentId = commentId;
                                        _replyingToUser = user is Map ? Map<String, dynamic>.from(user) : null;
                                      }),
                                      onDelete: () async {
                                        if (commentId == null || !isOwn) return;
                                        try {
                                          final res = await widget.apiService.deleteComment(commentId.toString());
                                          if (res.statusCode == 200 && res.data['success'] == true) {
                                            if (mounted) setState(() => _comments.removeAt(index));
                                          }
                                        } catch (_) {
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete')));
                                        }
                                      },
                                    ),
                                    if (repliesCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 48, top: 2, bottom: 4),
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            if (_expandedReplies.contains(commentId)) {
                                              _expandedReplies.remove(commentId);
                                            } else {
                                              _expandedReplies.add(commentId);
                                            }
                                          }),
                                          child: Text(
                                            _expandedReplies.contains(commentId)
                                                ? 'Hide ${repliesCount == 1 ? 'reply' : 'replies'}'
                                                : '${repliesCount} ${repliesCount == 1 ? 'reply' : 'replies'}',
                                            style: TextStyle(color: Color(0xFFEA580C), fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ),
                                    if (repliesCount > 0 && _expandedReplies.contains(commentId))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 48, top: 4, bottom: 8),
                                        child: Column(
                                          children: replies.map<Widget>((r) {
                                            final ru = r['user'];
                                            String ruName = ru is Map ? (ru['username'] ?? ru['name'] ?? '') : '';
                                            String? ruAvatar = ru is Map ? ru['profile_avatar']?.toString() : null;
                                            final rId = r['_id'] ?? r['id'];
                                            final rIsOwn = _currentUserId != null && (ru is Map && (ru['_id']?.toString() ?? ru['id']?.toString()) == _currentUserId);
                                            return _buildCommentTile(
                                              c: r,
                                              username: ruName.isEmpty ? 'User' : ruName,
                                              avatar: ruAvatar,
                                              commentId: rId,
                                              isGift: r['is_gift'] == true,
                                              isOwn: rIsOwn,
                                              isLiked: r['is_liked'] == true,
                                              likesCount: r['likes_count'] is int ? r['likes_count'] as int : 0,
                                              onProfileTap: () { if (ruName.isNotEmpty) context.push('/user/$ruName'); },
                                              onLike: () async {
                                                if (rId == null) return;
                                                try {
                                                  final res = await widget.apiService.toggleCommentLike(rId.toString());
                                                  if (res.statusCode == 200 && res.data['success'] == true && mounted) _loadComments();
                                                } catch (_) {}
                                              },
                                              onReply: () => setState(() {
                                                _replyingToCommentId = commentId;
                                                _replyingToUser = user is Map ? Map<String, dynamic>.from(user) : null;
                                              }),
                                              onDelete: () async {
                                                if (rId == null || !rIsOwn) return;
                                                try {
                                                  final res = await widget.apiService.deleteComment(rId.toString());
                                                  if (res.statusCode == 200 && mounted) _loadComments();
                                                } catch (_) {}
                                              },
                                              isReply: true,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                );
                              }
                            )
                    ),
                    if (_replyingToCommentId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            if (_replyingToUser != null) ...[
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white12,
                                backgroundImage: _replyingToUser!['profile_avatar'] != null &&
                                        _replyingToUser!['profile_avatar'].toString().isNotEmpty
                                    ? NetworkImage(
                                        _replyingToUser!['profile_avatar'].toString().startsWith('http')
                                            ? _replyingToUser!['profile_avatar'].toString()
                                            : 'https://api.tajify.com${_replyingToUser!['profile_avatar']}')
                                    : null,
                                child: _replyingToUser!['profile_avatar'] == null ||
                                        _replyingToUser!['profile_avatar'].toString().isEmpty
                                    ? Text(
                                        (_replyingToUser!['username'] ?? _replyingToUser!['name'] ?? '?').toString().isNotEmpty
                                            ? ((_replyingToUser!['username'] ?? _replyingToUser!['name']) as String).substring(0, 1).toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                'Replying to @${_replyingToUser?['username'] ?? _replyingToUser?['name'] ?? 'user'}',
                                style: TextStyle(color: Color(0xFFEA580C), fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() { _replyingToCommentId = null; _replyingToUser = null; }),
                              child: Icon(Icons.close, color: Colors.white54, size: 18),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 10, left: 10, right: 10, top: 10),
                        child: Row(
                            children: [
                                Expanded(child: TextField(
                                    controller: _ctrl,
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white10,
                                        hintText: _replyingToCommentId != null ? 'Write a reply...' : 'Add comment...',
                                        hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                                    ),
                                )),
                                IconButton(icon: Icon(Icons.send_rounded, color: Color(0xFFEA580C)), onPressed: _postComment)
                            ],
                        ),
                    )
                ],
            ),
        );
    }

  Widget _buildCommentTile({
    required dynamic c,
    required String username,
    String? avatar,
    required dynamic commentId,
    required bool isGift,
    required bool isOwn,
    required bool isLiked,
    required int likesCount,
    required VoidCallback onProfileTap,
    required VoidCallback onLike,
    required VoidCallback onReply,
    required VoidCallback onDelete,
    bool isReply = false,
  }) {
    final content = c['content']?.toString() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 2 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: isReply ? 12 : 18,
              backgroundColor: isGift ? Color(0xFFEA580C).withOpacity(0.25) : Colors.white12,
              backgroundImage: (avatar != null && avatar.isNotEmpty)
                  ? NetworkImage(avatar.startsWith('http') ? avatar : 'https://api.tajify.com$avatar')
                  : null,
              child: (avatar == null || avatar.isEmpty)
                  ? (isGift ? Icon(Icons.card_giftcard_rounded, color: Color(0xFFEA580C), size: isReply ? 14 : 18) : Icon(Icons.person_rounded, color: Colors.white54, size: isReply ? 14 : 18))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProfileTap,
                      child: Text('@$username', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    if (isGift) ...[ const SizedBox(width: 6), Icon(Icons.card_giftcard_rounded, color: Color(0xFFEA580C), size: 12) ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(content, style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 13, height: 1.3)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${_timeAgo(c['createdAt'] ?? c['created_at'])}', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.white38, size: 14),
                          if (likesCount > 0) ...[ const SizedBox(width: 4), Text('$likesCount', style: TextStyle(color: Colors.white38, fontSize: 10)) ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: onReply, child: Text('Reply', style: TextStyle(color: Colors.white38, fontSize: 10))),
                    if (isOwn) ...[
                      const SizedBox(width: 12),
                      GestureDetector(onTap: onDelete, child: Icon(Icons.delete_outline, color: Colors.white38, size: 14)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(dynamic date) {
    if (date == null) return '';
    DateTime? d;
    if (date is String) d = DateTime.tryParse(date);
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}