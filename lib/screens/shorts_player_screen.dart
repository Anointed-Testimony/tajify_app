import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
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
  // Add play/pause state
  late List<bool> _isPlaying;
  
  // Add API service
  final ApiService _apiService = ApiService();
  
  // Add loading states for interactions
  late List<bool> _likeLoading;
  late List<bool> _saveLoading;

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

  void _showComments() {
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
                  const Text('Comments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 8,
                      itemBuilder: (context, i) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.person, color: Colors.black),
                        ),
                        title: Text('User $i', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('This is a comment from user $i.', style: const TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
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
                          onPressed: () {},
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