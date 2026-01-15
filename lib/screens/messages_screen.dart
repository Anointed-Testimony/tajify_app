import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  int? _currentUserId;
  int? _selectedUserId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;
  StreamSubscription<QuerySnapshot>? _receiverMessagesSubscription;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _searchResults = [];
  Map<int, Map<String, dynamic>> _userCache = {};
  bool _loading = true;
  bool _sendingMessage = false;
  bool _showNewChat = false;
  bool _searching = false;
  String? _indexCreationUrl;
  File? _selectedFile;
  bool _canSendMessage = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_updateSendButtonState);
    _loadCurrentUser();
  }

  void _updateSendButtonState() {
    final canSend = _messageController.text.trim().isNotEmpty || _selectedFile != null;
    if (_canSendMessage != canSend) {
      setState(() {
        _canSendMessage = canSend;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final storedId = await _storageService.getUserId();
      final parsedId = storedId != null ? int.tryParse(storedId) : null;
      setState(() {
        _currentUserId = parsedId;
      });
      
      if (_currentUserId != null) {
        await _initializeFirebase();
        _loadConversations();
      }
    } catch (e) {
      print('[MESSAGES] Error loading current user: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  // Fetch conversations from API (like web)
  Future<void> _fetchConversationsFromAPI() async {
    try {
      print('[MESSAGES DEBUG] Fetching conversations from API...');
      final response = await _apiService.getConversations();
      print('[MESSAGES DEBUG] Conversations response status: ${response.statusCode}');
      
      // Handle different response formats (like web does)
      List<Map<String, dynamic>> conversations = [];
      if (response.data['success'] == true && response.data['data'] != null) {
        conversations = List<Map<String, dynamic>>.from(response.data['data']);
      } else if (response.data is List) {
        conversations = List<Map<String, dynamic>>.from(response.data);
      } else if (response.data['data'] != null && response.data['data'] is List) {
        conversations = List<Map<String, dynamic>>.from(response.data['data']);
      }
      
      print('[MESSAGES DEBUG] Found ${conversations.length} conversations from API');
      
      // Transform conversations to match expected format
      final transformedConversations = <Map<String, dynamic>>[];
      for (var conv in conversations) {
        final user = conv['user'] as Map<String, dynamic>?;
        final latestMessage = conv['latest_message'] as Map<String, dynamic>?;
        final unreadCount = conv['unread_count'] as int? ?? 0;
        
        if (user != null) {
          transformedConversations.add({
            'user_id': user['id'] as int,
            'last_message': latestMessage?['content']?.toString() ?? '',
            'last_message_time': latestMessage?['created_at'] != null
                ? _parseTimestamp(latestMessage!['created_at'])
                : null,
            'is_read': unreadCount == 0,
            'unread_count': unreadCount,
            'is_sent_by_me': latestMessage?['is_sent_by_me'] ?? false,
          });
          
          // Cache user details
          _userCache[user['id'] as int] = user;
        }
      }
      
      setState(() {
        _conversations = transformedConversations;
        _loading = false;
      });
    } catch (e) {
      print('[MESSAGES DEBUG] Error fetching conversations from API: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _initializeFirebase() async {
    print('[MESSAGES DEBUG] Initializing Firebase...');
    try {
      final initialized = await FirebaseService.initialize();
      print('[MESSAGES DEBUG] Firebase initialized: $initialized');
      if (initialized) {
        print('[MESSAGES DEBUG] Initializing Firebase Auth...');
        final authInitialized = await FirebaseService.initializeAuth();
        print('[MESSAGES DEBUG] Firebase auth initialized: $authInitialized');
        if (!authInitialized) {
          print('[MESSAGES DEBUG] ⚠️ Auth initialization failed, but continuing...');
        }
      } else {
        print('[MESSAGES DEBUG] ⚠️ Firebase initialization failed');
      }
    } catch (e, stackTrace) {
      print('[MESSAGES DEBUG] ❌ Firebase initialization error: $e');
      print('[MESSAGES DEBUG] Error type: ${e.runtimeType}');
      print('[MESSAGES DEBUG] Stack trace: $stackTrace');
    }
  }

  void _loadConversations() {
    print('[MESSAGES DEBUG] _loadConversations called');
    print('[MESSAGES DEBUG] _currentUserId: $_currentUserId');
    
    if (_currentUserId == null) {
      print('[MESSAGES DEBUG] Cannot load conversations - user ID not ready');
      setState(() {
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    // Fetch from API first (like web does)
    _fetchConversationsFromAPI();
    
    // Then set up Firebase listener for real-time updates (like web does)
    if (FirebaseService.isInitialized) {
      try {
        _conversationsSubscription?.cancel();
        print('[MESSAGES DEBUG] Setting up Firebase conversations stream listener for real-time updates...');
        
        // Use separate queries to avoid needing Firestore composite indexes
        final conversationsMap = <int, Map<String, dynamic>>{};
        int activeStreams = 0;
        bool hasError = false;
        
        // Stream 1: Messages where user is sender
        final senderSubscription = FirebaseService.getConversationsStream(_currentUserId!)
            .listen((snapshot) {
          print('[MESSAGES DEBUG] Sender messages snapshot: ${snapshot.docs.length} docs');
          _processMessagesSnapshot(snapshot, conversationsMap, true);
          activeStreams++;
          if (activeStreams >= 2 && !hasError) {
            _finalizeConversationsFromFirebase(conversationsMap);
          }
        }, onError: (error) {
          print('[MESSAGES DEBUG] ❌ Error in sender stream: $error');
          hasError = true;
          if (activeStreams >= 1) {
            _finalizeConversationsFromFirebase(conversationsMap);
          }
        });
        
        // Stream 2: Messages where user is receiver
        _receiverMessagesSubscription = FirebaseService.getReceiverMessagesStream(_currentUserId!)
            .listen((snapshot) {
          print('[MESSAGES DEBUG] Receiver messages snapshot: ${snapshot.docs.length} docs');
          _processMessagesSnapshot(snapshot, conversationsMap, false);
          activeStreams++;
          if (activeStreams >= 2 && !hasError) {
            _finalizeConversationsFromFirebase(conversationsMap);
          }
        }, onError: (error) {
          print('[MESSAGES DEBUG] ❌ Error in receiver stream: $error');
          hasError = true;
          if (activeStreams >= 1) {
            _finalizeConversationsFromFirebase(conversationsMap);
          }
        });
        
        // Store sender subscription so we can cancel it
        _conversationsSubscription = senderSubscription;
      } catch (e, stackTrace) {
        print('[MESSAGES DEBUG] ❌ Error setting up Firebase conversations stream: $e');
        print('[MESSAGES DEBUG] Stack trace: $stackTrace');
        // Continue without Firebase - API will work
      }
    }
  }
  
  void _finalizeConversationsFromFirebase(Map<int, Map<String, dynamic>> conversationsMap) {
    // Merge Firebase updates with API data
    final conversationsList = conversationsMap.values.toList();
    conversationsList.sort((a, b) {
      final timeA = a['last_message_time'] as Timestamp?;
      final timeB = b['last_message_time'] as Timestamp?;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });
    
    print('[MESSAGES DEBUG] Processed ${conversationsList.length} conversations from Firebase');
    
    // Update conversations with Firebase real-time data
    setState(() {
      // Merge Firebase data with existing API data
      for (var firebaseConv in conversationsList) {
        final userId = firebaseConv['user_id'] as int;
        final existingIndex = _conversations.indexWhere((c) => c['user_id'] == userId);
        if (existingIndex >= 0) {
          // Update existing conversation
          _conversations[existingIndex] = firebaseConv;
        } else {
          // Add new conversation
          _conversations.add(firebaseConv);
        }
      }
      
      // Re-sort after merge
      _conversations.sort((a, b) {
        final timeA = a['last_message_time'] as Timestamp?;
        final timeB = b['last_message_time'] as Timestamp?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });
    });
    
    // Load user details for new conversations
    for (var conv in conversationsList) {
      _loadUserDetails(conv['user_id'] as int);
    }
  }
  
  void _processMessagesSnapshot(QuerySnapshot snapshot, Map<int, Map<String, dynamic>> conversationsMap, bool isSender) {
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['sender_id'] as int?;
      final receiverId = data['receiver_id'] as int?;
      
      // Determine the other user in the conversation
      final otherUserId = isSender ? receiverId : senderId;
      if (otherUserId == null) continue;
      
      // Get the latest message for this conversation
      final existing = conversationsMap[otherUserId];
      final currentTimestamp = data['created_at'] as Timestamp?;
      final existingTimestamp = existing?['last_message_time'] as Timestamp?;
      if (existing == null || 
          (currentTimestamp != null && existingTimestamp != null && currentTimestamp.compareTo(existingTimestamp) > 0) ||
          (currentTimestamp != null && existingTimestamp == null)) {
        conversationsMap[otherUserId] = {
          'user_id': otherUserId,
          'last_message': data['content']?.toString() ?? '',
          'last_message_time': data['created_at'],
          'is_read': data['is_read'] ?? false,
          'sender_id': senderId,
        };
      }
    }
  }
  
  
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    
    setState(() {
      _searching = true;
    });
    
    try {
      print('[MESSAGES DEBUG] Searching users with query: $query');
      // Use the direct messages search endpoint (like web does)
      final response = await _apiService.searchUsersForMessages(query);
      print('[MESSAGES DEBUG] Search response status: ${response.statusCode}');
      
      // Handle different response formats (like web does)
      List<Map<String, dynamic>> users = [];
      if (response.data['success'] == true && response.data['data'] != null) {
        users = List<Map<String, dynamic>>.from(response.data['data']);
      } else if (response.data is List) {
        users = List<Map<String, dynamic>>.from(response.data);
      } else if (response.data['data'] != null && response.data['data'] is List) {
        users = List<Map<String, dynamic>>.from(response.data['data']);
      }
      
      // Filter out current user
      final filteredUsers = users.where((user) => user['id'] != _currentUserId).toList();
      print('[MESSAGES DEBUG] Found ${filteredUsers.length} users');
      
      setState(() {
        _searchResults = filteredUsers;
        _searching = false;
      });
    } catch (e) {
      print('[MESSAGES DEBUG] Error searching users: $e');
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    }
  }
  
  void _startChatWithUser(Map<String, dynamic> user) {
    final userId = user['id'] as int?;
    if (userId == null) return;
    
    print('[MESSAGES DEBUG] Starting chat with user: $userId');
    setState(() {
      _selectedUserId = userId;
      _showNewChat = false;
      _searchController.clear();
      _searchResults = [];
      _messages = [];
    });
    
    _userCache[userId] = user;
    _loadMessages(userId);
  }

  Future<void> _loadUserDetails(int userId) async {
    if (_userCache.containsKey(userId)) {
      print('[MESSAGES DEBUG] User $userId already in cache');
      return;
    }
    
    print('[MESSAGES DEBUG] Loading user details for userId: $userId');
    try {
      final response = await _apiService.get('/users/$userId');
      print('[MESSAGES DEBUG] User details response status: ${response.statusCode}');
      print('[MESSAGES DEBUG] User details response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final userData = response.data['data'];
        print('[MESSAGES DEBUG] User data loaded: ${userData['name'] ?? userData['username']}');
        print('[MESSAGES DEBUG] Profile avatar: ${userData['profile_avatar']}');
        print('[MESSAGES DEBUG] Profile photo URL: ${userData['profile_photo_url']}');
        
        setState(() {
          _userCache[userId] = userData;
        });
      } else {
        print('[MESSAGES DEBUG] Failed to load user details: ${response.data}');
      }
    } catch (e, stackTrace) {
      print('[MESSAGES DEBUG] ❌ Error loading user details for $userId: $e');
      print('[MESSAGES DEBUG] Stack trace: $stackTrace');
    }
  }

  void _openConversation(int userId) {
    setState(() {
      _selectedUserId = userId;
      _messages = [];
    });
    
    _loadUserDetails(userId);
    _loadMessages(userId);
  }

  // Fetch messages from API (like web does)
  Future<void> _fetchMessagesFromAPI(int otherUserId) async {
    try {
      print('[MESSAGES DEBUG] Fetching messages from API for user: $otherUserId');
      final response = await _apiService.getMessages(otherUserId);
      print('[MESSAGES DEBUG] Messages response status: ${response.statusCode}');
      
      // Handle different response formats (like web does)
      List<Map<String, dynamic>> messages = [];
      if (response.data['success'] == true && response.data['data'] != null) {
        messages = List<Map<String, dynamic>>.from(response.data['data']);
      } else if (response.data is List) {
        messages = List<Map<String, dynamic>>.from(response.data);
      } else if (response.data['data'] != null && response.data['data'] is List) {
        messages = List<Map<String, dynamic>>.from(response.data['data']);
      }
      
      // Transform messages to match expected format
      final transformedMessages = messages.map((msg) {
        return {
          'id': msg['id']?.toString() ?? msg['uuid']?.toString() ?? '',
          'sender_id': msg['sender_id'] as int?,
          'receiver_id': msg['receiver_id'] as int?,
          'content': msg['content']?.toString(),
          'media_url': msg['media_url']?.toString(),
          'media_type': msg['media_type']?.toString(),
          'is_read': msg['is_read'] ?? false,
          'created_at': msg['created_at'] != null
              ? _parseTimestamp(msg['created_at'])
              : null,
        };
      }).toList();
      
      print('[MESSAGES DEBUG] Processed ${transformedMessages.length} messages from API');
      setState(() {
        _messages = transformedMessages;
      });
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('[MESSAGES DEBUG] Error fetching messages from API: $e');
    }
  }

  void _loadMessages(int otherUserId) {
    print('[MESSAGES DEBUG] _loadMessages called for user: $otherUserId');
    print('[MESSAGES DEBUG] _currentUserId: $_currentUserId');
    
    if (_currentUserId == null) {
      print('[MESSAGES DEBUG] Cannot load messages - user ID not ready');
      return;
    }
    
    // Fetch from API first (like web does)
    _fetchMessagesFromAPI(otherUserId);
    
    // Then set up Firebase listener for real-time updates (like web does)
    if (FirebaseService.isInitialized) {
      _messagesSubscription?.cancel();
      print('[MESSAGES DEBUG] Setting up Firebase messages stream listener for real-time updates...');
      _messagesSubscription = FirebaseService.getMessagesStream(_currentUserId!, otherUserId)
          .listen((snapshot) {
        print('[MESSAGES DEBUG] Messages stream snapshot received: ${snapshot.docs.length} messages');
        final messages = <Map<String, dynamic>>[];
        
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          messages.add({
            'id': doc.id,
            ...data,
          });
        }
        
        print('[MESSAGES DEBUG] Processed ${messages.length} messages from Firebase');
        setState(() {
          _messages = messages;
        });
        
        // Mark messages as read
        for (var message in messages) {
          if (message['receiver_id'] == _currentUserId && 
              (message['is_read'] == false || message['is_read'] == null)) {
            print('[MESSAGES DEBUG] Marking message as read: ${message['id']}');
            FirebaseService.markMessageAsRead(message['id'] as String);
          }
        }
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }, onError: (error) {
        print('[MESSAGES DEBUG] ❌ Error loading messages from Firebase: $error');
        print('[MESSAGES DEBUG] Error type: ${error.runtimeType}');
        // Continue with API - Firebase is optional for real-time updates
      });
    }
  }

  Future<void> _sendMessage() async {
    print('[MESSAGES DEBUG] _sendMessage called');
    print('[MESSAGES DEBUG] _currentUserId: $_currentUserId');
    print('[MESSAGES DEBUG] _selectedUserId: $_selectedUserId');
    print('[MESSAGES DEBUG] Message text: ${_messageController.text}');
    print('[MESSAGES DEBUG] Selected file: $_selectedFile');
    
    if (_currentUserId == null || _selectedUserId == null) {
      print('[MESSAGES DEBUG] ❌ Cannot send - missing user IDs');
      return;
    }
    if (_messageController.text.trim().isEmpty && _selectedFile == null) {
      print('[MESSAGES DEBUG] ❌ Cannot send - empty message and no file');
      return;
    }
    if (_sendingMessage) {
      print('[MESSAGES DEBUG] ❌ Already sending message');
      return;
    }
    
    setState(() {
      _sendingMessage = true;
    });
    
    try {
      final messageContent = _messageController.text.trim();
      String? mediaUrl;
      String? mediaType;
      
      // Send via API first (like web does)
      print('[MESSAGES DEBUG] Sending message via API...');
      Response response;
      
      if (_selectedFile != null) {
        // Send media message
        print('[MESSAGES DEBUG] Sending media message...');
        response = await _apiService.sendMessage(
          _selectedUserId!,
          content: messageContent.isNotEmpty ? messageContent : null,
          media: _selectedFile!,
        );
        print('[MESSAGES DEBUG] Media API response status: ${response.statusCode}');
        
        // Extract media_url from response (like web does)
        final data = response.data;
        if (data['success'] == true && data['data'] != null) {
          final messageData = data['data'];
          mediaUrl = messageData['media_url']?.toString();
          mediaType = messageData['media_type']?.toString();
          
          // Determine media type from file if not provided
          if (mediaType == null) {
            final fileName = _selectedFile!.path.toLowerCase();
            if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || 
                fileName.endsWith('.png') || fileName.endsWith('.gif')) {
              mediaType = 'image';
            } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov') || 
                       fileName.endsWith('.avi')) {
              mediaType = 'video';
            } else if (fileName.endsWith('.mp3') || fileName.endsWith('.wav')) {
              mediaType = 'audio';
            } else {
              mediaType = 'file';
            }
          }
        }
        
        if (mediaUrl == null) {
          print('[MESSAGES DEBUG] ❌ No media_url returned from API');
          setState(() {
            _sendingMessage = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload media. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        // Send text message
        response = await _apiService.sendMessage(_selectedUserId!, content: messageContent);
        print('[MESSAGES DEBUG] Text API response status: ${response.statusCode}');
      }
      
      // Try to save to Firebase for real-time updates (optional - like web does)
      if (FirebaseService.isInitialized) {
        try {
          print('[MESSAGES DEBUG] Attempting to save to Firebase for real-time updates...');
          if (!FirebaseService.isAuthInitialized) {
            await FirebaseService.initializeAuth();
          }
          
          await FirebaseService.sendMessage(
            senderId: _currentUserId!,
            receiverId: _selectedUserId!,
            content: messageContent.isNotEmpty ? messageContent : null,
            mediaUrl: mediaUrl,
            mediaType: mediaType,
          );
          print('[MESSAGES DEBUG] ✅ Message saved to Firebase');
        } catch (firebaseError) {
          // Firebase save is optional - message already saved via API
          print('[MESSAGES DEBUG] ⚠️ Firebase save failed (non-critical): $firebaseError');
        }
      }
      
      print('[MESSAGES DEBUG] ✅ Message sent successfully');
      _messageController.clear();
      setState(() {
        _selectedFile = null;
      });
      _updateSendButtonState();
      
      // Refresh conversations and messages to show the new message immediately (like web does)
      _fetchConversationsFromAPI();
      if (_selectedUserId != null) {
        _fetchMessagesFromAPI(_selectedUserId!);
      }
    } catch (e, stackTrace) {
      print('[MESSAGES DEBUG] ❌ Error sending message: $e');
      print('[MESSAGES DEBUG] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'avi', 'mov', 'mp3', 'wav', 'pdf', 'doc', 'docx'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFile = File(file.path!);
          });
          _updateSendButtonState();
        }
      }
    } catch (e) {
      print('[MESSAGES DEBUG] Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Timestamp? _parseTimestamp(dynamic dateValue) {
    if (dateValue == null) return null;
    
    try {
      if (dateValue is Timestamp) {
        return dateValue;
      } else if (dateValue is String) {
        return Timestamp.fromDate(DateTime.parse(dateValue));
      } else if (dateValue is Map) {
        // Handle Laravel date format: {"date": "2024-01-01 12:00:00", "timezone_type": 3, "timezone": "UTC"}
        if (dateValue['date'] != null) {
          return Timestamp.fromDate(DateTime.parse(dateValue['date']));
        }
      }
      // Try to parse as string
      return Timestamp.fromDate(DateTime.parse(dateValue.toString()));
    } catch (e) {
      print('[MESSAGES DEBUG] Error parsing timestamp: $e, value: $dateValue');
      return null;
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Format time as HH:mm (24-hour format)
    final timeString = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    if (difference.inMinutes < 1) {
      return 'Just now • $timeString';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago • $timeString';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago • $timeString';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago • $timeString';
    } else {
      return '${date.day}/${date.month}/${date.year} • $timeString';
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    _receiverMessagesSubscription?.cancel();
    _messageController.removeListener(_updateSendButtonState);
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedUserId != null) {
      return _buildChatView();
    }
    
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.black, size: 22),
              onPressed: () {
                setState(() {
                  _showNewChat = true;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            ),
          ),
        ],
      ),
      body: _showNewChat
          ? _buildNewChatView()
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                )
              : !FirebaseService.isInitialized
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Firebase Not Connected',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Please rebuild the app to connect Firebase:\n\n1. Stop the app\n2. Run: flutter clean\n3. Run: flutter pub get\n4. Rebuild and run',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                _initializeFirebase();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Connection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFB875FB),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
              : _indexCreationUrl != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 64,
                              color: Color(0xFFB875FB),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Firestore Index Required',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'To load conversations, you need to create Firestore indexes.\n\nClick the button below to open Firebase Console and create them automatically.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(_indexCreationUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open URL'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Create Indexes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFB875FB),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _indexCreationUrl = null;
                                });
                                _loadConversations();
                              },
                              child: const Text(
                                'Retry After Creating Indexes',
                                style: TextStyle(color: Color(0xFFB875FB)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No conversations',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showNewChat = true;
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Start New Chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFB875FB),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final userId = conv['user_id'] as int;
                    final user = _userCache[userId];
                    
                    // Load user details if not in cache
                    if (user == null) {
                      _loadUserDetails(userId);
                    }
                    
                    final name = user?['name']?.toString() ?? 
                                user?['username']?.toString() ?? 
                                'Loading...';
                    final avatar = user?['profile_avatar']?.toString() ?? 
                                 user?['profile_photo_url']?.toString() ??
                                 user?['avatar']?.toString();
                    final lastMessage = conv['last_message']?.toString() ?? '';
                    final lastMessageTime = conv['last_message_time'] as Timestamp?;
                    final isRead = conv['is_read'] == true;
                    
                    // Get user initial
                    String getUserInitial() {
                      if (name.isEmpty || name == 'Loading...') return '?';
                      return name[0].toUpperCase();
                    }
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openConversation(userId),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFFB875FB).withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.transparent,
                                        backgroundImage: avatar != null && avatar.isNotEmpty 
                                            ? NetworkImage(avatar) 
                                            : null,
                                        onBackgroundImageError: avatar != null && avatar.isNotEmpty
                                            ? (exception, stackTrace) {
                                                print('[MESSAGES DEBUG] Error loading avatar for user $userId: $exception');
                                              }
                                            : null,
                                        child: avatar == null || avatar.isEmpty
                                            ? Text(
                                                getUserInitial(),
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 22,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (!isRead)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB875FB),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF0F0F0F),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0xFFB875FB).withOpacity(0.5),
                                                blurRadius: 4,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatTime(lastMessageTime),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildChatView() {
    final user = _userCache[_selectedUserId];
    
    // Load user details if not in cache
    if (user == null && _selectedUserId != null) {
      _loadUserDetails(_selectedUserId!);
    }
    
    final name = user?['name']?.toString() ?? 
                user?['username']?.toString() ?? 
                'Loading...';
    final avatar = user?['profile_avatar']?.toString() ?? 
                 user?['profile_photo_url']?.toString() ??
                 user?['avatar']?.toString();
    
    // Get user initial
    String getUserInitial() {
      if (name.isEmpty || name == 'Loading...') return '?';
      return name[0].toUpperCase();
    }
    
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
            setState(() {
              _selectedUserId = null;
              _messages = [];
              _showNewChat = false;
            });
            _messagesSubscription?.cancel();
          },
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFB875FB).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.transparent,
                backgroundImage: avatar != null && avatar.isNotEmpty 
                    ? NetworkImage(avatar) 
                    : null,
                onBackgroundImageError: avatar != null && avatar.isNotEmpty
                    ? (exception, stackTrace) {
                        print('[MESSAGES DEBUG] Error loading avatar in chat view: $exception');
                      }
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        getUserInitial(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F0F0F),
                    const Color(0xFF1A1A1A).withOpacity(0.5),
                  ],
                ),
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation!',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == _currentUserId;
                      final content = message['content']?.toString() ?? '';
                      final mediaUrl = message['media_url']?.toString();
                      final mediaType = message['media_type']?.toString();
                      final timestamp = message['created_at'] as Timestamp?;
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: 8,
                            left: isMe ? 50 : 0,
                            right: isMe ? 0 : 50,
                            top: 4,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            gradient: isMe
                                ? const LinearGradient(
                                    colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isMe ? null : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe
                                    ? Color(0xFFB875FB).withOpacity(0.2)
                                    : Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: isMe
                                ? null
                                : Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show media if present (like web does)
                                if (mediaUrl != null) ...[
                                  if (mediaType == 'image')
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        mediaUrl,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(isMe ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.attach_file,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '📎 ${mediaType ?? 'file'}',
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
                                  if (content.isNotEmpty) const SizedBox(height: 10),
                                ],
                                // Show content if present
                                if (content.isNotEmpty)
                                  Text(
                                    content,
                                    style: TextStyle(
                                      color: isMe ? Colors.black : Colors.white,
                                      fontSize: 15,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  )
                                else if (mediaUrl == null)
                                  Text(
                                    'Empty message',
                                    style: TextStyle(
                                      color: isMe ? Colors.black54 : Colors.grey[400],
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                if (timestamp != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(timestamp),
                                          style: TextStyle(
                                            color: isMe 
                                                ? Colors.black.withOpacity(0.6)
                                                : Colors.grey[400],
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 6),
                                            child: Icon(
                                              message['is_read'] == true
                                                  ? Icons.done_all
                                                  : Icons.done,
                                              size: 14,
                                              color: message['is_read'] == true
                                                  ? Colors.blue[700]
                                                  : Colors.black.withOpacity(0.5),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0F0F),
                  const Color(0xFF1A1A1A),
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
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file, color: Colors.white70, size: 22),
                        tooltip: 'Attach file',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: (_sendingMessage || !_canSendMessage)
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                              ),
                        color: (_sendingMessage || !_canSendMessage)
                            ? Colors.grey[700]
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: (_sendingMessage || !_canSendMessage)
                            ? null
                            : [
                                BoxShadow(
                                  color: Color(0xFFB875FB).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: IconButton(
                        onPressed: (_sendingMessage || !_canSendMessage) 
                            ? null 
                            : _sendMessage,
                        icon: _sendingMessage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.black, size: 22),
                      ),
                    ),
                  ],
                ),
                // Show selected file (like web does)
                if (_selectedFile != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFFB875FB).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.attach_file, color: Color(0xFFB875FB), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedFile!.path.split('/').last,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _selectedFile = null;
                            });
                            _updateSendButtonState();
                          },
                          icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNewChatView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: Colors.grey[800]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFFB875FB)),
              ),
              filled: true,
              fillColor: Colors.grey[900],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {});
              if (value.trim().isNotEmpty) {
                _searchUsers(value);
              } else {
                setState(() {
                  _searchResults = [];
                });
              }
            },
          ),
        ),
        Expanded(
          child: _searching
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                )
              : _searchResults.isEmpty && _searchController.text.isNotEmpty
                  ? Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Search for users to start a chat',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            final name = user['name']?.toString() ?? 
                                        user['username']?.toString() ?? 
                                        'Unknown User';
                            final username = user['username']?.toString() ?? '';
                            final avatar = user['profile_avatar']?.toString() ?? 
                                         user['profile_photo_url']?.toString() ??
                                         user['avatar']?.toString();
                            
                            // Get user initial
                            String getUserInitial() {
                              if (name.isEmpty || name == 'Unknown User') return 'U';
                              return name[0].toUpperCase();
                            }
                            
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: Color(0xFFB875FB),
                                backgroundImage: avatar != null && avatar.isNotEmpty 
                                    ? NetworkImage(avatar) 
                                    : null,
                                onBackgroundImageError: avatar != null && avatar.isNotEmpty
                                    ? (exception, stackTrace) {
                                        print('[MESSAGES DEBUG] Error loading avatar in search: $exception');
                                      }
                                    : null,
                                child: avatar == null || avatar.isEmpty
                                    ? Text(
                                        getUserInitial(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: username.isNotEmpty
                                  ? Text(
                                      '@$username',
                                      style: TextStyle(color: Colors.grey[400]),
                                    )
                                  : null,
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey,
                                size: 16,
                              ),
                              onTap: () => _startChatWithUser(user),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

