import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/tajify_top_bar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import 'dart:async';

const Color _primaryColor = Color(0xFFB875FB);
const Color _primaryColorLight = Color(0xFFE84BC4);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  int _notificationUnreadCount = 0;
  int _messagesUnreadCount = 0;
  StreamSubscription<int>? _messagesCountSubscription;
  List<dynamic> _topCreators = [];
  bool _isLoadingCreators = true;
  late AnimationController _shimmerController;
  
  // Trending videos
  List<Map<String, dynamic>> _trendingVideos = [];
  bool _isLoadingVideos = true;
  int _currentVideoPage = 1;
  bool _hasMoreVideos = true;
  bool _isLoadingMoreVideos = false;
  final ScrollController _trendingVideosScrollController = ScrollController();
  
  // Top tracks (audio posts)
  List<dynamic> _topTracks = [];
  bool _isLoadingTracks = true;
  
  // Latest articles (blogs)
  List<dynamic> _latestArticles = [];
  bool _isLoadingArticles = true;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _trendingVideosScrollController.addListener(_onTrendingVideosScroll);
    _loadUserProfile();
    _loadTopCreators();
    _loadTrendingVideos();
    _loadTopTracks();
    _loadLatestArticles();
    _loadNotificationUnreadCount();
    _initializeFirebaseAndLoadMessagesCount();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _trendingVideosScrollController.dispose();
    _messagesCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotificationUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count');
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _notificationUnreadCount = response.data['data']['count'] ?? 0;
          });
        }
      }
    } catch (_) {
      // ignored
    }
  }

  Future<void> _initializeFirebaseAndLoadMessagesCount() async {
    try {
      await FirebaseService.initialize();
      await FirebaseService.initializeAuth();
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final userId = response.data['data']['id'] as int?;
        if (userId != null && FirebaseService.isInitialized) {
          _messagesCountSubscription?.cancel();
          _messagesCountSubscription = FirebaseService.getUnreadCountStream(userId).listen((count) {
            if (mounted) {
              setState(() {
                _messagesUnreadCount = count;
              });
            }
          });
        }
      }
    } catch (_) {
      // ignored
    }
  }

  void _onTrendingVideosScroll() {
    if (_trendingVideosScrollController.position.pixels >=
        _trendingVideosScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreVideos && _hasMoreVideos) {
        _loadMoreTrendingVideos();
      }
    }
  }

  Future<void> _loadUserProfile() async {
    debugPrint('🔍 HomeScreen - Loading user profile...');
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = response.data['data'];
        debugPrint('🔍 HomeScreen - Profile data: $profile');
        if (mounted) {
          setState(() {
            // Handle nested user object
            final user = profile?['user'] ?? profile;
            final name = user?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = user?['profile_avatar']?.toString();
            debugPrint('🔍 HomeScreen - Avatar URL: $_currentUserAvatar');
            debugPrint('🔍 HomeScreen - Initial: $_currentUserInitial');
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading profile from API: $e');
    }

    try {
      final name = await _storageService.getUserName();
      final avatar = await _storageService.getUserProfilePicture();
      debugPrint('🔍 HomeScreen - From storage - Name: $name, Avatar: $avatar');
      if (mounted) {
        setState(() {
          if (name != null && name.isNotEmpty) {
            _currentUserInitial = name[0].toUpperCase();
          }
          _currentUserAvatar = avatar;
          debugPrint('🔍 HomeScreen - Set from storage - Avatar: $_currentUserAvatar, Initial: $_currentUserInitial');
        });
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading from storage: $e');
    }
  }

  Future<void> _loadTopCreators() async {
    try {
      debugPrint('🔍 HomeScreen - Loading top creators...');
      final response = await _apiService.getTopCreators(limit: 4);
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _topCreators = response.data['data'] ?? [];
            _isLoadingCreators = false;
          });
        }
        debugPrint('🔍 HomeScreen - Top creators loaded: ${_topCreators.length}');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading top creators: $e');
      if (mounted) {
        setState(() {
          _isLoadingCreators = false;
        });
      }
    }
  }

  Future<void> _loadTrendingVideos() async {
    try {
      debugPrint('🔍 HomeScreen - Loading trending videos...');
      setState(() {
        _isLoadingVideos = true;
        _currentVideoPage = 1;
      });
      
      final response = await _apiService.getTrendingPosts(page: 1, limit: 10);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final pagination = response.data['data'];
        if (mounted) {
          setState(() {
            final videos = pagination['data'] ?? [];
            _trendingVideos = videos.cast<Map<String, dynamic>>();
            _hasMoreVideos = _currentVideoPage < (pagination['last_page'] ?? 1);
            _isLoadingVideos = false;
          });
        }
        debugPrint('🔍 HomeScreen - Trending videos loaded: ${_trendingVideos.length}');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading trending videos: $e');
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
        });
      }
    }
  }

  Future<void> _loadMoreTrendingVideos() async {
    if (_isLoadingMoreVideos || !_hasMoreVideos) return;
    
    try {
      setState(() {
        _isLoadingMoreVideos = true;
      });
      
      final nextPage = _currentVideoPage + 1;
      final response = await _apiService.getTrendingPosts(page: nextPage, limit: 10);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final pagination = response.data['data'];
        if (mounted) {
          setState(() {
            final newVideos = pagination['data'] ?? [];
            _trendingVideos.addAll(newVideos.cast<Map<String, dynamic>>());
            _currentVideoPage = nextPage;
            _hasMoreVideos = nextPage < (pagination['last_page'] ?? 1);
            _isLoadingMoreVideos = false;
          });
        }
        debugPrint('🔍 HomeScreen - Loaded more videos. Total: ${_trendingVideos.length}');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading more videos: $e');
      if (mounted) {
        setState(() {
          _isLoadingMoreVideos = false;
        });
      }
    }
  }

  Future<void> _loadTopTracks() async {
    try {
      debugPrint('🔍 HomeScreen - Loading top tracks...');
      setState(() {
        _isLoadingTracks = true;
      });
      
      final response = await _apiService.getAudioPosts(page: 1, limit: 10);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final tracks = data is List ? data : (data['data'] ?? []);
        if (mounted) {
          setState(() {
            _topTracks = tracks;
            _isLoadingTracks = false;
          });
        }
        debugPrint('🔍 HomeScreen - Top tracks loaded: ${_topTracks.length}');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading top tracks: $e');
      if (mounted) {
        setState(() {
          _isLoadingTracks = false;
        });
      }
    }
  }

  Future<void> _loadLatestArticles() async {
    try {
      debugPrint('🔍 HomeScreen - Loading latest articles...');
      setState(() {
        _isLoadingArticles = true;
      });
      
      final response = await _apiService.getBlogPosts(page: 1, limit: 5);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final articles = data is List ? data : (data['data'] ?? []);
        if (mounted) {
          setState(() {
            _latestArticles = articles;
            _isLoadingArticles = false;
          });
        }
        debugPrint('🔍 HomeScreen - Latest articles loaded: ${_latestArticles.length}');
      }
    } catch (e) {
      debugPrint('❌ HomeScreen - Error loading latest articles: $e');
      if (mounted) {
        setState(() {
          _isLoadingArticles = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      appBar: TajifyTopBar(
        onSearch: () => context.push('/search'),
        onNotifications: () => context.push('/notifications').then((_) => _loadNotificationUnreadCount()),
        onMessages: () => context.push('/messages').then((_) => _initializeFirebaseAndLoadMessagesCount()),
        onAvatarTap: () => context.go('/profile'),
        notificationCount: _notificationUnreadCount,
        messageCount: _messagesUnreadCount,
        avatarUrl: _currentUserAvatar,
        displayLetter: _currentUserInitial,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Top Creators Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Top Creators',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.trending_up,
                        color: _primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                  const Text(
                    'View All',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: _isLoadingCreators
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Your Channel
                        _buildCreatorItem(
                          isYourChannel: true,
                          label: 'Your Channel',
                        ),
                        const SizedBox(width: 16),
                        // Skeleton loaders
                        _buildCreatorSkeleton(),
                        const SizedBox(width: 16),
                        _buildCreatorSkeleton(),
                        const SizedBox(width: 16),
                        _buildCreatorSkeleton(),
                        const SizedBox(width: 16),
                        _buildCreatorSkeleton(),
                      ],
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Your Channel
                        _buildCreatorItem(
                          isYourChannel: true,
                          label: 'Your Channel',
                        ),
                        const SizedBox(width: 16),
                        // Top creators from backend
                        ..._topCreators.map((creator) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                final username = creator['username'];
                                if (username != null && username.isNotEmpty) {
                                  context.push('/user/$username');
                                }
                              },
                              child: _buildCreatorItem(
                                name: creator['name'] ?? '',
                                avatarUrl: creator['profile_avatar'],
                                hasNewTag: false,
                                gradientColors: [_primaryColor, _primaryColorLight],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            // Trending Videos Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trending Videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/channel');
                    },
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _isLoadingVideos
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildVideoSkeleton(),
                        const SizedBox(width: 16),
                        _buildVideoSkeleton(),
                        const SizedBox(width: 16),
                        _buildVideoSkeleton(),
                      ],
                    )
                  : _trendingVideos.isEmpty
                      ? const Center(
                          child: Text(
                            'No trending videos',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          controller: _trendingVideosScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _trendingVideos.length + (_isLoadingMoreVideos ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _trendingVideos.length) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: _buildVideoSkeleton(),
                              );
                            }
                            
                            final video = _trendingVideos[index];
                            final user = video['user'] ?? {};
                            final thumbnailUrl = _getThumbnail(video);
                            final videoUrl = _getPrimaryMediaUrl(video);
                            
                            final likesCount = video['likes_count'] is int 
                                ? video['likes_count'] as int
                                : (video['likes_count'] is String 
                                    ? int.tryParse(video['likes_count'] as String) ?? 0
                                    : 0);
                            final viewsText = _formatViews(likesCount);
                            
                            return GestureDetector(
                              onTap: () {
                                Future<List<Map<String, dynamic>>> loadMoreVideos(int page) async {
                                  try {
                                    final response = await _apiService.getTrendingPosts(page: page, limit: 10);
                                    if (response.statusCode == 200 && response.data['success'] == true) {
                                      final pagination = response.data['data'];
                                      final videos = pagination['data'] ?? [];
                                      return videos.cast<Map<String, dynamic>>();
                                    }
                                  } catch (e) {
                                    debugPrint('Error loading more videos: $e');
                                  }
                                  return <Map<String, dynamic>>[];
                                }
                                
                                context.push('/tube-player', extra: {
                                  'videos': _trendingVideos,
                                  'initialIndex': index,
                                  'loadMoreVideos': loadMoreVideos,
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index == _trendingVideos.length - 1 ? 0 : 16,
                                ),
                                child: _buildVideoItem(
                                  title: video['title'] ?? video['description'] ?? 'Untitled',
                                  creator: user['name'] ?? user['username'] ?? 'Unknown',
                                  views: viewsText,
                                  thumbnailUrl: thumbnailUrl,
                                  videoUrl: videoUrl,
                                  showPlayButton: true,
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 32),
            // Top Tracks Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Top Tracks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/channel', extra: {'initialCategory': 'audio'});
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: _isLoadingTracks
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildTrackSkeleton(),
                        const SizedBox(width: 16),
                        _buildTrackSkeleton(),
                      ],
                    )
                  : _topTracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No tracks available',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _topTracks.length,
                          itemBuilder: (context, index) {
                            final track = _topTracks[index];
                            final user = track['user'] ?? {};
                            final likesCount = track['likes_count'] is int 
                                ? track['likes_count'] as int
                                : (track['likes_count'] is String 
                                    ? int.tryParse(track['likes_count'] as String) ?? 0
                                    : 0);
                            final playsText = _formatViews(likesCount);
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == _topTracks.length - 1 ? 0 : 16,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  context.push('/channel', extra: {
                                    'initialCategory': 'audio',
                                    'initialAudioTrack': track,
                                  });
                                },
                                child: _buildTrackItem(
                                  rank: '#${index + 1}',
                                  title: track['title'] ?? track['description'] ?? 'Untitled',
                                  artist: user['name'] ?? user['username'] ?? 'Unknown',
                                  plays: playsText,
                                  coverImageUrl: _getThumbnail(track),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 32),
            // Latest Articles Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Latest Articles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      context.push('/channel', extra: {'initialCategory': 'blog'});
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: _isLoadingArticles
                  ? ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildArticleSkeleton(),
                        const SizedBox(width: 16),
                        _buildArticleSkeleton(),
                      ],
                    )
                  : _latestArticles.isEmpty
                      ? const Center(
                          child: Text(
                            'No articles available',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _latestArticles.length,
                          itemBuilder: (context, index) {
                            final article = _latestArticles[index];
                            final user = article['user'] ?? {};
                            final coverImageUrl = article['cover_image_url'] ?? article['thumbnail_url'];
                            final tags = article['tags'] ?? [];
                            final category = tags.isNotEmpty ? tags[0].toString() : 'General';
                            
                            // Calculate time ago
                            String timeAgo = 'Recently';
                            if (article['created_at'] != null) {
                              try {
                                final createdAt = DateTime.parse(article['created_at']);
                                final now = DateTime.now();
                                final difference = now.difference(createdAt);
                                if (difference.inDays > 0) {
                                  timeAgo = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
                                } else if (difference.inHours > 0) {
                                  timeAgo = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
                                } else if (difference.inMinutes > 0) {
                                  timeAgo = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
                                }
                              } catch (e) {
                                timeAgo = 'Recently';
                              }
                            }
                            
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == _latestArticles.length - 1 ? 0 : 16,
                              ),
                              child: _buildArticleItem(
                                uuid: article['uuid'] ?? article['id']?.toString(),
                                category: category,
                                categoryColor: _primaryColor,
                                title: article['title'] ?? 'Untitled',
                                source: user['name'] ?? user['username'] ?? 'Unknown',
                                time: timeAgo,
                                coverImageUrl: coverImageUrl,
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 0),
    );
  }

  Widget _buildCreatorItem({
    bool isYourChannel = false,
    String? username,
    String? name,
    String? avatarUrl,
    bool hasNewTag = false,
    List<Color>? gradientColors,
    String label = '',
  }) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isYourChannel
                    ? null
                    : LinearGradient(
                        colors: gradientColors ?? [_primaryColor, _primaryColorLight],
                      ),
                color: isYourChannel ? Colors.grey[800] : null,
                border: isYourChannel
                    ? Border.all(color: Colors.grey[600]!, width: 2)
                    : null,
              ),
              child: isYourChannel
                  ? const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 32,
                    )
                  : avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[700],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[700],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
            ),
            if (hasNewTag)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isYourChannel ? label : (name ?? username ?? ''),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCreatorSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        final shimmerPosition = shimmerValue * 2 - 1; // Range from -1 to 1
        
        return Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(shimmerPosition - 0.5, shimmerPosition - 0.5),
                      end: Alignment(shimmerPosition + 0.5, shimmerPosition + 0.5),
                      colors: [
                        Colors.grey[800]!,
                        Colors.grey[700]!.withOpacity(0.5),
                        Colors.grey[800]!,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(shimmerPosition - 0.5, 0),
                      end: Alignment(shimmerPosition + 0.5, 0),
                      colors: [
                        Colors.grey[800]!,
                        Colors.grey[700]!.withOpacity(0.5),
                        Colors.grey[800]!,
                      ],
                      stops: const [0.0, 0.5, 1.0],
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

  Widget _buildVideoSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        final shimmerPosition = shimmerValue * 2 - 1; // Range from -1 to 1
        
        return Container(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(shimmerPosition - 0.5, shimmerPosition - 0.5),
                          end: Alignment(shimmerPosition + 0.5, shimmerPosition + 0.5),
                          colors: [
                            Colors.grey[800]!,
                            Colors.grey[700]!.withOpacity(0.5),
                            Colors.grey[800]!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 140,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shimmerPosition - 0.5, 0),
                        end: Alignment(shimmerPosition + 0.5, 0),
                        colors: [
                          Colors.grey[800]!,
                          Colors.grey[700]!.withOpacity(0.5),
                          Colors.grey[800]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shimmerPosition - 0.5, 0),
                        end: Alignment(shimmerPosition + 0.5, 0),
                        colors: [
                          Colors.grey[800]!,
                          Colors.grey[700]!.withOpacity(0.5),
                          Colors.grey[800]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatViews(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M views';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K views';
    } else {
      return '$count views';
    }
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

  Widget _buildVideoItem({
    required String title,
    required String creator,
    required String views,
    String? thumbnailUrl,
    String? videoUrl,
    bool showPlayButton = false,
  }) {
    return Container(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              // If thumbnail fails and we have video URL, show video preview
                              if (videoUrl != null && videoUrl.isNotEmpty) {
                                return _VideoPreviewWidget(videoUrl: videoUrl);
                              }
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white38,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          )
                        : videoUrl != null && videoUrl.isNotEmpty
                            ? _VideoPreviewWidget(videoUrl: videoUrl)
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.videocam,
                                    color: Colors.white38,
                                    size: 40,
                                  ),
                                ),
                              ),
                  ),
                  if (showPlayButton)
                    const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$creator • $views',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackItem({
    required String rank,
    required String title,
    required String artist,
    required String plays,
    String? coverImageUrl,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                coverImageUrl != null && coverImageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: coverImageUrl,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[700],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
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
                            child: const Center(
                              child: Icon(
                                Icons.music_note,
                                color: Colors.white38,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.music_note,
                            color: Colors.white38,
                            size: 32,
                          ),
                        ),
                      ),
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rank $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  plays,
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
        ],
      ),
    );
  }

  Widget _buildArticleItem({
    String? uuid,
    required String category,
    required Color categoryColor,
    required String title,
    required String source,
    required String time,
    String? coverImageUrl,
  }) {
    return GestureDetector(
      onTap: () {
        if (uuid != null && uuid.isNotEmpty) {
          context.push('/blog/$uuid');
        }
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Expanded(
            child: Stack(
              children: [
                if (coverImageUrl != null && coverImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: coverImageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.article,
                            color: Colors.white38,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.article,
                        color: Colors.white38,
                        size: 40,
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      source,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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

  Widget _buildTrackSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        final shimmerPosition = shimmerValue * 2 - 1;
        
        return Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shimmerPosition - 0.5, shimmerPosition - 0.5),
                        end: Alignment(shimmerPosition + 0.5, shimmerPosition + 0.5),
                        colors: [
                          Colors.grey[800]!,
                          Colors.grey[700]!.withOpacity(0.5),
                          Colors.grey[800]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(shimmerPosition - 0.5, 0),
                              end: Alignment(shimmerPosition + 0.5, 0),
                              colors: [
                                Colors.grey[800]!,
                                Colors.grey[700]!.withOpacity(0.5),
                                Colors.grey[800]!,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(shimmerPosition - 0.5, 0),
                              end: Alignment(shimmerPosition + 0.5, 0),
                              colors: [
                                Colors.grey[800]!,
                                Colors.grey[700]!.withOpacity(0.5),
                                Colors.grey[800]!,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(shimmerPosition - 0.5, 0),
                              end: Alignment(shimmerPosition + 0.5, 0),
                              colors: [
                                Colors.grey[800]!,
                                Colors.grey[700]!.withOpacity(0.5),
                                Colors.grey[800]!,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArticleSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerValue = _shimmerController.value;
        final shimmerPosition = shimmerValue * 2 - 1;
        
        return Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(shimmerPosition - 0.5, shimmerPosition - 0.5),
                          end: Alignment(shimmerPosition + 0.5, shimmerPosition + 0.5),
                          colors: [
                            Colors.grey[800]!,
                            Colors.grey[700]!.withOpacity(0.5),
                            Colors.grey[800]!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(shimmerPosition - 0.5, 0),
                              end: Alignment(shimmerPosition + 0.5, 0),
                              colors: [
                                Colors.grey[800]!,
                                Colors.grey[700]!.withOpacity(0.5),
                                Colors.grey[800]!,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(shimmerPosition - 0.5, 0),
                                  end: Alignment(shimmerPosition + 0.5, 0),
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[700]!.withOpacity(0.5),
                                    Colors.grey[800]!,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(shimmerPosition - 0.5, 0),
                                  end: Alignment(shimmerPosition + 0.5, 0),
                                  colors: [
                                    Colors.grey[800]!,
                                    Colors.grey[700]!.withOpacity(0.5),
                                    Colors.grey[800]!,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPreviewWidget({required this.videoUrl});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..setLooping(true)
        ..setVolume(0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _initialized = true);
        _controller!.play();
      }
    } catch (e) {
      debugPrint('Video preview initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !_initialized || _controller == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.videocam,
            color: Colors.white38,
            size: 40,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
