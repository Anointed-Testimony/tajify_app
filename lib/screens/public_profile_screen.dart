import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'tube_player_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String username;

  const PublicProfileScreen({
    super.key,
    required this.username,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _loadingPosts = false;
  bool _loadingMorePosts = false;
  bool _hasMorePosts = true;
  int _currentPage = 1;
  static const int _pageSize = 12;
  bool _isFollowing = false;
  bool _followLoading = false;
  int? _currentUserId;
  String _activeTab = 'posts'; // 'posts' or 'private'
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCurrentUserId();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200 pixels of bottom
      if (_hasMorePosts && !_loadingMorePosts && !_loadingPosts && _activeTab == 'posts') {
        _loadPosts(loadMore: true);
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      setState(() {
        _currentUserId = parsedId;
      });

      if (_currentUserId != null) {
        await _loadProfile();
        await _loadStats();
        await _loadPosts();
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading current user: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      // Get user profile by username
      final response = await _apiService.get('/profile/${widget.username}');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        setState(() {
          _profile = data;
          // Check if follow status is in profile data
          if (data.containsKey('is_following')) {
            _isFollowing = _toBool(data['is_following']) ?? false;
            print('[DEBUG] Public Profile - Follow status from profile data: $_isFollowing');
          } else {
            // If not found, check from API
            _isFollowing = false;
            _checkFollowStatus();
          }
        });
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_profile == null || widget.username.isEmpty) return;
    
    try {
      final response = await _apiService.checkFollowStatus(widget.username);
      if (mounted && response.data['success'] == true) {
        final data = response.data['data'];
        final isFollowing = data['following'] ?? false;
        setState(() {
          _isFollowing = isFollowing;
        });
        print('[DEBUG] Public Profile - Follow status from API: $isFollowing');
      }
    } catch (e) {
      print('[DEBUG] Public Profile - Error checking follow status: $e');
    }
  }

  bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true' || value == '1') return true;
      if (value.toLowerCase() == 'false' || value == '0') return false;
    }
    return null;
  }

  Future<void> _loadStats() async {
    if (_profile == null) return;

    try {
      // Use username-based endpoint like web version
      final response = await _apiService.get('/stats/user/${widget.username}');
      print('[PUBLIC PROFILE] Stats response status: ${response.statusCode}');
      print('[PUBLIC PROFILE] Stats response data: ${response.data}');
      
      if (response.statusCode == 200) {
        Map<String, dynamic>? statsData;
        
        // Handle different response structures like web version
        if (response.data['success'] == true && response.data['data'] != null) {
          // Format: {success: true, data: {...}}
          statsData = response.data['data'];
        } else if (response.data['followers_count'] != null || 
                   response.data['following_count'] != null || 
                   response.data['likes_count'] != null) {
          // Direct stats response: {followers_count: X, following_count: Y, ...}
          statsData = response.data;
        } else if (response.data is Map<String, dynamic>) {
          // Try response.data directly
          statsData = response.data;
        }
        
        print('[PUBLIC PROFILE] Parsed stats: $statsData');
        
        if (statsData != null) {
          setState(() {
            _stats = statsData;
          });
        }
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading stats: $e');
      print('[PUBLIC PROFILE] Error stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (_profile == null) return;

    if (loadMore) {
      if (_loadingMorePosts || !_hasMorePosts) return;
    } else {
      if (_loadingPosts) return;
      _hasMorePosts = true;
      _currentPage = 1;
    }

    final targetPage = loadMore ? _currentPage + 1 : 1;

    setState(() {
      if (loadMore) {
        _loadingMorePosts = true;
      } else {
        _loadingPosts = true;
      }
    });

    try {
      final response = await _apiService.getPosts(
        userId: _profile!['id'],
        page: targetPage,
        limit: _pageSize,
      );
      
      if (response.statusCode == 200) {
        List<dynamic> postsList = [];
        if (response.data['success'] == true && response.data['data'] != null) {
          final data = response.data['data'];
          if (data is Map<String, dynamic> && data['data'] is List) {
            postsList = data['data'];
          } else if (data is List) {
            postsList = data;
          }
        } else if (response.data is List) {
          postsList = response.data;
        }

        final newPosts = postsList
            .whereType<Map<String, dynamic>>()
            .map((post) => Map<String, dynamic>.from(post))
            .toList();

        setState(() {
          if (loadMore) {
            _posts.addAll(newPosts);
          } else {
            _posts = newPosts;
          }
          _currentPage = targetPage;
          _hasMorePosts = newPosts.length >= _pageSize;
        });
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading posts: $e');
    } finally {
      setState(() {
        if (loadMore) {
          _loadingMorePosts = false;
        } else {
          _loadingPosts = false;
        }
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _followLoading) return;

    setState(() {
      _followLoading = true;
    });

    try {
      final userId = _profile!['id'];
      final response = await _apiService.toggleFollowUser(userId);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _isFollowing = data['following'] ?? !_isFollowing;
        });
      } else {
        // Fallback to toggle if response doesn't have following status
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to follow/unfollow: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _followLoading = false;
      });
    }
  }

  String _getUserInitial(Map<String, dynamic>? user) {
    if (user == null) return 'U';
    final name = user['name']?.toString() ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _getUserAvatar(Map<String, dynamic>? user) {
    if (user == null) return null;
    return user['profile_avatar']?.toString() ?? 
           user['avatar']?.toString();
  }

  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is double) return value.toInt();
    return null;
  }

  String? _getPostThumbnail(Map<String, dynamic> post) {
    final mediaFiles = post['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final media = mediaFiles.first;
      // Check for thumbnail in media file
      final thumb = media['thumbnail_path'] ?? 
                   media['thumbnail_url'] ?? 
                   media['thumbnail'] ??
                   media['snippet_thumbnail'];
      if (thumb is String && thumb.isNotEmpty) {
        return thumb;
      }
      // For audio posts, check for cover image or album art
      final fileType = media['file_type']?.toString().toLowerCase() ?? '';
      final mediaType = media['media_type']?.toString().toLowerCase() ?? '';
      if (fileType.contains('audio') || mediaType.contains('audio')) {
        final audioThumb = media['cover_image'] ?? 
                          media['album_art'] ?? 
                          media['artwork'] ??
                          media['cover'];
        if (audioThumb is String && audioThumb.isNotEmpty) {
          return audioThumb;
        }
      }
    }
    // Fallback to post-level thumbnail fields
    final fallback = post['thumbnail'] ?? 
                    post['thumbnail_url'] ?? 
                    post['snippet_thumbnail'] ??
                    post['cover_image'];
    if (fallback is String && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  bool _isVideoPost(Map<String, dynamic> post) {
    // Check post_type first (like personal profile screen)
    final postType = post['post_type'];
    if (postType is Map<String, dynamic>) {
      final typeName = postType['name']?.toString().toLowerCase() ?? '';
      if (typeName == 'tube_short' || typeName == 'tube_max' || typeName == 'tube_prime') {
        return true;
      }
    }
    final typeName = postType?.toString().toLowerCase() ?? '';
    if (typeName == 'tube_short' || typeName == 'tube_max' || typeName == 'tube_prime') {
      return true;
    }
    
    // Fallback to media_type check
    final mediaType = post['media_type']?.toString().toLowerCase() ?? '';
    if (mediaType.contains('video')) return true;
    
    // Check thumbnail URL for video indicators
    final thumbnail = _getPostThumbnail(post);
    if (thumbnail != null && (thumbnail.contains('tube_max') || 
                              thumbnail.contains('tube_prime') || 
                              thumbnail.contains('tube_short'))) {
      return true;
    }
    
    return false;
  }

  bool _isAudioPost(Map<String, dynamic> post) {
    final mediaType = post['media_type']?.toString().toLowerCase() ?? '';
    return mediaType.contains('audio');
  }

  List<Map<String, dynamic>> _getVideoPosts() {
    return _posts.where((post) => _isVideoPost(post)).toList();
  }

  void _openTubePlayer(int index) {
    final videoPosts = _getVideoPosts();
    if (index < videoPosts.length) {
      context.push('/tube-player', extra: {
        'videos': videoPosts,
        'initialIndex': index,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/connect');
              }
            },
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            ),
          ),
          child: const Center(
            child: Text(
              'User not found',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final avatar = _getUserAvatar(_profile);
    final name = _profile!['name']?.toString() ?? 'Unknown User';
    final username = _profile!['username']?.toString() ?? '@user';
    final bio = _profile!['bio']?.toString() ?? '';
    
    // Extract stats with proper type handling
    final followersCount = _extractIntValue(_stats?['followers_count']) ?? 0;
    final followingCount = _extractIntValue(_stats?['following_count']) ?? 0;
    final postsCount = _extractIntValue(_stats?['posts_count']) ?? 0; // Use total from stats, not loaded posts
    final likesCount = _extractIntValue(_stats?['likes_count']) ?? 0;
    
    // Check if this is the user's own profile - handle both int and string IDs
    bool isOwnProfile = false;
    if (_currentUserId != null && _profile != null) {
      final profileId = _extractIntValue(_profile!['id']);
      isOwnProfile = profileId != null && profileId == _currentUserId;
      print('[DEBUG] Public Profile - isOwnProfile check: currentUserId=$_currentUserId, profileId=$profileId, isOwnProfile=$isOwnProfile');
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/connect');
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: avatar != null && avatar.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                avatar,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFFB875FB),
                                    child: Text(
                                      _getUserInitial(_profile),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 36,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFB875FB),
                              child: Text(
                                _getUserInitial(_profile),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Name and Username
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats Row - 4 columns like web version
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Posts', postsCount.toString()),
                          _buildStatItem('Followers', followersCount.toString()),
                          _buildStatItem('Following', followingCount.toString()),
                          _buildStatItem('Total Likes', likesCount.toString()),
                        ],
                      ),
                    ),

                    // Bio
                    if (bio.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          bio,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    if (!isOwnProfile)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _isFollowing
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                                      ),
                                color: _isFollowing ? Colors.white.withOpacity(0.08) : null,
                                borderRadius: BorderRadius.circular(12),
                                border: _isFollowing
                                    ? Border.all(
                                        color: Colors.white.withOpacity(0.15),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _followLoading ? null : _toggleFollow,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    child: _followLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          )
                                        : Text(
                                            _isFollowing ? 'Following' : 'Follow',
                                            style: TextStyle(
                                              color: _isFollowing ? Colors.grey[300] : Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.go('/messages');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: const Icon(
                                    Icons.message,
                                    color: Colors.white,
                                    size: 20,
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
            ),

            // Tabs
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton('Posts', 'posts'),
                    ),
                    Expanded(
                      child: _buildTabButton('Private Channel', 'private'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),

            // Content
            if (_activeTab == 'posts')
              _loadingPosts
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                          ),
                        ),
                      ),
                    )
                  : _posts.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.grid_off,
                                    color: Colors.grey[600],
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No posts yet',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                // Show loading indicator at the end
                                if (index >= _posts.length) {
                                  if (_loadingMorePosts) {
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }

                                final post = _posts[index];
                                final thumbnail = _getPostThumbnail(post);
                                final isVideo = _isVideoPost(post);
                                final isAudio = _isAudioPost(post);

                                return GestureDetector(
                                  onTap: () {
                                    if (isVideo) {
                                      final videoPosts = _getVideoPosts();
                                      if (videoPosts.isNotEmpty) {
                                        final videoIndex = videoPosts.indexWhere((p) => p['id'] == post['id']);
                                        if (videoIndex >= 0) {
                                          _openTubePlayer(videoIndex);
                                        }
                                      }
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (thumbnail != null && thumbnail.isNotEmpty)
                                            Image.network(
                                              thumbnail,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.white.withOpacity(0.05),
                                                  child: Icon(
                                                    isVideo
                                                        ? Icons.play_circle_outline
                                                        : isAudio
                                                            ? Icons.music_note
                                                            : Icons.image,
                                                    color: Colors.grey[600],
                                                    size: 32,
                                                  ),
                                                );
                                              },
                                            )
                                          else
                                            Container(
                                              color: Colors.white.withOpacity(0.05),
                                              child: Icon(
                                                isVideo
                                                    ? Icons.play_circle_outline
                                                    : isAudio
                                                        ? Icons.music_note
                                                        : Icons.image,
                                                color: Colors.grey[600],
                                                size: 32,
                                              ),
                                            ),
                                          if (isVideo)
                                            Container(
                                              color: Colors.black.withOpacity(0.3),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.play_circle_filled,
                                                  color: Colors.white,
                                                  size: 32,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _posts.length + (_loadingMorePosts ? 1 : 0),
                            ),
                          ),
                        )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Private Channel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "This user's private channel content is only available to subscribers.",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // TODO: Implement subscription
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                  child: const Text(
                                    'Subscribe to Access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, String tab) {
    final isActive = _activeTab == tab;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tab;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey[400],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

}

