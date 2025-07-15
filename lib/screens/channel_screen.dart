import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  int _selectedTab = 1; // Channel tab index

  // Example video data
  final List<Map<String, dynamic>> _videos = [
    {
      'url': 'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/americandad.mp4',
      'duration': Duration(minutes: 2, seconds: 30),
    },
    {
      'url': 'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/4b971467-b591-4ad7-8168-799bdb550c7d.mp4',
      'duration': Duration(minutes: 1, seconds: 45),
    },
    {
      'url': 'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/americandad.mp4',
      'duration': Duration(minutes: 3, seconds: 0),
    },
    {
      'url': 'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/4b971467-b591-4ad7-8168-799bdb550c7d.mp4',
      'duration': Duration(minutes: 4, seconds: 10),
    },
    {
      'url': 'https://f005.backblazeb2.com/file/bosspace-storage/posts/videos/americandad.mp4',
      'duration': Duration(minutes: 5, seconds: 0),
    },
  ];

  List<Map<String, dynamic>> get _shortVideos => _videos.where((v) => v['duration'] <= Duration(minutes: 3)).toList();
  List<Map<String, dynamic>> get _maxVideos => _videos.where((v) => v['duration'] > Duration(minutes: 3)).toList();

  Widget _verticalDivider() {
    return Container(
      width: 1.2,
      height: 18,
      color: Colors.brown[200],
      margin: const EdgeInsets.symmetric(horizontal: 6),
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
              // Top brown tabs
              Row(
                children: [
                  Expanded(child: _topTab('Tube', true)),
                  Expanded(child: _topTab('Audio', false)),
                  Expanded(child: _topTab('Image', false)),
                  Expanded(child: _topTab('Article', false)),
                  Expanded(child: _topTab('Live', false)),
                ],
              ),
              const SizedBox(height: 4),
              // Orange sub-tabs
              Container(
                width: double.infinity,
                color: const Color(0xFFFFD6B0),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _subTab('Tube SHORT', false),
                    _verticalDivider(),
                    _subTab('Tube MAX', false),
                    _verticalDivider(),
                    _subTab('Tube PRIME', false),
                    _verticalDivider(),
                    Icon(Icons.favorite_border, color: Colors.brown, size: 20),
                    Icon(Icons.add, color: Colors.brown, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tube SHORT label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'T u b e ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18, letterSpacing: 2)),
                      TextSpan(text: 'S H O R T', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
              // Tube SHORT row of 3 videos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _shortVideos.take(3).map((v) => _mediaCard(v)).toList(),
              ),
              const SizedBox(height: 18),
              // Tube MAX label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'T u b e ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18, letterSpacing: 2)),
                      TextSpan(text: 'M A X', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
              // Tube MAX grid of 2x2 videos
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
                children: _maxVideos.take(4).map((v) => _mediaCard(v)).toList(),
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
        selectedItemColor: Colors.amber, // Use a highlight color for active tab
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
        currentIndex: 1, // Channel tab is active
        onTap: (int index) {
          if (index == 0) {
            context.go('/connect');
          } else if (index == 1) {
            return;
          }
          // Add navigation for other tabs as needed
        },
      ),
    );
  }

  Widget _topTab(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFB97A56) : const Color(0xFFD2A06B),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _subTab(String label, bool selected) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.brown[700],
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _mediaCard(Map<String, dynamic> video) {
    return _VideoPreviewCard(url: video['url'], duration: video['duration']);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$m:$s';
  }
}

class _VideoPreviewCard extends StatefulWidget {
  final String url;
  final Duration duration;
  const _VideoPreviewCard({required this.url, required this.duration});

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
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
            child: _initialized
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value.size.width,
                                height: _controller.value.size.height,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                          ),
                          if (!_controller.value.isPlaying)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                        ],
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatDuration(widget.duration),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$m:$s';
  }
} 