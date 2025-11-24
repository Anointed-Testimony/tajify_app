import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;
  static bool _initialized = false;
  static bool _authInitialized = false;

  // Firebase configuration - YOU NEED TO ADD YOUR FIREBASE CONFIG HERE
  // Get this from Firebase Console > Project Settings > Your apps
  static const Map<String, String> firebaseConfig = {
    'apiKey': 'AIzaSyAHQJsl0AxjreUCXIgLnHk3rvmkiAEwMlQ',
    'authDomain': 'tajify-chat.firebaseapp.com',
    'projectId': 'tajify-chat',
    'storageBucket': 'tajify-chat.firebasestorage.app',
    'messagingSenderId': '47313466019',
    'appId': '1:47313466019:web:9626a01ff15aa0ce030516',
  };

  static Future<bool> initialize() async {
    if (_initialized && _firestore != null) {
      print('[FIREBASE DEBUG] Already initialized, firestore: ${_firestore != null}');
      return true;
    }

    print('[FIREBASE DEBUG] Starting initialization...');
    print('[FIREBASE DEBUG] Config: ${firebaseConfig.toString()}');

    try {
      // Check if Firebase is already initialized
      try {
        final apps = Firebase.apps;
        print('[FIREBASE DEBUG] Existing Firebase apps: ${apps.length}');
        if (apps.isNotEmpty) {
          print('[FIREBASE DEBUG] Firebase already initialized, using existing app: ${apps.first.name}');
          _firestore = FirebaseFirestore.instance;
          _auth = FirebaseAuth.instance;
          _initialized = true;
          print('[FIREBASE DEBUG] ✅ Using existing Firebase instance');
          print('[FIREBASE DEBUG] Firestore instance: ${_firestore != null}');
          print('[FIREBASE DEBUG] Auth instance: ${_auth != null}');
          return true;
        }
      } catch (e) {
        print('[FIREBASE DEBUG] Error checking existing apps: $e');
        // Continue with initialization
      }

      // For Android, try to use default initialization first (uses google-services.json)
      try {
        print('[FIREBASE DEBUG] Attempting default Firebase initialization (for Android)...');
        await Firebase.initializeApp();
        print('[FIREBASE DEBUG] Default Firebase.initializeApp completed');
        _firestore = FirebaseFirestore.instance;
        _auth = FirebaseAuth.instance;
        _initialized = true;
        print('[FIREBASE DEBUG] ✅ Initialized successfully with default config');
        print('[FIREBASE DEBUG] Firestore instance: ${_firestore != null}');
        print('[FIREBASE DEBUG] Auth instance: ${_auth != null}');
        return true;
      } catch (defaultError) {
        print('[FIREBASE DEBUG] Default initialization failed: $defaultError');
        print('[FIREBASE DEBUG] Trying manual configuration...');
        
        // If default fails, try manual configuration
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseConfig['apiKey']!,
            appId: firebaseConfig['appId']!,
            messagingSenderId: firebaseConfig['messagingSenderId']!,
            projectId: firebaseConfig['projectId']!,
            authDomain: firebaseConfig['authDomain']!,
            storageBucket: firebaseConfig['storageBucket']!,
          ),
        );

        print('[FIREBASE DEBUG] Manual Firebase.initializeApp completed');
        _firestore = FirebaseFirestore.instance;
        _auth = FirebaseAuth.instance;
        _initialized = true;

        print('[FIREBASE DEBUG] ✅ Initialized successfully with manual config');
        print('[FIREBASE DEBUG] Firestore instance: ${_firestore != null}');
        print('[FIREBASE DEBUG] Auth instance: ${_auth != null}');
        return true;
      }
    } catch (e, stackTrace) {
      print('[FIREBASE DEBUG] ❌ Error initializing: $e');
      print('[FIREBASE DEBUG] Error type: ${e.runtimeType}');
      print('[FIREBASE DEBUG] Error toString: ${e.toString()}');
      print('[FIREBASE DEBUG] Stack trace: $stackTrace');
      
      // Check if it's a channel error (requires rebuild)
      if (e.toString().contains('channel-error') || e.toString().contains('Unable to establish connection')) {
        print('[FIREBASE DEBUG] ⚠️ Channel error detected - Firebase plugins may not be properly registered');
        print('[FIREBASE DEBUG] ⚠️ This usually requires a full rebuild:');
        print('[FIREBASE DEBUG] ⚠️ 1. Stop the app completely');
        print('[FIREBASE DEBUG] ⚠️ 2. Run: flutter clean');
        print('[FIREBASE DEBUG] ⚠️ 3. Run: flutter pub get');
        print('[FIREBASE DEBUG] ⚠️ 4. Rebuild and run the app');
      }
      
      // Try to use existing Firebase instance if available
      try {
        final apps = Firebase.apps;
        print('[FIREBASE DEBUG] Checking for existing apps after error: ${apps.length}');
        if (apps.isNotEmpty) {
          print('[FIREBASE DEBUG] Attempting to use existing Firebase app after error...');
          _firestore = FirebaseFirestore.instance;
          _auth = FirebaseAuth.instance;
          _initialized = true;
          print('[FIREBASE DEBUG] ✅ Using existing Firebase instance after error');
          print('[FIREBASE DEBUG] Firestore instance: ${_firestore != null}');
          return true;
        }
      } catch (checkError) {
        print('[FIREBASE DEBUG] Error checking existing apps: $checkError');
      }
      
      _initialized = true; // Mark as initialized to prevent retries
      return false;
    }
  }

  static Future<bool> initializeAuth() async {
    print('[FIREBASE AUTH DEBUG] Starting auth initialization...');
    print('[FIREBASE AUTH DEBUG] _authInitialized: $_authInitialized');
    print('[FIREBASE AUTH DEBUG] Current user: ${_auth?.currentUser?.uid ?? 'null'}');
    
    if (_authInitialized && _auth?.currentUser != null) {
      print('[FIREBASE AUTH DEBUG] ✅ Already authenticated: ${_auth!.currentUser!.uid}');
      return true;
    }

    if (!_initialized) {
      print('[FIREBASE AUTH DEBUG] Firebase not initialized, initializing now...');
      final initSuccess = await initialize();
      if (!initSuccess) {
        print('[FIREBASE AUTH DEBUG] ❌ Firebase initialization failed');
        return false;
      }
    }

    try {
      if (_auth?.currentUser != null) {
        print('[FIREBASE AUTH DEBUG] ✅ Already authenticated: ${_auth!.currentUser!.uid}');
        print('[FIREBASE AUTH DEBUG] Is anonymous: ${_auth!.currentUser!.isAnonymous}');
        _authInitialized = true;
        return true;
      }

      // Sign in anonymously
      print('[FIREBASE AUTH DEBUG] Attempting anonymous sign in...');
      final userCredential = await _auth!.signInAnonymously();
      print('[FIREBASE AUTH DEBUG] ✅ Authenticated anonymously: ${userCredential.user!.uid}');
      print('[FIREBASE AUTH DEBUG] User metadata: ${userCredential.user!.metadata.creationTime}');
      _authInitialized = true;
      return true;
    } catch (e, stackTrace) {
      print('[FIREBASE AUTH DEBUG] ❌ Error authenticating: $e');
      print('[FIREBASE AUTH DEBUG] Error type: ${e.runtimeType}');
      try {
        final errorCode = (e as dynamic).code;
        print('[FIREBASE AUTH DEBUG] Error code: $errorCode');
      } catch (_) {
        print('[FIREBASE AUTH DEBUG] Error code: not available');
      }
      print('[FIREBASE AUTH DEBUG] Stack trace: $stackTrace');
      _authInitialized = true; // Mark as initialized to prevent retries
      return false;
    }
  }

  static FirebaseFirestore? get firestore => _firestore;
  static FirebaseAuth? get auth => _auth;
  static bool get isInitialized => _initialized && _firestore != null;
  static bool get isAuthInitialized => _authInitialized && _auth?.currentUser != null;

  // Get direct messages collection
  static CollectionReference get directMessagesCollection {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call FirebaseService.initialize() first.');
    }
    return _firestore!.collection('direct_messages');
  }

  // Stream messages between two users
  static Stream<QuerySnapshot> getMessagesStream(int userId1, int userId2) {
    print('[FIREBASE DEBUG] getMessagesStream called');
    print('[FIREBASE DEBUG] userId1: $userId1, userId2: $userId2');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore not initialized');
      throw Exception('Firebase not initialized');
    }

    print('[FIREBASE DEBUG] Setting up messages stream query...');
    final stream = _firestore!
        .collection('direct_messages')
        .where('sender_id', whereIn: [userId1, userId2])
        .where('receiver_id', whereIn: [userId1, userId2])
        .orderBy('created_at', descending: false)
        .snapshots();
    
    print('[FIREBASE DEBUG] ✅ Messages stream created');
    return stream;
  }

  // Send a message
  static Future<DocumentReference> sendMessage({
    required int senderId,
    required int receiverId,
    String? content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    print('[FIREBASE DEBUG] sendMessage called');
    print('[FIREBASE DEBUG] senderId: $senderId, receiverId: $receiverId');
    print('[FIREBASE DEBUG] content: ${content ?? 'null'}');
    print('[FIREBASE DEBUG] mediaUrl: ${mediaUrl ?? 'null'}');
    print('[FIREBASE DEBUG] mediaType: ${mediaType ?? 'null'}');
    print('[FIREBASE DEBUG] _firestore: ${_firestore != null}');
    print('[FIREBASE DEBUG] _auth?.currentUser: ${_auth?.currentUser?.uid ?? 'null'}');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] Firestore is null, initializing...');
      final initSuccess = await initialize();
      if (!initSuccess || _firestore == null) {
        print('[FIREBASE DEBUG] ❌ Failed to initialize Firestore');
        throw Exception('Firebase not initialized. Cannot send message.');
      }
    }
    if (_auth?.currentUser == null) {
      print('[FIREBASE DEBUG] Auth user is null, initializing auth...');
      await initializeAuth();
    }

    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore is still null after initialization');
      throw Exception('Firestore not available. Cannot send message.');
    }

    final messageData = {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'is_read': false,
    };

    print('[FIREBASE DEBUG] Message data: $messageData');
    print('[FIREBASE DEBUG] Adding message to Firestore...');
    
    try {
      final docRef = await _firestore!.collection('direct_messages').add(messageData);
      print('[FIREBASE DEBUG] ✅ Message sent successfully, doc ID: ${docRef.id}');
      return docRef;
    } catch (e, stackTrace) {
      print('[FIREBASE DEBUG] ❌ Error sending message: $e');
      print('[FIREBASE DEBUG] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get conversations list (users you've messaged or received messages from)
  // Using separate queries WITHOUT orderBy to avoid needing composite indexes
  // We'll sort in memory instead
  static Stream<QuerySnapshot> getConversationsStream(int currentUserId) {
    print('[FIREBASE DEBUG] getConversationsStream called');
    print('[FIREBASE DEBUG] currentUserId: $currentUserId');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore not initialized');
      throw Exception('Firebase not initialized');
    }

    print('[FIREBASE DEBUG] Setting up conversations stream query (without orderBy to avoid indexes)...');
    // Query without orderBy - we'll sort in memory
    // This avoids needing composite indexes
    try {
      final senderStream = _firestore!
          .collection('direct_messages')
          .where('sender_id', isEqualTo: currentUserId)
          .snapshots();
      
      print('[FIREBASE DEBUG] ✅ Sender stream created (no orderBy - will sort in memory)');
      return senderStream;
    } catch (e) {
      print('[FIREBASE DEBUG] ⚠️ Error creating stream: $e');
      rethrow;
    }
  }
  
  // Get receiver messages stream separately (without orderBy)
  static Stream<QuerySnapshot> getReceiverMessagesStream(int currentUserId) {
    if (_firestore == null) {
      throw Exception('Firebase not initialized');
    }
    
    print('[FIREBASE DEBUG] Creating receiver stream (without orderBy to avoid indexes)...');
    return _firestore!
        .collection('direct_messages')
        .where('receiver_id', isEqualTo: currentUserId)
        .snapshots();
  }

  // Mark message as read
  static Future<void> markMessageAsRead(String messageId) async {
    print('[FIREBASE DEBUG] markMessageAsRead called, messageId: $messageId');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore not initialized');
      throw Exception('Firebase not initialized');
    }

    try {
      await _firestore!.collection('direct_messages').doc(messageId).update({
        'is_read': true,
        'read_at': FieldValue.serverTimestamp(),
      });
      print('[FIREBASE DEBUG] ✅ Message marked as read');
    } catch (e) {
      print('[FIREBASE DEBUG] ❌ Error marking message as read: $e');
      rethrow;
    }
  }

  // Get unread message count
  static Stream<int> getUnreadCountStream(int currentUserId) {
    print('[FIREBASE DEBUG] getUnreadCountStream called, currentUserId: $currentUserId');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore not initialized');
      throw Exception('Firebase not initialized');
    }

    print('[FIREBASE DEBUG] Setting up unread count stream...');
    final stream = _firestore!
        .collection('direct_messages')
        .where('receiver_id', isEqualTo: currentUserId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          print('[FIREBASE DEBUG] Unread count updated: $count');
          return count;
        });
    
    print('[FIREBASE DEBUG] ✅ Unread count stream created');
    return stream;
  }

  // Get community messages stream (for real-time updates)
  static Stream<QuerySnapshot> getCommunityMessagesStream(String communityUuid) {
    print('[FIREBASE DEBUG] getCommunityMessagesStream called for community: $communityUuid');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore not initialized');
      throw Exception('Firebase not initialized');
    }

    print('[FIREBASE DEBUG] Setting up community messages stream query...');
    // Query messages by community_id (no orderBy to avoid composite index requirement)
    // We'll sort in memory instead
    final stream = _firestore!
        .collection('messages')
        .where('community_id', isEqualTo: communityUuid)
        .snapshots();
    
    print('[FIREBASE DEBUG] ✅ Community messages stream created');
    return stream;
  }

  // Send community message to Firebase
  static Future<DocumentReference> sendCommunityMessage({
    required String communityUuid,
    required int userId,
    required String userName,
    required String userUsername,
    String? userAvatar,
    String? content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    print('[FIREBASE DEBUG] sendCommunityMessage called');
    print('[FIREBASE DEBUG] communityUuid: $communityUuid, userId: $userId');
    print('[FIREBASE DEBUG] content: ${content ?? 'null'}');
    print('[FIREBASE DEBUG] mediaUrl: ${mediaUrl ?? 'null'}');
    
    if (_firestore == null) {
      print('[FIREBASE DEBUG] Firestore is null, initializing...');
      final initSuccess = await initialize();
      if (!initSuccess || _firestore == null) {
        print('[FIREBASE DEBUG] ❌ Failed to initialize Firestore');
        throw Exception('Firebase not initialized. Cannot send message.');
      }
    }
    if (_auth?.currentUser == null) {
      print('[FIREBASE DEBUG] Auth user is null, initializing auth...');
      await initializeAuth();
    }

    if (_firestore == null) {
      print('[FIREBASE DEBUG] ❌ Firestore is still null after initialization');
      throw Exception('Firestore not available. Cannot send message.');
    }

    final messageData = {
      'community_id': communityUuid,
      'user_id': userId,
      'user_name': userName,
      'user_username': userUsername,
      'user_avatar': userAvatar,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'created_at': FieldValue.serverTimestamp(),
    };

    print('[FIREBASE DEBUG] Community message data: $messageData');
    print('[FIREBASE DEBUG] Adding message to Firestore...');
    
    try {
      final docRef = await _firestore!.collection('messages').add(messageData);
      print('[FIREBASE DEBUG] ✅ Community message sent successfully, doc ID: ${docRef.id}');
      return docRef;
    } catch (e, stackTrace) {
      print('[FIREBASE DEBUG] ❌ Error sending community message: $e');
      print('[FIREBASE DEBUG] Stack trace: $stackTrace');
      rethrow;
    }
  }
}

