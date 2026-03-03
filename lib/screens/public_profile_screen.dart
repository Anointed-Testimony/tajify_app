import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'shorts_player_screen.dart';

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
  static const int _pageSize = 100;
  bool _isFollowing = false;
  bool _followLoading = false;
  int? _currentUserId;
  // Tabs like web: Shorts | Tube Max | Articles
  int _profileTabIndex = 0;
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
      if (_hasMorePosts && !_loadingMorePosts && !_loadingPosts) {
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
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading current user: $e');
    }
    // Always load profile regardless of current user status
    await _loadProfile();
    await _loadStats();
    await _loadPosts();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await _apiService.get('/profile/${widget.username}');
      if (response.statusCode == 200) {
        final data = response.data['data'] ?? response.data;
        setState(() {
          _profile = data;
          if (data.containsKey('is_following')) {
            _isFollowing = _toBool(data['is_following']) ?? false;
          } else {
            _isFollowing = false;
            _checkFollowStatus();
          }
        });
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading profile: $e');
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
      final response = await _apiService.get('/stats/user/${widget.username}');
      if (response.statusCode == 200) {
        Map<String, dynamic>? statsData;
        if (response.data['success'] == true && response.data['data'] != null) {
          statsData = response.data['data'];
        } else if (response.data['followers_count'] != null) {
          statsData = response.data;
        } else if (response.data is Map<String, dynamic>) {
          statsData = response.data;
        }
        
        if (statsData != null) {
          setState(() {
            _stats = statsData;
          });
        }
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error loading stats: $e');
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
    setState(() => _followLoading = true);
    try {
      final userId = _profile!['id'];
      final response = await _apiService.toggleFollowUser(userId);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _isFollowing = data['following'] ?? !_isFollowing;
        });
      } else {
        setState(() => _isFollowing = !_isFollowing);
      }
    } catch (e) {
      print('[PUBLIC PROFILE] Error toggling follow: $e');
    } finally {
      setState(() => _followLoading = false);
    }
  }

  String _getUserInitial(Map<String, dynamic>? user) {
    if (user == null) return 'U';
    final name = user['name']?.toString() ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _getUserAvatar(Map<String, dynamic>? user) {
    if (user == null) return null;
    return user['profile_avatar']?.toString() ?? user['avatar']?.toString();
  }

  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  String? _getPostThumbnail(Map<String, dynamic> post) {
    final mediaFiles = post['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final media = mediaFiles.first;
      final thumb = media['thumbnail_path'] ?? media['thumbnail_url'] ?? media['thumbnail'] ?? media['snippet_thumbnail'];
      if (thumb is String && thumb.isNotEmpty) return thumb;
    }
    final fallback = post['thumbnail'] ?? post['thumbnail_url'] ?? post['snippet_thumbnail'] ?? post['cover_image'];
    return (fallback is String && fallback.isNotEmpty) ? fallback : null;
  }

  bool _isVideoPost(Map<String, dynamic> post) {
    final postType = post['post_type']?.toString().toLowerCase() ?? '';
    if (['tube_short', 'tube_max', 'tube_prime', 'reel'].contains(postType)) return true;
    final mediaType = post['media_type']?.toString().toLowerCase() ?? '';
    if (mediaType.contains('video')) return true;
    return false;
  }

  List<Map<String, dynamic>> _getVideoPosts() {
    return _posts.where((post) => _isVideoPost(post)).toList();
  }

  List<Map<String, dynamic>> _getShortsPosts() {
    return _posts.where((p) {
      final t = p['post_type'] ?? p['type'];
      if (t == 'article') return false;
      if (t == 'reel' || t == 'tube_short' || p['is_reel'] == true) return true;
      if (t == 'tube_max' || t == 'tube_prime' || t == 'video' || p['is_long'] == true) return false;
      final duration = (p['media_files'] is List && (p['media_files'] as List).isNotEmpty)
          ? ((p['media_files'][0] as Map<String, dynamic>?)?['duration'])
          : null;
      final d = duration is num ? duration.toDouble() : (duration != null ? double.tryParse(duration.toString()) : null);
      return d != null && d <= 60;
    }).cast<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _getTubeMaxPosts() {
    return _posts.where((p) {
      final t = p['post_type'] ?? p['type'];
      if (t == 'article') return false;
      if (t == 'tube_max' || t == 'tube_prime' || t == 'video' || p['is_long'] == true) return true;
      if (t == 'reel' || t == 'tube_short' || p['is_reel'] == true) return false;
      final duration = (p['media_files'] is List && (p['media_files'] as List).isNotEmpty)
          ? ((p['media_files'][0] as Map<String, dynamic>?)?['duration'])
          : null;
      final d = duration is num ? duration.toDouble() : (duration != null ? double.tryParse(duration.toString()) : null);
      return d != null && d > 60;
    }).cast<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _getBlogsPosts() {
    return _posts.where((p) => (p['post_type'] ?? p['type']) == 'article').cast<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _getPostsForCurrentTab() {
    switch (_profileTabIndex) {
      case 1: return _getTubeMaxPosts();
      case 2: return _getBlogsPosts();
      default: return _getShortsPosts();
    }
  }

  void _openTubePlayerFromList(List<Map<String, dynamic>> tabPosts, int indexInTab) {
    if (tabPosts.isEmpty || indexInTab >= tabPosts.length) return;
    final post = tabPosts[indexInTab];
    if (!_isVideoPost(post)) return;
    final videoPosts = _getVideoPosts();
    final videoIndex = videoPosts.indexWhere((p) => (p['id'] ?? p['_id']) == (post['id'] ?? post['_id']));
    if (videoIndex == -1) return;
    context.push('/tube-player', extra: {
      'videos': videoPosts,
      'initialIndex': videoIndex,
    });
  }

  Widget _profileTab(String label, int index) {
    final isActive = _profileTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _profileTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: isActive ? const Border(bottom: BorderSide(color: Color(0xFFEA580C), width: 2)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFEA580C) : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredPosts() {
    if (_profileTabIndex == 0) {
        return _getShortsPosts();
    } else if (_profileTabIndex == 1) {
        return _getTubeMaxPosts();
    } else {
        return _getBlogsPosts();
    }
  }

  void _openTubePlayer(int index) {
    final filtered = _getFilteredPosts();
    if (index >= filtered.length) return;
    final post = filtered[index];
    if (_isVideoPost(post)) {
      _openTubePlayerFromList(filtered, index);
    } else if (_profileTabIndex == 2) {
      final postId = post['id'] ?? post['_id'];
      context.push('/blog/${post['uuid'] ?? postId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: IconThemeData(color: Colors.white)),
        body: Center(child: Text('User not found', style: TextStyle(color: Colors.white))),
      );
    }

    final avatar = _getUserAvatar(_profile);
    final name = _profile!['name']?.toString() ?? 'Unknown User';
    final username = _profile!['username']?.toString() ?? '@user';
    final bio = _profile!['bio']?.toString() ?? '';
    
    final followersCount = _extractIntValue(_stats?['followers_count']) ?? 0;
    final followingCount = _extractIntValue(_stats?['following_count']) ?? 0;
    final postsCount = _extractIntValue(_stats?['posts_count']) ?? 0;
    final likesCount = _extractIntValue(_stats?['likes_count']) ?? 0;
    
    bool isOwnProfile = false;
    if (_currentUserId != null) {
      final profileId = _extractIntValue(_profile!['id']);
      isOwnProfile = profileId != null && profileId == _currentUserId;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Banner & Header
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    // Banner
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Color(0xFF171717),
                      child: Stack(
                        children: [
                           Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFEA580C).withOpacity(0.2),
                                  Colors.black,
                                  Color(0xFF1E3A8A).withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: -50, right: -50,
                            child: Container(
                              width: 200, height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF59E0B).withOpacity(0.1),
                                boxShadow: [BoxShadow(color: Color(0xFFF59E0B).withOpacity(0.2), blurRadius: 100, spreadRadius: 20)],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -50, left: -50,
                            child: Container(
                              width: 300, height: 300,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF3B82F6).withOpacity(0.1),
                                boxShadow: [BoxShadow(color: Color(0xFF3B82F6).withOpacity(0.1), blurRadius: 100, spreadRadius: 20)],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50, left: 16,
                            child: GestureDetector(
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/connect');
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Profile Content
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            SizedBox(height: 60), 
                            Row(
                              children: [
                                Flexible(child: Text(name, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                SizedBox(width: 8),
                                if (_profile!['is_verified'] == true) Icon(Icons.check_circle, color: Color(0xFFF59E0B), size: 20),
                              ],
                            ),
                            Text('@$username', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStat('Posts', postsCount),
                                _buildStat('Followers', followersCount),
                                _buildStat('Following', followingCount),
                                _buildStat('Likes', likesCount),
                              ],
                            ),
                            SizedBox(height: 16),
                            if (bio.isNotEmpty) Text(bio, style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.4)),
                            SizedBox(height: 24),
                             if (!isOwnProfile)
                               Row(
                                 children: [
                                   Expanded(
                                     child: GestureDetector(
                                       onTap: _followLoading ? null : _toggleFollow,
                                       child: Container(
                                         height: 48,
                                         decoration: BoxDecoration(
                                            gradient: _isFollowing 
                                                ? null 
                                                : LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
                                            borderRadius: BorderRadius.circular(30),
                                            color: _isFollowing ? Colors.white.withOpacity(0.1) : null,
                                            border: _isFollowing ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
                                         ),
                                         alignment: Alignment.center,
                                         child: _followLoading 
                                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _isFollowing ? Colors.white : Colors.black))
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(_isFollowing ? Icons.person_remove : Icons.person_add, color: _isFollowing ? Colors.white : Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  _isFollowing ? 'Following' : 'Follow',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16
                                                  ),
                                                ),
                                              ],
                                            ),
                                       ),
                                     ),
                                   ),
                                   SizedBox(width: 12),
                                   GestureDetector(
                                      onTap: () => context.push('/messages'),
                                      child: Container(
                                          height: 48, width: 50,
                                          decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(color: Colors.white.withOpacity(0.2))
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(Icons.message_rounded, color: Colors.white, size: 22)
                                      ),
                                   ),
                                 ],
                               ),
                            SizedBox(height: 30),
                        ],
                      ),
                    )
                  ],
                ),
                Positioned(
                  top: 140, left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0xFFEA580C).withOpacity(0.3), blurRadius: 20, spreadRadius: 0)],
                      border: Border.all(color: Color(0xFF171717), width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF262626),
                      backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                      child: (avatar == null || avatar.isEmpty) ? Text(_getUserInitial(_profile), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)) : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
              child: Row(
                children: [
                  _profileTab('Shorts', 0),
                  SizedBox(width: 12),
                  _profileTab('Tube Max', 1),
                  SizedBox(width: 12),
                  _profileTab('Articles', 2),
                ],
              ),
            ),
          ),
          
          SliverPadding(
            padding: EdgeInsets.only(top: 16),
            sliver: _buildProfileTabGrid(),
          ),
          
           if (_loadingMorePosts)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFEA580C))),
              ),
            ),
            
           if (!_hasMorePosts && !_loadingPosts && _posts.isNotEmpty)
             SliverToBoxAdapter(
               child: Padding(
                 padding: EdgeInsets.all(30),
                 child: Center(child: Text('No more posts', style: TextStyle(color: Colors.white54))),
               ),
             )
        ],
      ),
    );
  }

  Widget _buildProfileTabGrid() {
    final tabPosts = _getPostsForCurrentTab();
    if (tabPosts.isEmpty && !_loadingMorePosts) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              _profileTabIndex == 0 ? 'No Shorts yet' : (_profileTabIndex == 1 ? 'No long videos yet' : 'No articles yet'),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= tabPosts.length) {
              if (_loadingMorePosts && _profileTabIndex == 0) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C))),
                  ),
                );
              }
              return const SizedBox.shrink();
            }
            final post = tabPosts[index];
            final thumbnail = _getPostThumbnail(post);
            final isVideo = _isVideoPost(post);
            final isArticle = (post['post_type'] ?? post['type']) == 'article';
            final postId = post['id'] ?? post['_id'];
            return GestureDetector(
              onTap: isVideo
                  ? () => _openTubePlayerFromList(tabPosts, index)
                  : (isArticle ? () => context.push('/blog/${post['uuid'] ?? postId}') : null),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail != null && thumbnail.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Icon(isArticle ? Icons.article : Icons.video_library_outlined, color: Colors.grey, size: 32)),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Icon(isArticle ? Icons.article : Icons.video_library_outlined, color: Colors.grey, size: 32)),
                        ),
                  if (isVideo)
                    const Positioned.fill(child: Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 36))),
                ],
              ),
            );
          },
          childCount: tabPosts.length + (_loadingMorePosts && _profileTabIndex == 0 ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
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
}
