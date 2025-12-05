import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';

class LiveViewerScreen extends StatefulWidget {
  final String channelName;
  final Map<String, dynamic>? sessionData;

  const LiveViewerScreen({
    super.key,
    required this.channelName,
    this.sessionData,
  });

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final ApiService _apiService = ApiService();
  late final RtcEngine _engine;

  bool _engineInitialized = false;
  bool _joined = false;
  String? _token;
  int _uid = 0;
  int? _remoteUid;
  String? _errorMessage;
  Map<String, dynamic>? _sessionData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sessionData = widget.sessionData;
    _startViewingFlow();
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  Future<void> _startViewingFlow() async {
    try {
      // Fetch session details if not provided
      if (_sessionData == null) {
        final response = await _apiService.getLiveSession(widget.channelName);
        if (response.statusCode == 200 && response.data['success'] == true) {
          setState(() {
            _sessionData = response.data['data'];
          });
        } else {
          throw Exception('Live session not found or has ended');
        }
      }

      // Generate viewer token
      final tokenResponse = await _apiService.generateViewerToken(
        channelName: widget.channelName,
      );

      if (tokenResponse.statusCode == 200 && tokenResponse.data['success'] == true) {
        _token = tokenResponse.data['data']['token'] ?? '';
        _uid = tokenResponse.data['data']['uid'] ?? 0;
      } else {
        throw Exception('Failed to generate viewer token');
      }

      // Update viewer count
      await _apiService.updateViewerCount(
        channelName: widget.channelName,
        increment: true,
      );

      await _initializeAgoraEngine();
      await _joinChannel();
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to join live stream: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _initializeAgoraEngine() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: AppConfig.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!mounted) return;
          setState(() {
            _joined = true;
            _loading = false;
            _errorMessage = null;
          });
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          if (!mounted) return;
          setState(() {
            _joined = false;
          });
        },
        onError: (ErrorCodeType error, String message) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Agora error ${error.value()}: $message';
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!mounted) return;
          // Broadcaster joined - store their UID
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          if (!mounted) return;
          // Broadcaster left
          setState(() {
            _remoteUid = null;
            _errorMessage = 'The broadcaster has ended the live stream';
          });
        },
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          if (!mounted) return;
          // Handle remote video state changes
        },
      ),
    );

    setState(() {
      _engineInitialized = true;
    });
  }

  Future<void> _joinChannel() async {
    try {
      await _engine.joinChannel(
        token: _token ?? '',
        channelId: widget.channelName,
        uid: _uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to join channel: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _leaveChannel() async {
    // Update viewer count
    if (_joined && widget.channelName.isNotEmpty) {
      try {
        await _apiService.updateViewerCount(
          channelName: widget.channelName,
          increment: false,
        );
      } catch (e) {
        // Ignore errors when leaving
      }
    }

    try {
      if (_engineInitialized) {
        await _engine.leaveChannel();
        await _engine.release();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  void _handleBack() {
    _leaveChannel();
    if (mounted) {
      context.pop();
    }
  }

  String _getBroadcasterName() {
    if (_sessionData?['user'] != null) {
      final user = _sessionData!['user'] as Map<String, dynamic>;
      return user['name'] ?? user['username'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  String? _getBroadcasterAvatar() {
    if (_sessionData?['user'] != null) {
      final user = _sessionData!['user'] as Map<String, dynamic>;
      return user['avatar'];
    }
    return null;
  }

  int _getViewerCount() {
    return _sessionData?['viewer_count'] ?? 0;
  }

  String? _getTitle() {
    return _sessionData?['title'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBack,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleBack,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading || !_engineInitialized || !_joined) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }

    return Stack(
      children: [
        // Remote video view
        if (_remoteUid != null)
          Positioned.fill(
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid!),
                connection: RtcConnection(channelId: widget.channelName),
              ),
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
                SizedBox(height: 16),
                Text(
                  'Waiting for broadcaster...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        // Overlay with broadcaster info
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Broadcaster info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _getBroadcasterAvatar() != null
                          ? NetworkImage(_getBroadcasterAvatar()!)
                          : null,
                      child: _getBroadcasterAvatar() == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getBroadcasterName(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_getTitle() != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getTitle()!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Viewer count
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_getViewerCount()} watching',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

