import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajify_top_bar.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();
  
  // Top bar state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  int _messagesUnreadCount = 0;
  StreamSubscription<int>? _messagesCountSubscription;
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  Map<String, dynamic>? _currentUserProfile;
  
  // Communities
  List<Map<String, dynamic>> _communities = [];
  List<Map<String, dynamic>> _myCommunities = [];
  bool _loadingCommunities = false;
  bool _showMyCommunities = false;
  
  // Users
  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _following = [];
  
  bool _loading = false;
  bool _searching = false;
  String _searchQuery = '';
  int _activeTab = 0; // 0: Communities, 1: People
  
  int? _currentUserId;
  Map<int, bool> _followingStatus = {};
  Map<int, bool> _followLoading = {};
  Map<String, bool> _communityMemberships = {};
  Map<String, bool> _joiningCommunity = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadUserProfile();
    _loadNotificationUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNotificationUnreadCount());
    _initializeFirebaseAndLoadMessagesCount();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      setState(() {
        _currentUserId = parsedId;
      });
      
      if (_currentUserId != null) {
        await Future.wait([
          _loadCommunities(),
          _loadMyCommunities(),
          _loadSuggestedUsers(),
          _loadFollowing(),
        ]);
      }
    } catch (e) {
      print('[CONNECT] Error loading current user: $e');
    }
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _loadingCommunities = true;
    });
    
    try {
      final response = await _apiService.get('/communities');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> communitiesList = [];
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          communitiesList = data['data'] as List<dynamic>;
        } else if (data is List) {
          communitiesList = data;
        }
        
        setState(() {
          _communities = communitiesList
              .whereType<Map<String, dynamic>>()
              .map((community) => Map<String, dynamic>.from(community))
              .toList();
        });
        
        await _checkCommunityMemberships();
      }
    } catch (e) {
      print('[CONNECT] Error loading communities: $e');
    } finally {
      setState(() {
        _loadingCommunities = false;
      });
    }
  }

  Future<void> _loadMyCommunities() async {
    try {
      final response = await _apiService.get('/communities/mine');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> communitiesList = [];
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          communitiesList = data['data'] as List<dynamic>;
        } else if (data is List) {
          communitiesList = data;
        }
        
        setState(() {
          _myCommunities = communitiesList
              .whereType<Map<String, dynamic>>()
              .map((community) => Map<String, dynamic>.from(community))
              .toList();
        });
      }
    } catch (e) {
      print('[CONNECT] Error loading my communities: $e');
    }
  }

  Future<void> _checkCommunityMemberships() async {
    try {
      final response = await _apiService.get('/communities/memberships');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> memberships = [];
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          memberships = data['data'] as List<dynamic>;
        } else if (data is List) {
          memberships = data;
        }
        
        final membershipMap = <String, bool>{};
        for (var membership in memberships) {
          if (membership is Map<String, dynamic>) {
            final uuid = membership['community_uuid']?.toString() ?? 
                        membership['uuid']?.toString();
            if (uuid != null) {
              membershipMap[uuid] = true;
            }
          }
        }
        
        setState(() {
          _communityMemberships = membershipMap;
        });
      }
    } catch (e) {
      print('[CONNECT] Error checking memberships: $e');
    }
  }

  Future<void> _joinCommunity(String uuid) async {
    setState(() {
      _joiningCommunity[uuid] = true;
    });
    
    try {
      final response = await _apiService.post('/communities/$uuid/join');
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _communityMemberships[uuid] = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadMyCommunities();
      }
    } catch (e) {
      print('[CONNECT] Error joining community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _joiningCommunity[uuid] = false;
      });
    }
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() {
      _loading = true;
    });
    
    try {
      // Try to get users from posts or use a different approach
      // Get users from the posts endpoint to find active users
      final postsResponse = await _apiService.getPosts(limit: 50);
      if (postsResponse.statusCode == 200 && postsResponse.data['success'] == true) {
        final data = postsResponse.data['data'];
        List<dynamic> postsList = [];
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          postsList = data['data'] as List<dynamic>;
        } else if (data is List) {
          postsList = data;
        }
        
        // Extract unique users from posts
        final userMap = <int, Map<String, dynamic>>{};
        for (var post in postsList) {
          if (post is Map<String, dynamic>) {
            final user = post['user'];
            if (user is Map<String, dynamic>) {
              final userId = user['id'];
              if (userId != null && userId != _currentUserId && !userMap.containsKey(userId)) {
                userMap[userId] = user;
              }
            }
          }
        }
        
        final users = userMap.values.take(20).toList();
        
        setState(() {
          _suggestedUsers = users;
          for (var user in users) {
            final userId = user['id'];
            if (userId != null) {
              _followingStatus[userId] = false;
              _followLoading[userId] = false;
            }
          }
        });
        
        await _checkFollowStatuses(users);
      }
    } catch (e) {
      print('[CONNECT] Error loading suggested users: $e');
      // Fallback: try search with a common term
      try {
        final response = await _apiService.search('a', type: 'users');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final data = response.data['data'];
          List<dynamic> usersList = [];
          
          if (data is Map<String, dynamic> && data['users'] is List) {
            usersList = data['users'] as List<dynamic>;
          } else if (data is List) {
            usersList = data;
          }
          
          final users = usersList
              .whereType<Map<String, dynamic>>()
              .where((user) => user['id'] != _currentUserId)
              .take(20)
              .map((user) => Map<String, dynamic>.from(user))
              .toList();
          
          setState(() {
            _suggestedUsers = users;
            for (var user in users) {
              final userId = user['id'];
              if (userId != null) {
                _followingStatus[userId] = false;
                _followLoading[userId] = false;
              }
            }
          });
          
          await _checkFollowStatuses(users);
        }
      } catch (e2) {
        print('[CONNECT] Error in fallback user loading: $e2');
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _checkFollowStatuses(List<Map<String, dynamic>> users) async {
    for (var user in users) {
      final userId = user['id'];
      if (userId != null) {
        final isFollowing = _following.any((f) => f['id'] == userId);
        setState(() {
          _followingStatus[userId] = isFollowing;
        });
      }
    }
  }

  Future<void> _loadFollowing() async {
    if (_currentUserId == null) return;
    
    try {
      final profileResponse = await _apiService.getProfile();
      if (profileResponse.statusCode == 200 && profileResponse.data['success'] == true) {
        final username = profileResponse.data['data']['username']?.toString() ?? '';
        if (username.isNotEmpty) {
          final response = await _apiService.getFollowing(username);
          if (response.statusCode == 200 && response.data['success'] == true) {
            final data = response.data['data'];
            List<dynamic> followingList = [];
            
            if (data is Map<String, dynamic> && data['data'] is List) {
              followingList = data['data'] as List<dynamic>;
            } else if (data is List) {
              followingList = data;
            }
            
            final following = followingList
                .whereType<Map<String, dynamic>>()
                .map((user) => Map<String, dynamic>.from(user))
                .toList();
            
            setState(() {
              _following = following;
              for (var user in following) {
                final userId = user['id'];
                if (userId != null) {
                  _followingStatus[userId] = true;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('[CONNECT] Error loading following: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }
    
    setState(() {
      _searching = true;
      _searchQuery = query;
    });
    
    try {
      final response = await _apiService.search(query, type: 'users');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> usersList = [];
        
        if (data is Map<String, dynamic> && data['users'] is List) {
          usersList = data['users'] as List<dynamic>;
        } else if (data is List) {
          usersList = data;
        }
        
        final users = usersList
            .whereType<Map<String, dynamic>>()
            .where((user) => user['id'] != _currentUserId)
            .map((user) => Map<String, dynamic>.from(user))
            .toList();
        
        setState(() {
          _searchResults = users;
          for (var user in users) {
            final userId = user['id'];
            if (userId != null) {
              if (!_followingStatus.containsKey(userId)) {
                _followingStatus[userId] = false;
                _followLoading[userId] = false;
              }
            }
          }
        });
        
        await _checkFollowStatuses(users);
      }
    } catch (e) {
      print('[CONNECT] Error searching users: $e');
    } finally {
      setState(() {
        _searching = false;
      });
    }
  }

  Future<void> _toggleFollow(int userId) async {
    setState(() {
      _followLoading[userId] = true;
    });
    
    try {
      final response = await _apiService.toggleFollowUser(userId);
      if (response.statusCode == 200 && response.data['success'] == true) {
        final isFollowing = response.data['data']['is_following'] ?? false;
        setState(() {
          _followingStatus[userId] = isFollowing;
        });
      }
    } catch (e) {
      print('[CONNECT] Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _followLoading[userId] = false;
      });
    }
  }

  String _getUserInitial(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? '';
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String? _getUserAvatar(Map<String, dynamic> user) {
    return user['profile_avatar']?.toString() ?? 
           user['profile_photo_url']?.toString() ??
           user['user_avatar']?.toString();
  }

  String? _getCommunityImage(Map<String, dynamic> community) {
    return community['image_url']?.toString() ?? 
           community['avatar']?.toString();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = response.data['data'];
        if (mounted) {
          setState(() {
            _currentUserProfile = profile;
            final name = profile?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = profile?['profile_avatar']?.toString();
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
      if (mounted) {
        setState(() {
          if (name != null && name.isNotEmpty) {
            _currentUserInitial = name[0].toUpperCase();
          }
          _currentUserAvatar = avatar;
        });
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

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openSearchDialog() {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    _activeTab == 0 ? 'Search Communities' : 'Search Users',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _activeTab == 0 
                          ? 'Search communities...' 
                          : 'Search by name or username...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFB800), width: 2),
                      ),
                    ),
                    onSubmitted: (value) {
                      Navigator.of(context).pop();
                      if (_activeTab == 0) {
                        _searchCommunities(value);
                      } else {
                        _searchUsers(value);
                      }
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _searchResults = [];
                        });
                      },
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (_activeTab == 0) {
                            _searchCommunities(_searchController.text);
                          } else {
                            _searchUsers(_searchController.text);
                          }
                        },
                        child: const Text('Search', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                            ),
                          ],
                        ),
              );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0F0F0F),
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          context.go('/channel');
        } else if (index == 2) {
          context.go('/market');
        } else if (index == 3) {
          context.go('/earn');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Connect'),
        BottomNavigationBarItem(icon: Icon(Icons.live_tv_outlined), label: 'Channel'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Market'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), label: 'Earn'),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          onPressed: () => context.go('/home'),
          child: const Icon(Icons.home, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
        children: [
            TajifyTopBar(
              onSearch: _openSearchDialog,
              onNotifications: () => context.push('/notifications').then((_) => _loadNotificationUnreadCount()),
              onMessages: () => context.push('/messages').then((_) => _initializeFirebaseAndLoadMessagesCount()),
              onAdd: () => context.go('/create'),
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserAvatar,
              displayLetter: _currentUserProfile?['name'] != null && _currentUserProfile!['name'].toString().isNotEmpty
                  ? _currentUserProfile!['name'].toString()[0].toUpperCase()
                  : _currentUserInitial,
            ),
          // Tabs - Always visible
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildTab('Communities', 0)),
                const SizedBox(width: 12),
                Expanded(child: _buildTab('People', 1)),
                    ],
                  ),
                ),
          
          // Filter buttons for Communities - Always visible when on Communities tab
          if (_activeTab == 0 && _searchQuery.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterButton(
                      'All Communities',
                      !_showMyCommunities,
                      () => setState(() => _showMyCommunities = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterButton(
                      'My Communities',
                      _showMyCommunities,
                      () => setState(() => _showMyCommunities = true),
                    ),
                  ),
                ],
              ),
            ),
          
          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (_activeTab == 0) {
                  await Future.wait([
                    _loadCommunities(),
                    _loadMyCommunities(),
                  ]);
                } else {
                  await Future.wait([
                    _loadSuggestedUsers(),
                    _loadFollowing(),
                  ]);
                }
              },
              color: const Color(0xFFFFB800),
              child: _activeTab == 0 ? _buildCommunitiesContent() : _buildPeopleContent(),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
          _searchQuery = '';
          _searchResults = [];
          _searchController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
      child: Text(
        label,
          textAlign: TextAlign.center,
        style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: isActive
              ? [
          BoxShadow(
                    color: Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCommunitiesContent() {
    if (_loadingCommunities) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
        ),
      );
    }

    final displayCommunities = _searchQuery.isNotEmpty ? _searchResults : 
                               _showMyCommunities ? _myCommunities : _communities;

    if (displayCommunities.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty 
            ? 'No communities found' 
            : _showMyCommunities
                ? 'You haven\'t joined any communities yet'
                : 'No communities available',
        Icons.group_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          if (_searchQuery.isEmpty) ...[
                Row(
                  children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                  ],
                ),
                  child: const Icon(Icons.group, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                        _showMyCommunities ? 'My Communities' : 'Discover Communities',
                style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showMyCommunities
                            ? 'Communities you\'ve joined'
                            : 'Join communities and connect with like-minded people',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
            const SizedBox(height: 20),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: displayCommunities.length,
            itemBuilder: (context, index) {
              return _buildCommunityCard(displayCommunities[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> community) {
    final uuid = community['uuid']?.toString() ?? '';
    final isMember = uuid.isNotEmpty && (_communityMemberships[uuid] ?? false);
    final isJoining = uuid.isNotEmpty && (_joiningCommunity[uuid] ?? false);
    final image = _getCommunityImage(community);
    final name = community['name']?.toString() ?? 'Unknown Community';
    final description = community['description']?.toString() ?? '';
    final joinPolicy = community['join_policy']?.toString() ?? 'open';
    
    return GestureDetector(
      onTap: () {
        if (uuid.isNotEmpty) {
          context.go('/community/$uuid');
        }
      },
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Community Image/Header
          Stack(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: image == null || image.isEmpty
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                        )
                      : null,
                ),
                child: image != null && image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
                          image,
              fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.group, color: Colors.white, size: 32),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group, color: Colors.white, size: 32),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                children: [
                      Icon(
                        joinPolicy == 'open' ? Icons.public : Icons.lock,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                  Text(
                        joinPolicy == 'open' ? 'Open' : 'Private',
                    style: const TextStyle(
                      color: Colors.white,
                          fontSize: 11,
                      fontWeight: FontWeight.bold,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
          
          // Community Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
                  Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ],
                  ),
                  if (!isMember && uuid.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isJoining ? null : () => _joinCommunity(uuid),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: isJoining
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Join',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                      ),
                    )
                  else if (isMember)
                    Container(
                  width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Member',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchCommunities(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
      });
      return;
    }
    
    setState(() {
      _loadingCommunities = true;
      _searchQuery = query;
    });
    
    try {
      final response = await _apiService.search(query, type: 'communities');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> communitiesList = [];
        
        if (data is Map<String, dynamic> && data['communities'] is List) {
          communitiesList = data['communities'] as List<dynamic>;
        } else if (data is List) {
          communitiesList = data;
        }
        
        setState(() {
          _searchResults = communitiesList
              .whereType<Map<String, dynamic>>()
              .map((community) => Map<String, dynamic>.from(community))
              .toList();
        });
        
        await _checkCommunityMemberships();
      }
    } catch (e) {
      print('[CONNECT] Error searching communities: $e');
    } finally {
      setState(() {
        _loadingCommunities = false;
      });
    }
  }

  Widget _buildPeopleContent() {
    final isLoading = _searchQuery.isNotEmpty ? _searching : _loading;
    
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
        ),
      );
    }

    final displayUsers = _searchQuery.isNotEmpty ? _searchResults : _suggestedUsers;

    if (displayUsers.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No users found' : 'No suggested users',
        _searchQuery.isNotEmpty ? Icons.search_off : Icons.explore_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: displayUsers.length,
      itemBuilder: (context, index) => _buildUserCard(displayUsers[index]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'];
    final isFollowing = userId != null ? (_followingStatus[userId] ?? false) : false;
    final isLoading = userId != null ? (_followLoading[userId] ?? false) : false;
    final avatar = _getUserAvatar(user);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Avatar
          avatar != null && avatar.isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.transparent,
                  backgroundImage: NetworkImage(avatar),
                  onBackgroundImageError: (exception, stackTrace) {
                    print('[CONNECT] Error loading avatar: $exception');
                  },
                )
              : CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFB800),
                  child: Text(
                    _getUserInitial(user),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
          const SizedBox(width: 12),
          
          // User Info
          Expanded(
            child: GestureDetector(
              onTap: () {
                final username = user['username']?.toString();
                if (username != null && username.isNotEmpty) {
                  context.go('/user/$username');
                }
              },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
              children: [
                  Text(
                    user['name']?.toString() ?? 'Unknown User',
                        style: const TextStyle(
                          color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user['username']?.toString() ?? 'username'}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Follow Button
          if (userId != null && userId != _currentUserId)
                      Container(
                        decoration: BoxDecoration(
                gradient: isFollowing
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                      ),
                color: isFollowing ? Colors.white.withOpacity(0.08) : null,
                          borderRadius: BorderRadius.circular(8),
                border: isFollowing
                    ? Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      )
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : () => _toggleFollow(userId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              color: isFollowing ? Colors.grey[300] : Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.grey[400],
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
                      Text(
            message,
                          style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 
