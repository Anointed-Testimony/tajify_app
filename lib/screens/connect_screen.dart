import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajify_top_bar.dart';
import '../widgets/custom_bottom_nav.dart';

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
  bool _loadingCommunities = false;
  bool _loadingMoreCommunities = false;
  int _communitiesPage = 1;
  bool _communitiesHasMore = true;
  final ScrollController _communitiesScrollController = ScrollController();
  List<Map<String, dynamic>> _myOwnedCommunities = [];
  List<Map<String, dynamic>> _myJoinedCommunities = [];
  bool _loadingMyCommunities = false;
  
  // Users
  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _following = [];
  
  bool _loading = false;
  bool _searching = false;
  String _searchQuery = '';
  int _activeTab = 0; // 0: Community, 1: Live, 2: Consult
  
  // Live sessions
  List<Map<String, dynamic>> _liveSessions = [];
  bool _loadingLiveSessions = false;
  Timer? _liveSessionsTimer;
  
  int? _currentUserId;
  Map<int, bool> _followingStatus = {};
  Map<int, bool> _followLoading = {};
  Map<String, bool> _communityMemberships = {};
  Map<String, bool> _joiningCommunity = {};
  
  // Create community state
  final TextEditingController _communityNameController = TextEditingController();
  final TextEditingController _communityDescriptionController = TextEditingController();
  File? _communityImage;
  String _joinPolicy = 'open';
  String _chatPolicy = 'everyone';
  bool _creatingCommunity = false;
  String? _createCommunityError;

  @override
  void initState() {
    super.initState();
    _communitiesScrollController.addListener(_onCommunitiesScroll);
    _loadCurrentUserId();
    _loadUserProfile();
    _loadNotificationUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNotificationUnreadCount());
    _liveSessionsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_activeTab == 1) {
        _loadLiveSessions();
      }
    });
    _initializeFirebaseAndLoadMessagesCount();
  }

  void _onCommunitiesScroll() {
    if (_communitiesScrollController.position.pixels >=
        _communitiesScrollController.position.maxScrollExtent * 0.8) {
      if (!_loadingMoreCommunities && _communitiesHasMore && _activeTab == 0) {
        _loadMoreCommunities();
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
        await Future.wait([
          _loadCommunities(),
          _loadSuggestedUsers(),
          _loadFollowing(),
          _loadLiveSessions(),
        ]);
      }
    } catch (e) {
      print('[CONNECT] Error loading current user: $e');
    }
  }

  Future<void> _loadCommunities({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMoreCommunities || !_communitiesHasMore) return;
    } else {
      if (_loadingCommunities) return;
      _communitiesPage = 1;
      _communitiesHasMore = true;
    }
    
    setState(() {
      if (loadMore) {
        _loadingMoreCommunities = true;
      } else {
        _loadingCommunities = true;
      }
    });
    
    try {
      final page = loadMore ? _communitiesPage + 1 : 1;
      final response = await _apiService.get('/communities', queryParameters: {
        'page': page,
        'limit': 20,
      });
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        List<dynamic> communitiesList = [];
        
        if (data is Map<String, dynamic> && data['data'] is List) {
          communitiesList = data['data'] as List<dynamic>;
        } else if (data is List) {
          communitiesList = data;
        }
        
        final newCommunities = communitiesList
            .whereType<Map<String, dynamic>>()
            .map((community) => Map<String, dynamic>.from(community))
            .toList();
        
        setState(() {
          if (loadMore) {
            _communities.addAll(newCommunities);
          } else {
            _communities = newCommunities;
          }
          _communitiesPage = page;
          _communitiesHasMore = newCommunities.length >= 20;
        });
        
        await _checkCommunityMemberships();
      }
    } catch (e) {
      print('[CONNECT] Error loading communities: $e');
    } finally {
      setState(() {
        if (loadMore) {
          _loadingMoreCommunities = false;
        } else {
          _loadingCommunities = false;
        }
      });
    }
  }
  
  Future<void> _loadMoreCommunities() async {
    await _loadCommunities(loadMore: true);
  }

  Future<void> _loadMyOwnedAndJoinedCommunities() async {
    setState(() {
      _loadingMyCommunities = true;
    });
    
    try {
      final userId = _currentUserId;
      final owned = <Map<String, dynamic>>[];
      final joined = <Map<String, dynamic>>[];
      
      // Get owned communities
      try {
        final ownedResponse = await _apiService.get('/communities/mine');
        if (ownedResponse.statusCode == 200 && ownedResponse.data['success'] == true) {
          final data = ownedResponse.data['data'];
          List<dynamic> communitiesList = [];
          
          if (data is Map<String, dynamic> && data['data'] is List) {
            communitiesList = data['data'] as List<dynamic>;
          } else if (data is List) {
            communitiesList = data;
          }
          
          final ownedCommunities = communitiesList
              .whereType<Map<String, dynamic>>()
              .map((community) => Map<String, dynamic>.from(community))
              .toList();
          
          owned.addAll(ownedCommunities);
        }
      } catch (e) {
        print('[CONNECT] Error loading owned communities: $e');
      }
      
      // Get joined communities (memberships)
      try {
        final membershipsResponse = await _apiService.get('/communities/memberships');
        if (membershipsResponse.statusCode == 200 && membershipsResponse.data['success'] == true) {
          final data = membershipsResponse.data['data'];
          List<dynamic> communitiesList = [];
          
          if (data is Map<String, dynamic> && data['data'] is List) {
            communitiesList = data['data'] as List<dynamic>;
          } else if (data is List) {
            communitiesList = data;
          }
          
          final membershipCommunities = communitiesList
              .whereType<Map<String, dynamic>>()
              .map((community) => Map<String, dynamic>.from(community))
              .toList();
          
          // Filter out communities that are already in owned list (to avoid duplicates)
          final ownedUuids = owned.map((c) => c['uuid']?.toString() ?? c['id']?.toString()).toSet();
          
          for (var community in membershipCommunities) {
            final communityUuid = community['uuid']?.toString() ?? community['id']?.toString();
            final ownerId = community['owner_id'] ?? community['user_id'];
            
            // Only add if not already owned and user is not the owner
            if (communityUuid != null && !ownedUuids.contains(communityUuid)) {
              if (userId != null && ownerId != null && ownerId != userId) {
                joined.add(community);
              }
            }
          }
        }
      } catch (e) {
        print('[CONNECT] Error loading memberships: $e');
      }
      
      setState(() {
        _myOwnedCommunities = owned;
        _myJoinedCommunities = joined;
      });
    } catch (e) {
      print('[CONNECT] Error loading my communities: $e');
    } finally {
      setState(() {
        _loadingMyCommunities = false;
      });
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
        await _loadCommunities();
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
            // Handle nested user object
            final user = profile?['user'] ?? profile;
            _currentUserProfile = user ?? profile;
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

  Future<void> _loadLiveSessions() async {
    setState(() {
      _loadingLiveSessions = true;
    });
    
    try {
      final response = await _apiService.getActiveLiveSessions();
      print('[CONNECT] Live sessions response status: ${response.statusCode}');
      print('[CONNECT] Live sessions response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // Handle different response formats
        List<dynamic> sessionsList = [];
        
        if (responseData['success'] == true) {
          final data = responseData['data'];
          
          if (data is List) {
            sessionsList = data;
          } else if (data is Map<String, dynamic>) {
            // Check if data contains a nested 'data' array
            if (data['data'] is List) {
              sessionsList = data['data'] as List<dynamic>;
            } else if (data['sessions'] is List) {
              sessionsList = data['sessions'] as List<dynamic>;
            }
          }
        } else if (responseData is List) {
          // Response might be a direct list
          sessionsList = responseData;
        } else if (responseData is Map<String, dynamic> && responseData['data'] is List) {
          // Response data might be directly in 'data' without 'success' field
          sessionsList = responseData['data'] as List<dynamic>;
        }
        
        print('[CONNECT] Parsed ${sessionsList.length} live sessions');
        
        setState(() {
          _liveSessions = sessionsList
              .whereType<Map<String, dynamic>>()
              .map((session) => Map<String, dynamic>.from(session))
              .toList();
        });
      } else {
        print('[CONNECT] Live sessions API returned non-200 status: ${response.statusCode}');
        print('[CONNECT] Response: ${response.data}');
        setState(() {
          _liveSessions = [];
        });
      }
    } catch (e) {
      print('[CONNECT] Error loading live sessions: $e');
      print('[CONNECT] Error stack trace: ${StackTrace.current}');
      setState(() {
        _liveSessions = [];
      });
    } finally {
      setState(() {
        _loadingLiveSessions = false;
      });
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
    _communitiesScrollController.dispose();
    _communityNameController.dispose();
    _communityDescriptionController.dispose();
    _notificationTimer?.cancel();
    _liveSessionsTimer?.cancel();
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
                    _activeTab == 0 
                        ? 'Search Communities' 
                        : _activeTab == 1 
                            ? 'Search Live Sessions' 
                            : 'Search Users',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _activeTab == 0 
                          ? 'Search communities...' 
                          : _activeTab == 1
                              ? 'Search live sessions...'
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
                        borderSide: const BorderSide(color: Color(0xFFB875FB), width: 2),
                      ),
                    ),
                    onSubmitted: (value) {
                      Navigator.of(context).pop();
                      if (_activeTab == 0) {
                        _searchCommunities(value);
                      } else if (_activeTab == 1) {
                        // Live search can be implemented later
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
                          colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (_activeTab == 0) {
                            _searchCommunities(_searchController.text);
                          } else if (_activeTab == 1) {
                            // Live search can be implemented later
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
    return const CustomBottomNav(currentIndex: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
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
                Expanded(child: _buildTab('Community', 0)),
                const SizedBox(width: 8),
                Expanded(child: _buildTab('Live', 1)),
                const SizedBox(width: 8),
                Expanded(child: _buildTab('Consult', 2)),
              ],
            ),
          ),
          
          // Icons header - only show in Community tab
          if (_activeTab == 0 && _searchQuery.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Plus icon
                  GestureDetector(
                    onTap: _openCreateCommunityDialog,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFB875FB).withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Profile icon
                  GestureDetector(
                    onTap: _showMyCommunities,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFB875FB).withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 20,
                      ),
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
                  await _loadCommunities();
                } else if (_activeTab == 1) {
                  await _loadLiveSessions();
                } else {
                  await Future.wait([
                    _loadSuggestedUsers(),
                    _loadFollowing(),
                  ]);
                }
              },
              color: const Color(0xFFB875FB),
              child: _activeTab == 0 
                  ? _buildCommunitiesContent() 
                  : _activeTab == 1 
                      ? _buildLiveContent() 
                      : _buildPeopleContent(),
            ),
          ),
        ],
        ),
      ),
        ),
      ],
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
        // Load live sessions when switching to Live tab
        if (index == 1) {
          _loadLiveSessions();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Color(0xFFB875FB).withOpacity(0.4),
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

  Widget _buildCommunitiesContent() {
    if (_loadingCommunities) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
        ),
      );
    }

    final displayCommunities = _searchQuery.isNotEmpty ? _searchResults : _communities;

    if (displayCommunities.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty 
            ? 'No communities found' 
            : 'No communities available',
        Icons.group_outlined,
      );
    }

    return SingleChildScrollView(
      controller: _communitiesScrollController,
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: displayCommunities.length + (_loadingMoreCommunities ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayCommunities.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildCommunityCard(displayCommunities[index]);
        },
      ),
    );
  }

  Widget _buildCommunityCard(Map<String, dynamic> community) {
    final uuid = community['uuid']?.toString() ?? '';
    final image = _getCommunityImage(community);
    final name = community['name']?.toString() ?? 'Unknown Community';
    final description = community['description']?.toString() ?? '';
    
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
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: image == null || image.isEmpty
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                        )
                      : null,
                ),
                child: image != null && image.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          memCacheWidth: 300,
                          memCacheHeight: 180,
                          maxWidthDiskCache: 300,
                          maxHeightDiskCache: 180,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: CachedNetworkImage(
                              imageUrl: 'https://img.freepik.com/free-vector/illustration-business-people_53876-5879.jpg?t=st=1764965940~exp=1764969540~hmac=b29e4fad4cf13ff431807916b6246dafa82c19f1a1997efb9042a5fb5b1571b9&w=1480',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              memCacheWidth: 300,
                              memCacheHeight: 180,
                              maxWidthDiskCache: 300,
                              maxHeightDiskCache: 180,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Container(
                          color: Colors.grey[800],
                          child: CachedNetworkImage(
                            imageUrl: 'https://img.freepik.com/free-vector/illustration-business-people_53876-5879.jpg?t=st=1764965940~exp=1764969540~hmac=b29e4fad4cf13ff431807916b6246dafa82c19f1a1997efb9042a5fb5b1571b9&w=1480',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            memCacheWidth: 300,
                            memCacheHeight: 180,
                            maxWidthDiskCache: 300,
                            maxHeightDiskCache: 180,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          // Community Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 10,
                      height: 1.1,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _pickCommunityImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _communityImage = File(image.path);
        });
      }
    } catch (e) {
      print('[CONNECT] Error picking image: $e');
    }
  }

  Future<void> _createCommunity() async {
    if (_communityNameController.text.trim().isEmpty) {
      setState(() {
        _createCommunityError = 'Community name is required';
      });
      return;
    }

    setState(() {
      _creatingCommunity = true;
      _createCommunityError = null;
    });

    try {
      final response = await _apiService.createCommunity(
        name: _communityNameController.text.trim(),
        description: _communityDescriptionController.text.trim().isNotEmpty
            ? _communityDescriptionController.text.trim()
            : null,
        image: _communityImage,
        joinPolicy: _joinPolicy,
        chatPolicy: _chatPolicy,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['success'] == true) {
          // Reset form
          _communityNameController.clear();
          _communityDescriptionController.clear();
          // Close dialog
          Navigator.of(context).pop();
          
          // Reset form
          setState(() {
            _communityImage = null;
            _joinPolicy = 'open';
            _chatPolicy = 'everyone';
          });

          // Reload communities
          await _loadCommunities();
          await _loadMyOwnedAndJoinedCommunities();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Community created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _createCommunityError = response.data['message'] ?? 'Failed to create community';
          });
        }
      } else {
        setState(() {
          _createCommunityError = 'Failed to create community';
        });
      }
    } catch (e) {
      print('[CONNECT] Error creating community: $e');
      setState(() {
        _createCommunityError = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _creatingCommunity = false;
      });
    }
  }

  void _openCreateCommunityDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildCreateCommunityDialog(),
    );
  }

  Future<void> _showMyCommunities() async {
    await _loadMyOwnedAndJoinedCommunities();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'My Communities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loadingMyCommunities
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Owned Communities
                          if (_myOwnedCommunities.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'OWNED',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_myOwnedCommunities.length}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._myOwnedCommunities.map((community) => _buildMyCommunityListItem(community, true)),
                            const SizedBox(height: 24),
                          ],
                          // Joined Communities
                          if (_myJoinedCommunities.isNotEmpty) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'JOINED',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_myJoinedCommunities.length}',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._myJoinedCommunities.map((community) => _buildMyCommunityListItem(community, false)),
                          ],
                          // Empty state
                          if (_myOwnedCommunities.isEmpty && _myJoinedCommunities.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.group_outlined,
                                      color: Colors.white.withOpacity(0.3),
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No communities yet',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
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

  Widget _buildMyCommunityListItem(Map<String, dynamic> community, bool isOwned) {
    final uuid = community['uuid']?.toString() ?? '';
    final image = _getCommunityImage(community);
    final name = community['name']?.toString() ?? 'Unknown Community';
    final description = community['description']?.toString() ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        if (uuid.isNotEmpty) {
          context.go('/community/$uuid');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOwned 
                ? const Color(0xFFB875FB).withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Community Image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: image == null || image.isEmpty
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                      )
                    : null,
              ),
              child: image != null && image.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                        memCacheWidth: 100,
                        memCacheHeight: 100,
                        maxWidthDiskCache: 100,
                        maxHeightDiskCache: 100,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: CachedNetworkImage(
                            imageUrl: 'https://img.freepik.com/free-vector/illustration-business-people_53876-5879.jpg?t=st=1764965940~exp=1764969540~hmac=b29e4fad4cf13ff431807916b6246dafa82c19f1a1997efb9042a5fb5b1571b9&w=1480',
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                            memCacheWidth: 100,
                            memCacheHeight: 100,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: 'https://img.freepik.com/free-vector/illustration-business-people_53876-5879.jpg?t=st=1764965940~exp=1764969540~hmac=b29e4fad4cf13ff431807916b6246dafa82c19f1a1997efb9042a5fb5b1571b9&w=1480',
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                        memCacheWidth: 100,
                        memCacheHeight: 100,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Community Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
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

  Widget _buildLiveContent() {
    if (_loadingLiveSessions) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
        ),
      );
    }

    if (_liveSessions.isEmpty) {
      return _buildEmptyState(
        'No live sessions at the moment',
        Icons.live_tv_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _liveSessions.length,
      itemBuilder: (context, index) {
        return _buildLiveSessionCard(_liveSessions[index]);
      },
    );
  }

  Widget _buildLiveSessionCard(Map<String, dynamic> session) {
    final channelName = session['channel_name']?.toString() ?? '';
    final user = session['user'] as Map<String, dynamic>?;
    final userName = user?['name']?.toString() ?? user?['username']?.toString() ?? 'Unknown';
    final userAvatar = user?['profile_avatar']?.toString() ?? user?['avatar']?.toString();
    final viewerCount = session['viewer_count'] ?? 0;
    final title = session['title']?.toString();
    final startedAt = session['started_at']?.toString();
    
    // Calculate duration
    String durationText = 'Just now';
    if (startedAt != null) {
      try {
        final startTime = DateTime.parse(startedAt);
        final now = DateTime.now();
        final difference = now.difference(startTime);
        
        if (difference.inMinutes < 1) {
          durationText = 'Just now';
        } else if (difference.inMinutes < 60) {
          durationText = '${difference.inMinutes}m ago';
        } else {
          final hours = difference.inHours;
          durationText = '${hours}h ${difference.inMinutes % 60}m ago';
        }
      } catch (e) {
        durationText = 'Live';
      }
    }

    return GestureDetector(
      onTap: () {
        if (channelName.isNotEmpty) {
          context.push('/live/$channelName', extra: {'sessionData': session});
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            color: Colors.red.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live indicator header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.2),
                    Colors.red.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    durationText,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar
                  Stack(
                    children: [
                      userAvatar != null && userAvatar.isNotEmpty
                          ? CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.transparent,
                              backgroundImage: NetworkImage(userAvatar),
                              onBackgroundImageError: (exception, stackTrace) {
                                // Handle error
                              },
                            )
                          : CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFB875FB),
                              child: Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                      // Live indicator on avatar
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F0F0F),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  
                  // User info and title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (title != null && title.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$viewerCount watching',
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
                  
                  // Watch button
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFB875FB).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (channelName.isNotEmpty) {
                            context.push('/live/$channelName', extra: {'sessionData': session});
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.black, size: 20),
                              SizedBox(width: 4),
                              Text(
                                'Watch',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCommunityDialog() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Create Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _createCommunityError = null;
                    });
                  },
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Basic Info
                  const Text(
                    'Step 1: Basic Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Community Name
                  TextField(
                    controller: _communityNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Community Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Enter community name...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFB875FB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: _communityDescriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Describe your community...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFB875FB), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Community Image
                  const Text(
                    'Community Image',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickCommunityImage,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: _communityImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _communityImage!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _communityImage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Image',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Step 2: Settings
                  const Text(
                    'Step 2: Community Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Join Policy
                  const Text(
                    'Join Policy',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _joinPolicy = 'open';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: _joinPolicy == 'open'
                                  ? const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    )
                                  : null,
                              color: _joinPolicy == 'open' ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _joinPolicy == 'open'
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Open',
                                  style: TextStyle(
                                    color: _joinPolicy == 'open' ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Anyone can join',
                                  style: TextStyle(
                                    color: _joinPolicy == 'open' ? Colors.white70 : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _joinPolicy = 'admin_approval';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: _joinPolicy == 'admin_approval'
                                  ? const LinearGradient(
                                      colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                                    )
                                  : null,
                              color: _joinPolicy == 'admin_approval' ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _joinPolicy == 'admin_approval'
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Approval',
                                  style: TextStyle(
                                    color: _joinPolicy == 'admin_approval' ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Admin approval',
                                  style: TextStyle(
                                    color: _joinPolicy == 'admin_approval' ? Colors.white70 : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Chat Policy
                  const Text(
                    'Chat Policy',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _chatPolicy = 'everyone';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: _chatPolicy == 'everyone'
                                  ? const LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                    )
                                  : null,
                              color: _chatPolicy == 'everyone' ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _chatPolicy == 'everyone'
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Everyone',
                                  style: TextStyle(
                                    color: _chatPolicy == 'everyone' ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All members can chat',
                                  style: TextStyle(
                                    color: _chatPolicy == 'everyone' ? Colors.white70 : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _chatPolicy = 'admin_only';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: _chatPolicy == 'admin_only'
                                  ? const LinearGradient(
                                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                    )
                                  : null,
                              color: _chatPolicy == 'admin_only' ? null : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _chatPolicy == 'admin_only'
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Admin Only',
                                  style: TextStyle(
                                    color: _chatPolicy == 'admin_only' ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Only admins can chat',
                                  style: TextStyle(
                                    color: _chatPolicy == 'admin_only' ? Colors.white70 : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Error Message
                  if (_createCommunityError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Text(
                        _createCommunityError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Create Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _creatingCommunity || _communityNameController.text.trim().isEmpty
                    ? null
                    : _createCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB875FB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: _creatingCommunity
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text(
                        'Create Community',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleContent() {
    final isLoading = _searchQuery.isNotEmpty ? _searching : _loading;
    
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
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
                  backgroundColor: const Color(0xFFB875FB),
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
                        colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
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
