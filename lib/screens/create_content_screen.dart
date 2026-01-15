import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajify_top_bar.dart';

class CreateContentScreen extends StatefulWidget {
  final String? initialCategory;
  
  const CreateContentScreen({super.key, this.initialCategory});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final ApiService _apiService = ApiService();
  static const MethodChannel _trimmerChannel = MethodChannel('create_content/trimmer');
  final StorageService _storageService = StorageService();
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  final bool _uploadDebug = kDebugMode;
  
  // Category selection
  late String _selectedCategory;
  final List<Map<String, String>> _categories = [
    {'id': 'Tube Short', 'name': 'Tube Short', 'label': 'Short', 'color': 'blue'},
    {'id': 'Tube Max', 'name': 'Tube Max', 'label': 'Max', 'color': 'green'},
    {'id': 'Tube Prime', 'name': 'Tube Prime', 'label': 'Prime', 'color': 'amber'},
    {'id': 'Private', 'name': 'Private', 'label': 'Private', 'color': 'red'},
    {'id': 'Audio', 'name': 'Audio', 'label': 'Audio', 'color': 'purple'},
    {'id': 'Blog', 'name': 'Blog', 'label': 'Blog', 'color': 'orange'},
  ];
  
  // Tab selection
  String _activeTab = 'upload'; // 'upload' or 'record' or 'audio'
  
  // Video state
  File? _uploadedVideoFile;
  VideoPlayerController? _videoController;
  double _videoDuration = 0;
  String _durationError = '';
  bool _showThumbnailSection = false;
  List<Map<String, dynamic>> _autoThumbnails = [];
  dynamic _selectedThumbnail;
  File? _customThumbnail;
  bool _isGeneratingThumbnails = false;
  int? _selectedAutoThumbnailId;
  double _thumbnailScrubberTime = 0;
  Uint8List? _scrubbedThumbnailBytes;
  bool _showVideoEditor = false;
  double _trimStart = 0;
  double _trimEnd = 0;
  bool _isTrimmingVideo = false;
  
  // Audio state
  File? _audioFile;
  String _audioTitle = '';
  String _audioGenre = '';
  File? _audioCover;
  String _audioType = 'single'; // 'single', 'ep', 'album'
  List<Map<String, dynamic>> _audioTracks = [];
  String _albumTitle = '';
  
  // Blog state
  final TextEditingController _blogTitleController = TextEditingController();
  late final HtmlEditorController _blogContentController;
  final TextEditingController _blogExcerptController = TextEditingController();
  final TextEditingController _blogTagInputController = TextEditingController();
  List<String> _blogTags = [];
  File? _blogCoverImage;
  Uint8List? _blogCoverPreview;
  bool _blogPublished = true;

  // Form fields
  String _videoTitle = '';
  List<String> _hashtags = [];
  
  // Upload state
  bool _isProcessing = false;
  
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _audioTitleController = TextEditingController();
  final TextEditingController _albumTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'Tube Short';
    _blogContentController = HtmlEditorController();
    _descriptionController.addListener(_onDescriptionChanged);
    _loadCurrentUserBasics();
  }

  Widget _buildVideoEditorPanel() {
    if (_uploadedVideoFile == null || _videoDuration <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showVideoEditor = !_showVideoEditor;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  color: _showVideoEditor ? const Color(0xFFB875FB) : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _showVideoEditor ? 'Hide video editor' : 'Edit & trim video',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  _showVideoEditor ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_showVideoEditor) ...[
          const SizedBox(height: 12),
          _buildTrimControls(),
        ],
      ],
    );
  }

  Widget _buildTrimControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trim video length',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RangeSlider(
            min: 0,
            max: _videoDuration,
            divisions: _videoDuration > 0 ? _videoDuration.clamp(1, double.infinity).round() : null,
            values: RangeValues(_trimStart, _trimEnd),
            activeColor: const Color(0xFFB875FB),
            inactiveColor: Colors.white24,
            onChanged: (values) {
              setState(() {
                _trimStart = values.start;
                _trimEnd = values.end;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${_formatTime(_trimStart)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                'End: ${_formatTime(_trimEnd)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                'Length: ${_formatTime(_trimEnd - _trimStart)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_trimEnd - _trimStart) > 1 && !_isTrimmingVideo ? _applyTrim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB875FB),
                disabledBackgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isTrimmingVideo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Apply Trim',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _videoController?.dispose();
    _descriptionController.dispose();
    _titleController.dispose();
    _audioTitleController.dispose();
    _albumTitleController.dispose();
    _blogTitleController.dispose();
    _blogExcerptController.dispose();
    _blogTagInputController.dispose();
    super.dispose();
  }


  void _onDescriptionChanged() {
    _extractHashtags(_descriptionController.text);
    _loadHashtagSuggestions(_descriptionController.text);
  }

  void _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(text);
    setState(() {
      _hashtags = matches.map((m) => m.group(1)!).toSet().toList();
    });
  }

  Future<void> _loadHashtagSuggestions(String query) async {
    // Hashtag suggestions can be implemented later if needed
  }

  Future<void> _loadCurrentUserBasics() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = response.data['data'];
        if (mounted) {
          setState(() {
            // Handle nested user object
            final user = profile?['user'] ?? profile;
            final name = user?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = user?['profile_avatar']?.toString();
          });
        }
        return;
      }
    } catch (_) {
      // ignored
    }

    try {
      final name = await _storageService.getUserName();
      final avatar = await _storageService.getUserProfilePicture();
      if (!mounted) return;
      setState(() {
        if (name != null && name.isNotEmpty) {
          _currentUserInitial = name[0].toUpperCase();
        }
        _currentUserAvatar = avatar;
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _loadVideo(file);
      }
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  Future<void> _loadVideo(File file) async {
    try {
      setState(() {
        _uploadedVideoFile = file;
        _showThumbnailSection = false;
      });

      _videoController?.dispose();
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      
      final duration = _videoController!.value.duration;
      setState(() {
        _videoDuration = duration.inSeconds.toDouble();
        _validateVideoDuration();
        _trimStart = 0;
        _trimEnd = _videoDuration;
        _thumbnailScrubberTime = _videoDuration > 0 ? _videoDuration / 2 : 0;
      });

      // Generate thumbnails
      await _generateThumbnails();
    } catch (e) {
      _showError('Failed to load video: $e');
    }
  }

  void _validateVideoDuration() {
    if (_selectedCategory == 'Tube Short' && _videoDuration > 90) {
      setState(() {
        _durationError = 'Video duration (${_formatTime(_videoDuration)}) exceeds the maximum allowed duration of 90 seconds (1 minute 30 seconds) for Tube Short';
      });
    } else {
      setState(() {
        _durationError = '';
      });
    }
  }

  Future<void> _generateThumbnails() async {
    if (_uploadedVideoFile == null || _videoDuration <= 0) return;

    setState(() {
      _isGeneratingThumbnails = true;
      _showThumbnailSection = true;
    });

    try {
      final videoPath = _uploadedVideoFile!.path;
      final intervals = [0.05, 0.25, 0.5, 0.75, 0.9];
      final thumbnails = <Map<String, dynamic>>[];

      for (int i = 0; i < intervals.length; i++) {
        final targetSeconds = (_videoDuration * intervals[i]).clamp(0, _videoDuration - 0.1) as double;
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          timeMs: (targetSeconds * 1000).round(),
          imageFormat: ImageFormat.JPEG,
          quality: 85,
        );

        if (bytes != null) {
          thumbnails.add({
            'id': i,
            'time': targetSeconds,
            'timeString': _formatTime(targetSeconds),
            'bytes': bytes,
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _autoThumbnails = thumbnails;
      });

      if (thumbnails.isNotEmpty) {
        await _selectAutoThumbnail(thumbnails.first, fromGenerator: true);
      }
    } catch (e) {
      print('[CREATE] Error generating thumbnails: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingThumbnails = false;
        });
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: _audioType != 'single',
      );

      if (result != null) {
        if (_audioType == 'single') {
          if (result.files.single.path != null) {
            setState(() {
              _audioFile = File(result.files.single.path!);
            });
          }
        } else {
          final files = result.files
              .where((f) => f.path != null)
              .map((f) => File(f.path!))
              .toList();
          
          setState(() {
            _audioTracks = files.asMap().entries.map((entry) {
              return {
                'id': entry.key,
                'file': entry.value,
                'title': '',
                'trackNumber': entry.key + 1,
                'duration': 0, // Would extract from audio file
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      _showError('Failed to pick audio: $e');
    }
  }

  Future<void> _pickCoverArt() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _audioCover = File(result.files.single.path!);
        });
      }
    } catch (e) {
      _showError('Failed to pick cover art: $e');
    }
  }

  Future<void> _pickCustomThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _customThumbnail = file;
          _selectedThumbnail = 'custom';
          _selectedAutoThumbnailId = null;
          _scrubbedThumbnailBytes = bytes;
        });
      }
    } catch (e) {
      _showError('Failed to pick thumbnail: $e');
    }
  }

  Future<void> _handlePublish() async {
    if (_selectedCategory == 'Tube Prime' && _videoTitle.trim().isEmpty) {
      _showError('Please enter a video title for Tube Prime content');
      return;
    }

    if (_selectedCategory == 'Audio' && _audioTitle.trim().isEmpty) {
      _showError('Please enter a track title for audio content');
      return;
    }

    if (_selectedCategory == 'Audio' && _audioType != 'single' && _albumTitle.trim().isEmpty) {
      _showError('Please enter ${_audioType == 'ep' ? 'EP' : 'album'} title');
      return;
    }

    if (_durationError.isNotEmpty) {
      _showError(_durationError);
      return;
    }

    _uploadLog('Starting publish flow', {
      'category': _selectedCategory,
      'activeTab': _activeTab,
      'isEditing': _showVideoEditor,
      'hashtags': _hashtags,
    });

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_selectedCategory == 'Audio') {
        _uploadLog('Publishing audio');
        await _publishAudio();
      } else if (_selectedCategory == 'Blog') {
        _uploadLog('Publishing blog');
        await _publishBlog();
      } else {
        _uploadLog('Publishing video');
        await _publishVideo();
      }
    } catch (e) {
      _showError('Upload failed: ${e.toString()}');
      _uploadLog('Publish failed', e.toString());
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _uploadLog(String message, [dynamic payload]) {
    if (!_uploadDebug) return;
    if (payload != null) {
      debugPrint('[UPLOAD] $message => $payload');
    } else {
      debugPrint('[UPLOAD] $message');
    }
  }

  Future<void> _publishVideo() async {
    if (_uploadedVideoFile == null) {
      throw Exception('No video file available');
    }

    try {
      // Step 1: Get upload token
      final tokenResponse = await _apiService.getUploadToken();
      final uploadToken = tokenResponse.data['token'];
       _uploadLog('Audio upload token received', tokenResponse.data);
      _uploadLog('Obtained upload token', tokenResponse.data);

      // Step 2: Upload video
      final uploadResponse = await _apiService.uploadMedia(
        _uploadedVideoFile!,
        'video',
        uploadToken: uploadToken,
        duration: _videoDuration,
      );
      _uploadLog('Video uploaded', {
        'statusCode': uploadResponse.statusCode,
        'response': uploadResponse.data,
      });
      final videoMediaId = _extractMediaId(uploadResponse.data);
      if (videoMediaId == null) {
        throw Exception('Video upload failed: missing media file id');
      }
      _uploadLog('Video media id', videoMediaId);

      // Step 3: Upload thumbnail if custom
      int? thumbnailMediaId;
      if (_selectedThumbnail == 'custom' && _customThumbnail != null) {
        try {
          final thumbTokenResponse = await _apiService.getUploadToken();
          final thumbToken = thumbTokenResponse.data['token'];
          final thumbResponse = await _apiService.uploadMedia(
            _customThumbnail!,
            'image',
            uploadToken: thumbToken,
          );
          thumbnailMediaId = _extractMediaId(thumbResponse.data);
          _uploadLog('Thumbnail uploaded', {
            'statusCode': thumbResponse.statusCode,
            'response': thumbResponse.data,
          });
        } catch (e) {
          print('[CREATE] Custom thumbnail upload failed: $e');
        }
      }

      // Step 4: Create post
      final postResponse = await _apiService.createPostWithAutoCategorization(
        videoDuration: _videoDuration,
        title: _selectedCategory == 'Tube Prime' ? _videoTitle : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        isPrime: _selectedCategory == 'Tube Prime',
        allowDuet: true,
        hashtags: _hashtags.isNotEmpty ? _hashtags : null,
      );
      _uploadLog('Post created (auto categorize)', postResponse.data);
      final postData = _extractPostData(postResponse.data);
      final postId = _toInt(postData?['id']);
      if (postId == null) {
        throw Exception('Unexpected response from server while creating post');
      }

      // Step 5: Complete upload
      await _apiService.completeUpload(
        postId,
        [videoMediaId],
        thumbnailMediaId: thumbnailMediaId,
      );
      _uploadLog('Complete upload called', {
        'postId': postId,
        'mediaIds': [videoMediaId],
        'thumbnailId': thumbnailMediaId,
      });

      _showSuccess('Video uploaded successfully!');
      _uploadLog('Video publish completed');
      _resetVideo();
      
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      throw Exception('Video upload failed: $e');
    }
  }

  Future<void> _publishAudio() async {
    if (_audioFile == null && _audioTracks.isEmpty) {
      throw Exception('No audio file available');
    }

    try {
      // Step 1: Get upload token
      final tokenResponse = await _apiService.getUploadToken();
      final uploadToken = tokenResponse.data['token'];

      // Step 2: Upload audio file(s)
      int audioMediaId;
      if (_audioType == 'single' && _audioFile != null) {
        final audioResponse = await _apiService.uploadMedia(
          _audioFile!,
          'audio',
          uploadToken: uploadToken,
        );
        audioMediaId = _extractMediaId(audioResponse.data) ??
            (throw Exception('Audio upload failed: missing media file id'));
        _uploadLog('Audio file uploaded', audioResponse.data);
      } else {
        // For EP/Album, upload first track (simplified)
        if (_audioTracks.isEmpty) throw Exception('No tracks available');
        final firstTrack = _audioTracks.first;
        final audioResponse = await _apiService.uploadMedia(
          firstTrack['file'] as File,
          'audio',
          uploadToken: uploadToken,
        );
        audioMediaId = _extractMediaId(audioResponse.data) ??
            (throw Exception('Audio upload failed: missing media file id'));
        _uploadLog('First track uploaded for album/EP', audioResponse.data);
      }

      // Step 3: Upload cover art if provided
      int? coverMediaId;
      if (_audioCover != null) {
        try {
          final coverTokenResponse = await _apiService.getUploadToken();
          final coverToken = coverTokenResponse.data['token'];
          final coverResponse = await _apiService.uploadMedia(
            _audioCover!,
            'image',
            uploadToken: coverToken,
          );
          coverMediaId = _extractMediaId(coverResponse.data);
          _uploadLog('Cover art uploaded', coverResponse.data);
        } catch (e) {
          print('[CREATE] Cover art upload failed: $e');
        }
      }

      // Step 4: Create audio post
      // Get post type ID for audio (default to 4 if not available)
      final postTypesResponse = await _apiService.getPostTypes();
      int audioTypeId = 4; // Default fallback
      if (postTypesResponse.statusCode == 200) {
        final postTypes = postTypesResponse.data['data'] as List?;
        _uploadLog('Post types fetched', postTypesResponse.data);
        if (postTypes != null) {
          final audioType = postTypes.firstWhere(
            (type) => type['name']?.toString().toLowerCase() == 'audio',
            orElse: () => null,
          );
          if (audioType != null) {
            audioTypeId = audioType['id'] ?? 4;
          }
        }
      }
      
      final postResponse = await _apiService.createPost(
        postTypeId: audioTypeId,
        title: _audioTitle.trim().isNotEmpty ? _audioTitle : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        isPrime: false,
        allowDuet: true,
        hashtags: _hashtags.isNotEmpty ? _hashtags : null,
      );
      _uploadLog('Audio post created', postResponse.data);
      final postData = _extractPostData(postResponse.data);
      final postId = _toInt(postData?['id']);
      if (postId == null) {
        throw Exception('Unexpected response from server while creating audio post');
      }

      // Step 5: Complete upload
      final mediaFileIds = [audioMediaId];
      await _apiService.completeUpload(
        postId,
        mediaFileIds,
        thumbnailMediaId: coverMediaId,
      );
      _uploadLog('Audio complete upload', {
        'postId': postId,
        'mediaIds': mediaFileIds,
        'coverId': coverMediaId,
      });

      _showSuccess('Audio track uploaded successfully!');
      _uploadLog('Audio publish completed');
      _resetAudio();
      
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      throw Exception('Audio upload failed: $e');
    }
  }

  Future<void> _publishBlog() async {
    final title = _blogTitleController.text.trim();
    // Get content from HTML editor
    String content = '';
    try {
      content = await _blogContentController.getText();
    } catch (e) {
      debugPrint('Error getting blog content: $e');
      content = '';
    }
    final excerpt = _blogExcerptController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      throw Exception('Blog title and content are required');
    }

    try {
      _uploadLog('Submitting blog', {
        'title': title,
        'excerpt': excerpt,
        'tags': _blogTags,
        'published': _blogPublished,
        'hasCover': _blogCoverImage != null,
      });

      final response = await _apiService.createBlog(
        title: title,
        content: content,
        excerpt: excerpt.isNotEmpty ? excerpt : null,
        tags: _blogTags,
        isPublished: _blogPublished,
        coverImage: _blogCoverImage,
      );

      _uploadLog('Blog response', response.data);

      _showSuccess(_blogPublished ? 'Blog published successfully!' : 'Blog saved as draft!');
      await _resetBlog();

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/channel');
        }
      }
    } catch (e) {
      throw Exception('Blog upload failed: $e');
    }
  }

  Future<void> _applyTrim() async {
    if (_uploadedVideoFile == null) return;
    final clipDuration = _trimEnd - _trimStart;
    if (clipDuration <= 1) {
      _showError('Trim length must be at least 1 second');
      return;
    }

    setState(() {
      _isTrimmingVideo = true;
    });

    try {
      final trimmedPath = await _trimVideoLocally(
        _uploadedVideoFile!.path,
        _trimStart,
        _trimEnd,
      );
      _uploadLog('Trim result path', trimmedPath);
      if (trimmedPath != null) {
        await _loadVideo(File(trimmedPath));
        if (mounted) {
          _showSuccess('Trim applied successfully');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTrimmingVideo = false;
        });
      }
    }
  }

  Future<String?> _trimVideoLocally(String inputPath, double start, double end) async {
    try {
      final result = await _trimmerChannel.invokeMethod<String>('trimVideo', {
        'inputPath': inputPath,
        'start': start,
        'end': end,
      });
      _uploadLog('Native trim invoked', {'input': inputPath, 'start': start, 'end': end, 'result': result});
      return result;
    } on PlatformException catch (e) {
      _showError(e.message ?? 'Failed to trim video');
      _uploadLog('Platform trim error', e.message);
    } catch (e) {
      _showError('Error trimming video: $e');
      _uploadLog('Trim exception', e.toString());
    }
    return null;
  }

  Map<String, dynamic>? _extractPostData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final directPost = responseData['post'];
      if (directPost is Map<String, dynamic>) {
        return directPost;
      }
      final nestedData = responseData['data'];
      if (nestedData is Map<String, dynamic>) {
        final nestedPost = nestedData['post'];
        if (nestedPost is Map<String, dynamic>) {
          return nestedPost;
        }
      }
    }
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _extractMediaId(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final direct = responseData['media_file_id'];
      final intDirect = _toInt(direct);
      if (intDirect != null) return intDirect;

      final nested = responseData['data'];
      if (nested is Map<String, dynamic>) {
        return _toInt(nested['media_file_id']);
      }
    }
    return _toInt(responseData);
  }

  void _resetVideo() {
    setState(() {
      _uploadedVideoFile = null;
      _videoController?.dispose();
      _videoController = null;
      _videoDuration = 0;
      _durationError = '';
      _showThumbnailSection = false;
      _autoThumbnails = [];
      _selectedThumbnail = null;
      _customThumbnail = null;
      _videoTitle = '';
      _descriptionController.clear();
      _hashtags = [];
      _isProcessing = false;
    });
  }

  void _resetAudio() {
    setState(() {
      _audioFile = null;
      _audioTitle = '';
      _audioGenre = '';
      _audioCover = null;
      _audioType = 'single';
      _audioTracks = [];
      _albumTitle = '';
      _audioTitleController.clear();
      _albumTitleController.clear();
      _descriptionController.clear();
      _hashtags = [];
      _isProcessing = false;
    });
  }

  Future<void> _resetBlog() async {
    _blogContentController.clear();
    setState(() {
      _blogTitleController.clear();
      _blogExcerptController.clear();
      _blogTagInputController.clear();
      _blogTags = [];
      _blogCoverImage = null;
      _blogCoverPreview = null;
      _blogPublished = true;
      _isProcessing = false;
    });
  }

  Future<void> _pickBlogCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _blogCoverImage = file;
          _blogCoverPreview = bytes;
        });
      }
    } catch (e) {
      _showError('Failed to pick cover image: $e');
    }
  }

  void _addBlogTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_blogTags.contains(trimmed)) {
        _blogTags.add(trimmed);
      }
    });
    _blogTagInputController.clear();
  }

  void _removeBlogTag(String tag) {
    setState(() {
      _blogTags.remove(tag);
    });
  }

  String _formatTime(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Color _getCategoryColor(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'amber':
        return Color(0xFFB875FB);
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Color(0xFFB875FB);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/channel');
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: TajifyTopBar(
        showBackButton: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/channel');
          }
        },
        onSearch: () => context.push('/search'),
        onNotifications: () => context.push('/notifications'),
        onMessages: () => context.push('/messages'),
        onAvatarTap: () => context.go('/profile'),
        showAddButton: false,
        notificationCount: 0,
        messageCount: 0,
        avatarUrl: _currentUserAvatar,
        displayLetter: _currentUserInitial,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection
              _buildCategorySelection(),
              const SizedBox(height: 24),
              
              // Tab Selection (for video categories)
              if (_selectedCategory != 'Audio' && _selectedCategory != 'Blog')
                _buildTabSelection(),
              
              if (_selectedCategory != 'Audio' && _selectedCategory != 'Blog')
                const SizedBox(height: 24),
              
              // Main Content
              if (_selectedCategory == 'Audio')
                _buildAudioContent()
              else if (_selectedCategory == 'Blog')
                _buildBlogContent()
              else
                _buildVideoContent(),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.asMap().entries.map((entry) {
              final category = entry.value;
              final isLast = entry.key == _categories.length - 1;
              final isSelected = _selectedCategory == category['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category['id']!;
                    if (_selectedCategory == 'Audio') {
                      _activeTab = 'audio';
                    } else {
                      _activeTab = 'upload';
                    }
                    if (_videoDuration > 0) {
                      _validateVideoDuration();
                    }
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              _getCategoryColor(category['color']!),
                              _getCategoryColor(category['color']!).withOpacity(0.7),
                            ],
                          )
                        : null,
                    color: isSelected ? null : Colors.grey[850],
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        category['label'] ?? category['name']!,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (category['id'] == 'Tube Short')
                        Text(
                          ' · 90s',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black.withOpacity(0.65)
                                : Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelection() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton('Upload', 'upload', Icons.upload),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTabButton('Record', 'record', Icons.videocam),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, String tab, IconData icon) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFB875FB), Color(0xFFB875FB)],
                )
              : null,
          color: isActive ? null : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video Preview/Upload
        if (_activeTab == 'upload')
          _buildVideoUploadSection()
        else
          _buildRecordSection(),
        
        const SizedBox(height: 24),
        
        // Thumbnail Selection
        if (_showThumbnailSection)
          _buildThumbnailSection(),
        
        if (_showThumbnailSection)
          const SizedBox(height: 24),
        
        // Video Details
        _buildVideoDetails(),
      ],
    );
  }

  Widget _buildVideoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Video',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickVideo,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[600]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.upload,
                  color: Colors.grey[400],
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Click to upload video',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MP4, WebM, MOV or other supported video formats',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_uploadedVideoFile != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _videoController != null && _videoController!.value.isInitialized
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                    ),
                  ),
          ),
          if (_videoDuration > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Duration: ${_formatTime(_videoDuration)}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          _buildVideoEditorPanel(),
        ],
      ],
    );
  }

  Widget _buildRecordSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        children: [
          Icon(Icons.videocam, color: Colors.grey[400], size: 48),
          const SizedBox(height: 12),
          Text(
            'Camera Recording',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Camera recording feature coming soon',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Thumbnail',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isGeneratingThumbnails)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB875FB)),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Generating smart thumbnails...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        if (!_isGeneratingThumbnails && _autoThumbnails.isNotEmpty) ...[
          const Text(
            'Auto-generated from video',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _autoThumbnails.length,
            itemBuilder: (context, index) {
              final thumbnail = _autoThumbnails[index];
              final bytes = thumbnail['bytes'] as Uint8List?;
              final isSelected = _selectedAutoThumbnailId == thumbnail['id'];
              return GestureDetector(
                onTap: () => _selectAutoThumbnail(thumbnail),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Color(0xFFB875FB) : Colors.grey[700]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(0xFFB875FB).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: bytes != null
                            ? Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Container(color: Colors.grey[800]),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB875FB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 14,
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                          ),
                          child: Text(
                            thumbnail['timeString'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        // Custom thumbnail option
        GestureDetector(
          onTap: _pickCustomThumbnail,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedAutoThumbnailId == null && _selectedThumbnail == 'custom'
                    ? Color(0xFFB875FB)
                    : Colors.grey[600]!,
                width: _selectedAutoThumbnailId == null && _selectedThumbnail == 'custom' ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.image,
                  color: _selectedAutoThumbnailId == null && _selectedThumbnail == 'custom'
                      ? Color(0xFFB875FB)
                      : Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upload Custom Thumbnail',
                    style: TextStyle(
                      color: _selectedAutoThumbnailId == null && _selectedThumbnail == 'custom'
                          ? Color(0xFFB875FB)
                          : Colors.white,
                      fontWeight: _selectedAutoThumbnailId == null && _selectedThumbnail == 'custom'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (_customThumbnail != null)
                  const Icon(Icons.check, color: Color(0xFFB875FB), size: 20),
              ],
            ),
          ),
        ),
        if (_customThumbnail != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _scrubbedThumbnailBytes != null
                ? Image.memory(
                    _scrubbedThumbnailBytes!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    _customThumbnail!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
        ],
        if (_uploadedVideoFile != null && _videoDuration > 0) ...[
          const SizedBox(height: 20),
          _buildManualThumbnailSelector(),
        ],
      ],
    );
  }

  Widget _buildManualThumbnailSelector() {
    final clampedValue = _thumbnailScrubberTime.clamp(0, _videoDuration) as double;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select frame from timestamp',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Slider(
            min: 0,
            max: _videoDuration,
            value: clampedValue,
            activeColor: const Color(0xFFB875FB),
            inactiveColor: Colors.white24,
            onChanged: (value) {
              setState(() {
                _thumbnailScrubberTime = value;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(_thumbnailScrubberTime),
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
              Text(
                _formatTime(_videoDuration),
                style: const TextStyle(color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _captureThumbnailAtCurrentPosition,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFB875FB)),
                foregroundColor: const Color(0xFFB875FB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.photo_camera),
              label: const Text(
                'Use frame at selected time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_scrubbedThumbnailBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _scrubbedThumbnailBytes!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _captureThumbnailAtCurrentPosition() async {
    if (_uploadedVideoFile == null) return;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: _uploadedVideoFile!.path,
        timeMs: (_thumbnailScrubberTime * 1000).round(),
        imageFormat: ImageFormat.JPEG,
        quality: 90,
      );
      if (bytes == null) return;
      final file = await _saveThumbnailBytes(bytes);
      if (!mounted) return;
      setState(() {
        _customThumbnail = file;
        _selectedThumbnail = 'custom';
        _selectedAutoThumbnailId = null;
        _scrubbedThumbnailBytes = bytes;
      });
    } catch (e) {
      _showError('Unable to capture frame: $e');
    }
  }

  Future<void> _selectAutoThumbnail(Map<String, dynamic> thumbnail, {bool fromGenerator = false}) async {
    final bytes = thumbnail['bytes'] as Uint8List?;
    if (bytes == null) return;
    final file = await _saveThumbnailBytes(bytes);
    if (!mounted) return;
    setState(() {
      _customThumbnail = file;
      _selectedThumbnail = 'custom';
      _selectedAutoThumbnailId = thumbnail['id'] as int?;
      _scrubbedThumbnailBytes = bytes;
    });
    if (!fromGenerator) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thumbnail updated'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<File> _saveThumbnailBytes(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  Widget _buildVideoDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Title (only for Tube Prime)
        if (_selectedCategory == 'Tube Prime') ...[
          TextField(
            controller: _titleController,
            onChanged: (value) {
              setState(() {
                _videoTitle = value;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Title *',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: 'Enter video title...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFB875FB)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Description
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Description',
            labelStyle: const TextStyle(color: Colors.grey),
            hintText: 'Describe your video... Use #hashtags for better discoverability',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB875FB)),
            ),
          ),
        ),
        
        // Hashtags display
        if (_hashtags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hashtags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
        
        // Duration error
        if (_durationError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _durationError,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio Type Selection
        _buildAudioTypeSelection(),
        const SizedBox(height: 24),
        
        // Upload Section
        Row(
          children: [
            Expanded(
              child: _buildAudioUploadSection(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCoverArtSection(),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Album/EP Details
        if ((_audioType == 'ep' || _audioType == 'album') && _audioTracks.isNotEmpty)
          _buildAlbumDetails(),
        
        // Track Details (for single)
        if (_audioType == 'single' && _audioFile != null) ...[
          const SizedBox(height: 24),
          _buildSingleTrackDetails(),
        ],
        
        // Track List (for EP/Album)
        if (_audioTracks.isNotEmpty && _audioType != 'single') ...[
          const SizedBox(height: 24),
          _buildTrackList(),
        ],
        
        // Genre Selection
        if ((_audioTracks.isNotEmpty || (_audioType == 'single' && _audioFile != null))) ...[
          const SizedBox(height: 24),
          _buildGenreSelection(),
        ],
        
        // Description
        if ((_audioTracks.isNotEmpty || (_audioType == 'single' && _audioFile != null))) ...[
          const SizedBox(height: 24),
          _buildAudioDescription(),
        ],
      ],
    );
  }

  Widget _buildAudioTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What are you uploading?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAudioTypeButton('Single', 'single', Icons.mic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAudioTypeButton('EP', 'ep', Icons.music_note),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAudioTypeButton('Album', 'album', Icons.album),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioTypeButton(String label, String type, IconData icon) {
    final isSelected = _audioType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _audioType = type;
          if (type == 'single') {
            _audioTracks.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                )
              : null,
          color: isSelected ? null : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _audioType == 'single' ? 'Upload Track' : 'Upload ${_audioType == 'ep' ? 'EP' : 'Album'} Tracks',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickAudio,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[600]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.music_note,
                  color: Colors.purple[300],
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  _audioType == 'single' ? 'Click to upload track' : 'Click to upload tracks',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MP3, WAV, M4A up to 100MB each',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_audioFile != null) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${_audioFile!.path.split('/').last}',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (_audioTracks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${_audioTracks.length} track(s) selected',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildCoverArtSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cover Art',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickCoverArt,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[600]!,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _audioCover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      _audioCover!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        color: Colors.purple[300],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload cover art',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_audioType == 'ep' ? 'EP' : 'Album'} Details',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _albumTitleController,
                onChanged: (value) {
                  setState(() {
                    _albumTitle = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '${_audioType == 'ep' ? 'EP' : 'Album'} Title *',
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: 'Enter ${_audioType == 'ep' ? 'EP' : 'album'} title...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9333EA)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Year',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9333EA)),
                  ),
                ),
                onChanged: (value) {
                  // Album year can be stored if needed
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleTrackDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Track Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _audioTitleController,
          onChanged: (value) {
            setState(() {
              _audioTitle = value;
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Track Title *',
            labelStyle: const TextStyle(color: Colors.grey),
            hintText: 'Enter track title...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9333EA)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Track List',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._audioTracks.map((track) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${track['trackNumber']}',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        track['title'] = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Track title...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      _audioTracks.removeWhere((t) => t['id'] == track['id']);
                    });
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGenreSelection() {
    final genres = [
      'Afrobeats', 'Afro-pop', 'Afro-fusion', 'Afro-house', 'Afro-soul',
      'Afro-jazz', 'Afro-rock', 'Afro-reggae', 'Afro-hip-hop', 'Afro-trap',
      'Afro-dancehall', 'Hip Hop', 'Pop', 'Rock', 'Electronic', 'R&B',
      'Jazz', 'Classical', 'Country', 'Reggae', 'Blues', 'Folk', 'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genre',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _audioGenre.isEmpty ? null : _audioGenre,
          decoration: InputDecoration(
            labelText: 'Select Genre',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9333EA)),
            ),
          ),
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select genre...', style: TextStyle(color: Colors.grey)),
            ),
            ...genres.map((genre) {
              return DropdownMenuItem<String>(
                value: genre,
                child: Text(genre, style: const TextStyle(color: Colors.white)),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _audioGenre = value ?? '';
            });
          },
        ),
      ],
    );
  }

  Widget _buildAudioDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Describe your ${_audioType == 'single' ? 'track' : _audioType == 'ep' ? 'EP' : 'album'}... Use #hashtags for better discoverability',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9333EA)),
            ),
          ),
        ),
        if (_hashtags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hashtags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Text(
                  '#$tag',
                  style: const TextStyle(color: Colors.purple, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildBlogContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.article_outlined, color: Color(0xFFB875FB)),
              SizedBox(width: 8),
              Text(
                'Write a Blog Post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLabeledField(
            label: 'Title *',
            child: TextField(
              controller: _blogTitleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Enter a captivating title'),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            label: 'Excerpt / Summary',
            child: TextField(
              controller: _blogExcerptController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecoration('Short summary (optional)'),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            label: 'Content *',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: HtmlEditor(
                controller: _blogContentController,
                htmlEditorOptions: const HtmlEditorOptions(
                  hint: 'Write your story...',
                  shouldEnsureVisible: true,
                  initialText: '',
                ),
                htmlToolbarOptions: HtmlToolbarOptions(
                  defaultToolbarButtons: [
                    const StyleButtons(),
                    const FontSettingButtons(fontSizeUnit: false),
                    const FontButtons(
                      clearAll: false,
                      strikethrough: false,
                      superscript: false,
                      subscript: false,
                    ),
                    const ColorButtons(),
                    const ListButtons(listStyles: false),
                    const ParagraphButtons(
                      textDirection: false,
                      lineHeight: false,
                      caseConverter: false,
                    ),
                    const InsertButtons(
                      video: false,
                      audio: false,
                      table: false,
                      hr: false,
                      otherFile: false,
                    ),
                    const OtherButtons(
                      fullscreen: false,
                      codeview: false,
                      undo: false,
                      redo: false,
                      help: false,
                      copy: false,
                      paste: false,
                    ),
                  ],
                  toolbarPosition: ToolbarPosition.aboveEditor,
                  toolbarType: ToolbarType.nativeScrollable,
                ),
                otherOptions: const OtherOptions(
                  height: 300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            label: 'Tags',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ 
                TextField(
                  controller: _blogTagInputController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addBlogTag,
                  decoration: _inputDecoration('Press enter to add tag')
                      .copyWith(suffixIcon: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: () => _addBlogTag(_blogTagInputController.text),
                  )),
                ),
                if (_blogTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _blogTags
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Color(0xFFB875FB).withOpacity(0.15),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            deleteIconColor: Colors.white70,
                            onDeleted: () => _removeBlogTag(tag),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildLabeledField(
            label: 'Cover Image',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickBlogCover,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _blogCoverImage == null ? 'Select cover image' : 'Change cover image',
                  ),
                ),
                if (_blogCoverPreview != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _blogCoverPreview!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _blogPublished ? 'Publish immediately' : 'Save as draft',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _blogPublished
                    ? 'Your blog will be visible to everyone once uploaded.'
                    : 'Keep this post private for now. You can publish it later.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              value: _blogPublished,
              activeColor: Color(0xFFB875FB),
              onChanged: (value) {
                setState(() {
                  _blogPublished = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB875FB)),
      ),
    );
  }

  Widget _buildActionButtons() {
    return FutureBuilder<bool>(
      future: _canPublish(),
      builder: (context, snapshot) {
        final canPublish = snapshot.data ?? false;
        
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _selectedCategory == 'Audio'
                    ? _resetAudio
                    : _selectedCategory == 'Blog'
                        ? _resetBlog
                        : _resetVideo,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.refresh, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Reset',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canPublish && !_isProcessing ? _handlePublish : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _selectedCategory == 'Audio'
                      ? Colors.purple
                      : _selectedCategory == 'Blog'
                          ? Colors.tealAccent.shade700
                          : const Color(0xFFB875FB),
                  disabledBackgroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.publish, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _selectedCategory == 'Audio'
                                ? 'Publish Track'
                                : _selectedCategory == 'Blog'
                                    ? (_blogPublished ? 'Publish Blog' : 'Save Draft')
                                    : 'Publish Video',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _canPublish() async {
    if (_selectedCategory == 'Tube Prime' && _videoTitle.trim().isEmpty) {
      return false;
    }
    if (_selectedCategory == 'Audio' && _audioTitle.trim().isEmpty) {
      return false;
    }
    if (_selectedCategory == 'Audio' && _audioType != 'single' && _albumTitle.trim().isEmpty) {
      return false;
    }
    if (_selectedCategory == 'Audio' && _audioType == 'single' && _audioFile == null) {
      return false;
    }
    if (_selectedCategory == 'Audio' && _audioType != 'single' && _audioTracks.isEmpty) {
      return false;
    }
    if (_selectedCategory == 'Blog') {
      try {
        final content = await _blogContentController.getText();
        if (_blogTitleController.text.trim().isEmpty || content.trim().isEmpty) {
          return false;
        }
      } catch (e) {
        debugPrint('Error checking blog content: $e');
        return false;
      }
    }
    if (_selectedCategory != 'Audio' && _selectedCategory != 'Blog' && _uploadedVideoFile == null) {
      return false;
    }
    if (_durationError.isNotEmpty) {
      return false;
    }
    return true;
  }
}

