import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import 'tube_player_screen.dart';
import 'shorts_player_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _apiService.getSavedPosts();
      
      if (response.data['success']) {
        final data = response.data['data'];
        final saves = List<Map<String, dynamic>>.from(data['data'] ?? []);
        
        // Extract posts from saves
        final posts = saves.map((save) => save['post']).where((post) => post != null).cast<Map<String, dynamic>>().toList();
        
        setState(() {
          _savedPosts = posts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = response.data['message'] ?? 'Failed to load saved posts';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error loading saved posts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    await _loadSavedPosts();
  }

  void _openPost(List<Map<String, dynamic>> posts, int index) {
    if (index < 0 || index >= posts.length) return;
    
    final post = posts[index];
    final postType = post['post_type']?['name'] ?? '';
    
    if (postType == 'tube_short') {
      context.push('/shorts-player', extra: {
        'videos': posts,
        'initialIndex': index,
      });
    } else if (postType == 'tube_max' || postType == 'tube_prime') {
      context.push('/tube-player', extra: {
        'videos': posts,
        'initialIndex': index,
      });
    }
  }

  Widget _mediaCard(Map<String, dynamic> video) {
    final index = _savedPosts.indexOf(video);
    final videoUrl = video['media_files']?[0]?['file_path']?.toString() ?? '';
    return GestureDetector(
      onTap: () => _openPost(_savedPosts, index),
      child: _VideoPreviewCard(url: videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232323),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          child: Padding(
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
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top brown tab with back button
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _topTab('Saved', true)),
                ],
              ),
              const SizedBox(height: 4),
              // Orange sub-tabs
              Container(
                width: double.infinity,
                color: const Color(0xFFFFD6B0),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _refreshPosts,
                      child: Icon(Icons.refresh, color: Colors.brown, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Content based on loading state
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                )
              else if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshPosts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_savedPosts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          color: Colors.white54,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No saved posts yet',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Posts you save will appear here',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // All saved posts in a grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: _savedPosts.length,
                  itemBuilder: (context, index) {
                    return _mediaCard(_savedPosts[index]);
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          elevation: 4,
          onPressed: () {
            context.go('/home');
          },
          child: const Icon(Icons.home, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF232323),
        selectedItemColor: Colors.amber,
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
        currentIndex: 1, // Channel tab is active
        onTap: (int index) {
          if (index == 0) {
            context.go('/connect');
          } else if (index == 1) {
            context.go('/channel');
          } else if (index == 2) {
            context.go('/market');
          } else if (index == 3) {
            context.go('/earn');
          }
        },
      ),
    );
  }

  Widget _topTab(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.brown[400] : Colors.brown[600],
        border: Border.all(color: Colors.brown[300]!, width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.brown[200],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewCard extends StatefulWidget {
  final String url;
  const _VideoPreviewCard({required this.url});

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.url)
        ..setLooping(true)
        ..setVolume(0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _initialized = true);
        if (_controller!.value.isInitialized) {
          _controller!.play(); // Always auto-play preview, muted
        }
      }
    } catch (e) {
      print('Video initialization error for ${widget.url}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
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
    return Container(
      width: 100,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _hasError
                ? Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                        size: 30,
                      ),
                    ),
                  )
                : _initialized && _controller != null
                    ? Center(
                        child: Stack(
                          alignment: Alignment.center,
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
                          ],
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

