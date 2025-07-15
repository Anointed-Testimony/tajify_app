import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

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
  final List<String> _carouselImages = [
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1465101046530-73398c7f28ca?auto=format&fit=crop&w=400&q=80',
    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=crop&w=400&q=80',
  ];

  final List<String> _mediaUrls = [
    // Add more video/photo URLs as needed
    'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/americandad.mp4',
    'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/4b971467-b591-4ad7-8168-799bdb550c7d.mp4',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80', // single image
    'carousel', // special marker for carousel
    'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/americandad.mp4',
    // You can add image URLs as well
  ];
  final List<VideoPlayerController?> _videoControllers = [];

  // --- Like, Save, Share state ---
  final List<bool> _liked = List.generate(5, (_) => false);
  final List<int> _likeCounts = [224400, 123000, 500, 0, 224400];
  final List<bool> _saved = List.generate(5, (_) => false);

  void _toggleLike(int index) {
    setState(() {
      _liked[index] = !_liked[index];
      if (_liked[index]) {
        _likeCounts[index]++;
      } else {
        _likeCounts[index]--;
      }
    });
  }

  void _toggleSave(int index) {
    setState(() {
      _saved[index] = !_saved[index];
    });
  }

  void _share(int index) {
    final url = _mediaUrls[index] == 'carousel' ? null : _mediaUrls[index];
    if (url != null) {
      Share.share(url);
    } else {
      Share.share('Check out these photos!');
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
    // Initialize video controllers for all video URLs
    for (var url in _mediaUrls) {
      if (url.endsWith('.mp4')) {
        final controller = VideoPlayerController.network(url);
        controller.addListener(() {
          if (mounted) setState(() {});
        });
        controller.initialize().then((_) {
          if (mounted) setState(() {});
          controller.setLooping(true);
          if (_mediaUrls.indexOf(url) == 0) controller.play(); // Autoplay first
        }).catchError((e) {
          print('Video failed to initialize: ${e.toString()}');
          if (mounted) setState(() {});
        });
        _videoControllers.add(controller);
      } else {
        _videoControllers.add(null); // For images
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var c in _videoControllers) {
      c?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
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
                    onPressed: () {}
                  ),
                        ],
                      ),
            ),
            // Tabs
            // Main Feed Section (Side-flip PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _mediaUrls.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final url = _mediaUrls[index];
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
                      if (url == 'carousel') {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _CarouselImageSlider(images: _carouselImages),
                        );
                      } else if (url.endsWith('.mp4')) {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: (videoController == null)
                              ? Container(color: Colors.black)
                              : (videoController.value.hasError
                                  ? Container(
                                      color: Colors.black,
                              child: Center(
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
                                                      child: Icon(
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
                                      : Container(
                                          color: Colors.black,
                                          child: const Center(child: CircularProgressIndicator()),
                                        ))),
                        );
                      } else {
                        mediaWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.black,
                                child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                              ),
                            ),
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
                                child: _VideoDescriptionBar(),
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
                    child: const Icon(Icons.person, color: Colors.black),
                            ),
                            const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('username', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _toggleLike(_currentPage),
                    child: _iconStatColumn(
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
                    onTap: () => _toggleSave(_currentPage),
                    child: _iconStatColumn(
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
                  label: 'Mining',
                ),
              ],
              currentIndex: 0, // Valid index, but all tabs look unselected
              onTap: (int index) {
                if (index == 0) {
                  context.go('/connect');
                } else if (index == 1) {
                  context.go('/channel');
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
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