import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // Added for ImageFilter

// Skeleton loading widgets
class _SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  
  const _SkeletonLoader({
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
      ),
    );
  }
}

class _VideoSkeleton extends StatelessWidget {
  const _VideoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[800]!,
                Colors.grey[700]!,
                Colors.grey[800]!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserInfoSkeleton extends StatelessWidget {
  const _UserInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar skeleton
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 8),
        // Username skeleton
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Action buttons skeleton
        Row(
          children: List.generate(6, (index) => [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),
          ]).expand((x) => x).toList()..removeLast(),
        ),
      ],
    );
  }
}

class _DescriptionSkeleton extends StatelessWidget {
  const _DescriptionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(minHeight: 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video skeleton
        Expanded(
          child: Stack(
            children: [
              const _VideoSkeleton(),
              // Description skeleton at bottom
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _DescriptionSkeleton(),
              ),
            ],
          ),
        ),
        // User info skeleton
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: _UserInfoSkeleton(),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 4; // Community
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Add API service
  final ApiService _apiService = ApiService();
  
  // Add tap animation states
  late List<bool> _likeTapped;
  late List<bool> _saveTapped;
  
  // Real data from backend
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Video controllers for real posts
  final List<VideoPlayerController?> _videoControllers = [];

  // Interaction states for real posts
  List<bool> _liked = [];
  List<int> _likeCounts = [];
  List<bool> _saved = [];
  List<int> _saveCounts = [];
  List<int> _commentCounts = [];
  
  // Loading states for interactions
  List<bool> _likeLoading = [];
  List<bool> _saveLoading = [];
  
  // Comments state
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;
  final TextEditingController _commentController = TextEditingController();
  
  // Comment replies state
  Map<int, List<Map<String, dynamic>>> _commentReplies = {};
  Map<int, bool> _repliesLoading = {};
  Map<int, bool> _showReplies = {};
  Map<int, bool> _showReplyInput = {};
  Map<int, TextEditingController> _replyControllers = {};
  
  // Duet state
  Map<int, bool> _duetLoading = {};
  Map<int, List<Map<String, dynamic>>> _duetFeed = {};
  Map<int, bool> _showDuetFeed = {};

  void _toggleLike(int index) {
    if (_likeLoading[index] || index >= _posts.length) return;
    
    setState(() {
      _likeLoading[index] = true;
    });
    
    final postId = _posts[index]['id'];
    _apiService.toggleLike(postId).then((response) {
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _liked[index] = data['liked'] ?? false;
          _likeCounts[index] = data['like_count'] ?? 0;
          _likeLoading[index] = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _likeLoading[index] = false;
        });
      }
      print('Error toggling like: $e');
    });
  }

  void _toggleSave(int index) {
    if (_saveLoading[index] || index >= _posts.length) return;
    
    setState(() {
      _saveLoading[index] = true;
    });
    
    final postId = _posts[index]['id'];
    _apiService.toggleSave(postId).then((response) {
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _saved[index] = data['saved'] ?? false;
          _saveLoading[index] = false;
        });
        // Refresh save count
        _loadInteractionCounts(index);
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _saveLoading[index] = false;
        });
      }
      print('Error toggling save: $e');
    });
  }

  void _share(int index) {
    if (index >= _posts.length) return;
    
    final post = _posts[index];
    final mediaUrl = post['media_files']?[0]?['file_path'] ?? '';
    
    if (mediaUrl.isNotEmpty) {
      Share.share(mediaUrl);
    } else {
      Share.share('Check out this post on Tajify!');
    }
  }

  // Load personalized feed
  Future<void> _loadPersonalizedFeed() async {
    if (_isLoading) return;
    
    print('[DEBUG] Starting to load personalized feed...');
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      print('[DEBUG] Calling API service getPersonalizedFeed...');
      final response = await _apiService.getPersonalizedFeed(limit: 20, page: 1);
      
      print('[DEBUG] API Response received:');
      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response data: ${response.data}');
      
      if (mounted && response.data['success']) {
        final posts = List<Map<String, dynamic>>.from(response.data['data']['posts']);
        
        print('[DEBUG] Posts extracted: ${posts.length} posts');
        print('[DEBUG] First post data: ${posts.isNotEmpty ? posts.first : 'No posts'}');
        
        setState(() {
          _posts = posts;
          _isLoading = false;
          
          // Initialize interaction states
          _liked = List.generate(posts.length, (_) => false);
          _likeCounts = List.generate(posts.length, (_) => 0);
          _saved = List.generate(posts.length, (_) => false);
          _saveCounts = List.generate(posts.length, (_) => 0);
          _commentCounts = List.generate(posts.length, (_) => 0);
          _likeLoading = List.generate(posts.length, (_) => false);
          _saveLoading = List.generate(posts.length, (_) => false);
          
          // Initialize video controllers
          _videoControllers.clear();
          for (int i = 0; i < posts.length; i++) {
            _videoControllers.add(null);
          }
        });
        
        print('[DEBUG] State updated with ${_posts.length} posts');
        
        // Load interaction counts for all posts
        for (int i = 0; i < posts.length; i++) {
          await _loadInteractionCounts(i);
        }
        
        // Initialize video controllers for video posts
        _initializeVideoControllers();
        
        print('[DEBUG] Feed loading completed successfully');
      } else {
        print('[DEBUG] API response not successful:');
        print('[DEBUG] Success flag: ${response.data['success']}');
        print('[DEBUG] Error message: ${response.data['message']}');
        
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = response.data['message'] ?? 'Unknown error';
        });
      }
    } catch (e, stackTrace) {
      print('[DEBUG] Error loading personalized feed:');
      print('[DEBUG] Error: $e');
      print('[DEBUG] Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load feed: $e';
        });
      }
    }
  }

  // Load interaction counts for a specific post
  Future<void> _loadInteractionCounts(int index) async {
    if (index >= _posts.length) return;
    
    print('[DEBUG] Loading interaction counts for post $index');
    
    try {
      final postId = _posts[index]['id'];
      print('[DEBUG] Post ID: $postId');
      
      final response = await _apiService.getInteractionCounts(postId);
      
      print('[DEBUG] Interaction counts response for post $index:');
      print('[DEBUG] Response status: ${response.statusCode}');
      print('[DEBUG] Response data: ${response.data}');
      
      if (mounted && response.data['success']) {
        final data = response.data['data'];
        final counts = data['counts'];
        final userInteractions = data['user_interactions'];
        
        print('[DEBUG] Counts for post $index: $counts');
        print('[DEBUG] User interactions for post $index: $userInteractions');
        
        setState(() {
          _likeCounts[index] = counts['likes'] ?? 0;
          _saveCounts[index] = counts['saves'] ?? 0;
          _commentCounts[index] = counts['comments'] ?? 0;
          _liked[index] = userInteractions['liked'] ?? false;
          _saved[index] = userInteractions['saved'] ?? false;
        });
        
        print('[DEBUG] Updated interaction states for post $index:');
        print('[DEBUG] - Likes: ${_likeCounts[index]}');
        print('[DEBUG] - Saves: ${_saveCounts[index]}');
        print('[DEBUG] - Comments: ${_commentCounts[index]}');
        print('[DEBUG] - Liked: ${_liked[index]}');
        print('[DEBUG] - Saved: ${_saved[index]}');
      } else {
        print('[DEBUG] Failed to load interaction counts for post $index:');
        print('[DEBUG] Success flag: ${response.data['success']}');
        print('[DEBUG] Error message: ${response.data['message']}');
      }
    } catch (e) {
      print('[DEBUG] Error loading interaction counts for post $index: $e');
    }
  }

  // Initialize video controllers for video posts
  void _initializeVideoControllers() {
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      final mediaFiles = post['media_files'] as List<dynamic>?;
      
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        final mediaFile = mediaFiles[0];
        final filePath = mediaFile['file_path'] as String?;
        final fileType = mediaFile['file_type'] as String?;
        
        if (filePath != null && fileType == 'video') {
          final controller = VideoPlayerController.network(filePath);
          controller.addListener(() {
            if (mounted) setState(() {});
          });
          
          controller.initialize().then((_) {
            if (mounted) {
              setState(() {
                _videoControllers[i] = controller;
              });
              if (i == 0) controller.play(); // Autoplay first video
            }
          }).catchError((e) {
            print('Error initializing video controller for post $i: $e');
          });
        }
      }
    }
  }

  void _showTajStarsGift(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TajStarsGiftModal(),
    );
  }

  // Quick logout function
  Future<void> _quickLogout() async {
    try {
      // Clear the token from secure storage
      await _apiService.clearToken();
      
      // Navigate to login screen
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      print('Error during logout: $e');
      // Still navigate to login even if token clearing fails
      if (mounted) {
        context.go('/login');
      }
    }
  }

  final List<String> _tabs = [
    'Contact', 'Chats', 'Group', 'Club', 'Community',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    
    // Load personalized feed
    _loadPersonalizedFeed();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    
    // Dispose video controllers
    for (var controller in _videoControllers) {
      controller?.dispose();
    }
    
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      // Clear comments when switching posts
      _comments = [];
      _commentsLoading = false;
      _commentReplies.clear();
      _showReplies.clear();
      _showReplyInput.clear();
      _replyControllers.clear();
      // Clear comment controller
      _commentController.clear();
      // Pause all videos except the current
      for (int i = 0; i < _videoControllers.length; i++) {
        if (_videoControllers[i] != null) {
          if (i == index) {
            if (_videoControllers[i]!.value.isInitialized) {
              _videoControllers[i]!.play();
            }
          } else {
            _videoControllers[i]!.pause();
          }
        }
      }
    });
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    
    print('[DEBUG] Loading comments for current video');
    
    // Set loading state immediately
    if (mounted) {
      setState(() {
        _commentsLoading = true;
      });
    }
    
    try {
      final postId = _posts[_currentPage]['id'];
      print('[DEBUG] Calling getComments API for postId: $postId');
      final response = await _apiService.getComments(postId);
      print('[DEBUG] Get comments response: ${response.data}');
      
      if (mounted && response.data['success']) {
        final comments = List<Map<String, dynamic>>.from(response.data['data']['data'] ?? []);
        
        // Update comments immediately without waiting for setState
        _comments = comments;
        
        // Update UI in next frame for better performance
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _commentsLoading = false;
              });
            }
          });
        }
        
        print('[DEBUG] Loaded ${_comments.length} comments');
      } else {
        print('[ERROR] Get comments failed: ${response.data}');
        if (mounted) {
          _comments = [];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _commentsLoading = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error loading comments: $e');
      if (mounted) {
        _comments = [];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _commentsLoading = false;
            });
          }
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final content = _commentController.text.trim();
    _commentController.clear();
    
    try {
      final postId = _posts[_currentPage]['id'];
      final response = await _apiService.addComment(postId, content);
      
      if (mounted && response.data['success']) {
        // Refresh comments to show the new comment
        await _loadComments();
      }
    } catch (e) {
      print('[ERROR] Error adding comment: $e');
    }
  }

  // Comment replies methods
  Future<void> _loadCommentReplies(int commentId) async {
    if (_repliesLoading[commentId] == true) return;
    
    // Set loading state immediately
    if (mounted) {
      setState(() {
        _repliesLoading[commentId] = true;
      });
    }
    
    try {
      final response = await _apiService.getCommentReplies(commentId);
      
      if (mounted && response.data['success']) {
        final replies = List<Map<String, dynamic>>.from(response.data['data']['data']);
        
        // Update replies immediately
        _commentReplies[commentId] = replies;
        
        // Update UI in next frame for better performance
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _repliesLoading[commentId] = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error loading comment replies: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _repliesLoading[commentId] = false;
            });
          }
        });
      }
    }
  }

  void _toggleReplies(int commentId) {
    setState(() {
      _showReplies[commentId] = !(_showReplies[commentId] ?? false);
    });
    
    // Load replies if showing and not already loaded
    if (_showReplies[commentId] == true && !_commentReplies.containsKey(commentId)) {
      _loadCommentReplies(commentId);
    }
  }

  void _toggleReplyInput(int commentId) {
    setState(() {
      _showReplyInput[commentId] = !(_showReplyInput[commentId] ?? false);
    });
  }

  TextEditingController _getReplyController(int commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  Future<void> _addCommentReply(int commentId) async {
    final controller = _getReplyController(commentId);
    if (controller.text.trim().isEmpty) return;
    
    final content = controller.text.trim();
    controller.clear();
    
    try {
      final postId = _posts[_currentPage]['id'];
      final response = await _apiService.addCommentReply(postId, content, commentId);
      
      if (mounted && response.data['success']) {
        // Refresh replies
        await _loadCommentReplies(commentId);
        // Hide reply input
        setState(() {
          _showReplyInput[commentId] = false;
        });
      }
    } catch (e) {
      print('[ERROR] Error adding comment reply: $e');
    }
  }

  String _formatCommentTime(String? createdAt) {
    if (createdAt == null) return 'Just now';
    
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Just now';
    }
  }

  // Duet methods
  Future<void> _createDuet(int postId) async {
    if (_duetLoading[postId] == true) return;
    
    print('[DEBUG] Creating duet for postId: $postId');
    setState(() {
      _duetLoading[postId] = true;
    });
    
    try {
      // For now, we'll create a duet with the current user's latest post
      // In a real implementation, you'd navigate to duet creation screen
      final response = await _apiService.createDuet(postId, postId); // This is a placeholder
      
      if (mounted && response.data['success']) {
        // Show success message or navigate to duet creation
        print('[DEBUG] Duet created successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duet created successfully!')),
        );
      }
    } catch (e) {
      print('[ERROR] Error creating duet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create duet: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _duetLoading[postId] = false;
        });
      }
    }
  }

  Future<void> _loadDuetFeed(int postId) async {
    if (_duetLoading[postId] == true) return;
    
    setState(() {
      _duetLoading[postId] = true;
    });
    
    try {
      final response = await _apiService.getDuetFeed(postId);
      
      if (mounted && response.data['success']) {
        setState(() {
          _duetFeed[postId] = List<Map<String, dynamic>>.from(response.data['data']['duets']['data']);
          _duetLoading[postId] = false;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading duet feed: $e');
      if (mounted) {
        setState(() {
          _duetLoading[postId] = false;
        });
      }
    }
  }

  void _toggleDuetFeed(int postId) {
    setState(() {
      _showDuetFeed[postId] = !(_showDuetFeed[postId] ?? false);
    });
    
    // Load duet feed if showing and not already loaded
    if (_showDuetFeed[postId] == true && !_duetFeed.containsKey(postId)) {
      _loadDuetFeed(postId);
    }
  }

  bool _isDuetAllowed(int index) {
    if (index >= _posts.length) return false;
    final post = _posts[index];
    return post['allow_duet'] == true && post['is_prime'] != true;
  }

  void _showComments() {
    // Show modal immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Start loading comments immediately when modal opens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadComments();
        });
        
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Text('Comments (${_commentCounts[_currentPage]})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _commentsLoading
                        ? ListView.builder(
                            controller: scrollController,
                            itemCount: 5,
                            itemBuilder: (context, i) => ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              title: Container(
                                width: 120,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 80,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[800],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _comments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No comments yet. Be the first to comment!',
                                  style: TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _comments.length,
                                itemBuilder: (context, i) {
                                  final comment = _comments[i];
                                  final commentId = comment['id'];
                                  final replies = _commentReplies[commentId] ?? [];
                                  final showReplies = _showReplies[commentId] ?? false;
                                  final repliesCount = comment['replies_count'] ?? 0;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.amber,
                                          child: Text(
                                            comment['user']?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          comment['user']?['name']?.toString() ?? 'Unknown User',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment['content']?.toString() ?? '',
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  _formatCommentTime(comment['created_at']),
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                ),
                                                if (repliesCount > 0) ...[
                                                  const SizedBox(width: 12),
                                                  GestureDetector(
                                                    onTap: () => _toggleReplies(commentId),
                                                    child: Text(
                                                      '${repliesCount} ${repliesCount == 1 ? 'reply' : 'replies'}',
                                                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.reply, color: Colors.white54, size: 20),
                                          onPressed: () => _toggleReplyInput(commentId),
                                        ),
                                      ),
                                      // Reply input field
                                      if (_showReplyInput[commentId] ?? false)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 60, right: 16, bottom: 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _getReplyController(commentId),
                                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                                  decoration: InputDecoration(
                                                    hintText: 'Reply to ${comment['user']?['name']}...',
                                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                                    filled: true,
                                                    fillColor: Colors.white10,
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                      borderSide: BorderSide.none,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.send, color: Colors.amber, size: 20),
                                                onPressed: () => _addCommentReply(commentId),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Replies section
                                      if (showReplies && replies.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 60, right: 16),
                                          child: Column(
                                            children: replies.map((reply) => ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.amber.withOpacity(0.7),
                                                radius: 12,
                                                child: Text(
                                                  reply['user']?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                                                ),
                                              ),
                                              title: Text(
                                                reply['user']?['name']?.toString() ?? 'Unknown User',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    reply['content']?.toString() ?? '',
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _formatCommentTime(reply['created_at']),
                                                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            )).toList(),
                                          ),
                                        ),
                                      // Loading indicator for replies
                                      if (showReplies && _repliesLoading[commentId] == true)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 60, right: 16),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.amber),
                          onPressed: _addComment,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      body: SafeArea(
                    child: Column(
                      children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                          children: [
                  const Text('Tajify', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.search, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.message_outlined, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  // Vertical divider
                            Container(
                    height: 24,
                    width: 1.2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: Colors.grey[600],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20), 
                    onPressed: () {}
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.person_outline, color: Colors.white, size: 20), 
                    onPressed: () => _quickLogout(),
                  ),
                        ],
                      ),
            ),
            // Tabs
            // Main Feed Section (Side-flip PageView)
            Expanded(
              child: _isLoading
                  ? const _FeedSkeleton()
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Failed to load feed',
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPersonalizedFeed,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _posts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'No posts available',
                                    style: TextStyle(color: Colors.white70, fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadPersonalizedFeed,
                                    child: const Text('Refresh Feed'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Debug: $_errorMessage',
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : PageView.builder(
                controller: _pageController,
                              itemCount: _posts.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                                final post = _posts[index];
                  final videoController = _videoControllers[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 0.0;
                      if (_pageController.position.haveDimensions) {
                        value = _pageController.page! - index;
                      } else if (_currentPage == index) {
                        value = 0.0;
                      } else {
                        value = _currentPage - index.toDouble();
                      }
                      value = value.clamp(-1.0, 1.0);
                      // 3D flip effect
                      final double rotationY = value * 1.2; // radians
                      final double opacity = (1 - value.abs()).clamp(0.0, 1.0);
                                    
                      Widget mediaWidget;
                                    final mediaFiles = post['media_files'] as List<dynamic>?;
                                    
                                    if (mediaFiles != null && mediaFiles.isNotEmpty) {
                                      final mediaFile = mediaFiles[0];
                                      final filePath = mediaFile['file_path'] as String?;
                                      final fileType = mediaFile['file_type'] as String?;
                                      
                                      if (fileType == 'video' && filePath != null) {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: (videoController == null)
                              ? Container(color: Colors.black)
                              : (videoController.value.hasError
                                  ? Container(
                                      color: Colors.black,
                                                      child: const Center(
                                child: Text(
                                          'Video failed to load',
                                          style: TextStyle(color: Colors.red, fontSize: 16),
                                        ),
                                      ),
                                    )
                                  : (videoController.value.isInitialized
                                      ? LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Stack(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      if (videoController.value.isPlaying) {
                                                        videoController.pause();
                                                      } else {
                                                        videoController.play();
                                                      }
                                                    });
                                                  },
                                                  child: Center(
                                                    child: FittedBox(
                                                      fit: BoxFit.contain,
                                                      child: SizedBox(
                                                        width: videoController.value.size.width,
                                                        height: videoController.value.size.height,
                                                        child: VideoPlayer(videoController),
                                  ),
                                ),
                              ),
                            ),
                                                if (!videoController.value.isPlaying)
                                                  Center(
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black45,
                                                        shape: BoxShape.circle,
                                  ),
                                                                      child: const Icon(
                                                        Icons.play_arrow,
                                      color: Colors.white,
                                                        size: 64,
                                                      ),
                                    ),
                                  ),
                                ],
                                            );
                                          },
                                        )
                                      : const _VideoSkeleton())),
                        );
                                      } else if (fileType == 'image' && filePath != null) {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                                            filePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.black,
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                              ),
                            ),
                                        );
                                      } else {
                                        mediaWidget = ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Container(
                                            color: Colors.black,
                                            child: const Center(child: Icon(Icons.media_bluetooth_off, color: Colors.white54)),
                                          ),
                                        );
                                      }
                                    } else {
                                      mediaWidget = ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          color: Colors.black,
                                          child: const Center(child: Icon(Icons.media_bluetooth_off, color: Colors.white54)),
                          ),
                        );
                      }
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(rotationY),
                        child: Opacity(
                          opacity: opacity,
                          child: Stack(
                            children: [
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: mediaWidget,
                              ),
                              // Video description at the bottom
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _VideoDescriptionBar(
                                  description: _currentPage < _posts.length 
                                      ? _posts[_currentPage]['description']?.toString() ?? 'No description available'
                                      : 'Loading...',
                                ),
                              ),
                        ],
                    ),
                  ),
                      );
                    },
                  );
                },
                    ),
                  ),
            // User info & actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  CircleAvatar(
                    backgroundColor: Colors.amber,
                  child: _currentPage < _posts.length && _posts[_currentPage]['user'] != null
                      ? Text(
                          _posts[_currentPage]['user']['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        )
                      : const Icon(Icons.person, color: Colors.black),
                            ),
                            const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _currentPage < _posts.length && _posts[_currentPage]['user'] != null
                          ? _posts[_currentPage]['user']['username']?.toString() ?? 'Unknown User'
                          : 'Loading...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _toggleLike(_currentPage) : null,
                    child: _iconStatColumn(
                      _currentPage < _posts.length && _liked[_currentPage] ? Icons.favorite : Icons.favorite_border,
                      _currentPage < _posts.length ? _formatCount(_likeCounts[_currentPage]) : '0',
                      color: _currentPage < _posts.length && _liked[_currentPage] ? Colors.amber : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showComments,
                    child: _iconStatColumn(
                      Icons.message_outlined, 
                      _currentPage < _posts.length ? _formatCount(_commentCounts[_currentPage]) : '0'
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _toggleSave(_currentPage) : null,
                    child: _iconStatColumn(
                      _currentPage < _posts.length && _saved[_currentPage] ? Icons.bookmark : Icons.bookmark_border,
                      _currentPage < _posts.length ? _formatCount(_saveCounts[_currentPage]) : '0',
                      color: _currentPage < _posts.length && _saved[_currentPage] ? Colors.amber : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _isDuetAllowed(_currentPage) && !(_duetLoading[_currentPage] ?? false) 
                        ? () => _createDuet(_posts[_currentPage]['id'])
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(_duetLoading[_currentPage] == true ? 0.9 : 1.0),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _duetLoading[_currentPage] == true ? 0.7 : (_isDuetAllowed(_currentPage) ? 1.0 : 0.4),
                        child: _iconStatColumn(
                          Icons.control_point_duplicate,
                          'Duet',
                          color: _isDuetAllowed(_currentPage) ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _showTajStarsGift(context),
                    child: _iconStatColumn(Icons.card_giftcard, 'Gift'),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _currentPage < _posts.length ? () => _share(_currentPage) : null,
                    child: _iconStatColumn(Icons.share_outlined, 'Share'),
                  ),
                ],
              ),
            ),
            // Bottom nav buttons
            BottomNavigationBar(
              backgroundColor: const Color(0xFF232323),
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_outlined),
                  label: 'Connect',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.live_tv_outlined),
                  label: 'Channel',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  label: 'Market',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_graph_outlined),
                  label: 'Earn',
                ),
              ],
              currentIndex: 0, // Valid index, but all tabs look unselected
              onTap: (int index) {
                if (index == 0) {
                  context.go('/connect');
                } else if (index == 1) {
                  context.go('/channel');
                } else if (index == 3) {
                  context.go('/earn');
                }
                // Add navigation for other tabs as needed
              },
                  ),
                ],
              ),
            ),
          );
  }

  Widget _iconStat(IconData icon, String stat) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 2),
        Text(stat, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  Widget _iconStatColumn(IconData icon, String stat, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 1),
        Text(stat, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

class _VideoDescriptionBar extends StatefulWidget {
  final String? description;
  const _VideoDescriptionBar({this.description});

  @override
  State<_VideoDescriptionBar> createState() => _VideoDescriptionBarState();
}

class _VideoDescriptionBarState extends State<_VideoDescriptionBar> {
  bool _expanded = false;
  bool _textOverflows = false;
  final GlobalKey _textKey = GlobalKey();
  final String _fallbackDescription = 'No description available';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
  }

  void _checkTextOverflow() {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: widget.description ?? _fallbackDescription,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: renderBox.size.width);
      setState(() {
        _textOverflows = textPainter.didExceedMaxLines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxLines = _expanded ? 5 : 1;
    final overflow = _expanded ? TextOverflow.visible : TextOverflow.ellipsis;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(minHeight: 70),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black54,
            Colors.black87,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              key: _textKey,
              widget.description ?? _fallbackDescription,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
          if (_textOverflows || _expanded)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  _expanded ? 'see less' : 'see more',
                  style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarouselImageSlider extends StatefulWidget {
  final List<String> images;
  const _CarouselImageSlider({required this.images});

  @override
  State<_CarouselImageSlider> createState() => _CarouselImageSliderState();
}

class _CarouselImageSliderState extends State<_CarouselImageSlider> {
  int _current = 0;
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _current = i),
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, i) => Image.network(
            widget.images[i],
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black,
              child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
            ),
          ),
        ),
        // Media count badge at top right
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 4),
        Text(
                  '${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _current ? Colors.amber : Colors.white24,
              ),
            )),
          ),
        ),
      ],
    );
  }
}

class _TajStarsGiftModal extends StatefulWidget {
  @override
  State<_TajStarsGiftModal> createState() => _TajStarsGiftModalState();
}

class _TajStarsGiftModalState extends State<_TajStarsGiftModal> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  int _selectedStars = 0;
  final List<Map<String, dynamic>> _starOptions = [
    {'stars': 10, 'color': Colors.blue, 'icon': Icons.star_border},
    {'stars': 50, 'color': Colors.green, 'icon': Icons.star_half},
    {'stars': 100, 'color': Colors.orange, 'icon': Icons.star},
    {'stars': 200, 'color': Colors.purple, 'icon': Icons.stars},
    {'stars': 500, 'color': Colors.red, 'icon': Icons.auto_awesome},
    {'stars': 1000, 'color': Colors.amber, 'icon': Icons.workspace_premium},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.purple.withOpacity(0.3),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                // Header
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.amber.withOpacity(0.3),
                                      Colors.orange.withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber,
                                  size: 56,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Send TajStars',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            fontFamily: 'Ebrima',
                            shadows: [
                              Shadow(
                                color: Colors.amber,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '✨ Show your appreciation with TajStars! ✨',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontFamily: 'Ebrima',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Star options
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _starOptions.length,
                        itemBuilder: (context, index) {
                          final option = _starOptions[index];
                          final stars = option['stars'] as int;
                          final color = option['color'] as Color;
                          final icon = option['icon'] as IconData;
                          final isSelected = _selectedStars == stars;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedStars = stars;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          color.withOpacity(0.8),
                                          color.withOpacity(0.6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSelected ? null : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? color : Colors.white.withOpacity(0.2),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 15,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: color.withOpacity(0.2),
                                          blurRadius: 30,
                                          offset: const Offset(0, 12),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Stack(
                                children: [
                                  if (isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          gradient: RadialGradient(
                                            colors: [
                                              color.withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          icon,
                                          color: isSelected ? Colors.white : color,
                                          size: 36,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        stars.toString(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          fontFamily: 'Ebrima',
                                        ),
                                      ),
                                      Text(
                                        'TajStars',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                          fontFamily: 'Ebrima',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Send button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: _selectedStars > 0
                          ? LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: _selectedStars > 0 ? null : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _selectedStars > 0
                          ? [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _selectedStars > 0 ? () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.stars, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('Sent $_selectedStars TajStars! ✨'),
                                ],
                              ),
                              backgroundColor: Colors.amber,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        } : null,
                        child: Center(
                          child: Text(
                            _selectedStars > 0 ? 'Send $_selectedStars TajStars' : 'Select Stars',
                            style: TextStyle(
                              color: _selectedStars > 0 ? Colors.black : Colors.grey[400],
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Ebrima',
                            ),
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
    );
  }
} 