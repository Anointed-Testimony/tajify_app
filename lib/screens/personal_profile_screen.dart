import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _updating = false;
  bool _uploadingAvatar = false;
  bool _loadingPosts = false;
  bool _loadingMorePosts = false;
  bool _hasMorePosts = true;
  int _currentPage = 1;
  static const int _pageSize = 12;
  int? _currentUserId;
  final ScrollController _scrollController = ScrollController();
  
  // Edit form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  
  bool _isEditing = false;
  File? _selectedAvatar;

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
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200 pixels of bottom
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
      
      if (_currentUserId != null) {
        await _loadProfile();
        await _loadStats();
        await _loadPosts();
      }
    } catch (e) {
      print('[PROFILE] Error loading current user: $e');
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
      final response = await _apiService.getProfile();
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profileData = response.data['data'];
        setState(() {
          _profile = profileData;
          _nameController.text = profileData['name']?.toString() ?? '';
          _usernameController.text = profileData['username']?.toString() ?? '';
          _emailController.text = profileData['email']?.toString() ?? '';
          _phoneController.text = profileData['phone']?.toString() ?? '';
          _bioController.text = profileData['bio']?.toString() ?? '';
          _dateOfBirthController.text = profileData['date_of_birth']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('[PROFILE] Error loading profile: $e');
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

  Future<void> _loadStats() async {
    try {
      final response = await _apiService.getProfileStats();
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _stats = response.data['data'];
        });
      }
    } catch (e) {
      print('[PROFILE] Error loading stats: $e');
    }
  }

  int? _extractIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (_currentUserId == null) return;

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
        userId: _currentUserId,
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
      print('[PROFILE] Error loading posts: $e');
      if (mounted && !loadMore) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load posts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedAvatar = File(image.path);
        });
      }
    } catch (e) {
      print('[PROFILE] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedAvatar == null) return;
    
    setState(() {
      _uploadingAvatar = true;
    });
    
    try {
      final response = await _apiService.uploadAvatar(_selectedAvatar!);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final avatarUrl = response.data['data']['profile_avatar'];
        setState(() {
          _profile?['profile_avatar'] = avatarUrl;
          _selectedAvatar = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload profile to get updated data
        _loadProfile();
      }
    } catch (e) {
      print('[PROFILE] Error uploading avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload avatar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _uploadingAvatar = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _updating = true;
    });
    
    try {
      // Upload avatar first if selected
      if (_selectedAvatar != null) {
        await _uploadAvatar();
      }
      
      // Update profile
      final response = await _apiService.updateProfile(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        dateOfBirth: _dateOfBirthController.text.trim().isNotEmpty ? _dateOfBirthController.text.trim() : null,
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _isEditing = false;
          _selectedAvatar = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload profile
        _loadProfile();
      }
    } catch (e) {
      print('[PROFILE] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _updating = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedAvatar = null;
      // Reset form fields
      if (_profile != null) {
        _nameController.text = _profile!['name']?.toString() ?? '';
        _usernameController.text = _profile!['username']?.toString() ?? '';
        _emailController.text = _profile!['email']?.toString() ?? '';
        _phoneController.text = _profile!['phone']?.toString() ?? '';
        _bioController.text = _profile!['bio']?.toString() ?? '';
        _dateOfBirthController.text = _profile!['date_of_birth']?.toString() ?? '';
      }
    });
  }

  Future<void> _deletePost(int postId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Post',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _apiService.deletePost(postId);
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _posts.removeWhere((post) => post['id'] == postId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Reload stats to update post count
        _loadStats();
      }
    } catch (e) {
      print('[PROFILE] Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _handleGoLive() {
    context.push('/go-live');
  }

  String _getUserInitial() {
    final name = _profile?['name']?.toString() ?? '';
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
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
    final postType = post['post_type'];
    if (postType is Map<String, dynamic>) {
      final typeName = postType['name']?.toString().toLowerCase() ?? '';
      return typeName == 'tube_short' || typeName == 'tube_max' || typeName == 'tube_prime';
    }
    final typeName = postType?.toString().toLowerCase() ?? '';
    return typeName == 'tube_short' || typeName == 'tube_max' || typeName == 'tube_prime';
  }

  bool _isAudioPost(Map<String, dynamic> post) {
    final postType = post['post_type'];
    if (postType is Map<String, dynamic>) {
      final typeName = postType['name']?.toString().toLowerCase() ?? '';
      return typeName.contains('audio') || typeName == 'audio';
    }
    final typeName = postType?.toString().toLowerCase() ?? '';
    if (typeName.contains('audio')) return true;
    
    // Also check media files
    final mediaFiles = post['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      final media = mediaFiles.first;
      final fileType = media['file_type']?.toString().toLowerCase() ?? '';
      final mediaType = media['media_type']?.toString().toLowerCase() ?? '';
      return fileType.contains('audio') || mediaType.contains('audio');
    }
    return false;
  }

  List<Map<String, dynamic>> _getVideoPosts() {
    return _posts.where((post) => _isVideoPost(post)).toList();
  }

  void _openTubePlayer(int postIndex) {
    final videoPosts = _getVideoPosts();
    if (videoPosts.isEmpty) return;
    
    // Find the index of the clicked post in the video posts list
    final clickedPost = _posts[postIndex];
    final videoIndex = videoPosts.indexWhere((p) => p['id'] == clickedPost['id']);
    
    if (videoIndex == -1) return;
    
    context.push('/tube-player', extra: {
      'videos': videoPosts,
      'initialIndex': videoIndex,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF0F0F0F),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (!_isEditing)
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                    onPressed: _openProfileMenu,
                  ),
                ),
                const SizedBox(width: 10),
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: _handleGoLive,
                    icon: const Icon(Icons.wifi_tethering, color: Colors.black, size: 16),
                    label: const Text(
                      'Go Live',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ),
              ],
            )
          else
            Row(
              children: [
                TextButton(
                  onPressed: _updating ? null : _cancelEdit,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextButton(
                    onPressed: _updating ? null : _saveProfile,
                    child: _updating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
              ),
            )
          : _profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load profile',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadProfile();
                    await _loadStats();
                    await _loadPosts();
                  },
                  color: const Color(0xFFFFB800),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Profile Header
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF1A1A1A),
                                const Color(0xFF0F0F0F),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              // Avatar
                              Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.4),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: _selectedAvatar != null ||
                                            (_profile!['profile_avatar'] != null &&
                                             _profile!['profile_avatar'].toString().isNotEmpty)
                                        ? CircleAvatar(
                                            radius: 60,
                                            backgroundColor: Colors.transparent,
                                            backgroundImage: _selectedAvatar != null
                                                ? FileImage(_selectedAvatar!)
                                                : NetworkImage(_profile!['profile_avatar'].toString()) as ImageProvider,
                                            onBackgroundImageError: (exception, stackTrace) {
                                              print('[PROFILE] Error loading avatar: $exception');
                                            },
                                          )
                                        : CircleAvatar(
                                            radius: 60,
                                            backgroundColor: Colors.transparent,
                                            child: Text(
                                              _getUserInitial(),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 48,
                                              ),
                                            ),
                                          ),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF0F0F0F),
                                            width: 3,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: _uploadingAvatar
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                                  ),
                                                )
                                              : const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Name and Username
                              Text(
                                _profile!['name']?.toString() ?? 'No Name',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${_profile!['username']?.toString() ?? 'username'}',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                              if (_profile!['bio'] != null && _profile!['bio'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _profile!['bio'].toString(),
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      // Stats Section
                      if (_stats != null)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Posts',
                                  (_extractIntValue(_stats?['total_posts']) ?? 0).toString(),
                                  Icons.video_library_outlined,
                                ),
                                _buildStatItem(
                                  'Followers',
                                  (_extractIntValue(_stats?['followers']) ?? 0).toString(),
                                  Icons.people_outline,
                                ),
                                _buildStatItem(
                                  'Following',
                                  (_extractIntValue(_stats?['following']) ?? 0).toString(),
                                  Icons.person_add_outlined,
                                ),
                                _buildStatItem(
                                  'Likes',
                                  (_extractIntValue(_stats?['total_likes']) ?? 0).toString(),
                                  Icons.favorite_outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Profile Details Section
                      if (_isEditing)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Profile Information',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildEditableField(
                                  label: 'Name',
                                  controller: _nameController,
                                  icon: Icons.person_outline,
                                  enabled: _isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  label: 'Username',
                                  controller: _usernameController,
                                  icon: Icons.alternate_email,
                                  enabled: _isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  label: 'Email',
                                  controller: _emailController,
                                  icon: Icons.email_outlined,
                                  enabled: _isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  label: 'Phone',
                                  controller: _phoneController,
                                  icon: Icons.phone_outlined,
                                  enabled: _isEditing,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  label: 'Bio',
                                  controller: _bioController,
                                  icon: Icons.description_outlined,
                                  enabled: _isEditing,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildEditableField(
                                  label: 'Date of Birth',
                                  controller: _dateOfBirthController,
                                  icon: Icons.calendar_today_outlined,
                                  enabled: _isEditing,
                                  onTap: _isEditing
                                      ? () async {
                                          final DateTime? picked = await showDatePicker(
                                            context: context,
                                            initialDate: _dateOfBirthController.text.isNotEmpty
                                                ? DateTime.tryParse(_dateOfBirthController.text) ?? DateTime.now()
                                                : DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                            _dateOfBirthController.text = picked.toIso8601String().split('T')[0];
                                          }
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // My Posts Section
                      if (!_isEditing)
                        _loadingPosts
                            ? const SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                                    ),
                                  ),
                                ),
                              )
                            : _posts.isEmpty
                                ? SliverToBoxAdapter(
                                    child: Container(
                                      margin: const EdgeInsets.all(16),
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.video_library_outlined,
                                              color: Colors.grey,
                                              size: 48,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'No posts yet',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : SliverPadding(
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
                                          // Show loading indicator at the end
                                          if (index >= _posts.length) {
                                            if (_loadingMorePosts) {
                                              return const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          }
                                            final post = _posts[index];
                                            final thumbnail = _getPostThumbnail(post);
                                            final isAudio = _isAudioPost(post);
                                            final isVideo = _isVideoPost(post);
                                            
                                            return GestureDetector(
                                              onTap: isVideo ? () => _openTubePlayer(index) : null,
                                              onLongPress: () => _deletePost(post['id']),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  thumbnail != null && thumbnail.isNotEmpty
                                                      ? ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Image.network(
                                                            thumbnail,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors.grey[800],
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Center(
                                                                  child: Icon(
                                                                    isAudio ? Icons.music_note : Icons.video_library_outlined,
                                                                    color: Colors.grey,
                                                                    size: 32,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      : Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[800],
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Center(
                                                            child: Icon(
                                                              isAudio ? Icons.music_note : Icons.video_library_outlined,
                                                              color: Colors.grey,
                                                              size: 32,
                                                            ),
                                                          ),
                                                        ),
                                                  if (isAudio)
                                                    Positioned(
                                                      bottom: 4,
                                                      left: 4,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.6),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Icon(
                                                          Icons.music_note,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: GestureDetector(
                                                      onTap: () => _deletePost(post['id']),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.withOpacity(0.8),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          childCount: _posts.length + (_loadingMorePosts ? 1 : 0),
                                        ),
                                      ),
                                    ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFB800), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[400], size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onTap: onTap,
          readOnly: onTap != null,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFFB800),
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

}
