import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'tube_player_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'saved_posts_screen.dart';
import 'camera_recording_screen.dart';

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

class _VideoCardSkeleton extends StatelessWidget {
  const _VideoCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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

class _GridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  
  const _GridSkeleton({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: List.generate(
        crossAxisCount * 2, // Show 2 rows of skeleton
        (i) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
        ),
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        3,
        (i) => _VideoCardSkeleton(),
      ),
    );
  }
}

class _UploadProgressSkeleton extends StatelessWidget {
  const _UploadProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upload icon skeleton
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        const SizedBox(height: 24),
        
        // Title skeleton
        Container(
          width: 150,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        
        // Subtitle skeleton
        Container(
          width: 200,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 24),
        
        // Progress steps skeleton
        for (int i = 0; i < 4; i++) ...[
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 120 + (i * 20),
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          if (i < 3) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ThumbnailSkeleton extends StatelessWidget {
  const _ThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[600]!, width: 1),
      ),
    );
  }
}

class _VideoPlayerSkeleton extends StatelessWidget {
  const _VideoPlayerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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

enum TubeTab { none, short, max, prime }

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  int _selectedTab = 1; // Channel tab index
  TubeTab _selectedTubeTab = TubeTab.none;
  
  // Upload state variables
  bool _allowDuet = true;
  bool _useVideoThumbnail = true;
  File? _selectedThumbnail;
  File? _selectedVideo;
  String _selectedContentType = '';
  
  // Add thumbnail generation state
  File? _generatedThumbnail;
  List<File> _generatedThumbnails = [];
  bool _isGeneratingThumbnail = false;
  bool _isUploading = false;

  // Add a set to track saved video URLs
  final Set<String> _savedVideos = {};

  // Add a controller for the description
  final TextEditingController _descController = TextEditingController();

  // Real data from backend
  List<Map<String, dynamic>> _tubeShortPosts = [];
  List<Map<String, dynamic>> _tubeMaxPosts = [];
  List<Map<String, dynamic>> _tubePrimePosts = [];
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  // Add hashtag suggestions state
  List<Map<String, dynamic>> _hashtagSuggestions = [];
  bool _showHashtagSuggestions = false;
  String _currentHashtagQuery = '';
  int _cursorPosition = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all post types in parallel
      await Future.wait([
        _loadTubeShortPosts(),
        _loadTubeMaxPosts(),
        _loadTubePrimePosts(),
      ]);
    } catch (e) {
      print('Error loading posts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTubeShortPosts() async {
    try {
      final response = await _apiService.getTubeShortPosts();
      if (response.data['success']) {
        setState(() {
          _tubeShortPosts = List<Map<String, dynamic>>.from(response.data['data']['data']);
        });
      }
    } catch (e) {
      print('Error loading tube short posts: $e');
    }
  }

  Future<void> _loadTubeMaxPosts() async {
    try {
      final response = await _apiService.getTubeMaxPosts();
      if (response.data['success']) {
        setState(() {
          _tubeMaxPosts = List<Map<String, dynamic>>.from(response.data['data']['data']);
        });
      }
    } catch (e) {
      print('Error loading tube max posts: $e');
    }
  }

  Future<void> _loadTubePrimePosts() async {
    try {
      final response = await _apiService.getTubePrimePosts();
      if (response.data['success']) {
        setState(() {
          _tubePrimePosts = List<Map<String, dynamic>>.from(response.data['data']['data']);
        });
      }
    } catch (e) {
      print('Error loading tube prime posts: $e');
    }
  }

  // Hashtag suggestions methods
  Future<void> _getHashtagSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
      return;
    }

    try {
      final response = await _apiService.getHashtagSuggestions(query);
      if (response.data['success']) {
        setState(() {
          _hashtagSuggestions = List<Map<String, dynamic>>.from(response.data['data']);
          _showHashtagSuggestions = _hashtagSuggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error getting hashtag suggestions: $e');
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
    }
  }

  void _onDescriptionChanged(String text) {
    // Check if user is typing a hashtag
    final cursorPosition = _descController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    
    // Find the last hashtag being typed
    final hashtagMatch = RegExp(r'#(\w*)$').firstMatch(textBeforeCursor);
    
    if (hashtagMatch != null) {
      final hashtagQuery = hashtagMatch.group(1) ?? '';
      _currentHashtagQuery = hashtagQuery;
      _cursorPosition = cursorPosition;
      _getHashtagSuggestions(hashtagQuery);
    } else {
      setState(() {
        _showHashtagSuggestions = false;
        _hashtagSuggestions = [];
      });
    }
  }

  void _insertHashtagSuggestion(String hashtag) {
    final text = _descController.text;
    final beforeHashtag = text.substring(0, _cursorPosition - _currentHashtagQuery.length - 1); // -1 for #
    final afterHashtag = text.substring(_cursorPosition);
    
    final newText = '$beforeHashtag#$hashtag $afterHashtag';
    _descController.text = newText;
    
    // Set cursor position after the inserted hashtag
    final newCursorPosition = beforeHashtag.length + hashtag.length + 2; // +2 for # and space
    _descController.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursorPosition),
    );
    
    setState(() {
      _showHashtagSuggestions = false;
      _hashtagSuggestions = [];
    });
  }

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
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTubeTab = TubeTab.short;
                        });
                      },
                      child: _subTab('Tube SHORT', _selectedTubeTab == TubeTab.short),
                    ),
                    _verticalDivider(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTubeTab = TubeTab.max;
                        });
                      },
                      child: _subTab('Tube MAX', _selectedTubeTab == TubeTab.max),
                    ),
                    _verticalDivider(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTubeTab = TubeTab.prime;
                        });
                      },
                      child: _subTab('Tube PRIME', _selectedTubeTab == TubeTab.prime),
                    ),
                    _verticalDivider(),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SavedPostsScreen(),
                          ),
                        );
                      },
                      child: Icon(Icons.bookmark_border, color: Colors.brown, size: 20),
                    ),
                    GestureDetector(
                      onTap: () {
                        _showUploadOptions(context);
                      },
                      child: Icon(Icons.add, color: Colors.brown, size: 20),
                    ),
                  ],
                ),
              ),
              // Tube SHORT and Tube MAX sections
              if (_selectedTubeTab == TubeTab.short)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    _isLoading
                        ? const _RowSkeleton()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _tubeShortPosts.take(3).map((v) => _mediaCardWithSave(v)).toList(),
                          ),
                  ],
                )
              else if (_selectedTubeTab == TubeTab.max)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    _isLoading
                        ? const _GridSkeleton(crossAxisCount: 2, childAspectRatio: 1.1, spacing: 8)
                        : GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.1,
                            children: List.generate(
                              _tubeMaxPosts.take(4).length,
                              (i) => GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TubePlayerScreen(
                                        videos: _tubeMaxPosts,
                                        initialIndex: i,
                                      ),
                                    ),
                                  );
                                },
                                child: _VideoPreviewCard(url: _tubeMaxPosts[i]['media_files']?[0]?['file_path']?.toString() ?? ''),
                              ),
                            ),
                          ),
                  ],
                )
              else if (_selectedTubeTab == TubeTab.prime)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tube PRIME label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(text: 'T u b e ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18, letterSpacing: 2)),
                            TextSpan(text: 'P R I M E', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoading
                        ? const _GridSkeleton(crossAxisCount: 2, childAspectRatio: 0.8, spacing: 16)
                        : GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.8,
                            children: List.generate(
                              _tubePrimePosts.length,
                              (i) => _TubePrimeCardWithSave(
                                video: _tubePrimePosts[i],
                                isSaved: _savedVideos.contains(_tubePrimePosts[i]['media_files']?[0]?['file_path']?.toString() ?? ''),
                                onToggleSave: () => _toggleSave(_tubePrimePosts[i]['media_files']?[0]?['file_path']?.toString() ?? ''),
                              ),
                            ),
                          ),
                  ],
                )
              else if (_selectedTubeTab == TubeTab.none)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    _isLoading
                        ? const _RowSkeleton()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _tubeShortPosts.take(3).map((v) => _mediaCardWithSave(v)).toList(),
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
                    _isLoading
                        ? const _GridSkeleton(crossAxisCount: 2, childAspectRatio: 1.1, spacing: 8)
                        : GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.1,
                            children: List.generate(
                              _tubeMaxPosts.take(4).length,
                              (i) => GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TubePlayerScreen(
                                        videos: _tubeMaxPosts,
                                        initialIndex: i,
                                      ),
                                    ),
                                  );
                                },
                                child: _VideoPreviewCard(url: _tubeMaxPosts[i]['media_files']?[0]?['file_path']?.toString() ?? ''),
                              ),
                            ),
                          ),
                  ],
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
            label: 'Earn',
          ),
        ],
        currentIndex: 1, // Channel tab is active
        onTap: (int index) {
          if (index == 0) {
            context.go('/connect');
          } else if (index == 1) {
            return;
          } else if (index == 3) {
            context.go('/earn');
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
        color: selected ? Colors.blueAccent : Colors.brown[700],
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _mediaCard(Map<String, dynamic> video) {
    final index = _tubeShortPosts.indexOf(video);
    final videoUrl = video['media_files']?[0]?['file_path']?.toString() ?? '';
    return GestureDetector(
      onTap: () {
        print('DEBUG: Opening TubePlayerScreen at index: ' + index.toString());
        Navigator.of(context).push(
          MaterialPageRoute(
                              builder: (context) => TubePlayerScreen(
                    videos: _tubeShortPosts,
                    initialIndex: index,
                  ),
          ),
        );
      },
      child: _VideoPreviewCard(url: videoUrl),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '${d.inHours > 0 ? '${twoDigits(d.inHours)}:' : ''}$m:$s';
  }

  void _showContentTypeSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Text(
                              'Create Content',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Content Type Selection
                        const Text(
                          'Choose Content Type',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'For videos under 10 minutes, they will be automatically categorized as Short. For longer videos, they will be categorized as Max.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Tube Short Option
                        _buildContentTypeOption(
                          context,
                          'Tube Short',
                          'Videos under 10 minutes (auto-detected)',
                          Icons.short_text,
                          Colors.blue,
                          'tube_short',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tube Max Option
                        _buildContentTypeOption(
                          context,
                          'Tube Max',
                          'Videos 10 minutes or longer (auto-detected)',
                          Icons.video_library,
                          Colors.green,
                          'tube_max',
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tube Prime Option
                        _buildContentTypeOption(
                          context,
                          'Tube Prime',
                          'Premium content (paid)',
                          Icons.star,
                          Colors.amber,
                          'tube_prime',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentTypeOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    String contentType,
  ) {
    final isSelected = _selectedContentType == contentType;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedContentType = contentType;
        });
        _showUploadModal(context, contentType);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadModal(BuildContext context, String contentType) {
    Navigator.pop(context); // Close the content type modal
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Text(
                                  'Upload ${_getContentTypeTitle(contentType)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Video Selection & Preview
                            const Text(
                              'Select Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildVideoSelectionSection(setModalState),
                            if (_selectedVideo != null) ...[
                              const SizedBox(height: 16),
                              _buildVideoPreview(),
                            ],
                            const SizedBox(height: 24),
                            // Duet Toggle (only for tube_short and tube_max)
                            if (contentType != 'tube_prime') ...[
                              _buildDuetToggle(setModalState),
                              const SizedBox(height: 24),
                            ],
                            // Thumbnail Selection & Preview
                            const Text(
                              'Thumbnail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildThumbnailSelectionSection(setModalState),
                            const SizedBox(height: 12),
                            _buildThumbnailPreview(),
                            const SizedBox(height: 24),
                            // Description Field
                            const Text(
                              'Description (with hashtags)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                              onChanged: _onDescriptionChanged,
                              decoration: InputDecoration(
                                hintText: 'Describe your video... #funny #music',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            if (_showHashtagSuggestions) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _hashtagSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final hashtag = _hashtagSuggestions[index]['name'] ?? _hashtagSuggestions[index]['hashtag'] ?? '';
                                    final postCount = _hashtagSuggestions[index]['posts_count'] ?? 0;
                                    return GestureDetector(
                                      onTap: () {
                                        _insertHashtagSuggestion(hashtag);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                        child: Row(
                                          children: [
                                            Text(
                                              '#$hashtag',
                                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '($postCount posts)',
                                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            // Upload Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _selectedVideo != null ? () {
                                  print('[DEBUG] Upload button pressed. _isUploading: $_isUploading');
                                  _handleUpload();
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedVideo != null ? Colors.amber : Colors.grey[600],
                                  foregroundColor: _selectedVideo != null ? Colors.black : Colors.grey[400],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _selectedVideo != null ? 'Upload Content' : 'Select a video to upload',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedVideo != null ? Colors.black : Colors.grey[400],
                                  ),
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
        );
      },
    );
  }

  Widget _buildVideoSelectionSection([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (_selectedVideo == null) ...[
            Row(
              children: [
                Icon(Icons.video_library, color: Colors.grey[400]),
                const SizedBox(width: 12),
                const Text(
                  'No video selected',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _pickVideo();
                  if (setModalState != null) setModalState(() {});
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Select Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.video_file, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedVideo!.path.split('/').last,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedVideo = null;
                    });
                    if (setModalState != null) setModalState(() {});
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDuetToggle([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.people, color: Colors.grey[400]),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow Duets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Let other users create duets with your video',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _allowDuet,
            onChanged: (value) {
              setState(() {
                _allowDuet = value;
              });
              if (setModalState != null) setModalState(() {});
            },
            activeColor: Colors.amber,
          ),
        ],
      ),
    );
  }

  String _getContentTypeTitle(String contentType) {
    switch (contentType) {
      case 'tube_short':
        return 'Tube Short';
      case 'tube_max':
        return 'Tube Max';
      case 'tube_prime':
        return 'Tube Prime';
      default:
        return 'Content';
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedVideo = File(result.files.first.path!);
          _generatedThumbnails = []; // Reset generated thumbnails
        });
        
        // Auto-generate thumbnail if video thumbnail is selected
        if (_useVideoThumbnail) {
          await _generateThumbnailFromVideo();
        }
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        setState(() {
          _selectedThumbnail = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking thumbnail: $e');
    }
  }

  Future<void> _handleUpload() async {
    print('=== UPLOAD DEBUG START ===');
    print('Uploading content:');
    print('Content Type: $_selectedContentType');
    print('Video: ${_selectedVideo?.path}');
    print('Allow Duet: $_allowDuet');
    print('Use Video Thumbnail: $_useVideoThumbnail');
    print('Custom Thumbnail: ${_selectedThumbnail?.path}');
    print('Generated Thumbnail: ${_generatedThumbnails.map((f) => f.path).toList()}');
    print('Description: ${_descController.text}');

    try {
      setState(() {
        _isUploading = true;
      });
      print('[DEBUG] _isUploading set to true');
      
      // Show upload progress modal immediately
      _showUploadProgressModal();
      
      // Check if user is authenticated
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('User not authenticated. Please login again.');
      }
      print('[UPLOAD] User authenticated with token: ${token.substring(0, 20)}...');

      // Get video duration from frontend
      double? videoDuration;
      if (_selectedVideo != null) {
        videoDuration = await _getVideoDuration(_selectedVideo!);
        print('[UPLOAD] Video duration: ${videoDuration} seconds');
      }

      // 1. Upload video
      print('[UPLOAD] Uploading video...');
      final videoRes = await _apiService.uploadMedia(_selectedVideo!, 'video', duration: videoDuration);
      print('[UPLOAD] Video upload response: ${videoRes.data}');
      final videoMediaId = videoRes.data['data']['media_file_id'];
      print('[UPLOAD] Video uploaded. Media ID: $videoMediaId');

      // 2. Upload thumbnail (if custom or generated)
      int? thumbnailMediaId;
      if (!_useVideoThumbnail && _selectedThumbnail != null) {
        print('[UPLOAD] Uploading custom thumbnail...');
        final thumbRes = await _apiService.uploadMedia(_selectedThumbnail!, 'image');
        thumbnailMediaId = thumbRes.data['data']['media_file_id'];
        print('[UPLOAD] Custom thumbnail uploaded. Media ID: $thumbnailMediaId');
      } else if (_useVideoThumbnail && _generatedThumbnails.isNotEmpty) {
        print('[UPLOAD] Uploading first generated video thumbnail...');
        // Only upload the first generated thumbnail
        final thumbRes = await _apiService.uploadMedia(_generatedThumbnails.first, 'image');
        thumbnailMediaId = thumbRes.data['data']['media_file_id'];
        print('[UPLOAD] Generated thumbnail uploaded. Media ID: $thumbnailMediaId');
      }

      // 3. Map content type to post_type_id
      final postTypeMap = {
        'tube_short': 1,
        'tube_max': 2,
        'tube_prime': 3,
        'audio': 4,
        'image': 5,
        'article': 6,
      };
      final postTypeId = postTypeMap[_selectedContentType] ?? 1;
      print('[UPLOAD] Using post type ID: $postTypeId for content type: $_selectedContentType');

      // 4. Create post
      print('[UPLOAD] Creating post...');
      final hashtags = RegExp(r'#(\w+)')
          .allMatches(_descController.text)
          .map((m) => m.group(1))
          .whereType<String>()
          .toList();
      print('[UPLOAD] Extracted hashtags: $hashtags');
      
      final postRes = await _apiService.createPost(
        postTypeId: postTypeId,
        description: _descController.text,
        isPrime: _selectedContentType == 'tube_prime',
        allowDuet: _allowDuet,
        hashtags: hashtags,
      );
      print('[UPLOAD] Post creation response: ${postRes.data}');
      final postId = postRes.data['data']['id'];
      print('[UPLOAD] Post created. Post ID: $postId');

      // 5. Complete upload (associate media with post)
      print('[UPLOAD] Completing upload...');
      final mediaFileIds = [videoMediaId as int];
      if (thumbnailMediaId != null) mediaFileIds.add(thumbnailMediaId as int);
      print('[UPLOAD] Media file IDs to associate: $mediaFileIds');
      await _apiService.completeUpload(postId, mediaFileIds, thumbnailMediaId: thumbnailMediaId as int?);
      print('[UPLOAD] Upload complete!');

      // Reset state
      setState(() {
        _selectedVideo = null;
        _selectedThumbnail = null;
        _generatedThumbnails = [];
        _allowDuet = true;
        _useVideoThumbnail = true;
        _selectedContentType = '';
        _isGeneratingThumbnail = false;
        _isUploading = false;
      });
      print('[DEBUG] _isUploading set to false (success)');
      _descController.clear();
      
      // Close upload modal and show success toast
      Navigator.pop(context); // Close upload modal
      Navigator.pop(context); // Close the upload options modal
      _showSuccessToast();
      print('=== UPLOAD DEBUG END - SUCCESS ===');
    } catch (e, st) {
      print('=== UPLOAD DEBUG END - ERROR ===');
      print('[UPLOAD ERROR] $e');
      print('[UPLOAD ERROR STACK] $st');
      
      // Reset loading state on error
      setState(() {
        _isUploading = false;
      });
      print('[DEBUG] _isUploading set to false (error)');
      
      // Close upload modal and show error toast
      Navigator.pop(context); // Close upload modal
      Navigator.pop(context); // Close the upload options modal
      _showErrorToast(e.toString());
    }
  }

  void _showUploadProgressModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent closing with back button
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated upload icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Center(
                      child: _SkeletonLoader(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Upload title
                  const Text(
                    'Uploading Content',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Upload subtitle
                  Text(
                    'Please wait while we upload your ${_getContentTypeTitle(_selectedContentType)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Progress steps
                  _buildProgressStep('Preparing video...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Uploading to cloud...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Processing thumbnail...', true),
                  const SizedBox(height: 8),
                  _buildProgressStep('Creating post...', false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStep(String text, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.amber : Colors.grey[600],
            borderRadius: BorderRadius.circular(10),
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: isCompleted ? Colors.white : Colors.grey[500],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Content uploaded successfully!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorToast(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upload failed: $error',
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<double?> _getVideoDuration(File videoFile) async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds / 1000.0;
      controller.dispose();
      return duration;
    } catch (e) {
      print('Error getting video duration: $e');
      return null;
    }
  }

  void _showSavedVideos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final savedShorts = _tubeShortPosts.where((v) => _savedVideos.contains(v['media_files']?[0]?['file_path']?.toString() ?? '')).toList();
        final savedMax = _tubeMaxPosts.where((v) => _savedVideos.contains(v['media_files']?[0]?['file_path']?.toString() ?? '')).toList();
        final savedPrime = _tubePrimePosts.where((v) => _savedVideos.contains(v['media_files']?[0]?['file_path']?.toString() ?? '')).toList();
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Saved Videos', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  const SizedBox(height: 18),
                  if (savedShorts.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube SHORT', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedShorts.map((v) => _mediaCardWithSave(v)).toList(),
                      ),
                    ),
                  ],
                  if (savedMax.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube MAX', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedMax.map((v) => _mediaCardWithSave(v)).toList(),
                      ),
                    ),
                  ],
                  if (savedPrime.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Tube PRIME', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: savedPrime.map((v) => _TubePrimeCardWithSave(video: v, isSaved: true, onToggleSave: () => _toggleSave(v['media_files']?[0]?['file_path']?.toString() ?? ''))).toList(),
                      ),
                    ),
                  ],
                  if (savedShorts.isEmpty && savedMax.isEmpty && savedPrime.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No saved videos yet.', style: TextStyle(color: Colors.white70, fontSize: 16)),
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

  Widget _mediaCardWithSave(Map<String, dynamic> video) {
    return _mediaCard(video);
  }

  void _toggleSave(String url) {
    setState(() {
      if (_savedVideos.contains(url)) {
        _savedVideos.remove(url);
      } else {
        _savedVideos.add(url);
      }
    });
  }

  void _showUploadOptions(BuildContext parentContext) {
    _showRecordOrUploadModal(parentContext);
  }

  void _showRecordOrUploadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Text(
                              'Create Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Option Selection
                        const Text(
                          'How would you like to create your video?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Record with Camera Option
                        _buildRecordOrUploadOption(
                          context,
                          'Record with Camera',
                          'Record a new video with filters',
                          Icons.videocam,
                          Colors.red,
                          true, // isRecord
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Upload from Gallery Option
                        _buildRecordOrUploadOption(
                          context,
                          'Upload from Gallery',
                          'Choose an existing video to upload',
                          Icons.photo_library,
                          Colors.blue,
                          false, // isRecord
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordOrUploadOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    bool isRecord,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Close current modal
        if (isRecord) {
          _showCameraRecordingScreen(context);
        } else {
          _showContentTypeSelectionModal(context);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[500],
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showCameraRecordingScreen(BuildContext context) async {
    // Navigate to camera recording screen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CameraRecordingScreen(),
      ),
    );
    
    // If user recorded a video, handle the result
    if (result != null && result is Map<String, dynamic>) {
      final videoPath = result['videoPath'] as String?;
      final duration = result['duration'] as double?;
      final isRecorded = result['isRecorded'] as bool? ?? false;
      
      if (videoPath != null && duration != null && isRecorded) {
        // Set the recorded video as selected and proceed with upload
        setState(() {
          _selectedVideo = File(videoPath);
        });
        
        // Show upload modal with auto-categorization
        _showUploadModalForRecordedVideo(context, videoPath, duration);
      }
    }
  }

  void _showUploadModalForRecordedVideo(BuildContext context, String videoPath, double duration) {
    // Determine the content type based on duration for UI display
    final contentType = duration < 600 ? 'tube_short' : 'tube_max';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.98,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Text(
                                  'Upload Recorded ${_getContentTypeTitle(contentType)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Auto-categorization info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Colors.amber),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Auto-Categorized',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Duration: ${_formatRecordingDuration(duration)} - Automatically categorized as ${_getContentTypeTitle(contentType)}',
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Video Preview
                            _buildVideoPreview(),
                            const SizedBox(height: 24),
                            
                            // Duet Toggle (only for tube_short and tube_max)
                            if (contentType != 'tube_prime') ...[
                              _buildDuetToggle(setModalState),
                              const SizedBox(height: 24),
                            ],
                            
                            // Thumbnail Selection
                            const Text(
                              'Thumbnail',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildThumbnailSelectionSection(setModalState),
                            const SizedBox(height: 12),
                            _buildThumbnailPreview(),
                            const SizedBox(height: 24),
                            
                            // Description Field
                            const Text(
                              'Description (with hashtags)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _descController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Write your description here... #hashtag',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[800],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Upload Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isUploading ? null : () => _handleRecordedVideoUpload(duration),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isUploading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Upload Video',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatRecordingDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$secs';
  }

  Future<void> _handleRecordedVideoUpload(double duration) async {
    print('=== RECORDED VIDEO UPLOAD DEBUG START ===');
    print('Uploading recorded video with auto-categorization:');
    print('Video: ${_selectedVideo?.path}');
    print('Duration: $duration seconds');
    print('Allow Duet: $_allowDuet');
    print('Use Video Thumbnail: $_useVideoThumbnail');
    print('Custom Thumbnail: ${_selectedThumbnail?.path}');
    print('Description: ${_descController.text}');

    try {
      setState(() {
        _isUploading = true;
      });
      
      // Show upload progress modal immediately
      _showUploadProgressModal();
      
      // Check if user is authenticated
      final token = await _apiService.getToken();
      if (token == null) {
        throw Exception('User not authenticated. Please login again.');
      }
      
      print('[UPLOAD] User authenticated with token: ${token.substring(0, 20)}...');

      // 1. Upload video with duration
      print('[UPLOAD] Uploading video...');
      final videoRes = await _apiService.uploadMedia(_selectedVideo!, 'video', duration: duration);
      print('[UPLOAD] Video upload response: ${videoRes.data}');
      final videoMediaId = videoRes.data['data']['media_file_id'];
      print('[UPLOAD] Video uploaded. Media ID: $videoMediaId');

      // 2. Upload thumbnail (if custom or generated)
      int? thumbnailMediaId;
      if (!_useVideoThumbnail && _selectedThumbnail != null) {
        print('[UPLOAD] Uploading custom thumbnail...');
        final thumbnailRes = await _apiService.uploadMedia(_selectedThumbnail!, 'image');
        print('[UPLOAD] Thumbnail upload response: ${thumbnailRes.data}');
        thumbnailMediaId = thumbnailRes.data['data']['media_file_id'];
        print('[UPLOAD] Thumbnail uploaded. Media ID: $thumbnailMediaId');
      } else if (_useVideoThumbnail && _generatedThumbnails.isNotEmpty) {
        print('[UPLOAD] Uploading generated thumbnail...');
        final thumbnailRes = await _apiService.uploadMedia(_generatedThumbnails.first, 'image');
        print('[UPLOAD] Generated thumbnail upload response: ${thumbnailRes.data}');
        thumbnailMediaId = thumbnailRes.data['data']['media_file_id'];
        print('[UPLOAD] Generated thumbnail uploaded. Media ID: $thumbnailMediaId');
      }

      // 3. Create post with auto-categorization based on duration
      print('[UPLOAD] Creating post with auto-categorization...');
      
      // Extract hashtags from description
      final description = _descController.text;
      final hashtagRegex = RegExp(r'#\w+');
      final hashtags = hashtagRegex.allMatches(description)
          .map((match) => match.group(0)!.substring(1))
          .toList();
      
      final postRes = await _apiService.createPostWithAutoCategorization(
        videoDuration: duration,
        description: description,
        allowDuet: _allowDuet,
        hashtags: hashtags.isNotEmpty ? hashtags : null,
      );
      
      print('[UPLOAD] Post creation response: ${postRes.data}');
      final postId = postRes.data['data']['post']['id'];
      final determinedType = postRes.data['data']['determined_type'];
      print('[UPLOAD] Post created with ID: $postId, Type: $determinedType');

      // 4. Complete upload by associating media with post
      print('[UPLOAD] Completing upload...');
      final completeRes = await _apiService.completeUpload(
        postId,
        [videoMediaId],
        thumbnailMediaId: thumbnailMediaId,
      );
      print('[UPLOAD] Complete upload response: ${completeRes.data}');

      // 5. Reset state and show success
      setState(() {
        _isUploading = false;
        _selectedVideo = null;
        _selectedThumbnail = null;
        _generatedThumbnails = [];
        _descController.clear();
        _allowDuet = true;
        _useVideoThumbnail = true;
      });

      // Close upload progress modal
      Navigator.of(context).pop();
      
      // Close upload modal
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video uploaded successfully as $determinedType!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Refresh the posts
      _loadTubeShortPosts();
      _loadTubeMaxPosts();
      _loadTubePrimePosts();

      print('=== RECORDED VIDEO UPLOAD DEBUG END ===');
      
    } catch (e) {
      print('[UPLOAD ERROR] $e');
      
      setState(() {
        _isUploading = false;
      });

      // Close any open modals
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildVideoPreview() {
    if (_selectedVideo == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: VideoPlayerWidget(file: _selectedVideo!),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    if (_useVideoThumbnail) {
      if (_isGeneratingThumbnail) {
        return Container(
          width: 160, // Increased from 120
          height: 120, // Increased from 80
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber, width: 1),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _SkeletonLoader(
                    width: 20,
                    height: 20,
                    borderRadius: 10,
                  ),
                ),
                SizedBox(height: 4),
                Text('Generating...', style: TextStyle(color: Colors.amber, fontSize: 10)),
              ],
            ),
          ),
        );
      } else if (_generatedThumbnails.isNotEmpty) {
        return Container(
          width: 160, // Increased from 120
          height: 120, // Increased from 80
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _generatedThumbnails.first, // Use the first generated thumbnail for preview
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _youtubeStyleThumbnailPlaceholder();
              },
            ),
          ),
        );
      } else {
        return _youtubeStyleThumbnailPlaceholder();
      }
    } else if (_selectedThumbnail != null && _selectedThumbnail!.existsSync()) {
      return Container(
        width: 160, // Increased from 120
        height: 120, // Increased from 80
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            _selectedThumbnail!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _youtubeStyleThumbnailPlaceholder();
            },
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _youtubeStyleThumbnailPlaceholder() {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF232526), Color(0xFF414345)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
      ),
    );
  }

  Future<void> _generateThumbnailFromVideo() async {
    if (_selectedVideo == null) return;
    
    setState(() {
      _isGeneratingThumbnail = true;
      _generatedThumbnails = [];
    });

    try {
      // Generate multiple thumbnails from different timestamps
      await _generateMultipleThumbnails();
    } catch (e) {
      print('Error generating thumbnails: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  Future<void> _generateMultipleThumbnails() async {
    if (_selectedVideo == null) return;

    try {
      // Create a temporary directory for the thumbnails
      final tempDir = await Directory.systemTemp.createTemp('tajify_thumbnails');
      
      // Generate thumbnails at different timestamps (0s, 25%, 50%, 75% of video duration)
      final timestamps = <double>[0, 0.25, 0.5, 0.75];
      final List<File> thumbnails = [];
      
      for (int i = 0; i < timestamps.length; i++) {
        final timestamp = timestamps[i];
        final thumbnailPath = '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        
        final thumbnailFile = await _captureVideoFrameAtTime(thumbnailPath, timestamp as double);
        if (thumbnailFile != null && thumbnailFile.existsSync() && thumbnailFile.lengthSync() > 0) {
          thumbnails.add(thumbnailFile);
          print('[DEBUG] Generated thumbnail $i at ${timestamp * 100}% of video');
        }
      }
      
      if (thumbnails.isNotEmpty) {
        setState(() {
          _generatedThumbnails = thumbnails;
          _isGeneratingThumbnail = false;
        });
        print('[DEBUG] Generated ${thumbnails.length} thumbnails successfully');
      } else {
        setState(() {
          _isGeneratingThumbnail = false;
        });
        print('[DEBUG] No thumbnails were generated successfully');
      }
    } catch (e) {
      print('Error generating multiple thumbnails: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  Future<File?> _captureVideoFrameAtTime(String thumbnailPath, double timePercent) async {
    try {
      print('[DEBUG] Generating thumbnail at ${timePercent * 100}% of video: ${_selectedVideo?.path}');
      if (_selectedVideo == null) return null;
      
      final String? thumbPath = await VideoThumbnail.thumbnailFile(
        video: _selectedVideo!.path,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720, // Increased from 80 to 720 for high resolution
        maxWidth: 1280, // Added maxWidth for better aspect ratio
        quality: 95, // Increased from 85 to 95 for better quality
        timeMs: (timePercent * 1000).round(), // Convert percentage to milliseconds
      );
      
      print('[DEBUG] video_thumbnail generated at ${timePercent * 100}%: $thumbPath');
      if (thumbPath != null) {
        final file = File(thumbPath);
        if (file.existsSync()) {
          print('[DEBUG] Thumbnail file exists and will be used: ${file.path}');
          return file;
        } else {
          print('[DEBUG] Thumbnail file does not exist after generation.');
        }
      }
      return null;
    } catch (e, st) {
      print('[ERROR] Error generating video thumbnail at ${timePercent * 100}%: ${e.toString()}');
      print('[ERROR] Stack trace: ${st.toString()}');
      return null;
    }
  }

  Widget _buildThumbnailSelectionSection([void Function(void Function())? setModalState]) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Use video thumbnail option
          Row(
            children: [
              Icon(Icons.video_library, color: Colors.grey[400]),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Use video thumbnail',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Switch(
                value: _useVideoThumbnail,
                onChanged: (value) async {
                  setState(() {
                    _useVideoThumbnail = value;
                    if (value) {
                      _selectedThumbnail = null;
                    } else {
                      _generatedThumbnails = [];
                    }
                  });
                  
                  // Generate thumbnail if video thumbnail is selected and video is available
                  if (value && _selectedVideo != null) {
                    await _generateThumbnailFromVideo();
                  }
                  
                  if (setModalState != null) setModalState(() {});
                },
                activeColor: Colors.amber,
              ),
            ],
          ),
          
          if (!_useVideoThumbnail) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 16),
            
            if (_selectedThumbnail == null) ...[
              Row(
                children: [
                  Icon(Icons.image, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  const Text(
                    'No thumbnail selected',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _pickThumbnail();
                    if (setModalState != null) setModalState(() {});
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Select Thumbnail'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Icon(Icons.image, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedThumbnail!.path.split('/').last,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedThumbnail = null;
                      });
                      if (setModalState != null) setModalState(() {});
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ],
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
                    : const _VideoPlayerSkeleton(),
          ),
        ],
      ),
    );
  }

  // No duration method needed
}

class _TubePrimeCard extends StatefulWidget {
  final Map<String, dynamic> video;
  const _TubePrimeCard({required this.video});

  @override
  State<_TubePrimeCard> createState() => _TubePrimeCardState();
}

class _TubePrimeCardState extends State<_TubePrimeCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isPreviewing = false;
  bool _hasError = false;
  double _progress = 0.0;
  late Duration _previewDuration;
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();
    _previewDuration = const Duration(seconds: 15);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.video['snippetUrl'])
        ..setLooping(false)
        ..setVolume(0);
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _initialized = true);
        if (_controller!.value.isInitialized) {
          _startPreview();
        }
      }
      
      _listener = () {
        if (!_controller!.value.isInitialized) return;
        final pos = _controller!.value.position;
        setState(() {
          _progress = pos.inMilliseconds / _previewDuration.inMilliseconds;
          if (_progress > 1.0) _progress = 1.0;
        });
        if (pos >= _previewDuration && _isPreviewing) {
          _controller!.pause();
          setState(() => _isPreviewing = false);
        }
      };
      _controller!.addListener(_listener!);
    } catch (e) {
      print('Video initialization error for ${widget.video['snippetUrl']}: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
        });
      }
    }
  }

  void _startPreview() {
    _controller!.seekTo(Duration.zero);
    _controller!.play();
    setState(() {
      _isPreviewing = true;
      _progress = 0.0;
    });
    // Add a timer to force stop at 15s
    Future.delayed(_previewDuration, () {
      if (mounted && _isPreviewing) {
        _controller!.pause();
        _controller!.seekTo(_previewDuration);
        setState(() => _isPreviewing = false);
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_listener!);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_initialized && !_hasError) _startPreview();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown.shade900, Colors.black, Colors.brown.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _hasError
                  ? Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ),
                    )
                  : _initialized && _controller != null
                      ? ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.35),
                            BlendMode.darken,
                          ),
                          child: Stack(
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
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const _VideoPlayerSkeleton(),
            ),
            // Progress bar
            if (_isPreviewing)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 5,
                  backgroundColor: Colors.black26,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            // Preview badge
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_circle_fill, color: Colors.black, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.video['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Pay to Unlock button
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment flow coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Pay to Unlock'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TubePrimeCardWithSave extends StatelessWidget {
  final Map<String, dynamic> video;
  final bool isSaved;
  final VoidCallback onToggleSave;
  const _TubePrimeCardWithSave({required this.video, required this.isSaved, required this.onToggleSave});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _TubePrimeCard(video: video),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: onToggleSave,
            child: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? Colors.amber : Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
} 

class VideoPlayerWidget extends StatefulWidget {
  final File file;
  const VideoPlayerWidget({required this.file, Key? key}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.setVolume(0.5);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const _VideoPlayerSkeleton();
    }
    
    // Calculate aspect ratio to contain the video properly
    final videoAspectRatio = _controller.value.aspectRatio;
    
    return Center(
      child: AspectRatio(
        aspectRatio: videoAspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
} 