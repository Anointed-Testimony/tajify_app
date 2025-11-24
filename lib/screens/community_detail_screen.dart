import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityUuid;

  const CommunityDetailScreen({
    super.key,
    required this.communityUuid,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _members = [];
  int? _currentUserId;
  bool _loading = true;
  bool _loadingMessages = true;
  bool _loadingMembers = false;
  bool _sendingMessage = false;
  bool _isMember = false;
  bool _isOwner = false;
  bool _showMembers = false;
  bool _showSettings = false;
  File? _selectedFile;
  Timer? _messagesTimer;
  StreamSubscription<QuerySnapshot>? _firebaseMessagesSubscription;
  bool _firebaseListenerActive = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _messagesTimer?.cancel();
    _firebaseMessagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      setState(() {
        _currentUserId = parsedId;
      });
      
      if (_currentUserId != null) {
        await _loadCommunity();
      }
    } catch (e) {
      print('[COMMUNITY] Error loading current user: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCommunity() async {
    try {
      setState(() {
        _loading = true;
      });

      final response = await _apiService.getCommunity(widget.communityUuid);
      if (response.statusCode == 200) {
        Map<String, dynamic>? communityData;
        if (response.data['success'] == true && response.data['data'] != null) {
          communityData = response.data['data'];
        } else if (response.data['uuid'] != null) {
          communityData = response.data;
        }

        if (communityData != null) {
          setState(() {
            _community = communityData;
            final ownerId = communityData?['owner_id'];
            final owner = communityData?['owner'] as Map<String, dynamic>?;
            _isOwner = _currentUserId != null && 
                      (ownerId == _currentUserId || 
                       owner?['id'] == _currentUserId);
          });

          // Check membership first and wait for it to complete
          await _checkMembership();
          
          // Set up Firebase listener for real-time messages (like web version)
          await _setupFirebaseListener();
          
          // Load members
          await _loadMembers();
        }
      }
    } catch (e) {
      print('[COMMUNITY] Error loading community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading community: ${e.toString()}'),
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

  Future<void> _checkMembership() async {
    if (_currentUserId == null || _community == null) {
      print('[COMMUNITY] Cannot check membership: userId=$_currentUserId, community=${_community != null}');
      return;
    }

    try {
      print('[COMMUNITY] Checking membership for user $_currentUserId in community ${widget.communityUuid}');
      final membersResponse = await _apiService.getCommunityMembers(widget.communityUuid);
      print('[COMMUNITY] Membership response status: ${membersResponse.statusCode}');
      print('[COMMUNITY] Membership response data: ${membersResponse.data}');
      
      if (membersResponse.statusCode == 200) {
        List<dynamic> membersList = [];
        if (membersResponse.data['success'] == true && membersResponse.data['data'] != null) {
          membersList = membersResponse.data['data'];
        } else if (membersResponse.data is List) {
          membersList = membersResponse.data;
        } else if (membersResponse.data['data'] is List) {
          membersList = membersResponse.data['data'];
        }

        print('[COMMUNITY] Found ${membersList.length} members');
        
        final isMember = membersList.any((member) {
          final memberMap = member as Map<String, dynamic>;
          final userId = memberMap['user_id'] ?? 
                        memberMap['user']?['id'] ??
                        (memberMap['user'] as Map<String, dynamic>?)?['id'];
          final matches = userId == _currentUserId;
          if (matches) {
            print('[COMMUNITY] Found matching member: userId=$userId');
          }
          return matches;
        });

        print('[COMMUNITY] Is member: $isMember');
        setState(() {
          _isMember = isMember;
        });
      }
    } catch (e) {
      print('[COMMUNITY] Error checking membership: $e');
      // If membership check fails, still try to load messages (might be open community)
      setState(() {
        _isMember = false;
      });
    }
  }

  Future<void> _setupFirebaseListener() async {
    // Only set up if member or owner
    if (!_isMember && !_isOwner) {
      print('[COMMUNITY] Not a member, skipping Firebase listener');
      setState(() {
        _loadingMessages = false;
      });
      return;
    }

    try {
      print('[COMMUNITY] Setting up Firebase listener for community ${widget.communityUuid}');
      
      // Initialize Firebase
      final firebaseInit = await FirebaseService.initialize();
      if (!firebaseInit) {
        print('[COMMUNITY] Firebase initialization failed, falling back to API');
        await _loadMessages();
        // Set up polling as fallback
        _messagesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (!_firebaseListenerActive) {
            _loadMessages();
          }
        });
        return;
      }

      // Initialize Firebase Auth
      final authInit = await FirebaseService.initializeAuth();
      if (!authInit) {
        print('[COMMUNITY] Firebase auth initialization failed, falling back to API');
        await _loadMessages();
        _messagesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (!_firebaseListenerActive) {
            _loadMessages();
          }
        });
        return;
      }

      // Set up Firebase listener
      _firebaseMessagesSubscription = FirebaseService
          .getCommunityMessagesStream(widget.communityUuid)
          .listen(
        (snapshot) {
          print('[COMMUNITY] Firebase snapshot received with ${snapshot.docs.length} messages');
          _firebaseListenerActive = true;
          
          // Cancel API polling if Firebase is working
          _messagesTimer?.cancel();
          _messagesTimer = null;

          final messagesList = <Map<String, dynamic>>[];
          
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Handle timestamp conversion
            String? createdAt;
            if (data['created_at'] != null) {
              if (data['created_at'] is Timestamp) {
                createdAt = (data['created_at'] as Timestamp).toDate().toIso8601String();
              } else {
                createdAt = data['created_at'].toString();
              }
            }

            messagesList.add({
              'id': doc.id,
              'user_id': data['user_id'],
              'user': {
                'name': data['user_name'] ?? 'Unknown User',
                'username': data['user_username'] ?? '@user',
                'avatar': data['user_avatar'],
              },
              'content': data['content'],
              'media_url': data['media_url'],
              'media_type': data['media_type'],
              'created_at': createdAt ?? DateTime.now().toIso8601String(),
            });
          }

          // Sort by created_at
          messagesList.sort((a, b) {
            final timeA = a['created_at']?.toString() ?? '';
            final timeB = b['created_at']?.toString() ?? '';
            return timeA.compareTo(timeB);
          });

          print('[COMMUNITY] Processed ${messagesList.length} messages from Firebase');
          
          setState(() {
            _messages = messagesList;
            _loadingMessages = false;
          });

          // Scroll to bottom
          if (_scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        },
        onError: (error) {
          print('[COMMUNITY] Firebase listener error: $error');
          _firebaseListenerActive = false;
          
          // Fall back to API
          _loadMessages();
          _messagesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
            if (!_firebaseListenerActive) {
              _loadMessages();
            }
          });
        },
      );

      print('[COMMUNITY] Firebase listener set up successfully');
    } catch (e) {
      print('[COMMUNITY] Error setting up Firebase listener: $e');
      _firebaseListenerActive = false;
      
      // Fall back to API
      await _loadMessages();
      _messagesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_firebaseListenerActive) {
          _loadMessages();
        }
      });
    }
  }

  Future<void> _loadMessages() async {
    // Allow loading messages if member, owner, or if community is open (chat_policy is 'everyone')
    final chatPolicy = _community?['chat_policy']?.toString() ?? 'everyone';
    final canViewMessages = _isMember || _isOwner || chatPolicy == 'everyone';
    
    if (!canViewMessages) {
      print('[COMMUNITY] Cannot load messages: isMember=$_isMember, isOwner=$_isOwner, chatPolicy=$chatPolicy');
      setState(() {
        _loadingMessages = false;
      });
      return;
    }

    try {
      print('[COMMUNITY] Loading messages for community ${widget.communityUuid}');
      final response = await _apiService.getCommunityMessages(widget.communityUuid);
      print('[COMMUNITY] Messages response status: ${response.statusCode}');
      print('[COMMUNITY] Messages response data: ${response.data}');
      print('[COMMUNITY] Messages response data type: ${response.data.runtimeType}');
      if (response.data is Map) {
        print('[COMMUNITY] Response data keys: ${(response.data as Map).keys}');
        if (response.data['data'] != null) {
          print('[COMMUNITY] Response.data.data type: ${response.data['data'].runtimeType}');
          if (response.data['data'] is Map) {
            print('[COMMUNITY] Response.data.data keys: ${(response.data['data'] as Map).keys}');
          }
        }
      }
      
      if (response.statusCode == 200) {
        List<dynamic> messagesList = [];
        
        // Handle different response formats exactly like web version
        if (response.data['success'] == true && response.data['data'] != null) {
          final data = response.data['data'];
          // Check if it's a paginated response (Laravel pagination has 'data' key inside)
          if (data is Map<String, dynamic> && data.containsKey('data') && data['data'] is List) {
            // Paginated response: {success: true, data: {data: [...], current_page: 1, ...}}
            messagesList = data['data'] as List<dynamic>;
            print('[COMMUNITY] Found paginated response with ${messagesList.length} messages');
          } else if (data is List) {
            // Direct list: {success: true, data: [...]}
            messagesList = data;
            print('[COMMUNITY] Found direct list with ${messagesList.length} messages');
          }
        } else if (response.data is List) {
          // Response is directly a list
          messagesList = response.data as List<dynamic>;
          print('[COMMUNITY] Response is direct list with ${messagesList.length} messages');
        } else if (response.data['data'] != null && response.data['data'] is List) {
          // Fallback: {data: [...]}
          messagesList = response.data['data'] as List<dynamic>;
          print('[COMMUNITY] Found messages in data key: ${messagesList.length} messages');
        }

        print('[COMMUNITY] Total messages to process: ${messagesList.length}');

        // Transform messages to match expected format (exactly like web version)
        final formattedMessages = messagesList.map((message) {
          // Handle dynamic message object
          final msgMap = message is Map<String, dynamic> 
              ? message 
              : Map<String, dynamic>.from(message as Map);
          
          // Extract user info (handle nested user object or flat fields)
          final userData = msgMap['user'];
          final userName = userData is Map<String, dynamic> 
              ? (userData['name'] ?? msgMap['user_name'] ?? 'Unknown User')
              : (msgMap['user_name'] ?? 'Unknown User');
          final userUsername = userData is Map<String, dynamic>
              ? (userData['username'] ?? msgMap['user_username'] ?? '@user')
              : (msgMap['user_username'] ?? '@user');
          final userAvatar = userData is Map<String, dynamic>
              ? (userData['profile_avatar'] ?? userData['avatar'] ?? msgMap['user_avatar'])
              : msgMap['user_avatar'];
          
          return {
            'id': msgMap['id'] ?? msgMap['uuid'],
            'user_id': msgMap['user_id'],
            'user': {
              'name': userName,
              'username': userUsername,
              'avatar': userAvatar,
            },
            'content': msgMap['content'],
            'media_url': msgMap['media_url'],
            'media_type': msgMap['media_type'],
            'created_at': msgMap['created_at'],
            'updated_at': msgMap['updated_at'],
          };
        }).toList();

        // Sort messages by created_at to ensure proper order
        formattedMessages.sort((a, b) {
          final timeA = a['created_at']?.toString() ?? '';
          final timeB = b['created_at']?.toString() ?? '';
          return timeA.compareTo(timeB);
        });

        print('[COMMUNITY] Formatted ${formattedMessages.length} messages');
        setState(() {
          _messages = formattedMessages;
          _loadingMessages = false;
        });

        // Scroll to bottom
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      } else {
        print('[COMMUNITY] Unexpected response status: ${response.statusCode}');
        setState(() {
          _loadingMessages = false;
        });
      }
    } catch (e) {
      print('[COMMUNITY] Error loading messages: $e');
      print('[COMMUNITY] Error stack trace: ${StackTrace.current}');
      setState(() {
        _loadingMessages = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    try {
      setState(() {
        _loadingMembers = true;
      });

      final response = await _apiService.getCommunityMembers(widget.communityUuid);
      if (response.statusCode == 200) {
        List<dynamic> membersList = [];
        if (response.data['success'] == true && response.data['data'] != null) {
          membersList = response.data['data'];
        } else if (response.data is List) {
          membersList = response.data;
        }

        final formattedMembers = membersList.map((member) {
          final user = member['user'] ?? {};
          return {
            'id': user['id'] ?? member['user_id'],
            'name': user['name'] ?? 'Unknown User',
            'username': user['username'] ?? '@user',
            'avatar': user['profile_avatar'],
            'role': member['role'] ?? 'member',
          };
        }).toList();

        setState(() {
          _members = formattedMembers;
        });
      }
    } catch (e) {
      print('[COMMUNITY] Error loading members: $e');
    } finally {
      setState(() {
        _loadingMembers = false;
      });
    }
  }

  Future<void> _joinCommunity() async {
    try {
      final response = await _apiService.post('/communities/${widget.communityUuid}/join');
      if (response.statusCode == 200) {
        setState(() {
          _isMember = true;
        });
        // Set up Firebase listener after joining
        await _setupFirebaseListener();
        await _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined community'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('[COMMUNITY] Error joining community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining community: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Leave Community',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to leave this community?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await _apiService.leaveCommunity(widget.communityUuid);
      if (response.statusCode == 200) {
        // Cancel Firebase listener
        _firebaseMessagesSubscription?.cancel();
        _firebaseMessagesSubscription = null;
        _firebaseListenerActive = false;
        _messagesTimer?.cancel();
        _messagesTimer = null;
        
        setState(() {
          _isMember = false;
          _messages = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left community'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('[COMMUNITY] Error leaving community: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving community: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      print('[COMMUNITY] Error picking file: $e');
    }
  }

  Future<void> _sendMessage() async {
    if ((_messageController.text.trim().isEmpty && _selectedFile == null) || !_isMember || _currentUserId == null) {
      return;
    }

    setState(() {
      _sendingMessage = true;
    });

    String? mediaUrl;
    String? mediaType;

    try {
      // First, send to API (for backend storage and media upload)
      if (_selectedFile != null) {
        await _apiService.sendCommunityMessage(
          widget.communityUuid,
          content: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
          media: _selectedFile,
        );
        // Note: API response should contain media_url, but we'll get it from Firebase listener
      } else if (_messageController.text.trim().isNotEmpty) {
        await _apiService.sendCommunityMessage(
          widget.communityUuid,
          content: _messageController.text.trim(),
        );
      }

      // Get current user profile for Firebase
      Map<String, dynamic>? userProfile;
      try {
        final profileResponse = await _apiService.getProfile();
        if (profileResponse.statusCode == 200 && profileResponse.data['success'] == true) {
          userProfile = profileResponse.data['data'];
        }
      } catch (e) {
        print('[COMMUNITY] Error fetching user profile: $e');
      }

      final userName = userProfile?['name']?.toString() ?? 'Unknown User';
      final userUsername = userProfile?['username']?.toString() ?? '@user';
      final userAvatar = userProfile?['profile_avatar']?.toString();

      // Also save to Firebase for real-time updates (like web version)
      try {
        await FirebaseService.sendCommunityMessage(
          communityUuid: widget.communityUuid,
          userId: _currentUserId!,
          userName: userName,
          userUsername: userUsername,
          userAvatar: userAvatar,
          content: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );
        print('[COMMUNITY] Message saved to Firebase');
      } catch (firebaseError) {
        print('[COMMUNITY] Error saving to Firebase (non-critical): $firebaseError');
        // Firebase save is optional - message already saved via API
      }

      _messageController.clear();
      setState(() {
        _selectedFile = null;
      });

      // Messages will update automatically via Firebase listener
      // No need to manually reload
    } catch (e) {
      print('[COMMUNITY] Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _sendingMessage = false;
      });
    }
  }

  String _getUserInitial(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String? _getCommunityImage() {
    return _community?['image'] ?? 
           _community?['image_url'] ?? 
           _community?['cover_image'];
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
            ),
          ),
        ),
      );
    }

    if (_community == null) {
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
            child: Text(
              'Community not found',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final communityImage = _getCommunityImage();
    final communityName = _community!['name']?.toString() ?? 'Unknown Community';
    final membersCount = _community!['members_count'] ?? _members.length;
    final joinPolicy = _community!['join_policy']?.toString() ?? 'open';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/connect');
              }
            },
          ),
        ),
        title: Row(
          children: [
            // Community Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: communityImage != null && communityImage.isNotEmpty
                    ? Image.network(
                        communityImage,
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
                            child: Icon(
                              joinPolicy == 'open' ? Icons.public : Icons.lock,
                              color: Colors.white,
                              size: 18,
                            ),
                          );
                        },
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                          ),
                        ),
                        child: Icon(
                          joinPolicy == 'open' ? Icons.public : Icons.lock,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    communityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$membersCount members',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Join/Leave Button
          if (!_isMember && !_isOwner)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _joinCommunity,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Text(
                      'Join',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (_isMember && !_isOwner)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _leaveCommunity,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Text(
                      'Leave',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isMember || _isOwner)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.people, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _showMembers = !_showMembers;
                  });
                },
              ),
            ),
          if (_isOwner)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _showSettings = !_showSettings;
                  });
                },
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        child: Column(
          children: [

          // Messages Section
          if (_isMember || _isOwner)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Messages List
                    Expanded(
                      child: _loadingMessages
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading messages...',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _messages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.grey[500],
                                          size: 48,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No messages yet',
                                        style: TextStyle(
                                          color: Colors.grey[300],
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Be the first to send a message!',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final message = _messages[index];
                                      final isMe = message['user_id'] == _currentUserId;
                                      final user = message['user'] as Map<String, dynamic>;
                                      final avatar = user['avatar'];
                                      final name = user['name'] ?? 'Unknown';
                                      final content = message['content']?.toString() ?? '';
                                      final mediaUrl = message['media_url']?.toString();
                                      final mediaType = message['media_type']?.toString() ?? '';

                                      return Container(
                                        margin: EdgeInsets.only(
                                          bottom: 16,
                                          left: isMe ? 40 : 0,
                                          right: isMe ? 0 : 40,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: isMe
                                              ? MainAxisAlignment.end
                                              : MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (!isMe) ...[
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.2),
                                                    width: 2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: avatar != null && avatar.isNotEmpty
                                                    ? CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor: Colors.transparent,
                                                        backgroundImage: NetworkImage(avatar),
                                                        onBackgroundImageError: (_, __) {},
                                                      )
                                                    : CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor: const Color(0xFFFFB800),
                                                        child: Text(
                                                          _getUserInitial(user),
                                                          style: const TextStyle(
                                                            color: Colors.black,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  gradient: isMe
                                                      ? const LinearGradient(
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                          colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                                        )
                                                      : null,
                                                  color: isMe ? null : Colors.white.withOpacity(0.08),
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: const Radius.circular(20),
                                                    topRight: const Radius.circular(20),
                                                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                                                    bottomRight: Radius.circular(isMe ? 4 : 20),
                                                  ),
                                                  border: isMe
                                                      ? null
                                                      : Border.all(
                                                          color: Colors.white.withOpacity(0.1),
                                                          width: 1,
                                                        ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: isMe
                                                          ? Colors.amber.withOpacity(0.3)
                                                          : Colors.black.withOpacity(0.2),
                                                      blurRadius: 12,
                                                      spreadRadius: 0,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (!isMe)
                                                      Padding(
                                                        padding: const EdgeInsets.only(bottom: 6),
                                                        child: Text(
                                                          name,
                                                          style: TextStyle(
                                                            color: isMe ? Colors.black : Colors.white,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.3,
                                                          ),
                                                        ),
                                                      ),
                                                    if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
                                                      if (mediaType.contains('image'))
                                                        ClipRRect(
                                                          borderRadius: BorderRadius.circular(12),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(12),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.3),
                                                                  blurRadius: 8,
                                                                  spreadRadius: 0,
                                                                ),
                                                              ],
                                                            ),
                                                            child: Image.network(
                                                              mediaUrl,
                                                              width: 220,
                                                              height: 220,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        )
                                                      else if (mediaType.contains('video'))
                                                        Container(
                                                          width: 220,
                                                          height: 160,
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.4),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Colors.white.withOpacity(0.1),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.play_circle_filled,
                                                              color: Colors.white,
                                                              size: 56,
                                                            ),
                                                          ),
                                                        )
                                                      else
                                                        Container(
                                                          padding: const EdgeInsets.all(14),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black.withOpacity(0.3),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Colors.white.withOpacity(0.1),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.all(8),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white.withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: const Icon(
                                                                  Icons.attach_file,
                                                                  color: Colors.white,
                                                                  size: 20,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Flexible(
                                                                child: Text(
                                                                  'Media file',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      if (content.isNotEmpty) const SizedBox(height: 10),
                                                    ],
                                                    if (content.isNotEmpty)
                                                      Text(
                                                        content,
                                                        style: TextStyle(
                                                          color: isMe ? Colors.black : Colors.white,
                                                          fontSize: 14.5,
                                                          height: 1.4,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 10),
                                              Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.2),
                                                    width: 2,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: avatar != null && avatar.isNotEmpty
                                                    ? CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor: Colors.transparent,
                                                        backgroundImage: NetworkImage(avatar),
                                                        onBackgroundImageError: (_, __) {},
                                                      )
                                                    : CircleAvatar(
                                                        radius: 18,
                                                        backgroundColor: const Color(0xFFFFB800),
                                                        child: Text(
                                                          _getUserInitial(user),
                                                          style: const TextStyle(
                                                            color: Colors.black,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),

                    // Modern Message Input
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_selectedFile != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB800).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.attach_file, color: Color(0xFFFFB800), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFile!.path.split('/').last,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ready to send',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFile = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.attach_file, color: Colors.white, size: 22),
                                  onPressed: _pickFile,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _messageController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 15,
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                    ),
                                    maxLines: null,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _sendingMessage ? null : _sendMessage,
                                    borderRadius: BorderRadius.circular(50),
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      alignment: Alignment.center,
                                      child: _sendingMessage
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                              ),
                                            )
                                          : const Icon(Icons.send, color: Colors.black, size: 22),
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
              ),
            )
          else
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Center(
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
                            color: Colors.white.withOpacity(0.15),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[400],
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Join to see messages',
                        style: TextStyle(
                          color: Colors.grey[200],
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Join this community to view and send messages',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Members Sidebar
      endDrawer: _showMembers
          ? Drawer(
              backgroundColor: const Color(0xFF1A1A1A),
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _showMembers = false;
                        });
                      },
                    ),
                    title: const Text(
                      'Members',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: _loadingMembers
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                            ),
                          )
                        : _members.isEmpty
                            ? const Center(
                                child: Text(
                                  'No members',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _members.length,
                                itemBuilder: (context, index) {
                                  final member = _members[index];
                                  final avatar = member['avatar'];
                                  return ListTile(
                                    leading: avatar != null && avatar.isNotEmpty
                                        ? CircleAvatar(
                                            backgroundImage: NetworkImage(avatar),
                                            onBackgroundImageError: (_, __) {},
                                          )
                                        : CircleAvatar(
                                            backgroundColor: const Color(0xFFFFB800),
                                            child: Text(
                                              _getUserInitial(member),
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                    title: Text(
                                      member['name'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      member['username'] ?? '@user',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                    trailing: member['role'] == 'admin' || member['role'] == 'owner'
                                        ? Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 20,
                                          )
                                        : null,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

