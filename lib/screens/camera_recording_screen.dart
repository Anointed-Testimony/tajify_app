import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:async';

class CameraRecordingScreen extends StatefulWidget {
  const CameraRecordingScreen({super.key});

  @override
  State<CameraRecordingScreen> createState() => _CameraRecordingScreenState();
}

class _CameraRecordingScreenState extends State<CameraRecordingScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  
  // Recording state
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  
  // UI state
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;
  
  // Animation controllers
  late AnimationController _recordButtonController;
  late AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _timerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordButtonController.dispose();
    _timerController.dispose();
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    print('=== CAMERA INITIALIZATION DEBUG START ===');
    
    try {
      print('[CAMERA] Getting available cameras...');
      _cameras = await availableCameras();
      print('[CAMERA] Found ${_cameras.length} cameras');
      
      for (int i = 0; i < _cameras.length; i++) {
        print('[CAMERA] Camera $i: ${_cameras[i].name} - ${_cameras[i].lensDirection}');
      }
      
      if (_cameras.isEmpty) {
        print('[CAMERA ERROR] No cameras available on device');
        _showError('No cameras available');
        return;
      }

      print('[CAMERA] Selected camera index: $_selectedCameraIndex');
      print('[CAMERA] Selected camera: ${_cameras[_selectedCameraIndex].name}');
      print('[CAMERA] Camera direction: ${_cameras[_selectedCameraIndex].lensDirection}');
      
      print('[CAMERA] Creating CameraController...');
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      print('[CAMERA] Initializing camera controller...');
      await _cameraController!.initialize();
      print('[CAMERA] Camera controller initialized successfully');
      
      if (mounted) {
        print('[CAMERA] Setting camera as initialized in UI');
        setState(() {
          _isCameraInitialized = true;
        });
        print('[CAMERA] Camera initialization complete');
      } else {
        print('[CAMERA WARNING] Widget not mounted, skipping UI update');
      }
      
      print('=== CAMERA INITIALIZATION DEBUG END (SUCCESS) ===');
    } catch (e, stackTrace) {
      print('=== CAMERA INITIALIZATION DEBUG END (ERROR) ===');
      print('[CAMERA ERROR] Failed to initialize camera: $e');
      print('[CAMERA ERROR] Error type: ${e.runtimeType}');
      print('[CAMERA ERROR] Stack trace: $stackTrace');
      
      // Additional specific error handling
      if (e.toString().contains('permission') || e.toString().contains('CameraAccessDenied')) {
        print('[CAMERA ERROR] Camera permission issue detected');
        _showPermissionDialog();
      } else if (e.toString().contains('busy') || e.toString().contains('in use')) {
        print('[CAMERA ERROR] Camera busy/in use detected');
        _showError('Camera is being used by another app. Please close other camera apps and try again.');
      } else if (e.toString().contains('not available') || e.toString().contains('not found')) {
        print('[CAMERA ERROR] Camera not available detected');
        _showError('Camera not available. Please check if your device has a working camera.');
      } else if (e.toString().contains('channel-error')) {
        print('[CAMERA ERROR] Plugin communication error detected');
        _showError('Camera plugin error. Please restart the app and try again.');
      } else {
        print('[CAMERA ERROR] Generic camera error');
        _showError('Failed to initialize camera: $e');
      }
    }
  }

  Future<void> _switchCamera() async {
    print('=== CAMERA SWITCH DEBUG START ===');
    if (_cameras.length < 2) {
      print('[CAMERA SWITCH] Only ${_cameras.length} camera(s) available, cannot switch');
      return;
    }
    
    print('[CAMERA SWITCH] Current camera index: $_selectedCameraIndex');
    print('[CAMERA SWITCH] Switching camera...');
    
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      _isCameraInitialized = false;
    });
    
    print('[CAMERA SWITCH] New camera index: $_selectedCameraIndex');
    print('[CAMERA SWITCH] Disposing current controller...');
    await _cameraController?.dispose();
    print('[CAMERA SWITCH] Controller disposed, reinitializing...');
    await _initializeCamera();
    print('=== CAMERA SWITCH DEBUG END ===');
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    
    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      _showError('Failed to toggle flash: $e');
    }
  }

  Future<void> _startRecording() async {
    print('=== RECORDING START DEBUG ===');
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('[RECORDING ERROR] Camera controller not initialized');
      _showError('Camera not ready. Please wait for initialization.');
      return;
    }

    if (_isRecording) {
      print('[RECORDING] Already recording, stopping instead');
      await _stopRecording();
      return;
    }

    try {
      print('[RECORDING] Getting temporary directory...');
      final directory = await getTemporaryDirectory();
      final videoPath = path.join(
        directory.path,
        'tajify_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      print('[RECORDING] Video will be saved to: $videoPath');

      print('[RECORDING] Starting video recording...');
      await _cameraController!.startVideoRecording();
      print('[RECORDING] Video recording started successfully');
      
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      print('[RECORDING] Updating UI and starting timer...');
      _recordButtonController.forward();
      _startRecordingTimer();
      
      // Haptic feedback
      HapticFeedback.mediumImpact();
      print('[RECORDING] Recording session active');
      
    } catch (e, stackTrace) {
      print('[RECORDING ERROR] Failed to start recording: $e');
      print('[RECORDING ERROR] Stack trace: $stackTrace');
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    print('=== RECORDING STOP DEBUG ===');
    
    if (!_isRecording || _cameraController == null) {
      print('[RECORDING STOP] Not recording or camera controller is null');
      return;
    }

    try {
      print('[RECORDING STOP] Stopping video recording...');
      final video = await _cameraController!.stopVideoRecording();
      print('[RECORDING STOP] Video saved to: ${video.path}');
      print('[RECORDING STOP] Recording duration: ${_recordingDuration.inSeconds} seconds');
      
      setState(() {
        _isRecording = false;
      });

      print('[RECORDING STOP] Updating UI and canceling timer...');
      _recordButtonController.reverse();
      _recordingTimer?.cancel();
      
      // Haptic feedback
      HapticFeedback.lightImpact();
      
      print('[RECORDING STOP] Showing video preview...');
      // Show preview/save options
      _showVideoPreview(video.path);
      
    } catch (e, stackTrace) {
      print('[RECORDING STOP ERROR] Failed to stop recording: $e');
      print('[RECORDING STOP ERROR] Stack trace: $stackTrace');
      _showError('Failed to stop recording: $e');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _showVideoPreview(String videoPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoPreviewModal(
        videoPath: videoPath,
        duration: _recordingDuration,
        onSave: _saveVideo,
        onRetake: _retakeVideo,
      ),
    );
  }

  void _saveVideo(String videoPath) async {
    // Return the video path and duration to the upload flow
    Navigator.of(context).pop(); // Close preview modal
    Navigator.of(context).pop({ // Return to channel screen with video data
      'videoPath': videoPath,
      'duration': _recordingDuration.inSeconds.toDouble(),
      'isRecorded': true,
    });
  }

  void _retakeVideo() {
    Navigator.of(context).pop(); // Close preview modal
    setState(() {
      _recordingDuration = Duration.zero;
    });
  }

  void _showError(String message) {
    print('[ERROR DISPLAY] Showing error to user: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      print('[ERROR DISPLAY] Widget not mounted, cannot show snackbar');
    }
  }

  void _showPermissionDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Camera Permission Required',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Camera and microphone permissions are required to record videos. Please:\n\n1. Go to your device Settings\n2. Find this app (Tajify)\n3. Enable Camera and Microphone permissions\n4. Return to the app and try again',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Also close camera screen
              },
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isCameraInitialized
            ? _buildCameraView()
            : _buildLoadingView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text(
            'Initializing Camera...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      children: [
        // Camera Preview
        Positioned.fill(
          child: _buildCameraPreview(),
        ),
        
        // Top Controls
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildTopControls(),
        ),
        
        // Bottom Controls
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),
        
        // Recording Timer
        if (_isRecording)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: _buildRecordingTimer(),
          ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ),
        
        // Camera controls
        Row(
          children: [
            // Flash toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: _isFlashOn ? Colors.amber : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Switch camera
            if (_cameras.length > 1)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  onPressed: _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        // Record button
        Center(
          child: GestureDetector(
            onTap: _startRecording,
            child: AnimatedBuilder(
              animation: _recordButtonController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isRecording ? 30 : 60,
                      height: _isRecording ? 30 : 60,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.white : Colors.red,
                        borderRadius: BorderRadius.circular(_isRecording ? 4 : 30),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Recording status
        Text(
          _isRecording ? 'Recording...' : 'Tap to record',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingTimer() {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, child) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8 + 0.2 * _timerController.value),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class VideoPreviewModal extends StatelessWidget {
  final String videoPath;
  final Duration duration;
  final Function(String) onSave;
  final VoidCallback onRetake;

  const VideoPreviewModal({
    super.key,
    required this.videoPath,
    required this.duration,
    required this.onSave,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Video Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRetake,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Video info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.amber),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recording Complete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Duration: ${_formatDuration(duration)}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
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
                          duration.inSeconds < 600 
                              ? 'This video will be uploaded as a Tube Short'
                              : 'This video will be uploaded as a Tube Max',
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
            
            const Spacer(),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetake,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retake',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onSave(videoPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Use Video',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

