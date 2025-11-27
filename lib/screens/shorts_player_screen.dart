import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class ShortsPlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  const ShortsPlayerScreen({required this.videos, required this.initialIndex, Key? key}) : super(key: key);

  @override
  State<ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<ShortsPlayerScreen> {
  late PageController _pageController;
  late List<VideoPlayerController?> _videoControllers;
  int _currentPage = 0;
  // Add like/save/share state per video
  late List<bool> _liked;
  late List<int> _likeCounts;
  late List<bool> _saved;
  late List<int> _commentCounts;
  // Add play/pause state
  late List<bool> _isPlaying;
  
  // Add API service
  final ApiService _apiService = ApiService();
  
  // Add loading states for interactions
  late List<bool> _likeLoading;
  late List<bool> _saveLoading;
  
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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _videoControllers = widget.videos.map((video) {
      final url = video['media_files']?[0]?['file_path']?.toString() ?? '';
      final controller = VideoPlayerController.network(url);
      controller.setLooping(true);
      controller.setVolume(1);
      controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
          // Auto-play the initial video after initialization
          if (_videoControllers.indexOf(controller) == _currentPage) {
            controller.play();
            _isPlaying[_currentPage] = true;
          }
        }
      });
      return controller;
    }).toList();
    
    // Initialize like/save/share state
    _liked = List.generate(widget.videos.length, (_) => false);
    _likeCounts = List.generate(widget.videos.length, (i) => 1000 + i * 100); // placeholder
    _saved = List.generate(widget.videos.length, (_) => false);
    _commentCounts = List.generate(widget.videos.length, (i) => 50 + i * 10); // placeholder
    _isPlaying = List.generate(widget.videos.length, (_) => false);
    _likeLoading = List.generate(widget.videos.length, (_) => false);
    _saveLoading = List.generate(widget.videos.length, (_) => false);
    
    // Load interaction counts from API
    _loadInteractionCounts();
    
    // Auto-play the initial video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_videoControllers[_currentPage]?.value.isInitialized ?? false) {
        _videoControllers[_currentPage]?.play();
        _isPlaying[_currentPage] = true;
        setState(() {});
      }
    });
  }

  Future<void> _loadInteractionCounts() async {
    for (int i = 0; i < widget.videos.length; i++) {
      try {
        final postId = widget.videos[i]['id'];
        final response = await _apiService.getInteractionCounts(postId);
        if (response.data['success']) {
          final data = response.data['data'];
          setState(() {
            _likeCounts[i] = data['likes_count'] ?? 0;
            _commentCounts[i] = data['comments_count'] ?? 0;
            _liked[i] = data['is_liked'] ?? false;
            _saved[i] = data['is_saved'] ?? false;
          });
        }
      } catch (e) {
        print('Error loading interaction counts for video $i: $e');
      }
    }
  }

  @override
  void dispose() {
    for (var c in _videoControllers) {
      c?.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
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

  void _toggleLike(int index) async {
    if (_likeLoading[index]) return; // Prevent multiple calls
    
    setState(() {
      _likeLoading[index] = true;
    });
    
    try {
      final postId = widget.videos[index]['id'];
      final response = await _apiService.toggleLike(postId);
      
      if (response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _liked[index] = data['is_liked'] ?? false;
          _likeCounts[index] = data['likes_count'] ?? 0;
          _likeLoading[index] = false;
        });
      } else {
        // Revert on error
        setState(() {
          _likeLoading[index] = false;
        });
      }
    } catch (e) {
      print('Error toggling like for video $index: $e');
      setState(() {
        _likeLoading[index] = false;
    });
    }
  }

  void _toggleSave(int index) async {
    if (_saveLoading[index]) return; // Prevent multiple calls
    
    setState(() {
      _saveLoading[index] = true;
    });
    
    try {
      final postId = widget.videos[index]['id'];
      final response = await _apiService.toggleSave(postId);
      
      if (response.data['success']) {
        final data = response.data['data'];
        setState(() {
          _saved[index] = data['is_saved'] ?? false;
          _saveLoading[index] = false;
    });
      } else {
        // Revert on error
        setState(() {
          _saveLoading[index] = false;
        });
      }
    } catch (e) {
      print('Error toggling save for video $index: $e');
      setState(() {
        _saveLoading[index] = false;
      });
    }
  }

  Future<void> _loadComments() async {
    if (_commentsLoading) return;
    
    print('[DEBUG] Loading comments for current video');
    setState(() {
      _commentsLoading = true;
      _comments = []; // Clear existing comments while loading
    });
    
    try {
      final postId = widget.videos[_currentPage]['id'];
      print('[DEBUG] Calling getComments API for postId: $postId');
      final response = await _apiService.getComments(postId);
      print('[DEBUG] Get comments response: ${response.data}');
      
      if (mounted && response.data['success']) {
        final comments = List<Map<String, dynamic>>.from(response.data['data']['data'] ?? []);
        
        // Process comments to extract replies
        for (var comment in comments) {
          final commentId = comment['id'];
          final replies = comment['replies'] ?? [];
          
          // Store replies for this comment
          if (replies.isNotEmpty) {
            _commentReplies[commentId] = List<Map<String, dynamic>>.from(replies);
          }
          
          // Add replies count to comment
          comment['replies_count'] = replies.length;
        }
        
        setState(() {
          _comments = comments;
          _commentsLoading = false;
        });
        print('[DEBUG] Loaded ${_comments.length} comments with replies');
      } else {
        print('[ERROR] Get comments failed: ${response.data}');
        if (mounted) {
          setState(() {
            _comments = [];
            _commentsLoading = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error loading comments: $e');
      if (mounted) {
        setState(() {
          _comments = [];
          _commentsLoading = false;
        });
      }
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final content = _commentController.text.trim();
    _commentController.clear();
    
    try {
      final postId = widget.videos[_currentPage]['id'];
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
    
    setState(() {
      _repliesLoading[commentId] = true;
    });
    
    try {
      final response = await _apiService.getCommentReplies(commentId);
      
      if (mounted && response.data['success']) {
        setState(() {
          _commentReplies[commentId] = List<Map<String, dynamic>>.from(response.data['data']['data']);
          _repliesLoading[commentId] = false;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading comment replies: $e');
      if (mounted) {
        setState(() {
          _repliesLoading[commentId] = false;
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
      final postId = widget.videos[_currentPage]['id'];
      final response = await _apiService.addCommentReply(postId, content, commentId);
      
      if (mounted && response.data['success']) {
        // Refresh comments to show the new reply
        await _loadComments();
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
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
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
                      itemCount: 8,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
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
                                  const SizedBox(width: 12),
                                  // Content skeleton
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Name skeleton
                                        Container(
                                          width: 120,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[800],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Comment text skeleton
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
                                          width: MediaQuery.of(context).size.width * 0.6,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[800],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Time and actions skeleton
                                        Row(
                                          children: [
                                            Container(
                                              width: 60,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Container(
                                              width: 40,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[800],
                                                borderRadius: BorderRadius.circular(4),
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
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          showReplies ? 'Hide' : 'Show',
                                                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w500),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '${repliesCount} ${repliesCount == 1 ? 'reply' : 'replies'}',
                                                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                                                        ),
                                                      ],
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
                                        Container(
                                          margin: const EdgeInsets.only(left: 60, right: 16, top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                                          ),
                                          child: Column(
                                            children: replies.map((reply) => Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: Colors.amber.withOpacity(0.7),
                                                    radius: 14,
                                                    child: Text(
                                                      reply['user']?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              reply['user']?['name']?.toString() ?? 'Unknown User',
                                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              _formatCommentTime(reply['created_at']),
                                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          reply['content']?.toString() ?? '',
                                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                        ),
                                                      ],
                                                    ),
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
                            onSubmitted: (_) => _addComment(),
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

  void _share(int index) async {
    try {
      final postId = widget.videos[index]['id'];
      await _apiService.share(postId);
      
      final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url);
      } else {
        Share.share('Check out this video!');
      }
    } catch (e) {
      print('Error sharing video $index: $e');
      // Still share even if API call fails
    final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
    if (url.isNotEmpty) {
      Share.share(url);
    } else {
      Share.share('Check out this video!');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.pop();
      },
      child: Scaffold(
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
                    onPressed: () {},
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.message_outlined, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
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
                    onPressed: () {},
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Main Content (video + overlays)
            Expanded(
              child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              onPageChanged: _onPageChanged,
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                final controller = _videoControllers[index]!;
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
                    final double rotationY = value * 1.2; // radians
                    final double opacity = (1 - value.abs()).clamp(0.0, 1.0);
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(rotationY),
                      child: Opacity(
                        opacity: opacity,
                        child: Stack(
                          children: [
                            Center(
                              child: controller.value.isInitialized
                                  ? GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (controller.value.isPlaying) {
                                            controller.pause();
                                            _isPlaying[index] = false;
                                          } else {
                                            controller.play();
                                            _isPlaying[index] = true;
                                          }
                                        });
                                      },
                                        child: Center(
                                                  child: FittedBox(
                                            fit: BoxFit.contain,
                                                    child: SizedBox(
                                                      width: controller.value.size.width,
                                                      height: controller.value.size.height,
                                                      child: VideoPlayer(controller),
                                                    ),
                                                  ),
                                                ),
                                      )
                                    : const Center(child: CircularProgressIndicator()),
                              ),
                              // Description bar overlays the bottom of the video
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _VideoDescriptionBar(),
                              ),
                              // Back button on the video in top left
                              Positioned(
                                top: 20,
                                left: 20,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                                        shape: BoxShape.circle,
                                                      ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                                    onPressed: () => Navigator.of(context).pop(),
                                    iconSize: 20,
                                    padding: const EdgeInsets.all(8),
                                    constraints: BoxConstraints(),
                                  ),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.person, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'username',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                    onTap: _likeLoading[_currentPage] ? null : () => _toggleLike(_currentPage),
                    child: _likeLoading[_currentPage]
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          )
                        : _iconStatColumn(
                        _liked[_currentPage] ? Icons.favorite : Icons.favorite_border,
                        _formatCount(_likeCounts[_currentPage]),
                        color: _liked[_currentPage] ? Colors.amber : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _showComments,
                      child: _iconStatColumn(Icons.message_outlined, '5677'),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                    onTap: _saveLoading[_currentPage] ? null : () => _toggleSave(_currentPage),
                    child: _saveLoading[_currentPage]
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          )
                        : _iconStatColumn(
                        _saved[_currentPage] ? Icons.bookmark : Icons.bookmark_border,
                        '8.2K',
                        color: _saved[_currentPage] ? Colors.amber : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _iconStatColumn(Icons.control_point_duplicate, 'Duet'),
                    const SizedBox(width: 16),
                    _iconStatColumn(Icons.card_giftcard, 'Gift'),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _share(_currentPage),
                      child: _iconStatColumn(Icons.share_outlined, '12.5K'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
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
}

class _VideoDescriptionBar extends StatefulWidget {
  @override
  State<_VideoDescriptionBar> createState() => _VideoDescriptionBarState();
}

class _VideoDescriptionBarState extends State<_VideoDescriptionBar> {
  bool _expanded = false;
  final String _description = 'I just love my life – life is good. This is a longer description to demonstrate the see more and see less functionality. Tajify is awesome!';

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
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              _description,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
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