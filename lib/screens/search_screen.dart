import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import 'tube_player_screen.dart';

enum SearchCategory { all, users, posts, blogs, communities }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  SearchCategory _selectedCategory = SearchCategory.all;
  String _searchQuery = '';
  bool _isSearching = false;
  
  // Search results
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _blogs = [];
  List<Map<String, dynamic>> _communities = [];
  
  // Posts by type
  List<Map<String, dynamic>> _shorts = [];
  List<Map<String, dynamic>> _max = [];
  List<Map<String, dynamic>> _prime = [];
  List<Map<String, dynamic>> _audio = [];
  
  // Loading states
  bool _usersLoading = false;
  bool _postsLoading = false;
  bool _blogsLoading = false;
  bool _communitiesLoading = false;
  
  // Error states
  String? _usersError;
  String? _postsError;
  String? _blogsError;
  String? _communitiesError;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      _searchQuery = query;
      if (query.isEmpty) {
        setState(() {
          _users = [];
          _posts = [];
          _blogs = [];
          _communities = [];
          _isSearching = false;
        });
      } else {
        _performSearch();
      }
    }
  }

  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });

        // Search based on selected category
    switch (_selectedCategory) {
      case SearchCategory.all:
        // For "all", we need to search and extract posts by type
        await Future.wait([
          _searchUsers(),
          _searchPosts(),
          _searchBlogs(),
          _searchCommunities(),
        ]);
        // Ensure posts by type are extracted (fallback if API didn't return grouped data)
        if (_shorts.isEmpty && _max.isEmpty && _prime.isEmpty && _audio.isEmpty) {
          _extractPostsByType();
        }
        break;
      case SearchCategory.users:
        await _searchUsers();
        break;
      case SearchCategory.posts:
        await _searchPosts();
        break;
      case SearchCategory.blogs:
        await _searchBlogs();
        break;
      case SearchCategory.communities:
        await _searchCommunities();
        break;
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _searchUsers() async {
    setState(() {
      _usersLoading = true;
      _usersError = null;
    });

    try {
      final response = await _apiService.search(_searchQuery, type: 'users');
      if (mounted) {
        if (response.data['success'] == true) {
          final data = response.data['data'];
          List<Map<String, dynamic>> users = [];
          if (data is Map<String, dynamic>) {
            if (data['users'] is List) {
              users = (data['users'] as List).whereType<Map<String, dynamic>>().map((u) => Map<String, dynamic>.from(u)).toList();
            } else if (data['data'] is List) {
              users = (data['data'] as List).whereType<Map<String, dynamic>>().map((u) => Map<String, dynamic>.from(u)).toList();
            }
          } else if (data is List) {
            users = data.whereType<Map<String, dynamic>>().map((u) => Map<String, dynamic>.from(u)).toList();
          }
          setState(() {
            _users = users;
            _usersLoading = false;
          });
        } else {
          throw Exception('Failed to search users');
        }
      }
    } catch (e) {
      print('[ERROR] Error searching users: $e');
      if (mounted) {
        setState(() {
          _usersError = 'Failed to load users';
          _usersLoading = false;
        });
      }
    }
  }

  Future<void> _searchPosts() async {
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });

    try {
      print('[SEARCH DEBUG] ========================================');
      print('[SEARCH DEBUG] Searching posts with query: "$_searchQuery"');
      final response = await _apiService.search(_searchQuery, type: 'posts');
      
      print('[SEARCH DEBUG] ========================================');
      print('[SEARCH DEBUG] Backend Response Received:');
      print('[SEARCH DEBUG] Full response.data (JSON):');
      try {
        // Convert to JSON string for better readability
        final encoder = JsonEncoder.withIndent('  ');
        final jsonString = encoder.convert(response.data);
        print('[SEARCH DEBUG] $jsonString');
      } catch (e) {
        print('[SEARCH DEBUG] Could not convert to JSON string: $e');
        print('[SEARCH DEBUG] Raw response.data: ${response.data}');
      }
      print('[SEARCH DEBUG] Response success: ${response.data['success']}');
      if (response.data['data'] != null) {
        print('[SEARCH DEBUG] Response data type: ${response.data['data'].runtimeType}');
        try {
          final encoder = JsonEncoder.withIndent('  ');
          final dataJson = encoder.convert(response.data['data']);
          print('[SEARCH DEBUG] Response data (full JSON):');
          print('[SEARCH DEBUG] $dataJson');
        } catch (e) {
          print('[SEARCH DEBUG] Response data (raw): ${response.data['data']}');
        }
      }
      
      if (mounted) {
        if (response.data['success'] == true) {
          final data = response.data['data'];
          print('[SEARCH DEBUG] ========================================');
          print('[SEARCH DEBUG] Processing response data...');
          print('[SEARCH DEBUG] Data keys: ${data is Map ? (data as Map<String, dynamic>).keys.toList() : 'N/A (not a Map)'}');
          
          List<Map<String, dynamic>> posts = [];
          Map<String, dynamic> postsByType = {};
          
          if (data is Map<String, dynamic>) {
            print('[SEARCH DEBUG] Data is Map<String, dynamic>');
            if (data['posts'] is List) {
              print('[SEARCH DEBUG] Found posts in data[\'posts\']: ${(data['posts'] as List).length} items');
              posts = (data['posts'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
            } else if (data['data'] is List) {
              print('[SEARCH DEBUG] Found posts in data[\'data\']: ${(data['data'] as List).length} items');
              posts = (data['data'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
            }
            
            // Extract posts by type
            if (data['posts_by_type'] is Map<String, dynamic>) {
              print('[SEARCH DEBUG] Found posts_by_type in response');
              postsByType = data['posts_by_type'] as Map<String, dynamic>;
              print('[SEARCH DEBUG] posts_by_type keys: ${postsByType.keys.toList()}');
              if (postsByType['shorts'] is List) {
                print('[SEARCH DEBUG] Shorts count: ${(postsByType['shorts'] as List).length}');
              }
              if (postsByType['max'] is List) {
                print('[SEARCH DEBUG] Max count: ${(postsByType['max'] as List).length}');
              }
              if (postsByType['prime'] is List) {
                print('[SEARCH DEBUG] Prime count: ${(postsByType['prime'] as List).length}');
              }
              if (postsByType['audio'] is List) {
                print('[SEARCH DEBUG] Audio count: ${(postsByType['audio'] as List).length}');
              }
            } else {
              print('[SEARCH DEBUG] No posts_by_type found in response');
            }
          } else if (data is List) {
            print('[SEARCH DEBUG] Data is List: ${data.length} items');
            posts = data.whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
          }
          
          print('[SEARCH DEBUG] Total posts extracted: ${posts.length}');
          if (posts.isNotEmpty) {
            print('[SEARCH DEBUG] First post sample:');
            print('[SEARCH DEBUG]   - ID: ${posts[0]['id']}');
            print('[SEARCH DEBUG]   - Title: ${posts[0]['title']}');
            print('[SEARCH DEBUG]   - Post Type: ${posts[0]['post_type']}');
            print('[SEARCH DEBUG]   - Media Files: ${posts[0]['media_files']}');
            if (posts[0]['media_files'] is List && (posts[0]['media_files'] as List).isNotEmpty) {
              final firstMedia = (posts[0]['media_files'] as List)[0];
              print('[SEARCH DEBUG]   - First Media File: $firstMedia');
              if (firstMedia is Map) {
                print('[SEARCH DEBUG]   - First Media File keys: ${firstMedia.keys.toList()}');
                print('[SEARCH DEBUG]   - First Media File thumbnail_path: ${firstMedia['thumbnail_path']}');
                print('[SEARCH DEBUG]   - First Media File thumbnail_url: ${firstMedia['thumbnail_url']}');
                print('[SEARCH DEBUG]   - First Media File thumbnail: ${firstMedia['thumbnail']}');
              }
            }
          }
          
          // Parse posts by type
          List<Map<String, dynamic>> shorts = [];
          List<Map<String, dynamic>> max = [];
          List<Map<String, dynamic>> prime = [];
          List<Map<String, dynamic>> audio = [];
          
          print('[SEARCH DEBUG] ========================================');
          print('[SEARCH DEBUG] Parsing posts by type...');
          if (postsByType.isNotEmpty) {
            print('[SEARCH DEBUG] postsByType is not empty, has ${postsByType.length} keys');
            if (postsByType['shorts'] is List) {
              shorts = (postsByType['shorts'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
              print('[SEARCH DEBUG] Parsed ${shorts.length} shorts');
            }
            if (postsByType['max'] is List) {
              max = (postsByType['max'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
              print('[SEARCH DEBUG] Parsed ${max.length} max');
            }
            if (postsByType['prime'] is List) {
              prime = (postsByType['prime'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
              print('[SEARCH DEBUG] Parsed ${prime.length} prime');
            }
            if (postsByType['audio'] is List) {
              audio = (postsByType['audio'] as List).whereType<Map<String, dynamic>>().map((p) => Map<String, dynamic>.from(p)).toList();
              print('[SEARCH DEBUG] Parsed ${audio.length} audio');
            }
          } else {
            print('[SEARCH DEBUG] postsByType is empty, will extract from posts list');
          }
          
          print('[SEARCH DEBUG] ========================================');
          print('[SEARCH DEBUG] Final counts:');
          print('[SEARCH DEBUG]   - Total posts: ${posts.length}');
          print('[SEARCH DEBUG]   - Shorts: ${shorts.length}');
          print('[SEARCH DEBUG]   - Max: ${max.length}');
          print('[SEARCH DEBUG]   - Prime: ${prime.length}');
          print('[SEARCH DEBUG]   - Audio: ${audio.length}');
          print('[SEARCH DEBUG] ========================================');
          
          setState(() {
            _posts = posts;
            _shorts = shorts;
            _max = max;
            _prime = prime;
            _audio = audio;
            _postsLoading = false;
          });
        } else {
          print('[SEARCH DEBUG] ========================================');
          print('[SEARCH DEBUG] ✗ Backend returned success: false');
          print('[SEARCH DEBUG] Response: ${response.data}');
          throw Exception('Failed to search posts');
        }
      }
    } catch (e, stackTrace) {
      print('[SEARCH DEBUG] ========================================');
      print('[SEARCH DEBUG] ✗ ERROR searching posts: $e');
      print('[SEARCH DEBUG] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _postsError = 'Failed to load posts';
          _postsLoading = false;
        });
      }
    }
  }

  Future<void> _searchBlogs() async {
    setState(() {
      _blogsLoading = true;
      _blogsError = null;
    });

    try {
      final response = await _apiService.search(_searchQuery, type: 'blogs');
      if (mounted) {
        if (response.data['success'] == true) {
          final data = response.data['data'];
          List<Map<String, dynamic>> blogs = [];
          if (data is Map<String, dynamic>) {
            if (data['blogs'] is List) {
              blogs = (data['blogs'] as List).whereType<Map<String, dynamic>>().map((b) => Map<String, dynamic>.from(b)).toList();
            } else if (data['data'] is List) {
              blogs = (data['data'] as List).whereType<Map<String, dynamic>>().map((b) => Map<String, dynamic>.from(b)).toList();
            }
          } else if (data is List) {
            blogs = data.whereType<Map<String, dynamic>>().map((b) => Map<String, dynamic>.from(b)).toList();
          }
          setState(() {
            _blogs = blogs;
            _blogsLoading = false;
          });
        } else {
          throw Exception('Failed to search blogs');
        }
      }
    } catch (e) {
      print('[ERROR] Error searching blogs: $e');
      if (mounted) {
        setState(() {
          _blogsError = 'Failed to load blogs';
          _blogsLoading = false;
        });
      }
    }
  }

  void _extractPostsByType() {
    // Group posts by type from _posts
    _shorts = [];
    _max = [];
    _prime = [];
    _audio = [];
    
    for (var post in _posts) {
      final postType = post['post_type']?.toString().toLowerCase() ?? '';
      if (postType.contains('short')) {
        _shorts.add(post);
      } else if (postType.contains('max') && !postType.contains('prime')) {
        _max.add(post);
      } else if (postType.contains('prime')) {
        _prime.add(post);
      } else if (postType.contains('audio')) {
        _audio.add(post);
      }
    }
  }

  Future<void> _searchCommunities() async {
    setState(() {
      _communitiesLoading = true;
      _communitiesError = null;
    });

    try {
      final response = await _apiService.search(_searchQuery, type: 'communities');
      if (mounted) {
        if (response.data['success'] == true) {
          final data = response.data['data'];
          List<Map<String, dynamic>> communities = [];
          if (data is Map<String, dynamic>) {
            if (data['communities'] is List) {
              communities = (data['communities'] as List).whereType<Map<String, dynamic>>().map((c) => Map<String, dynamic>.from(c)).toList();
            } else if (data['data'] is List) {
              communities = (data['data'] as List).whereType<Map<String, dynamic>>().map((c) => Map<String, dynamic>.from(c)).toList();
            }
          } else if (data is List) {
            communities = data.whereType<Map<String, dynamic>>().map((c) => Map<String, dynamic>.from(c)).toList();
          }
          setState(() {
            _communities = communities;
            _communitiesLoading = false;
          });
        } else {
          throw Exception('Failed to search communities');
        }
      }
    } catch (e) {
      print('[ERROR] Error searching communities: $e');
      if (mounted) {
        setState(() {
          _communitiesError = 'Failed to load communities';
          _communitiesLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar (TikTok style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _users = [];
                          _posts = [];
                          _blogs = [];
                          _communities = [];
                        });
                      },
                    ),
                ],
              ),
            ),
            // Category Tabs
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
                ),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _buildCategoryTab('All', SearchCategory.all),
                  _buildCategoryTab('Users', SearchCategory.users),
                  _buildCategoryTab('Posts', SearchCategory.posts),
                  _buildCategoryTab('Blogs', SearchCategory.blogs),
                  _buildCategoryTab('Communities', SearchCategory.communities),
                ],
              ),
            ),
            // Search Results
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String label, SearchCategory category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
        if (_searchQuery.isNotEmpty) {
          _performSearch();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState('Start typing to search...');
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }

    switch (_selectedCategory) {
      case SearchCategory.all:
        return _buildAllResults();
      case SearchCategory.users:
        return _buildUsersResults();
      case SearchCategory.posts:
        return _buildPostsResults();
      case SearchCategory.blogs:
        return _buildBlogsResults();
      case SearchCategory.communities:
        return _buildCommunitiesResults();
    }
  }

  Widget _buildAllResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_users.isNotEmpty) ...[
            _buildSectionHeader('Users', _users.length),
            _buildUsersHorizontalList(_users),
          ],
          if (_shorts.isNotEmpty) ...[
            _buildSectionHeader('Shorts', _shorts.length),
            _buildPostsHorizontalList(_shorts),
          ],
          if (_max.isNotEmpty) ...[
            _buildSectionHeader('Max', _max.length),
            _buildPostsHorizontalList(_max),
          ],
          if (_prime.isNotEmpty) ...[
            _buildSectionHeader('Prime', _prime.length),
            _buildPostsHorizontalList(_prime),
          ],
          if (_audio.isNotEmpty) ...[
            _buildSectionHeader('Audio', _audio.length),
            _buildPostsHorizontalList(_audio),
          ],
          if (_blogs.isNotEmpty) ...[
            _buildSectionHeader('Blogs', _blogs.length),
            _buildBlogsHorizontalList(_blogs),
          ],
          if (_communities.isNotEmpty) ...[
            _buildSectionHeader('Communities', _communities.length),
            _buildCommunitiesHorizontalList(_communities),
          ],
          if (_users.isEmpty && _shorts.isEmpty && _max.isEmpty && _prime.isEmpty && _audio.isEmpty && _blogs.isEmpty && _communities.isEmpty && !_usersLoading && !_postsLoading && !_blogsLoading && !_communitiesLoading)
            _buildEmptyState('No results found'),
        ],
      ),
    );
  }

  Widget _buildUsersResults() {
    if (_usersLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }
    if (_usersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_usersError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_users.isEmpty) {
      return _buildEmptyState('No users found');
    }
    return _buildUsersList(_users);
  }

  Widget _buildPostsResults() {
    if (_postsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }
    if (_postsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_postsError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchPosts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_shorts.isEmpty && _max.isEmpty && _prime.isEmpty && _audio.isEmpty) {
      return _buildEmptyState('No posts found');
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_shorts.isNotEmpty) ...[
            _buildSectionHeader('Shorts', _shorts.length),
            _buildPostsHorizontalList(_shorts),
          ],
          if (_max.isNotEmpty) ...[
            _buildSectionHeader('Max', _max.length),
            _buildPostsHorizontalList(_max),
          ],
          if (_prime.isNotEmpty) ...[
            _buildSectionHeader('Prime', _prime.length),
            _buildPostsHorizontalList(_prime),
          ],
          if (_audio.isNotEmpty) ...[
            _buildSectionHeader('Audio', _audio.length),
            _buildPostsHorizontalList(_audio),
          ],
        ],
      ),
    );
  }

  Widget _buildBlogsResults() {
    if (_blogsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }
    if (_blogsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_blogsError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchBlogs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_blogs.isEmpty) {
      return _buildEmptyState('No blogs found');
    }
    return _buildBlogsList(_blogs);
  }

  Widget _buildCommunitiesResults() {
    if (_communitiesLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }
    if (_communitiesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_communitiesError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchCommunities,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_communities.isEmpty) {
      return _buildEmptyState('No communities found');
    }
    return _buildCommunitiesList(_communities);
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final name = user['name']?.toString() ?? user['username']?.toString() ?? 'Unknown';
        final username = user['username']?.toString() ?? '';
        final avatar = user['profile_avatar']?.toString() ?? 
                      user['profile_photo_url']?.toString() ?? 
                      user['user_avatar']?.toString();
        
        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.amber,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: username.isNotEmpty
              ? Text(
                  '@$username',
                  style: TextStyle(color: Colors.grey[400]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            // TODO: Navigate to user profile
          },
        );
      },
    );
  }


  Widget _buildBlogsList(List<Map<String, dynamic>> blogs) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: blogs.length,
      itemBuilder: (context, index) {
        final blog = blogs[index];
        final title = blog['title']?.toString() ?? 'Untitled';
        final excerpt = blog['excerpt']?.toString() ?? blog['description']?.toString() ?? '';
        final coverImage = blog['cover_image_url']?.toString();
        
        return ListTile(
          leading: coverImage != null
              ? Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.article, color: Colors.grey),
                      ),
                    ),
                  ),
                )
              : Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article, color: Colors.grey),
                ),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: excerpt.isNotEmpty
              ? Text(
                  excerpt,
                  style: TextStyle(color: Colors.grey[400]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            final uuid = blog['uuid']?.toString() ?? blog['id']?.toString();
            if (uuid != null) {
              context.push('/blog/$uuid');
            }
          },
        );
      },
    );
  }

  Widget _buildCommunitiesList(List<Map<String, dynamic>> communities) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: communities.length,
      itemBuilder: (context, index) {
        final community = communities[index];
        final name = community['name']?.toString() ?? 'Unknown Community';
        final description = community['description']?.toString() ?? '';
        final avatar = community['avatar']?.toString() ?? 
                      community['image_url']?.toString();
        
        return ListTile(
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.blue,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: description.isNotEmpty
              ? Text(
                  description,
                  style: TextStyle(color: Colors.grey[400]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          onTap: () {
            // TODO: Navigate to community
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: Colors.grey[500], fontSize: 16),
      ),
    );
  }

  // Horizontal list builders for "All" tab
  Widget _buildUsersHorizontalList(List<Map<String, dynamic>> users) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final name = user['name']?.toString() ?? user['username']?.toString() ?? 'Unknown';
          final username = user['username']?.toString() ?? '';
          final avatar = user['profile_avatar']?.toString() ?? 
                        user['profile_photo_url']?.toString() ?? 
                        user['user_avatar']?.toString();
          
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.amber,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _getThumbnail(Map<String, dynamic> post) {
    final postId = post['id']?.toString() ?? 'unknown';
    print('[SEARCH DEBUG] Getting thumbnail for post ID: $postId');
    
    // First check media_files for thumbnail
    final mediaFiles = post['media_files'];
    print('[SEARCH DEBUG] Media files type: ${mediaFiles.runtimeType}, is List: ${mediaFiles is List}');
    
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      print('[SEARCH DEBUG] Found ${mediaFiles.length} media file(s)');
      for (int i = 0; i < mediaFiles.length; i++) {
        final media = mediaFiles[i];
        print('[SEARCH DEBUG] Media file $i: ${media.runtimeType}');
        if (media is Map<String, dynamic>) {
          print('[SEARCH DEBUG] Media file $i keys: ${media.keys.toList()}');
          print('[SEARCH DEBUG] Media file $i - thumbnail_path: ${media['thumbnail_path']}');
          print('[SEARCH DEBUG] Media file $i - thumbnail_url: ${media['thumbnail_url']}');
          print('[SEARCH DEBUG] Media file $i - thumbnail: ${media['thumbnail']}');
          print('[SEARCH DEBUG] Media file $i - snippet_thumbnail: ${media['snippet_thumbnail']}');
          
          // Check multiple possible keys for thumbnail
          final thumb = media['thumbnail_path'] ?? 
                       media['thumbnail_url'] ?? 
                       media['thumbnail'] ??
                       media['snippet_thumbnail'];
          print('[SEARCH DEBUG] Resolved thumbnail from media file $i: $thumb');
          
          if (thumb is String && thumb.isNotEmpty && thumb.trim().isNotEmpty) {
            print('[SEARCH DEBUG] ✓ Using thumbnail from media file $i: $thumb');
            return thumb;
          } else {
            print('[SEARCH DEBUG] ✗ Thumbnail from media file $i is invalid (empty or null)');
          }
        }
      }
    } else {
      print('[SEARCH DEBUG] No media files found or mediaFiles is not a List');
    }
    
    // Fallback to post-level thumbnail fields
    print('[SEARCH DEBUG] Checking post-level thumbnail fields...');
    print('[SEARCH DEBUG] post[thumbnail]: ${post['thumbnail']}');
    print('[SEARCH DEBUG] post[thumbnail_url]: ${post['thumbnail_url']}');
    print('[SEARCH DEBUG] post[thumbnail_path]: ${post['thumbnail_path']}');
    print('[SEARCH DEBUG] post[snippet_thumbnail]: ${post['snippet_thumbnail']}');
    
    final fallback = post['thumbnail'] ?? 
                     post['thumbnail_url'] ?? 
                     post['thumbnail_path'] ??
                     post['snippet_thumbnail'];
    print('[SEARCH DEBUG] Resolved fallback thumbnail: $fallback');
    
    if (fallback is String && fallback.isNotEmpty && fallback.trim().isNotEmpty) {
      print('[SEARCH DEBUG] ✓ Using fallback thumbnail: $fallback');
      return fallback;
    }
    
    print('[SEARCH DEBUG] ✗ No valid thumbnail found for post ID: $postId');
    return null;
  }

  String? _getVideoUrl(Map<String, dynamic> post) {
    final mediaFiles = post['media_files'];
    if (mediaFiles is List && mediaFiles.isNotEmpty) {
      for (var media in mediaFiles) {
        if (media is Map<String, dynamic>) {
          final filePath = media['file_path'];
          final fileType = media['file_type']?.toString().toLowerCase() ?? '';
          // Only return video URLs, not audio
          if (filePath is String && filePath.isNotEmpty && 
              (fileType.contains('video') || filePath.contains('.mp4') || filePath.contains('.mov') || filePath.contains('.avi'))) {
            return filePath;
          }
        }
      }
    }
    return null;
  }

  Widget _buildPostsHorizontalList(List<Map<String, dynamic>> posts) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final description = post['description']?.toString() ?? '';
          final user = post['user'] is Map<String, dynamic> ? post['user'] as Map<String, dynamic> : null;
          final userName = user?['name']?.toString() ?? user?['username']?.toString() ?? 'Unknown';
          final thumbnailUrl = _getThumbnail(post);
          final videoUrl = _getVideoUrl(post);
          print('[SEARCH DEBUG] Post index $index - Final thumbnail URL: $thumbnailUrl');
          print('[SEARCH DEBUG] Post index $index - Video URL: $videoUrl');
          
          return GestureDetector(
            onTap: () {
              context.push('/tube-player', extra: {
                'videos': posts,
                'initialIndex': index,
              });
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumbnailUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  print('[SEARCH DEBUG] ✓ Image loaded successfully: $thumbnailUrl');
                                  return child;
                                }
                                print('[SEARCH DEBUG] Loading image: $thumbnailUrl - ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('[SEARCH DEBUG] ✗ Image load error for: $thumbnailUrl');
                                print('[SEARCH DEBUG] Error: $error');
                                // Fallback to video if thumbnail fails
                                if (videoUrl != null) {
                                  print('[SEARCH DEBUG] Falling back to video: $videoUrl');
                                  return _VideoPreviewWidget(videoUrl: videoUrl);
                                }
                                return const Icon(Icons.video_library, color: Colors.grey);
                              },
                            ),
                          )
                        : videoUrl != null
                            ? _VideoPreviewWidget(videoUrl: videoUrl)
                            : const Icon(Icons.video_library, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      userName,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlogsHorizontalList(List<Map<String, dynamic>> blogs) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: blogs.length,
        itemBuilder: (context, index) {
          final blog = blogs[index];
          final title = blog['title']?.toString() ?? 'Untitled';
          final coverImage = blog['cover_image_url']?.toString();
          
          return GestureDetector(
            onTap: () {
              final uuid = blog['uuid']?.toString() ?? blog['id']?.toString();
              if (uuid != null) {
                context.push('/blog/$uuid');
              }
            },
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: coverImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              coverImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.article, color: Colors.grey),
                              ),
                            ),
                          )
                        : const Icon(Icons.article, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommunitiesHorizontalList(List<Map<String, dynamic>> communities) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: communities.length,
        itemBuilder: (context, index) {
          final community = communities[index];
          final name = community['name']?.toString() ?? 'Unknown Community';
          final avatar = community['avatar']?.toString() ?? 
                        community['image_url']?.toString();
          
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
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
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..setLooping(false)
        ..setVolume(0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Seek to first frame but don't play
        _controller!.seekTo(Duration.zero);
        _controller!.pause();
      }
    } catch (e) {
      print('[SEARCH DEBUG] Video initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
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
    if (_hasError) {
      return const Icon(Icons.video_library, color: Colors.grey);
    }
    
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
          // Play icon overlay
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
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
  }
}

