import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class TubePlayerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;
  const TubePlayerScreen({required this.videos, required this.initialIndex, Key? key}) : super(key: key);

  @override
  State<TubePlayerScreen> createState() => _TubePlayerScreenState();
}

class _TubePlayerScreenState extends State<TubePlayerScreen> with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late List<VideoPlayerController?> _videoControllers;
  int _currentPage = 0;
  // Add like/save/share state per video
  late List<bool> _liked;
  late List<int> _likeCounts;
  late List<bool> _saved;
  late List<int> _saveCounts;
  late List<int> _commentCounts;
  // Add play/pause state
  late List<bool> _isPlaying;
  
  // Add API service
  final ApiService _apiService = ApiService();
  
  // Add loading states for interactions
  late List<bool> _likeLoading;
  late List<bool> _saveLoading;
  
  // Add tap animation states
  late List<bool> _likeTapped;
  late List<bool> _saveTapped;
  
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
  
  // Memory management
  bool _disposed = false;
  static const int _maxControllers = 3; // Only keep 3 controllers in memory

  @override
  bool get wantKeepAlive => false; // Don't keep alive to prevent memory issues

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialize arrays
    _liked = List.generate(widget.videos.length, (_) => false);
    _likeCounts = List.generate(widget.videos.length, (_) => 0);
    _saved = List.generate(widget.videos.length, (_) => false);
    _saveCounts = List.generate(widget.videos.length, (_) => 0);
    _commentCounts = List.generate(widget.videos.length, (_) => 0);
    _isPlaying = List.generate(widget.videos.length, (_) => false);
    _likeLoading = List.generate(widget.videos.length, (_) => false);
    _saveLoading = List.generate(widget.videos.length, (_) => false);
    _likeTapped = List.generate(widget.videos.length, (_) => false);
    _saveTapped = List.generate(widget.videos.length, (_) => false);
    
    // Initialize video controllers with lazy loading
    _videoControllers = List.generate(widget.videos.length, (_) => null);
    
    // Load initial video controller
    _initializeVideoController(widget.initialIndex);
    
    // Load interaction counts from API
    _loadInteractionCounts();
    
    // Auto-play the initial video
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && (_videoControllers[_currentPage]?.value.isInitialized ?? false)) {
        _videoControllers[_currentPage]?.play();
        _isPlaying[_currentPage] = true;
        setState(() {});
      }
    });
  }

  Future<void> _initializeVideoController(int index) async {
    if (_disposed || index < 0 || index >= widget.videos.length) return;
    
    // Dispose old controllers if we have too many
    _cleanupOldControllers();
    
    // Initialize the requested controller
    if (_videoControllers[index] == null) {
      try {
        final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
        if (url.isNotEmpty) {
          print('[DEBUG] Initializing video controller for index $index');
          final controller = VideoPlayerController.network(url);
          controller.setLooping(true);
          controller.setVolume(1);
          
          await controller.initialize();
          
          if (!_disposed && mounted) {
            setState(() {
              _videoControllers[index] = controller;
            });
            
            // Auto-play if this is the current page
            if (index == _currentPage) {
              controller.play();
              _isPlaying[_currentPage] = true;
            }
          } else {
            // Dispose if widget was disposed during initialization
            controller.dispose();
          }
        }
      } catch (e) {
        print('[ERROR] Error initializing video controller for index $index: $e');
      }
    }
  }

  void _cleanupOldControllers() {
    // Count active controllers
    int activeCount = 0;
    for (var controller in _videoControllers) {
      if (controller != null) activeCount++;
    }
    
    // If we have too many, dispose the oldest ones (except current and adjacent)
    if (activeCount >= _maxControllers) {
      for (int i = 0; i < _videoControllers.length; i++) {
        if (_videoControllers[i] != null && 
            i != _currentPage && 
            i != _currentPage - 1 && 
            i != _currentPage + 1) {
          print('[DEBUG] Disposing video controller for index $i');
          _videoControllers[i]?.dispose();
          _videoControllers[i] = null;
          activeCount--;
          if (activeCount < _maxControllers) break;
        }
      }
    }
  }

  Future<void> _loadInteractionCounts() async {
    if (_disposed) return;
    
    print('[DEBUG] Loading interaction counts for ${widget.videos.length} videos');
    for (int i = 0; i < widget.videos.length; i++) {
      if (_disposed) break;
      
      try {
        final postId = widget.videos[i]['id'];
        print('[DEBUG] Loading counts for video $i, postId: $postId');
        final response = await _apiService.getInteractionCounts(postId);
        print('[DEBUG] Interaction counts response for video $i: ${response.data}');
        
        if (!_disposed && response.data['success']) {
          final data = response.data['data'];
          final counts = data['counts'] ?? {};
          final userInteractions = data['user_interactions'] ?? {};
          
          setState(() {
            _likeCounts[i] = counts['likes'] ?? 0;
            _commentCounts[i] = counts['comments'] ?? 0;
            _saveCounts[i] = counts['saves'] ?? 0;
            _liked[i] = userInteractions['liked'] ?? false;
            _saved[i] = userInteractions['saved'] ?? false;
          });
          print('[DEBUG] Updated counts for video $i - likes: ${_likeCounts[i]}, comments: ${_commentCounts[i]}, saves: ${_saveCounts[i]}, liked: ${_liked[i]}, saved: ${_saved[i]}');
        }
      } catch (e) {
        print('[ERROR] Error loading interaction counts for video $i: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    print('[DEBUG] Disposing TubePlayerScreen');
    
    // Dispose all video controllers
    for (int i = 0; i < _videoControllers.length; i++) {
      if (_videoControllers[i] != null) {
        print('[DEBUG] Disposing video controller $i');
        _videoControllers[i]?.dispose();
        _videoControllers[i] = null;
      }
    }
    
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_disposed) return;
    
    setState(() {
      _currentPage = index;
    });
    
    // Pause all videos
    for (int i = 0; i < _videoControllers.length; i++) {
      if (_videoControllers[i] != null) {
        _videoControllers[i]!.pause();
        _isPlaying[i] = false;
      }
    }
    
    // Initialize and play the new video
    _initializeVideoController(index).then((_) {
      if (!_disposed && (_videoControllers[index]?.value.isInitialized ?? false)) {
        _videoControllers[index]?.play();
        _isPlaying[index] = true;
        setState(() {});
      }
    });
  }

  void _toggleLike(int index) async {
    if (_disposed || _likeLoading[index]) return; // Prevent multiple calls
    
    print('[DEBUG] Toggling like for video $index');
    
    // Trigger tap animation
    setState(() {
      _likeTapped[index] = true;
    });
    
    // Reset tap animation after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_disposed) {
        setState(() {
          _likeTapped[index] = false;
        });
      }
    });
    
    // Immediate UI feedback
    final previousLiked = _liked[index];
    final previousCount = _likeCounts[index];
    
    setState(() {
      _likeLoading[index] = true;
      _liked[index] = !_liked[index]; // Toggle immediately
      _likeCounts[index] = _liked[index] ? previousCount + 1 : previousCount - 1; // Update count immediately
    });
    
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling toggleLike API for postId: $postId');
      final response = await _apiService.toggleLike(postId);
      print('[DEBUG] Toggle like response: ${response.data}');
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        
        setState(() {
          _liked[index] = data['liked'] ?? false;
          _likeCounts[index] = data['like_count'] ?? 0;
          _likeLoading[index] = false;
        });
        print('[DEBUG] Like toggled successfully - is_liked: ${_liked[index]}, count: ${_likeCounts[index]}');
      } else {
        print('[ERROR] Toggle like failed: ${response.data}');
        // Revert to previous state on error
        if (!_disposed) {
          setState(() {
            _liked[index] = previousLiked;
            _likeCounts[index] = previousCount;
            _likeLoading[index] = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error toggling like for video $index: $e');
      // Revert to previous state on error
      if (!_disposed) {
        setState(() {
          _liked[index] = previousLiked;
          _likeCounts[index] = previousCount;
          _likeLoading[index] = false;
        });
      }
    }
  }

  void _toggleSave(int index) async {
    if (_disposed || _saveLoading[index]) return; // Prevent multiple calls
    
    print('[DEBUG] Toggling save for video $index');
    
    // Trigger tap animation
    setState(() {
      _saveTapped[index] = true;
    });
    
    // Reset tap animation after a short delay
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_disposed) {
        setState(() {
          _saveTapped[index] = false;
        });
      }
    });
    
    // Immediate UI feedback
    final previousSaved = _saved[index];
    final previousCount = _saveCounts[index];
    
    setState(() {
      _saveLoading[index] = true;
      _saved[index] = !_saved[index]; // Toggle immediately
      _saveCounts[index] = _saved[index] ? previousCount + 1 : previousCount - 1; // Update count immediately
    });
    
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling toggleSave API for postId: $postId');
      final response = await _apiService.toggleSave(postId);
      print('[DEBUG] Toggle save response: ${response.data}');
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        
        setState(() {
          _saved[index] = data['saved'] ?? false;
          _saveLoading[index] = false;
        });
        print('[DEBUG] Save toggled successfully - is_saved: ${_saved[index]}');
        
        // Refresh the save count from the interaction counts endpoint
        await _refreshSaveCount(index);
      } else {
        print('[ERROR] Toggle save failed: ${response.data}');
        // Revert to previous state on error
        if (!_disposed) {
          setState(() {
            _saved[index] = previousSaved;
            _saveCounts[index] = previousCount;
            _saveLoading[index] = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error toggling save for video $index: $e');
      // Revert to previous state on error
      if (!_disposed) {
        setState(() {
          _saved[index] = previousSaved;
          _saveCounts[index] = previousCount;
          _saveLoading[index] = false;
        });
      }
    }
  }

  Future<void> _refreshSaveCount(int index) async {
    if (_disposed) return;
    
    try {
      final postId = widget.videos[index]['id'];
      final response = await _apiService.getInteractionCounts(postId);
      
      if (!_disposed && response.data['success']) {
        final data = response.data['data'];
        final counts = data['counts'] ?? {};
        
        setState(() {
          _saveCounts[index] = counts['saves'] ?? 0;
        });
        print('[DEBUG] Refreshed save count for video $index: ${_saveCounts[index]}');
      }
    } catch (e) {
      print('[ERROR] Error refreshing save count for video $index: $e');
    }
  }

  Future<void> _loadComments() async {
    if (_disposed || _commentsLoading) return;
    
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
      
      if (!_disposed && response.data['success']) {
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
        if (!_disposed) {
          setState(() {
            _comments = [];
            _commentsLoading = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error loading comments: $e');
      if (!_disposed) {
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
      
      if (!_disposed && response.data['success']) {
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
      
      if (!_disposed && response.data['success']) {
        setState(() {
          _commentReplies[commentId] = List<Map<String, dynamic>>.from(response.data['data']['data']);
          _repliesLoading[commentId] = false;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading comment replies: $e');
      if (!_disposed) {
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

  void _addCommentReply(int commentId) async {
    final controller = _replyControllers[commentId];
    if (controller == null || controller.text.trim().isEmpty) return;
    
    final content = controller.text.trim();
    controller.clear();
    
    try {
      final postId = widget.videos[_currentPage]['id'];
      final response = await _apiService.addCommentReply(postId, content, commentId);
      
      if (!_disposed && response.data['success']) {
        // Refresh replies for this comment
        await _loadCommentReplies(commentId);
      }
    } catch (e) {
      print('[ERROR] Error adding comment reply: $e');
    }
  }

  TextEditingController _getReplyController(int commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  // Duet methods
  Future<void> _createDuet(int postId) async {
    if (_duetLoading[postId] == true) return;
    
    setState(() {
      _duetLoading[postId] = true;
    });
    
    try {
      // For now, we'll create a duet with the current user's latest post
      // In a real implementation, you'd show a video picker
      final response = await _apiService.createDuet(postId, postId); // This is a placeholder
      
      if (!_disposed && response.data['success']) {
        // Show success message or navigate to duet creation
        print('[DEBUG] Duet created successfully');
      }
    } catch (e) {
      print('[ERROR] Error creating duet: $e');
    } finally {
      if (!_disposed) {
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
      
      if (!_disposed && response.data['success']) {
        setState(() {
          _duetFeed[postId] = List<Map<String, dynamic>>.from(response.data['data']['duets']['data']);
          _duetLoading[postId] = false;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading duet feed: $e');
      if (!_disposed) {
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
    final post = widget.videos[index];
    return post['allow_duet'] == true && post['is_prime'] != true;
  }

  void _showComments() {
    _loadComments(); // Load comments when modal opens
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  ),
                                                  onSubmitted: (_) => _addCommentReply(commentId),
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
                                      if (showReplies && _repliesLoading[commentId] == true)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 60, right: 16),
                                          child: Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16.0),
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      const Divider(color: Colors.white24, height: 1),
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

  void _share(int index) async {
    if (_disposed) return;
    
    print('[DEBUG] Sharing video $index');
    try {
      final postId = widget.videos[index]['id'];
      print('[DEBUG] Calling share API for postId: $postId');
      await _apiService.share(postId);
      print('[DEBUG] Share API call successful');
      
      final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url);
      } else {
        Share.share('Check out this video!');
      }
    } catch (e) {
      print('[ERROR] Error sharing video $index: $e');
      // Still share even if API call fails
      final url = widget.videos[index]['media_files']?[0]?['file_path']?.toString() ?? '';
      if (url.isNotEmpty) {
        Share.share(url);
      } else {
        Share.share('Check out this video!');
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$m:$s';
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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_disposed) {
      return const Scaffold(
        backgroundColor: Color(0xFF232323),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }
    
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
                  final video = widget.videos[index];
                  final controller = _videoControllers[index];
                  
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
                              // Video player
                              GestureDetector(
                                onTap: () {
                                  if (!_disposed && controller?.value.isInitialized == true) {
                                    setState(() {
                                      if (controller!.value.isPlaying) {
                                        controller.pause();
                                        _isPlaying[index] = false;
                                      } else {
                                        controller.play();
                                        _isPlaying[index] = true;
                                      }
                                    });
                                  }
                                },
                                child: Center(
                                  child: controller?.value.isInitialized == true
                                      ? FittedBox(
                                          fit: BoxFit.contain,
                                          child: SizedBox(
                                            width: controller!.value.size.width,
                                            height: controller!.value.size.height,
                                            child: VideoPlayer(controller!),
                                          ),
                                        )
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                          ),
                                        ),
                                ),
                              ),
                              // Play/Pause icon overlay
                              if (controller?.value.isInitialized == true && !controller!.value.isPlaying)
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
                              // Back button
                              Positioned(
                                top: 20,
                                left: 20,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              // Video description bar
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _VideoDescriptionBar(
                                  description: widget.videos[index]['description'] ?? 'No description available',
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
                  const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('username', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _likeLoading[_currentPage] ? null : () => _toggleLike(_currentPage),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(
                        _likeTapped[_currentPage] ? 0.8 : 
                        _likeLoading[_currentPage] ? 0.9 : 1.0
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _likeLoading[_currentPage] ? 0.7 : 1.0,
                        child: _iconStatColumn(
                          _liked[_currentPage] ? Icons.favorite : Icons.favorite_border,
                          _formatCount(_likeCounts[_currentPage]),
                          color: _liked[_currentPage] ? Colors.amber : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _showComments,
                    child: _iconStatColumn(Icons.message_outlined, _formatCount(_commentCounts[_currentPage])),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _saveLoading[_currentPage] ? null : () => _toggleSave(_currentPage),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.identity()..scale(
                        _saveTapped[_currentPage] ? 0.8 : 
                        _saveLoading[_currentPage] ? 0.9 : 1.0
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _saveLoading[_currentPage] ? 0.7 : 1.0,
                        child: _iconStatColumn(
                          _saved[_currentPage] ? Icons.bookmark : Icons.bookmark_border,
                          _formatCount(_saveCounts[_currentPage]),
                          color: _saved[_currentPage] ? Colors.amber : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _isDuetAllowed(_currentPage) && !(_duetLoading[_currentPage] ?? false) 
                        ? () => _createDuet(widget.videos[_currentPage]['id'])
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
                  _iconStatColumn(Icons.card_giftcard, 'Gift'),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _share(_currentPage),
                    child: _iconStatColumn(Icons.share_outlined, 'Share'),
                  ),
                ],
              ),
            ),
          ],
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
  final String description;
  const _VideoDescriptionBar({required this.description});

  @override
  State<_VideoDescriptionBar> createState() => _VideoDescriptionBarState();
}

class _VideoDescriptionBarState extends State<_VideoDescriptionBar> {
  bool _expanded = false;
  bool _textOverflows = false;
  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Check for text overflow after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
  }

  void _checkTextOverflow() {
    final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: widget.description,
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
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              widget.description,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: maxLines,
              overflow: overflow,
              key: _textKey,
            ),
          ),
          if (_textOverflows)
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