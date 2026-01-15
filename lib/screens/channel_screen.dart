import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'tube_player_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import 'camera_recording_screen.dart';
import '../widgets/create_video_option_sheet.dart';
import '../widgets/tajify_top_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../services/storage_service.dart';

// Skeleton loading widgets
class _SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  
  const _SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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
    );
  }
}

class _VideoCardSkeleton extends StatelessWidget {
  const _VideoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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

class _GridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  
  const _GridSkeleton({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: List.generate(
        crossAxisCount * 2, // Show 2 rows of skeleton
        (i) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
        ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        3,
        (i) => _VideoCardSkeleton(),
      ),
    );
  }
}

class _UploadProgressSkeleton extends StatelessWidget {
  const _UploadProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upload icon skeleton
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        const SizedBox(height: 24),
        
        // Title skeleton
        Container(
          width: 150,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        
        // Subtitle skeleton
        Container(
          width: 200,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 24),
        
        // Progress steps skeleton
        for (int i = 0; i < 4; i++) ...[
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120 + (i * 20),
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          if (i < 3) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ThumbnailSkeleton extends StatelessWidget {
  const _ThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
    );
  }
}

class _VideoPlayerSkeleton extends StatelessWidget {
  const _VideoPlayerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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

enum ChannelCategory { short, max, prime, blog, audio }

class ChannelScreen extends StatefulWidget {
  final bool openCreateModalOnStart;
  final String? initialCategory;
  final Map<String, dynamic>? initialAudioTrack;
  const ChannelScreen({
    super.key, 
    this.openCreateModalOnStart = false, 
    this.initialCategory,
    this.initialAudioTrack,
  });

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  int _selectedTab = 1; // Channel tab index
  ChannelCategory _selectedCategory = ChannelCategory.short;
  
  // Upload state variables
  bool _allowDuet = true;
  bool _useVideoThumbnail = true;
  File? _selectedThumbnail;
  File? _selectedVideo;
  String _selectedContentType = '';
  
  // Add thumbnail generation state
  File? _generatedThumbnail;
  List<File> _generatedThumbnails = [];
  bool _isGeneratingThumbnail = false;
  bool _isUploading = false;

  // Add a set to track saved video URLs
  final Set<String> _savedVideos = {};

  // Add a controller for the description
  final TextEditingController _descController = TextEditingController();

  // Real data from backend
  static const int _tubePageSize = 12;
  List<Map<String, dynamic>> _tubeShortPosts = [];
  List<Map<String, dynamic>> _tubeMaxPosts = [];
  List<Map<String, dynamic>> _tubePrimePosts = [];
  bool _shortInitialLoading = false;
  bool _shortMoreLoading = false;
  bool _shortHasMore = true;
  int _shortCurrentPage = 1;
  String? _shortError;
  bool _maxInitialLoading = false;
  bool _maxMoreLoading = false;
  bool _maxHasMore = true;
  int _maxCurrentPage = 1;
  String? _maxError;
  bool _primeInitialLoading = false;
  bool _primeMoreLoading = false;
  bool _primeHasMore = true;
  int _primeCurrentPage = 1;
  String? _primeError;
  List<Map<String, dynamic>> _blogPosts = [];
  bool _blogInitialLoading = false;
  bool _blogMoreLoading = false;
  bool _blogHasMore = true;
  int _blogCurrentPage = 1;
  String? _blogError;
  
  // Audio section state
  List<Map<String, dynamic>> _audioPosts = [];
  List<Map<String, dynamic>> _recentlyPlayedAudio = [];
  List<Map<String, dynamic>> _topChartsAudio = [];
  bool _audioInitialLoading = false;
  bool _audioMoreLoading = false;
  bool _audioHasMore = true;
  int _audioCurrentPage = 1;
  String? _audioError;
  
  // Audio player state
  AudioPlayer? _audioPlayer;
  Map<String, dynamic>? _currentPlayingAudio;
  bool _isAudioPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';

  // Add hashtag suggestions state
  List<Map<String, dynamic>> _hashtagSuggestions = [];
  bool _showHashtagSuggestions = false;
  String _currentHashtagQuery = '';
  int _cursorPosition = 0;

  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();
  
  // Notification state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  
  // Messages state
  int _messagesUnreadCount = 0;
  StreamSubscription? _messagesCountSubscription;

  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategory != null) {
      switch (widget.initialCategory) {
        case 'audio':
          _selectedCategory = ChannelCategory.audio;
          break;
        case 'short':
          _selectedCategory = ChannelCategory.short;
          break;
        case 'max':
          _selectedCategory = ChannelCategory.max;
          break;
        case 'prime':
          _selectedCategory = ChannelCategory.prime;
          break;
        case 'blog':
          _selectedCategory = ChannelCategory.blog;
          break;
      }
    }
    _scrollController.addListener(_onScroll);
    _loadPosts();
    if (widget.openCreateModalOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showUploadOptions(context);
      });
    }
    
    // Load notification unread count
    _loadNotificationUnreadCount();
    
    // Set up periodic refresh for notification count
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotificationUnreadCount();
    });
    
    // Initialize Firebase and load messages count
    _initializeFirebaseAndLoadMessagesCount();
    _loadLocalUserInfo();
    
    // Initialize audio player
    _audioPlayer = AudioPlayer();
    _audioPlayer!.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _audioDuration = duration ?? Duration.zero;
        });
      }
    });
    _audioPlayer!.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _audioPosition = position;
        });
      }
    });
    _audioPlayer!.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = playing;
        });
      }
    });
    
    // Play initial audio track if provided
    if (widget.initialAudioTrack != null && _selectedCategory == ChannelCategory.audio) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Wait for audio posts to load, then play the track
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _playAudio(widget.initialAudioTrack!);
        }
      });
    }
  }

  Future<void> _loadLocalUserInfo() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = response.data['data'];
        if (mounted) {
          setState(() {
            // Handle nested user object
            final user = profile?['user'] ?? profile;
            final name = user?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = user?['profile_avatar']?.toString();
          });
        }
        return;
      }
    } catch (_) {
      // ignored
    }

    try {
      final name = await _storageService.getUserName();
      final avatar = await _storageService.getUserProfilePicture();
      if (!mounted) return;
      setState(() {
        if (name != null && name.isNotEmpty) {
          _currentUserInitial = name[0].toUpperCase();
        }
        _currentUserAvatar = avatar;
      });
    } catch (e) {
      // ignore silently
    }
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
          if (userId != null && FirebaseService.isInitialized && mounted) {
            _messagesCountSubscription = FirebaseService.getUnreadCountStream(userId)
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

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _descController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playAudio(Map<String, dynamic> audio) async {
    try {
      final audioUrl = _getAudioMediaUrl(audio);
      if (audioUrl.isEmpty) {
        print('[AUDIO] No audio URL found');
        return;
      }
      
      if (_currentPlayingAudio?['id'] == audio['id'] && _audioPlayer != null) {
        // Same audio - toggle play/pause
        if (_isAudioPlaying) {
          await _audioPlayer!.pause();
        } else {
          await _audioPlayer!.play();
        }
      } else {
        // New audio - stop current and play new
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
        }
        
        setState(() {
          _currentPlayingAudio = audio;
        });
        
        await _audioPlayer!.setUrl(audioUrl);
        await _audioPlayer!.play();
      }
    } catch (e) {
      print('[AUDIO] Error playing audio: $e');
    }
  }
  
  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      print('[AUDIO] Error pausing audio: $e');
    }
  }
  
  Future<void> _resumeAudio() async {
    try {
      await _audioPlayer?.play();
    } catch (e) {
      print('[AUDIO] Error resuming audio: $e');
    }
  }
  
  String _getAudioMediaUrl(Map<String, dynamic> audio) {
    final mediaFiles = audio['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final first = mediaFiles.first;
      if (first is Map<String, dynamic>) {
        final path = first['file_path'] ?? first['file_url'] ?? first['url'];
        if (path is String && path.isNotEmpty) {
          return path;
        }
      }
    }
    final fallback = audio['audio_url'] ??
        audio['media_url'] ??
        audio['file_path'] ??
        audio['file_url'] ??
        audio['url'];
    return fallback?.toString() ?? '';
  }
  
  String _formatAudioDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  Widget _buildBottomAudioPlayer() {
    if (_currentPlayingAudio == null) {
      return const SizedBox.shrink();
    }
    
    final user = _currentPlayingAudio!['user'] ?? {};
    final coverImageUrl = _getThumbnail(_currentPlayingAudio!);
    final title = _currentPlayingAudio!['title'] ?? _currentPlayingAudio!['description'] ?? 'Untitled';
    final artist = user['name'] ?? user['username'] ?? 'Unknown';
    
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cover image
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: coverImageUrl != null && coverImageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: coverImageUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Color(0xFFB875FB),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white38,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ),
            ),
          ),
          // Title and artist
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Play/Pause button
          IconButton(
            onPressed: () {
              if (_isAudioPlaying) {
                _pauseAudio();
              } else {
                _resumeAudio();
              }
            },
            icon: Icon(
              _isAudioPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
          // Progress indicator
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                    ),
                    child: Slider(
                      value: _audioDuration.inMilliseconds > 0
                          ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
                          : 0.0,
                      onChanged: (value) {
                        if (_audioDuration.inMilliseconds > 0) {
                          final position = Duration(
                            milliseconds: (value * _audioDuration.inMilliseconds).round(),
                          );
                          _audioPlayer?.seek(position);
                        }
                      },
                      activeColor: Color(0xFFB875FB),
                      inactiveColor: Colors.grey[700],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatAudioDuration(_audioPosition),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          _formatAudioDuration(_audioDuration),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200 pixels of bottom
      switch (_selectedCategory) {
        case ChannelCategory.short:
          if (_shortHasMore && !_shortMoreLoading && !_shortInitialLoading) {
            _loadTubeShortPosts(loadMore: true);
          }
          break;
        case ChannelCategory.max:
          if (_maxHasMore && !_maxMoreLoading && !_maxInitialLoading) {
            _loadTubeMaxPosts(loadMore: true);
          }
          break;
        case ChannelCategory.prime:
          if (_primeHasMore && !_primeMoreLoading && !_primeInitialLoading) {
            _loadTubePrimePosts(loadMore: true);
          }
          break;
        case ChannelCategory.blog:
          if (_blogHasMore && !_blogMoreLoading && !_blogInitialLoading) {
            _loadBlogPosts(loadMore: true);
          }
          break;
        case ChannelCategory.audio:
          if (_audioHasMore && !_audioMoreLoading && !_audioInitialLoading) {
            _loadAudioPosts(loadMore: true);
          }
          break;
        default:
          break;
      }
    }
  }

  Future<void> _loadPosts() async {
    try {
      await Future.wait([
        _loadTubeShortPosts(),
        _loadTubeMaxPosts(),
        _loadTubePrimePosts(),
        _loadBlogPosts(),
        _loadAudioPosts(),
      ]);
    } catch (e) {
      print('Error loading posts: $e');
    }
  }

  List<Map<String, dynamic>> _extractPosts(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().map((post) => Map<String, dynamic>.from(post)).toList();
      }
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();
      }
    } else if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().map((post) => Map<String, dynamic>.from(post)).toList();
    }
    return [];
  }

  String? _getThumbnail(Map<String, dynamic> video) {
    final mediaFiles = video['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final media = mediaFiles.first;
      final thumb = media['thumbnail_path'] ?? media['thumbnail_url'] ?? media['thumbnail'];
      if (thumb is String && thumb.isNotEmpty) {
        return thumb;
      }
    }
    final fallback = video['thumbnail'] ?? video['thumbnail_url'] ?? video['snippet_thumbnail'];
    if (fallback is String && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  String _getPrimaryMediaUrl(Map<String, dynamic> video) {
    final mediaFiles = video['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final first = mediaFiles.first;
      if (first is Map<String, dynamic>) {
        final path = first['file_path'] ?? first['file_url'] ?? first['url'];
        if (path is String && path.isNotEmpty) {
          return path;
        }
      }
    }
    final fallback = video['video_url'] ??
        video['media_url'] ??
        video['file_path'] ??
        video['file_url'] ??
        video['url'];
    return fallback?.toString() ?? '';
  }

  Future<void> _loadTubeShortPosts({bool loadMore = false}) async {
    if (loadMore) {
      if (_shortMoreLoading || !_shortHasMore) return;
    } else {
      if (_shortInitialLoading) return;
      _shortHasMore = true;
    }

    final targetPage = loadMore ? _shortCurrentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _shortMoreLoading = true;
      } else {
        _shortInitialLoading = true;
        _shortError = null;
      }
    });

    try {
      final response = await _apiService.getTubeShortPosts(page: targetPage, limit: _tubePageSize);
      if (response.data['success']) {
        final posts = _extractPosts(response.data['data']);
        if (!mounted) return;
        setState(() {
          if (loadMore) {
            _tubeShortPosts.addAll(posts);
          } else {
            _tubeShortPosts = posts;
          }
          _shortCurrentPage = targetPage;
          _shortHasMore = posts.length >= _tubePageSize;
        });
      } else if (!loadMore && mounted) {
        setState(() {
          _shortError = response.data['message']?.toString() ?? 'Failed to load videos.';
          _shortHasMore = false;
        });
      }
    } catch (e) {
      print('Error loading tube short posts: $e');
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _shortError = 'Failed to load videos.';
        }
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _shortMoreLoading = false;
        } else {
          _shortInitialLoading = false;
        }
      });
    }
  }

  Future<void> _loadTubeMaxPosts({bool loadMore = false}) async {
    if (loadMore) {
      if (_maxMoreLoading || !_maxHasMore) return;
    } else {
      if (_maxInitialLoading) return;
      _maxHasMore = true;
    }

    final targetPage = loadMore ? _maxCurrentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _maxMoreLoading = true;
      } else {
        _maxInitialLoading = true;
        _maxError = null;
      }
    });

    try {
      final response = await _apiService.getTubeMaxPosts(page: targetPage, limit: _tubePageSize);
      if (response.data['success']) {
        final posts = _extractPosts(response.data['data']);
        if (!mounted) return;
        setState(() {
          if (loadMore) {
            _tubeMaxPosts.addAll(posts);
          } else {
            _tubeMaxPosts = posts;
          }
          _maxCurrentPage = targetPage;
          _maxHasMore = posts.length >= _tubePageSize;
        });
      } else if (!loadMore && mounted) {
        setState(() {
          _maxError = response.data['message']?.toString() ?? 'Failed to load videos.';
          _maxHasMore = false;
        });
      }
    } catch (e) {
      print('Error loading tube max posts: $e');
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _maxError = 'Failed to load videos.';
        }
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _maxMoreLoading = false;
        } else {
          _maxInitialLoading = false;
        }
      });
    }
  }

  Future<void> _loadBlogPosts({bool loadMore = false}) async {
    if (loadMore) {
      if (_blogMoreLoading || !_blogHasMore) return;
      setState(() => _blogMoreLoading = true);
    } else {
      if (_blogInitialLoading) return;
      setState(() {
        _blogInitialLoading = true;
        _blogError = null;
      });
    }

    try {
      final targetPage = loadMore ? _blogCurrentPage + 1 : 1;
      final response = await _apiService.getBlogPosts(page: targetPage, limit: _tubePageSize);
      
      print('[DEBUG] Blog response: ${response.data}');
      
      if (mounted) {
        List<Map<String, dynamic>> blogs = [];
        
        // Handle different response structures like the web version
        if (response.data['success'] == true && response.data['data'] != null) {
          final data = response.data['data'];
          if (data is List) {
            blogs = data.whereType<Map<String, dynamic>>().map((blog) => Map<String, dynamic>.from(blog)).toList();
          } else if (data is Map<String, dynamic>) {
            if (data['data'] is List) {
              blogs = (data['data'] as List).whereType<Map<String, dynamic>>().map((blog) => Map<String, dynamic>.from(blog)).toList();
            } else if (data['items'] is List) {
              blogs = (data['items'] as List).whereType<Map<String, dynamic>>().map((blog) => Map<String, dynamic>.from(blog)).toList();
            }
          }
        } else if (response.data is List) {
          blogs = response.data.whereType<Map<String, dynamic>>().map((blog) => Map<String, dynamic>.from(blog)).toList();
        } else if (response.data['data'] is List) {
          blogs = (response.data['data'] as List).whereType<Map<String, dynamic>>().map((blog) => Map<String, dynamic>.from(blog)).toList();
        }
        
        print('[DEBUG] Extracted ${blogs.length} blogs');
        
        setState(() {
          if (loadMore) {
            _blogPosts.addAll(blogs);
            _blogCurrentPage = targetPage;
            _blogHasMore = blogs.length >= _tubePageSize;
            _blogMoreLoading = false;
          } else {
            _blogPosts = blogs;
            _blogCurrentPage = 1;
            _blogHasMore = blogs.length >= _tubePageSize;
            _blogInitialLoading = false;
          }
          _blogError = null;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading blog posts: $e');
      if (mounted) {
        setState(() {
          if (loadMore) {
            _blogMoreLoading = false;
          } else {
            _blogInitialLoading = false;
            _blogError = e.toString();
          }
        });
      }
    }
  }

  Future<void> _loadTubePrimePosts({bool loadMore = false}) async {
    if (loadMore) {
      if (_primeMoreLoading || !_primeHasMore) return;
    } else {
      if (_primeInitialLoading) return;
      _primeHasMore = true;
    }

    final targetPage = loadMore ? _primeCurrentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _primeMoreLoading = true;
      } else {
        _primeInitialLoading = true;
        _primeError = null;
      }
    });

    try {
      final response = await _apiService.getTubePrimePosts(page: targetPage, limit: _tubePageSize);
      if (response.data['success']) {
        final posts = _extractPosts(response.data['data']);
        if (!mounted) return;
        setState(() {
          if (loadMore) {
            _tubePrimePosts.addAll(posts);
          } else {
            _tubePrimePosts = posts;
          }
          _primeCurrentPage = targetPage;
          _primeHasMore = posts.length >= _tubePageSize;
        });
      } else if (!loadMore && mounted) {
        setState(() {
          _primeError = response.data['message']?.toString() ?? 'Failed to load videos.';
          _primeHasMore = false;
        });
      }
    } catch (e) {
      print('Error loading tube prime posts: $e');
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _primeError = 'Failed to load videos.';
        }
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _primeMoreLoading = false;
        } else {
          _primeInitialLoading = false;
        }
      });
    }
  }

  Future<void> _refreshFeeds() async {
    setState(() {
      _shortCurrentPage = 1;
      _maxCurrentPage = 1;
      _primeCurrentPage = 1;
      _blogCurrentPage = 1;
      _audioCurrentPage = 1;
    });
    await Future.wait([
      _loadTubeShortPosts(),
      _loadTubeMaxPosts(),
      _loadTubePrimePosts(),
      _loadBlogPosts(),
      _loadAudioPosts(),
    ]);
  }
  
  Future<void> _loadAudioPosts({bool loadMore = false}) async {
    if (loadMore) {
      if (_audioMoreLoading || !_audioHasMore) return;
    } else {
      if (_audioInitialLoading) return;
      _audioHasMore = true;
    }

    final targetPage = loadMore ? _audioCurrentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _audioMoreLoading = true;
      } else {
        _audioInitialLoading = true;
        _audioError = null;
      }
    });

    try {
      final response = await _apiService.getAudioPosts(page: targetPage, limit: 10);
      print('[DEBUG] Audio posts response: ${response.statusCode}');
      print('[DEBUG] Audio posts data: ${response.data}');
      if (response.data['success']) {
        print('[DEBUG] Response data structure: ${response.data['data'].runtimeType}');
        print('[DEBUG] Response data keys: ${response.data['data'] is Map ? (response.data['data'] as Map).keys.toList() : 'not a map'}');
        final posts = _extractPosts(response.data['data']);
        print('[DEBUG] Extracted audio posts: ${posts.length}');
        if (posts.isNotEmpty) {
          print('[DEBUG] First audio post: ${posts[0]}');
        }
        if (!mounted) return;
        setState(() {
          if (loadMore) {
            _audioPosts.addAll(posts);
          } else {
            _audioPosts = posts;
            // Set recently played to first 4 posts
            _recentlyPlayedAudio = posts.take(4).toList();
            // Set top charts to top 4 by likes
            _topChartsAudio = List.from(posts)
              ..sort((a, b) {
                final aLikes = (a['likes_count'] ?? 0) is int 
                    ? (a['likes_count'] ?? 0) as int
                    : int.tryParse((a['likes_count'] ?? 0).toString()) ?? 0;
                final bLikes = (b['likes_count'] ?? 0) is int 
                    ? (b['likes_count'] ?? 0) as int
                    : int.tryParse((b['likes_count'] ?? 0).toString()) ?? 0;
                return bLikes.compareTo(aLikes);
              });
            _topChartsAudio = _topChartsAudio.take(4).toList();
          }
          _audioCurrentPage = targetPage;
          _audioHasMore = posts.length >= 10;
        });
      } else if (!loadMore && mounted) {
        setState(() {
          _audioError = response.data['message']?.toString() ?? 'Failed to load audio.';
          _audioHasMore = false;
        });
      }
    } catch (e) {
      print('Error loading audio posts: $e');
      if (!mounted) return;
      setState(() {
        if (!loadMore) {
          _audioError = 'Failed to load audio.';
        }
      });
    } finally {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _audioMoreLoading = false;
        } else {
          _audioInitialLoading = false;
        }
      });
    }
  }

  // Hashtag suggestions methods
  Future<void> _getHashtagSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
      return;
    }

    try {
      final response = await _apiService.getHashtagSuggestions(query);
      if (response.data['success']) {
        setState(() {
          _hashtagSuggestions = List<Map<String, dynamic>>.from(response.data['data']);
          _showHashtagSuggestions = _hashtagSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error getting hashtag suggestions: $e');
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
    }
  }

  void _onDescriptionChanged(String text) {
    // Check if user is typing a hashtag
    final cursorPosition = _descController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    
    // Find the last hashtag being typed
    final hashtagMatch = RegExp(r'#(\w*)$').firstMatch(textBeforeCursor);
    
    if (hashtagMatch != null) {
      final hashtagQuery = hashtagMatch.group(1) ?? '';
      _currentHashtagQuery = hashtagQuery;
      _cursorPosition = cursorPosition;
      _getHashtagSuggestions(hashtagQuery);
    } else {
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
    }
  }

  void _insertHashtagSuggestion(String hashtag) {
    final text = _descController.text;
    final beforeHashtag = text.substring(0, _cursorPosition - _currentHashtagQuery.length - 1); // -1 for #
    final afterHashtag = text.substring(_cursorPosition);
    
    final newText = '$beforeHashtag#$hashtag $afterHashtag';
    _descController.text = newText;
    
    // Set cursor position after the inserted hashtag
    final newCursorPosition = beforeHashtag.length + hashtag.length + 2; // +2 for # and space
    _descController.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursorPosition),
    );
    
    setState(() {
      _showHashtagSuggestions = false;
      _hashtagSuggestions = [];
    });
  }

  Widget _buildTubeShortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_shortInitialLoading && _tubeShortPosts.isEmpty)
          const _RowSkeleton()
        else if (_tubeShortPosts.isEmpty)
          _buildEmptyState('No Tube Short videos yet.')
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.6,
            ),
            itemCount: _tubeShortPosts.length,
            itemBuilder: (context, index) => _mediaCardWithSave(_tubeShortPosts[index]),
          ),
          if (_shortMoreLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                ),
              ),
            ),
        ],
        if (_shortError != null && _tubeShortPosts.isEmpty)
          _buildErrorBanner(_shortError!, () => _loadTubeShortPosts()),
      ],
    );
  }

  Widget _buildTubeMaxSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTubeHeading('M A X'),
        if (_maxInitialLoading && _tubeMaxPosts.isEmpty)
          const _GridSkeleton(crossAxisCount: 2, childAspectRatio: 1.1, spacing: 8)
        else if (_tubeMaxPosts.isEmpty)
          _buildEmptyState('No Tube Max videos yet.')
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
            ),
            itemCount: _tubeMaxPosts.length,
            itemBuilder: (context, index) {
              final video = _tubeMaxPosts[index];
              return GestureDetector(
                onTap: () => _openTubePlayer(_tubeMaxPosts, index),
                child: _VideoPreviewCard(
                  url: _getPrimaryMediaUrl(video),
                  thumbnailUrl: _getThumbnail(video),
                ),
              );
            },
          ),
          if (_maxMoreLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                ),
              ),
            ),
        ],
        if (_maxError != null && _tubeMaxPosts.isEmpty)
          _buildErrorBanner(_maxError!, () => _loadTubeMaxPosts()),
      ],
    );
  }

  Widget _buildTubePrimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTubeHeading('P R I M E'),
        if (_primeInitialLoading && _tubePrimePosts.isEmpty)
          const _GridSkeleton(crossAxisCount: 2, childAspectRatio: 0.8, spacing: 16)
        else if (_tubePrimePosts.isEmpty)
          _buildEmptyState('No Tube Prime videos yet.')
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: _tubePrimePosts.length,
            itemBuilder: (context, index) {
              final video = _tubePrimePosts[index];
              return GestureDetector(
                onTap: () => _openTubePlayer(_tubePrimePosts, index),
                child: _VideoPreviewCard(
                  url: _getPrimaryMediaUrl(video),
                  thumbnailUrl: _getThumbnail(video),
                ),
              );
            },
          ),
          if (_primeMoreLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                ),
              ),
            ),
        ],
        if (_primeError != null && _tubePrimePosts.isEmpty)
          _buildErrorBanner(_primeError!, () => _loadTubePrimePosts()),
      ],
    );
  }

  Widget _buildBlogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_blogInitialLoading && _blogPosts.isEmpty)
          const _GridSkeleton(crossAxisCount: 1, childAspectRatio: 1.5, spacing: 16)
        else if (_blogPosts.isEmpty)
          _buildEmptyState('No blog posts yet.')
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _blogPosts.length,
            itemBuilder: (context, index) {
              final blog = _blogPosts[index];
              return _buildBlogCard(blog);
            },
          ),
          if (_blogMoreLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                ),
              ),
            ),
        ],
        if (_blogError != null && _blogPosts.isEmpty)
          _buildErrorBanner(_blogError!, () => _loadBlogPosts()),
      ],
    );
  }

  Widget _buildBlogCard(Map<String, dynamic> blog) {
    final title = blog['title']?.toString() ?? 'Untitled';
    final description = blog['description']?.toString() ?? 
                        blog['excerpt']?.toString() ?? 
                        blog['content']?.toString() ?? '';
    final user = blog['user'] is Map<String, dynamic> ? blog['user'] as Map<String, dynamic> : null;
    final userName = user?['name']?.toString() ?? user?['username']?.toString() ?? 'Unknown';
    final userAvatar = user?['profile_avatar']?.toString() ?? 
                       user?['profile_photo_url']?.toString() ?? 
                       user?['user_avatar']?.toString();
    final createdAt = blog['created_at']?.toString();
    // Blogs use cover_image_url, not media_files
    final thumbnailUrl = blog['cover_image_url']?.toString() ?? 
                        blog['thumbnail_url']?.toString() ??
                        blog['image_url']?.toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final uuid = blog['uuid']?.toString() ?? blog['id']?.toString();
            if (uuid != null) {
              context.push('/blog/$uuid');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnailUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[800],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _stripHtmlTags(description),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFB875FB),
                          backgroundImage: userAvatar != null 
                              ? NetworkImage(userAvatar) 
                              : null,
                          child: userAvatar == null
                              ? Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt != null)
                                Text(
                                  _formatBlogDate(createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
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
      ),
    );
  }

  String _stripHtmlTags(String htmlString) {
    // Remove HTML tags and decode entities
    String result = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode common HTML entities
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&euro;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&cent;', '¢');
    
    // Decode numeric HTML entities like &#8217;
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });
    
    return result.trim();
  }

  String _formatBlogDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildTubeHeading(String accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'T u b e ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18, letterSpacing: 2),
            ),
            TextSpan(
              text: accent,
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSection() {
    // Load audio posts if not already loading and empty
    if (!_audioInitialLoading && _audioPosts.isEmpty && _audioError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAudioPosts();
      });
    }
    
    if (_audioInitialLoading && _audioPosts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
          ),
        ),
      );
    }
    
    if (_audioError != null && _audioPosts.isEmpty) {
      return _buildErrorBanner(_audioError!, () => _loadAudioPosts());
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Access Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAccessButton(
                    icon: Icons.music_note,
                    label: 'Songs',
                    gradient: [Colors.purple, Colors.pink],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAccessButton(
                    icon: Icons.library_music,
                    label: 'Albums',
                    gradient: [Colors.blue, Colors.cyan],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAccessButton(
                    icon: Icons.playlist_play,
                    label: 'Playlists',
                    gradient: [Color(0xFFB875FB), Colors.red],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Top Charts
          if (_topChartsAudio.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Text(
                'Top Charts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _topChartsAudio.length,
                itemBuilder: (context, index) {
                  final audio = _topChartsAudio[index];
                  final user = audio['user'] ?? {};
                  final gradients = [
                    [Colors.purple.shade700, Colors.purple.shade900],
                    [Colors.pink.shade700, Colors.red.shade900],
                    [Color(0xFFB875FB), Color(0xFFB875FB)],
                    [Colors.blue.shade700, Colors.indigo.shade900],
                  ];
                  return Padding(
                    padding: EdgeInsets.only(right: index == _topChartsAudio.length - 1 ? 0 : 16),
                    child: _buildChartCard(
                      rank: index + 1,
                      title: audio['title'] ?? audio['description'] ?? 'Untitled',
                      artist: user['name'] ?? user['username'] ?? 'Unknown',
                      gradient: gradients[index % gradients.length],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          // All Audio Posts List
          if (_audioPosts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: const Text(
                'All Audio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _audioPosts.length + (_audioMoreLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _audioPosts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                        ),
                      ),
                    ),
                  );
                }
                final audio = _audioPosts[index];
                final user = audio['user'] ?? {};
                final likesCount = (audio['likes_count'] ?? 0) is int 
                    ? (audio['likes_count'] ?? 0) as int
                    : int.tryParse((audio['likes_count'] ?? 0).toString()) ?? 0;
                final coverImageUrl = _getThumbnail(audio);
                return _buildLibraryItem({
                  'title': audio['title'] ?? audio['description'] ?? 'Untitled',
                  'subtitle': '${user['name'] ?? user['username'] ?? 'Unknown'} • $likesCount likes',
                  'coverImageUrl': coverImageUrl,
                  'audio': audio,
                });
              },
            ),
            const SizedBox(height: 24),
          ] else if (!_audioInitialLoading) ...[
            _buildEmptyState('No audio posts available.'),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyPlayedCard({
    required String title,
    required String artist,
    required List<Color> gradient,
  }) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.white38,
                size: 50,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: playlist['gradient'] as List<Color>,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  playlist['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  playlist['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required int rank,
    required String title,
    required String artist,
    required List<Color> gradient,
  }) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.white38,
                size: 50,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryItem(Map<String, dynamic> item) {
    final coverImageUrl = item['coverImageUrl'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final audio = item['audio'] as Map<String, dynamic>?;
            if (audio != null) {
              _playAudio(audio);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: coverImageUrl != null && coverImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: coverImageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[700],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFB875FB),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white38,
                                size: 28,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white38,
                            size: 28,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'] as String,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderSection({
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openTubePlayer(List<Map<String, dynamic>> videos, int initialIndex) {
    context.push('/tube-player', extra: {
      'videos': videos,
      'initialIndex': initialIndex,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: SafeArea(
        child: Column(
          children: [
            TajifyTopBar(
              onSearch: () => context.push('/search'),
              onNotifications: () {
                context.push('/notifications').then((_) => _loadNotificationUnreadCount());
              },
              onMessages: () {
                context.push('/messages').then((_) => _initializeFirebaseAndLoadMessagesCount());
              },
              onAdd: () => context.go('/create'),
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserAvatar,
              displayLetter: _currentUserInitial,
            ),
            Expanded(
              child: RefreshIndicator(
        onRefresh: _refreshFeeds,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary tabs (Short, Max, Prime, Blog, Audio)
              Row(
                children: [
                  _primaryTab('Short', ChannelCategory.short),
                  _primaryTab('Max', ChannelCategory.max),
                  _primaryTab('Prime', ChannelCategory.prime),
                  _primaryTab('Blog', ChannelCategory.blog),
                  _primaryTab('Audio', ChannelCategory.audio),
                ],
              ),
              const SizedBox(height: 16),
              // Category sections
              Builder(
                builder: (_) {
                  switch (_selectedCategory) {
                    case ChannelCategory.short:
                      return _buildTubeShortSection();
                    case ChannelCategory.max:
                      return _buildTubeMaxSection();
                    case ChannelCategory.prime:
                      return _buildTubePrimeSection();
                    case ChannelCategory.blog:
                      return _buildBlogSection();
                    case ChannelCategory.audio:
                      return _buildAudioSection();
                  }
                },
              ),
                  ],
                ),
          ),
        ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomAudioPlayer(),
            const CustomBottomNav(currentIndex: 0),
          ],
        ),
      ),
    );
  }

  Widget _primaryTab(String label, ChannelCategory category) {
    final selected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = category);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Color(0xFFB875FB) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Color(0xFFB875FB) : Colors.white24,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaCard(Map<String, dynamic> video) {
    final index = _tubeShortPosts.indexOf(video);
    final videoUrl = _getPrimaryMediaUrl(video);
    final thumbnailUrl = _getThumbnail(video);
    return GestureDetector(
      onTap: () {
        print('DEBUG: Opening TubePlayerScreen at index: ' + index.toString());
        context.push('/tube-player', extra: {
          'videos': _tubeShortPosts,
          'initialIndex': index,
        });
      },
      child: _VideoPreviewCard(
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$m:$s';
  }

  void _showContentTypeSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Text(
                              'Create Content',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Content Type Selection
                        const Text(
                          'Choose Content Type',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'For videos under 10 minutes, they will be automatically categorized as Short. For longer videos, they will be categorized as Max.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Tube Short Option
                        _buildContentTypeOption(
                          context,
                          'Tube Short',
                          'Videos under 10 minutes (auto-detected)',
                          Icons.short_text,
                          Colors.blue,
                          'tube_short',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tube Max Option
                        _buildContentTypeOption(
                          context,
                          'Tube Max',
                          'Videos 10 minutes or longer (auto-detected)',
                          Icons.video_library,
                          Colors.green,
                          'tube_max',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tube Prime Option
                        _buildContentTypeOption(
                          context,
                          'Tube Prime',
                          'Premium content (paid)',
                          Icons.star,
                          Color(0xFFB875FB),
                          'tube_prime',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentTypeOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    String contentType,
  ) {
    final isSelected = _selectedContentType == contentType;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedContentType = contentType;
        });
        _showUploadModal(context, contentType);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadModal(BuildContext context, String contentType) {
    Navigator.pop(context); // Close the content type modal
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Text(
                                  'Upload ${_getContentTypeTitle(contentType)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Video Selection & Preview
                            const Text(
                              'Select Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildVideoSelectionSection(setModalState),
                            if (_selectedVideo != null) ...[
                              const SizedBox(height: 16),
                              _buildVideoPreview(),
                            ],
                            const SizedBox(height: 24),
                            // Duet Toggle (only for tube_short and tube_max)
                            if (contentType != 'tube_prime') ...[
                              _buildDuetToggle(setModalState),
                              const SizedBox(height: 24),
                            ],
                            // Thumbnail Selection & Preview
                            const Text(
                              'Thumbnail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildThumbnailSelectionSection(setModalState),
                            const SizedBox(height: 12),
                            _buildThumbnailPreview(),
                            const SizedBox(height: 24),
                            // Description Field
                            const Text(
                              'Description (with hashtags)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                              onChanged: _onDescriptionChanged,
                              decoration: InputDecoration(
                                hintText: 'Describe your video... #funny #music',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            if (_showHashtagSuggestions) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _hashtagSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final hashtag = _hashtagSuggestions[index]['name'] ?? _hashtagSuggestions[index]['hashtag'] ?? '';
                                    final postCount = _hashtagSuggestions[index]['posts_count'] ?? 0;
                                    return GestureDetector(
                                      onTap: () {
                                        _insertHashtagSuggestion(hashtag);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                        child: Row(
                                          children: [
                                            Text(
                                              '#$hashtag',
                                              style: const TextStyle(color: Color(0xFFB875FB), fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '($postCount posts)',
                                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            // Upload Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _selectedVideo != null ? () {
                                  print('[DEBUG] Upload button pressed. _isUploading: $_isUploading');
                                  _handleUpload();
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedVideo != null ? Color(0xFFB875FB) : Colors.grey[600],
                                  foregroundColor: _selectedVideo != null ? Colors.black : Colors.grey[400],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _selectedVideo != null ? 'Upload Content' : 'Select a video to upload',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedVideo != null ? Colors.black : Colors.grey[400],
                                  ),
                                ),
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
        );
      },
    );
  }

  Widget _buildVideoSelectionSection([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (_selectedVideo == null) ...[
            Row(
              children: [
                Icon(Icons.video_library, color: Colors.grey[400]),
                const SizedBox(width: 12),
                const Text(
                  'No video selected',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _pickVideo();
                  if (setModalState != null) setModalState(() {});
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Select Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.video_file, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedVideo!.path.split('/').last,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedVideo = null;
                    });
                    if (setModalState != null) setModalState(() {});
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDuetToggle([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.people, color: Colors.grey[400]),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow Duets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Let other users create duets with your video',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _allowDuet,
            onChanged: (value) {
              setState(() {
                _allowDuet = value;
              });
              if (setModalState != null) setModalState(() {});
            },
            activeColor: Color(0xFFB875FB),
          ),
        ],
      ),
    );
  }

  String _getContentTypeTitle(String contentType) {
    switch (contentType) {
      case 'tube_short':
        return 'Tube Short';
      case 'tube_max':
        return 'Tube Max';
      case 'tube_prime':
        return 'Tube Prime';
      default:
        return 'Content';
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedVideo = File(result.files.first.path!);
          _generatedThumbnails = []; // Reset generated thumbnails
        });
        
        // Auto-generate thumbnail if video thumbnail is selected
        if (_useVideoThumbnail) {
          await _generateThumbnailFromVideo();
        }
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        setState(() {
          _selectedThumbnail = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking thumbnail: $e');
    }
  }

  Future<void> _handleUpload() async {
    print('=== UPLOAD DEBUG START ===');
    print('Uploading content:');
    print('Content Type: $_selectedContentType');
    print('Video: ${_selectedVideo?.path}');
    print('Allow Duet: $_allowDuet');
    print('Use Video Thumbnail: $_useVideoThumbnail');
    print('Custom Thumbnail: ${_selectedThumbnail?.path}');
    print('Generated Thumbnail: ${_generatedThumbnails.map((f) => f.path).toList()}');
    print('Description: ${_descController.text}');

    try {
      setState(() {
        _isUploading = true;
      });
      print('[DEBUG] _isUploading set to true');
      
      // Show upload progress modal immediately
      _showUploadProgressModal();
      
      // Check if user is authenticated
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('User not authenticated. Please login again.');
      }
      print('[UPLOAD] User authenticated with token: ${token.substring(0, 20)}...');

      // Get video duration from frontend
      double? videoDuration;
      if (_selectedVideo != null) {
        videoDuration = await _getVideoDuration(_selectedVideo!);
        print('[UPLOAD] Video duration: ${videoDuration} seconds');
      }

      // 1. Upload video
      print('[UPLOAD] Uploading video...');
      final videoRes = await _apiService.uploadMedia(_selectedVideo!, 'video', duration: videoDuration);
      print('[UPLOAD] Video upload response: ${videoRes.data}');
      final videoMediaId = videoRes.data['data']['media_file_id'];
      print('[UPLOAD] Video uploaded. Media ID: $videoMediaId');

      // 2. Upload thumbnail (if custom or generated)
      int? thumbnailMediaId;
      if (!_useVideoThumbnail && _selectedThumbnail != null) {
        print('[UPLOAD] Uploading custom thumbnail...');
        final thumbRes = await _apiService.uploadMedia(_selectedThumbnail!, 'image');
        thumbnailMediaId = thumbRes.data['data']['media_file_id'];
        print('[UPLOAD] Custom thumbnail uploaded. Media ID: $thumbnailMediaId');
      } else if (_useVideoThumbnail && _generatedThumbnails.isNotEmpty) {
        print('[UPLOAD] Uploading first generated video thumbnail...');
        // Only upload the first generated thumbnail
        final thumbRes = await _apiService.uploadMedia(_generatedThumbnails.first, 'image');
        thumbnailMediaId = thumbRes.data['data']['media_file_id'];
        print('[UPLOAD] Generated thumbnail uploaded. Media ID: $thumbnailMediaId');
      }

      // 3. Map content type to post_type_id
      final postTypeMap = {
        'tube_short': 1,
        'tube_max': 2,
        'tube_prime': 3,
        'audio': 4,
        'image': 5,
        'article': 6,
      };
      final postTypeId = postTypeMap[_selectedContentType] ?? 1;
      print('[UPLOAD] Using post type ID: $postTypeId for content type: $_selectedContentType');

      // 4. Create post
      print('[UPLOAD] Creating post...');
      final hashtags = RegExp(r'#(\w+)')
          .allMatches(_descController.text)
          .map((m) => m.group(1))
          .whereType<String>()
          .toList();
      print('[UPLOAD] Extracted hashtags: $hashtags');
      
      final postRes = await _apiService.createPost(
        postTypeId: postTypeId,
        description: _descController.text,
        isPrime: _selectedContentType == 'tube_prime',
        allowDuet: _allowDuet,
        hashtags: hashtags,
      );
      print('[UPLOAD] Post creation response: ${postRes.data}');
      final postId = postRes.data['data']['id'];
      print('[UPLOAD] Post created. Post ID: $postId');

      // 5. Complete upload (associate media with post)
      print('[UPLOAD] Completing upload...');
      final mediaFileIds = [videoMediaId as int];
      if (thumbnailMediaId != null) mediaFileIds.add(thumbnailMediaId as int);
      print('[UPLOAD] Media file IDs to associate: $mediaFileIds');
      await _apiService.completeUpload(postId, mediaFileIds, thumbnailMediaId: thumbnailMediaId as int?);
      print('[UPLOAD] Upload complete!');

      // Reset state
      setState(() {
        _selectedVideo = null;
        _selectedThumbnail = null;
        _generatedThumbnails = [];
        _allowDuet = true;
        _useVideoThumbnail = true;
        _selectedContentType = '';
        _isGeneratingThumbnail = false;
        _isUploading = false;
      });
      print('[DEBUG] _isUploading set to false (success)');
      _descController.clear();
      
      // Close upload modal and show success toast
      Navigator.pop(context); // Close upload modal
      Navigator.pop(context); // Close the upload options modal
      _showSuccessToast();
      print('=== UPLOAD DEBUG END - SUCCESS ===');
    } catch (e, st) {
      print('=== UPLOAD DEBUG END - ERROR ===');
      print('[UPLOAD ERROR] $e');
      print('[UPLOAD ERROR STACK] $st');
      
      // Reset loading state on error
      setState(() {
        _isUploading = false;
      });
      print('[DEBUG] _isUploading set to false (error)');
      
      // Close upload modal and show error toast
      Navigator.pop(context); // Close upload modal
      Navigator.pop(context); // Close the upload options modal
      _showErrorToast(e.toString());
    }
  }

  void _showUploadProgressModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent closing with back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated upload icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFFB875FB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Center(
                      child: _SkeletonLoader(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Upload title
                  const Text(
                    'Uploading Content',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Upload subtitle
                  Text(
                    'Please wait while we upload your ${_getContentTypeTitle(_selectedContentType)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Progress steps
                  _buildProgressStep('Preparing video...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Uploading to cloud...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Processing thumbnail...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Creating post...', false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStep(String text, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? Color(0xFFB875FB) : Colors.grey[600],
            borderRadius: BorderRadius.circular(10),
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: isCompleted ? Colors.white : Colors.grey[500],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Content uploaded successfully!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorToast(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upload failed: $error',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<double?> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000.0;
      controller.dispose();
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      return null;
    }
  }

  void _showSavedVideos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final savedShorts = _tubeShortPosts.where((v) {
          final url = _getPrimaryMediaUrl(v);
          return url.isNotEmpty && _savedVideos.contains(url);
        }).toList();
        final savedMax = _tubeMaxPosts.where((v) {
          final url = _getPrimaryMediaUrl(v);
          return url.isNotEmpty && _savedVideos.contains(url);
        }).toList();
        final savedPrime = _tubePrimePosts.where((v) {
          final url = _getPrimaryMediaUrl(v);
          return url.isNotEmpty && _savedVideos.contains(url);
        }).toList();
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Saved Videos', style: TextStyle(color: Color(0xFFB875FB), fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  const SizedBox(height: 18),
                  if (savedShorts.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube SHORT', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedShorts.map((v) => _mediaCardWithSave(v)).toList(),
                      ),
                    ),
                  ],
                  if (savedMax.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube MAX', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedMax.map((v) => _mediaCardWithSave(v)).toList(),
                      ),
                    ),
                  ],
                  if (savedPrime.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube PRIME', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedPrime
                            .map((v) => _TubePrimeCardWithSave(
                                  video: v,
                                  isSaved: true,
                                  onToggleSave: () {
                                    final url = _getPrimaryMediaUrl(v);
                                    if (url.isNotEmpty) {
                                      _toggleSave(url);
                                    }
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                  if (savedShorts.isEmpty && savedMax.isEmpty && savedPrime.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No saved videos yet.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _mediaCardWithSave(Map<String, dynamic> video) {
    return _mediaCard(video);
  }

  void _toggleSave(String url) {
    setState(() {
      if (_savedVideos.contains(url)) {
        _savedVideos.remove(url);
      } else {
        _savedVideos.add(url);
      }
    });
  }

  Future<void> _showUploadOptions(BuildContext parentContext) async {
    final choice = await showCreateVideoOptionSheet(parentContext);
    if (choice == null) return;
    if (choice == CreateVideoOption.record) {
      _showCameraRecordingScreen(parentContext);
    } else if (choice == CreateVideoOption.upload) {
      _showContentTypeSelectionModal(parentContext);
    }
  }


  void _showCameraRecordingScreen(BuildContext context) async {
    // Navigate to camera recording screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CameraRecordingScreen(),
      ),
    );
    
    // If user recorded a video, handle the result
    if (result != null && result is Map<String, dynamic>) {
      final videoPath = result['videoPath'] as String?;
      final duration = result['duration'] as double?;
      final isRecorded = result['isRecorded'] as bool? ?? false;
      
      if (videoPath != null && duration != null && isRecorded) {
        // Set the recorded video as selected and proceed with upload
        setState(() {
          _selectedVideo = File(videoPath);
        });
        
        // Show upload modal with auto-categorization
        _showUploadModalForRecordedVideo(context, videoPath, duration);
      }
    }
  }

  void _showUploadModalForRecordedVideo(BuildContext context, String videoPath, double duration) {
    // Determine the content type based on duration for UI display
    final contentType = duration < 600 ? 'tube_short' : 'tube_max';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Text(
                                  'Upload Recorded ${_getContentTypeTitle(contentType)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Auto-categorization info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFB875FB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFFB875FB).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Color(0xFFB875FB)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Auto-Categorized',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Duration: ${_formatRecordingDuration(duration)} - Automatically categorized as ${_getContentTypeTitle(contentType)}',
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Video Preview
                            _buildVideoPreview(),
                            const SizedBox(height: 24),
                            
                            // Duet Toggle (only for tube_short and tube_max)
                            if (contentType != 'tube_prime') ...[
                              _buildDuetToggle(setModalState),
                              const SizedBox(height: 24),
                            ],
                            
                            // Thumbnail Selection
                            const Text(
                              'Thumbnail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildThumbnailSelectionSection(setModalState),
                            const SizedBox(height: 12),
                            _buildThumbnailPreview(),
                            const SizedBox(height: 24),
                            
                            // Description Field
                            const Text(
                              'Description (with hashtags)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Write your description here... #hashtag',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[800],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Upload Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isUploading ? null : () => _handleRecordedVideoUpload(duration),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFB875FB),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isUploading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Upload Video',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatRecordingDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$secs';
  }

  Future<void> _handleRecordedVideoUpload(double duration) async {
    print('=== RECORDED VIDEO UPLOAD DEBUG START ===');
    print('Uploading recorded video with auto-categorization:');
    print('Video: ${_selectedVideo?.path}');
    print('Duration: $duration seconds');
    print('Allow Duet: $_allowDuet');
    print('Use Video Thumbnail: $_useVideoThumbnail');
    print('Custom Thumbnail: ${_selectedThumbnail?.path}');
    print('Description: ${_descController.text}');

    try {
      setState(() {
        _isUploading = true;
      });
      
      // Show upload progress modal immediately
      _showUploadProgressModal();
      
      // Check if user is authenticated
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('User not authenticated. Please login again.');
      }
      
      print('[UPLOAD] User authenticated with token: ${token.substring(0, 20)}...');

      // 1. Upload video with duration
      print('[UPLOAD] Uploading video...');
      final videoRes = await _apiService.uploadMedia(_selectedVideo!, 'video', duration: duration);
      print('[UPLOAD] Video upload response: ${videoRes.data}');
      final videoMediaId = videoRes.data['data']['media_file_id'];
      print('[UPLOAD] Video uploaded. Media ID: $videoMediaId');

      // 2. Upload thumbnail (if custom or generated)
      int? thumbnailMediaId;
      if (!_useVideoThumbnail && _selectedThumbnail != null) {
        print('[UPLOAD] Uploading custom thumbnail...');
        final thumbnailRes = await _apiService.uploadMedia(_selectedThumbnail!, 'image');
        print('[UPLOAD] Thumbnail upload response: ${thumbnailRes.data}');
        thumbnailMediaId = thumbnailRes.data['data']['media_file_id'];
        print('[UPLOAD] Thumbnail uploaded. Media ID: $thumbnailMediaId');
      } else if (_useVideoThumbnail && _generatedThumbnails.isNotEmpty) {
        print('[UPLOAD] Uploading generated thumbnail...');
        final thumbnailRes = await _apiService.uploadMedia(_generatedThumbnails.first, 'image');
        print('[UPLOAD] Generated thumbnail upload response: ${thumbnailRes.data}');
        thumbnailMediaId = thumbnailRes.data['data']['media_file_id'];
        print('[UPLOAD] Generated thumbnail uploaded. Media ID: $thumbnailMediaId');
      }

      // 3. Create post with auto-categorization based on duration
      print('[UPLOAD] Creating post with auto-categorization...');
      
      // Extract hashtags from description
      final description = _descController.text;
      final hashtagRegex = RegExp(r'#\w+');
      final hashtags = hashtagRegex.allMatches(description)
          .map((match) => match.group(0)!.substring(1))
          .toList();
      
      final postRes = await _apiService.createPostWithAutoCategorization(
        videoDuration: duration,
        description: description,
        allowDuet: _allowDuet,
        hashtags: hashtags.isNotEmpty ? hashtags : null,
      );
      
      print('[UPLOAD] Post creation response: ${postRes.data}');
      final postId = postRes.data['data']['post']['id'];
      final determinedType = postRes.data['data']['determined_type'];
      print('[UPLOAD] Post created with ID: $postId, Type: $determinedType');

      // 4. Complete upload by associating media with post
      print('[UPLOAD] Completing upload...');
      final completeRes = await _apiService.completeUpload(
        postId,
        [videoMediaId],
        thumbnailMediaId: thumbnailMediaId,
      );
      print('[UPLOAD] Complete upload response: ${completeRes.data}');

      // 5. Reset state and show success
      setState(() {
        _isUploading = false;
        _selectedVideo = null;
        _selectedThumbnail = null;
        _generatedThumbnails = [];
        _descController.clear();
        _allowDuet = true;
        _useVideoThumbnail = true;
      });

      // Close upload progress modal
      Navigator.of(context).pop();
      
      // Close upload modal
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video uploaded successfully as $determinedType!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Refresh the posts
      _loadTubeShortPosts();
      _loadTubeMaxPosts();
      _loadTubePrimePosts();

      print('=== RECORDED VIDEO UPLOAD DEBUG END ===');
      
    } catch (e) {
      print('[UPLOAD ERROR] $e');
      
      setState(() {
        _isUploading = false;
      });

      // Close any open modals
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildVideoPreview() {
    if (_selectedVideo == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: VideoPlayerWidget(file: _selectedVideo!),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    if (_useVideoThumbnail) {
      if (_isGeneratingThumbnail) {
        return Container(
          width: 160, // Increased from 120
          height: 120, // Increased from 80
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFB875FB), width: 1),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _SkeletonLoader(
                    width: 20,
                    height: 20,
                    borderRadius: 10,
                  ),
                ),
                SizedBox(height: 4),
                Text('Generating...', style: TextStyle(color: Color(0xFFB875FB), fontSize: 10)),
              ],
            ),
          ),
        );
      } else if (_generatedThumbnails.isNotEmpty) {
        return Container(
          width: 160, // Increased from 120
          height: 120, // Increased from 80
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFB875FB), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _generatedThumbnails.first, // Use the first generated thumbnail for preview
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _youtubeStyleThumbnailPlaceholder();
              },
            ),
          ),
        );
      } else {
        return _youtubeStyleThumbnailPlaceholder();
      }
    } else if (_selectedThumbnail != null && _selectedThumbnail!.existsSync()) {
      return Container(
        width: 160, // Increased from 120
        height: 120, // Increased from 80
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            _selectedThumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _youtubeStyleThumbnailPlaceholder();
            },
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _youtubeStyleThumbnailPlaceholder() {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF414345)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
      ),
    );
  }

  Future<void> _generateThumbnailFromVideo() async {
    if (_selectedVideo == null) return;
    
    setState(() {
      _isGeneratingThumbnail = true;
      _generatedThumbnails = [];
    });

    try {
      // Generate multiple thumbnails from different timestamps
      await _generateMultipleThumbnails();
    } catch (e) {
      print('Error generating thumbnails: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  Future<void> _generateMultipleThumbnails() async {
    if (_selectedVideo == null) return;

    try {
      // Create a temporary directory for the thumbnails
      final tempDir = await Directory.systemTemp.createTemp('tajify_thumbnails');
      
      // Generate thumbnails at different timestamps (0s, 25%, 50%, 75% of video duration)
      final timestamps = <double>[0, 0.25, 0.5, 0.75];
      final List<File> thumbnails = [];
      
      for (int i = 0; i < timestamps.length; i++) {
        final timestamp = timestamps[i];
        final thumbnailPath = '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        final thumbnailFile = await _captureVideoFrameAtTime(thumbnailPath, timestamp as double);
        if (thumbnailFile != null && thumbnailFile.existsSync() && thumbnailFile.lengthSync() > 0) {
          thumbnails.add(thumbnailFile);
          print('[DEBUG] Generated thumbnail $i at ${timestamp * 100}% of video');
        }
      }
      
      if (thumbnails.isNotEmpty) {
        setState(() {
          _generatedThumbnails = thumbnails;
          _isGeneratingThumbnail = false;
        });
        print('[DEBUG] Generated ${thumbnails.length} thumbnails successfully');
      } else {
        setState(() {
          _isGeneratingThumbnail = false;
        });
        print('[DEBUG] No thumbnails were generated successfully');
      }
    } catch (e) {
      print('Error generating multiple thumbnails: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  Future<File?> _captureVideoFrameAtTime(String thumbnailPath, double timePercent) async {
    try {
      print('[DEBUG] Generating thumbnail at ${timePercent * 100}% of video: ${_selectedVideo?.path}');
      if (_selectedVideo == null) return null;
      
      final String? thumbPath = await VideoThumbnail.thumbnailFile(
        video: _selectedVideo!.path,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720, // Increased from 80 to 720 for high resolution
        maxWidth: 1280, // Added maxWidth for better aspect ratio
        quality: 95, // Increased from 85 to 95 for better quality
        timeMs: (timePercent * 1000).round(), // Convert percentage to milliseconds
      );
      
      print('[DEBUG] video_thumbnail generated at ${timePercent * 100}%: $thumbPath');
      if (thumbPath != null) {
        final file = File(thumbPath);
        if (file.existsSync()) {
          print('[DEBUG] Thumbnail file exists and will be used: ${file.path}');
          return file;
        } else {
          print('[DEBUG] Thumbnail file does not exist after generation.');
        }
      }
      return null;
    } catch (e, st) {
      print('[ERROR] Error generating video thumbnail at ${timePercent * 100}%: ${e.toString()}');
      print('[ERROR] Stack trace: ${st.toString()}');
      return null;
    }
  }

  Widget _buildThumbnailSelectionSection([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Use video thumbnail option
          Row(
            children: [
              Icon(Icons.video_library, color: Colors.grey[400]),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Use video thumbnail',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Switch(
                value: _useVideoThumbnail,
                onChanged: (value) async {
                  setState(() {
                    _useVideoThumbnail = value;
                    if (value) {
                      _selectedThumbnail = null;
                    } else {
                      _generatedThumbnails = [];
                    }
                  });
                  
                  // Generate thumbnail if video thumbnail is selected and video is available
                  if (value && _selectedVideo != null) {
                    await _generateThumbnailFromVideo();
                  }
                  
                  if (setModalState != null) setModalState(() {});
                },
                activeColor: Color(0xFFB875FB),
              ),
            ],
          ),
          
          if (!_useVideoThumbnail) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
            
            if (_selectedThumbnail == null) ...[
              Row(
                children: [
                  Icon(Icons.image, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  const Text(
                    'No thumbnail selected',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _pickThumbnail();
                    if (setModalState != null) setModalState(() {});
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Select Thumbnail'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.image, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedThumbnail!.path.split('/').last,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedThumbnail = null;
                      });
                      if (setModalState != null) setModalState(() {});
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  final String url;
  final String? thumbnailUrl;
  const _VideoPreviewCard({required this.url, this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B1B1B), Color(0xFF0E0E0E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasThumbnail
                    ? Image.network(
                        thumbnailUrl!,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackPreview(),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _VideoPlayerSkeleton();
                        },
                      )
                    : _fallbackPreview(),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fallbackPreview() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white38,
          size: 28,
        ),
      ),
    );
  }
}

class _TubePrimeCard extends StatefulWidget {
  final Map<String, dynamic> video;
  const _TubePrimeCard({required this.video});

  @override
  State<_TubePrimeCard> createState() => _TubePrimeCardState();
}

class _TubePrimeCardState extends State<_TubePrimeCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPreviewing = false;
  bool _hasError = false;
  double _progress = 0.0;
  late Duration _previewDuration;
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _previewDuration = const Duration(seconds: 15);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.video['snippetUrl'])
        ..setLooping(false)
        ..setVolume(0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _initialized = true);
        if (_controller!.value.isInitialized) {
          _startPreview();
        }
      }
      
      _listener = () {
        if (!_controller!.value.isInitialized) return;
        final pos = _controller!.value.position;
        setState(() {
          _progress = pos.inMilliseconds / _previewDuration.inMilliseconds;
          if (_progress > 1.0) _progress = 1.0;
        });
        if (pos >= _previewDuration && _isPreviewing) {
          _controller!.pause();
          setState(() => _isPreviewing = false);
        }
      };
      _controller!.addListener(_listener!);
    } catch (e) {
      print('Video initialization error for ${widget.video['snippetUrl']}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
        });
      }
    }
  }

  void _startPreview() {
    _controller!.seekTo(Duration.zero);
    _controller!.play();
    setState(() {
      _isPreviewing = true;
      _progress = 0.0;
    });
    // Add a timer to force stop at 15s
    Future.delayed(_previewDuration, () {
      if (mounted && _isPreviewing) {
        _controller!.pause();
        _controller!.seekTo(_previewDuration);
        setState(() => _isPreviewing = false);
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener!);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_initialized && !_hasError) _startPreview();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown.shade900, Colors.black, Colors.brown.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _hasError
                  ? Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    )
                  : _initialized && _controller != null
                      ? ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.35),
                            BlendMode.darken,
                          ),
                          child: Stack(
                            children: [
                              SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _controller!.value.size.width,
                                    height: _controller!.value.size.height,
                                    child: VideoPlayer(_controller!),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const _VideoPlayerSkeleton(),
            ),
            // Progress bar
            if (_isPreviewing)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 5,
                  backgroundColor: Colors.black26,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                ),
              ),
            // Preview badge
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFB875FB).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFB875FB).withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_circle_fill, color: Colors.black, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.video['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Pay to Unlock button
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFB875FB),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment flow coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Pay to Unlock'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TubePrimeCardWithSave extends StatelessWidget {
  final Map<String, dynamic> video;
  final bool isSaved;
  final VoidCallback onToggleSave;
  const _TubePrimeCardWithSave({required this.video, required this.isSaved, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TubePrimeCard(video: video),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: onToggleSave,
            child: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? Color(0xFFB875FB) : Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
} 

class VideoPlayerWidget extends StatefulWidget {
  final File file;
  const VideoPlayerWidget({required this.file, Key? key}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.setVolume(0.5);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _VideoPlayerSkeleton();
    }
    
    // Calculate aspect ratio to contain the video properly
    final videoAspectRatio = _controller.value.aspectRatio;
    
    return Center(
      child: AspectRatio(
        aspectRatio: videoAspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
} 