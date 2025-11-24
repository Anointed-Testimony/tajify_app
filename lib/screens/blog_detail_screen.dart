import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BlogDetailScreen extends StatefulWidget {
  final String blogUuid;
  
  const BlogDetailScreen({super.key, required this.blogUuid});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  Map<String, dynamic>? _blog;
  bool _isLoading = true;
  bool _isLiking = false;
  bool _isLiked = false;
  int _likeCount = 0;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadBlog();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userId = await _secureStorage.read(key: 'user_id');
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      print('[ERROR] Error loading current user ID: $e');
    }
  }

  Future<void> _loadBlog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getBlog(widget.blogUuid);
      
      if (mounted) {
        if (response.data['success'] == true && response.data['data'] != null) {
          final blog = response.data['data'] as Map<String, dynamic>;
          setState(() {
            _blog = blog;
            _isLiked = blog['is_liked'] == true;
            _likeCount = _toInt(blog['likes_count']) ?? 
                        _toInt(blog['like_count']) ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Blog not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('[ERROR] Error loading blog: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load blog';
          _isLoading = false;
        });
      }
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _toggleLike() async {
    if (_isLiking || _blog == null) return;
    
    setState(() {
      _isLiking = true;
    });

    try {
      final response = await _apiService.toggleBlogLike(widget.blogUuid);
      
      if (mounted && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _isLiked = data['liked'] == true;
          _likeCount = _toInt(data['like_count']) ?? _likeCount;
          _isLiking = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLiking = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to like blog')),
        );
      }
    } catch (e) {
      print('[ERROR] Error toggling like: $e');
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to like blog')),
        );
      }
    }
  }

  void _shareBlog() {
    if (_blog == null) return;
    final title = _blog!['title']?.toString() ?? 'Check out this blog';
    final url = 'https://tajify.com/blog/${widget.blogUuid}';
    Share.share('$title\n$url');
  }

  bool _isOwner() {
    if (_blog == null || _currentUserId == null) return false;
    final blogUserId = _blog!['user_id']?.toString() ?? 
                      _blog!['user']?['id']?.toString();
    return blogUserId == _currentUserId;
  }

  String _stripHtmlTags(String htmlString) {
    String result = htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Decode common HTML entities
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&#8217;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&euro;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&cent;', '¢');
    
    // Decode numeric HTML entities like &#8217;
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        return String.fromCharCode(code);
      }
      return match.group(0) ?? '';
    });
    
    return result.trim();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    if (_error != null || _blog == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error ?? 'Blog not found',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final title = _blog!['title']?.toString() ?? 'Untitled';
    final excerpt = _blog!['excerpt']?.toString() ?? '';
    final content = _blog!['content']?.toString() ?? '';
    final coverImage = _blog!['cover_image_url']?.toString();
    final user = _blog!['user'] is Map<String, dynamic> 
        ? _blog!['user'] as Map<String, dynamic> 
        : null;
    final userName = user?['name']?.toString() ?? user?['username']?.toString() ?? 'Unknown';
    final userAvatar = user?['profile_avatar']?.toString() ?? 
                      user?['profile_photo_url']?.toString();
    final createdAt = _blog!['created_at']?.toString();
    final tags = _blog!['tags'] is List ? _blog!['tags'] as List : [];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isOwner())
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () {
                // TODO: Navigate to edit screen
              },
            ),
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : Colors.white,
            ),
            onPressed: _toggleLike,
          ),
          if (_likeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '$_likeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareBlog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverImage != null)
              Image.network(
                coverImage,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey[800],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                      ),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.amber,
                        backgroundImage: userAvatar != null 
                            ? NetworkImage(userAvatar) 
                            : null,
                        child: userAvatar == null
                            ? Text(
                                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (createdAt != null)
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (excerpt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _stripHtmlTags(excerpt),
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final tagStr = tag.toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.withOpacity(0.5)),
                          ),
                          child: Text(
                            '#$tagStr',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Content
                  if (content.isNotEmpty)
                    Text(
                      _stripHtmlTags(content),
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

