import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final ApiService _apiService = ApiService();
  late final RtcEngine _engine;

  bool _engineInitialized = false;
  bool _joined = false;
  bool _ending = false;
  String? _channelName;
  String? _token;
  int _uid = 0;
  String? _errorMessage;
  bool _showDebug = false;
  final List<String> _debugLogs = [];
  bool _isInitializing = false;
  DateTime? _lastNetworkQualityLog;

  @override
  void initState() {
    super.initState();
    _startLiveFlow();
  }

  @override
  void dispose() {
    _leaveChannel();
    super.dispose();
  }

  void _addDebugLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _debugLogs.add('[$timestamp] $message');
      if (_debugLogs.length > 50) {
        _debugLogs.removeAt(0);
      }
    });
    print('🔴 [Live Debug] $message');
  }

  Future<void> _startLiveFlow() async {
    if (_isInitializing) {
      _addDebugLog('Already initializing, skipping duplicate call');
      return;
    }
    
    _isInitializing = true;
    _addDebugLog('Starting live flow...');
    _addDebugLog('App ID: ${AppConfig.agoraAppId}');
    
    if (AppConfig.agoraAppId.isEmpty) {
      setState(() {
        _errorMessage =
            'AGORA_APP_ID is not configured. Run the app with --dart-define=AGORA_APP_ID=YOUR_APP_ID.';
      });
      _addDebugLog('ERROR: App ID is empty');
      _isInitializing = false;
      return;
    }

    _addDebugLog('Requesting permissions...');
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      setState(() {
        _errorMessage =
            'Camera and microphone permissions are required to start a live session.';
      });
      _addDebugLog('ERROR: Permissions not granted');
      return;
    }
    _addDebugLog('Permissions granted');

    try {
      _addDebugLog('Fetching token from backend...');
      final tokenResponse = await _apiService.generateLiveToken();
      _addDebugLog('Token response status: ${tokenResponse.statusCode}');
      _addDebugLog('Token response data: ${tokenResponse.data}');
      
      final data = tokenResponse.data['data'] ?? tokenResponse.data;
      _channelName = data['channel']?.toString();
      _token = data['token']?.toString();
      _uid = data['uid'] is int ? data['uid'] : int.tryParse(data['uid']?.toString() ?? '0') ?? 0;

      _addDebugLog('Channel: $_channelName');
      if (_token != null && _token!.isNotEmpty) {
        _addDebugLog('Token: ${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}... (${_token!.length} chars)');
      } else {
        _addDebugLog('Token: (empty - Testing Mode)');
      }
      _addDebugLog('UID: $_uid');

      if (_channelName == null) {
        throw Exception('Missing channel from server response.');
      }
      // Token can be empty for Testing Mode

      await _initializeAgoraEngine();
      await _joinChannel();
    } catch (e, stackTrace) {
      _addDebugLog('ERROR: ${e.toString()}');
      _addDebugLog('Stack: ${stackTrace.toString()}');
      setState(() {
        _errorMessage = 'Unable to start live session: ${e.toString()}';
      });
    } finally {
      _isInitializing = false;
    }
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraGranted = statuses[Permission.camera] == PermissionStatus.granted;
    final micGranted = statuses[Permission.microphone] == PermissionStatus.granted;

    return cameraGranted && micGranted;
  }

  String _getErrorDescription(int errorCode) {
    switch (errorCode) {
      case 110:
      case -110:
        return 'ERR_INVALID_APP_ID - The App ID and certificate don\'t match.\n\n'
            '🔧 FIX THIS:\n'
            '1. Go to your backend .env file\n'
            '2. Verify AGORA_APP_ID=535e547ebc064b1daf086ed0984c449b\n'
            '3. Verify AGORA_APP_CERTIFICATE=0b414b8e1ddf4ac49814441efb8e91ef\n'
            '4. Make sure there are NO spaces or quotes around the values\n'
            '5. Run: php artisan config:clear && php artisan config:cache\n'
            '6. Verify in Agora Console that these credentials match your project';
      case 101:
        return 'ERR_ALREADY_IN_USE - The App ID is already in use.';
      case 2:
        return 'ERR_INVALID_ARGUMENT - Invalid argument passed to Agora SDK.';
      case 7:
        return 'ERR_NOT_INITIALIZED - Engine not initialized.';
      case 17:
      case -17:
        return 'ERR_JOIN_CHANNEL_REJECTED - Join channel rejected. This usually means:\n'
            '1. Token is invalid or expired\n'
            '2. Token doesn\'t have required privileges\n'
            '3. Token authentication is enabled in Agora console but token is wrong\n'
            '4. Try disabling token authentication in Agora console for testing';
      case 102:
        return 'ERR_INVALID_CHANNEL_NAME - Invalid channel name.';
      default:
        return 'Unknown error code: $errorCode. Check Agora documentation.';
    }
  }

  Future<void> _initializeAgoraEngine() async {
    _addDebugLog('Creating Agora engine...');
    _engine = createAgoraRtcEngine();
    
    _addDebugLog('Initializing engine with App ID: ${AppConfig.agoraAppId}');
    await _engine.initialize(
      RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    _addDebugLog('Engine initialized successfully');

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          if (!mounted) return;
          _addDebugLog('✅ Joined channel successfully (elapsed: ${elapsed}ms)');
          _addDebugLog('Channel: ${connection.channelId}, UID: ${connection.localUid}');
          
          // Register live session with backend
          if (_channelName != null) {
            try {
              await _apiService.startLiveSession(
                channelName: _channelName!,
                uid: _uid,
              );
              _addDebugLog('✅ Live session registered with backend');
            } catch (e) {
              _addDebugLog('⚠️ Failed to register session: $e');
              // Continue anyway - session might still work
            }
          }
          
          setState(() {
            _joined = true;
            _errorMessage = null; // Clear any previous errors
          });
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          if (!mounted) return;
          _addDebugLog('Left channel');
          _addDebugLog('Stats: duration=${stats.duration}ms, txBytes=${stats.txBytes}, rxBytes=${stats.rxBytes}');
          setState(() {
            _joined = false;
          });
        },
        onError: (ErrorCodeType error, String message) {
          if (!mounted) return;
          final errorCode = error.value();
          final errorDesc = _getErrorDescription(errorCode);
          _addDebugLog('❌ Agora Error $errorCode: $message');
          _addDebugLog('Error description: $errorDesc');
          
          // Handle critical errors that should stop the stream
          final criticalErrors = [110, -110, 101, -101, 2, -2, 7, -7];
          if (criticalErrors.contains(errorCode)) {
            setState(() {
              _errorMessage = 'Agora error $errorCode: $message\n\n$errorDesc';
              _joined = false;
            });
          } else if (errorCode != -17 && errorCode != 17) {
            // For non-critical errors, log but don't stop
            setState(() {
              _errorMessage = 'Agora error $errorCode: $message\n\n$errorDesc';
            });
          }
          // -17 errors are handled by retry logic, don't set error message immediately
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          _addDebugLog('Connection state: $state (reason: $reason)');
          
          if (!mounted) return;
          
          // Handle specific reasons based on Agora documentation
          String? reasonMessage;
          switch (reason) {
            case ConnectionChangedReasonType.connectionChangedConnecting:
              reasonMessage = 'Connecting to Agora server...';
              break;
            case ConnectionChangedReasonType.connectionChangedJoinSuccess:
              reasonMessage = '✅ Successfully joined channel';
              setState(() {
                _joined = true;
                _errorMessage = null;
              });
              break;
            case ConnectionChangedReasonType.connectionChangedInterrupted:
              reasonMessage = '⚠️ Connection interrupted';
              break;
            case ConnectionChangedReasonType.connectionChangedBannedByServer:
              reasonMessage = '❌ Banned by server (kicked out)';
              setState(() {
                _joined = false;
                _errorMessage = 'You were banned from the channel. Please try again later.';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedJoinFailed:
              reasonMessage = '❌ Failed to join channel (after 20 minutes)';
              setState(() {
                _joined = false;
                _errorMessage = 'Failed to join channel. Please switch network and try again.';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedLeaveChannel:
              reasonMessage = 'Left channel';
              setState(() {
                _joined = false;
              });
              break;
            case ConnectionChangedReasonType.connectionChangedInvalidAppId:
              reasonMessage = '❌ Invalid App ID';
              setState(() {
                _joined = false;
                _errorMessage = 'Invalid App ID. Check Agora Console:\n'
                    '1. Verify App ID: 535e547ebc064b1daf086ed0984c449b\n'
                    '2. Ensure project is Active\n'
                    '3. Check for any restrictions';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedInvalidChannelName:
              reasonMessage = '❌ Invalid channel name';
              setState(() {
                _joined = false;
                _errorMessage = 'Invalid channel name. Channel name must be:\n'
                    '• Max 64 characters\n'
                    '• Only: a-z, A-Z, 0-9, and special chars: !#\$%&()+.-:;<=>?@[]^_{|}~';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedInvalidToken:
              reasonMessage = '❌ Invalid token';
              setState(() {
                _joined = false;
                _errorMessage = '❌ Invalid Token - Connection Rejected\n\n'
                    'This means your App ID and Certificate don\'t match Agora Console.\n\n'
                    '🔧 VERIFY IN AGORA CONSOLE:\n'
                    '1. Go to https://console.agora.io/\n'
                    '2. Select your project\n'
                    '3. Go to Project Management → Edit\n'
                    '4. Check these EXACT values:\n'
                    '   • App ID: 535e547ebc064b1daf086ed0984c449b\n'
                    '   • Primary Certificate: 0b414b8e1ddf4ac49814441efb8e91ef\n\n'
                    '⚠️ If they DON\'T match:\n'
                    '   • Update backend code with correct values from Console\n'
                    '   • OR generate new certificate in Console and update backend\n\n'
                    '✅ If they DO match:\n'
                    '   • Check if project is Active (not suspended)\n'
                    '   • Verify no restrictions are enabled\n'
                    '   • Try creating a new test project';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedTokenExpired:
              reasonMessage = '⚠️ Token expired';
              _addDebugLog('Token expired, refreshing...');
              _refreshToken();
              break;
            case ConnectionChangedReasonType.connectionChangedRejectedByServer:
              reasonMessage = '❌ Rejected by server';
              setState(() {
                _joined = false;
                _errorMessage = 'Connection rejected by server. Possible causes:\n'
                    '1. Already in channel (stop calling joinChannel repeatedly)\n'
                    '2. Test call in progress\n'
                    '3. Server-side restrictions';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedSettingProxyServer:
              reasonMessage = 'Setting proxy server...';
              break;
            case ConnectionChangedReasonType.connectionChangedRenewToken:
              reasonMessage = 'Token renewed';
              break;
            case ConnectionChangedReasonType.connectionChangedClientIpAddressChanged:
              reasonMessage = '⚠️ Client IP changed';
              break;
            case ConnectionChangedReasonType.connectionChangedKeepAliveTimeout:
              reasonMessage = '⚠️ Keep-alive timeout, reconnecting...';
              break;
            case ConnectionChangedReasonType.connectionChangedRejoinSuccess:
              reasonMessage = '✅ Rejoined channel successfully';
              setState(() {
                _joined = true;
                _errorMessage = null;
              });
              break;
            case ConnectionChangedReasonType.connectionChangedLost:
              reasonMessage = '⚠️ Connection lost';
              break;
            case ConnectionChangedReasonType.connectionChangedEchoTest:
              reasonMessage = 'Echo test in progress';
              break;
            case ConnectionChangedReasonType.connectionChangedClientIpAddressChangedByUser:
              reasonMessage = 'IP address changed by user';
              break;
            case ConnectionChangedReasonType.connectionChangedSameUidLogin:
              reasonMessage = '⚠️ Same UID logged in from different device';
              setState(() {
                _joined = false;
                _errorMessage = 'Same UID is already in channel from another device.';
              });
              break;
            case ConnectionChangedReasonType.connectionChangedTooManyBroadcasters:
              reasonMessage = '❌ Too many broadcasters';
              setState(() {
                _joined = false;
                _errorMessage = 'Channel has reached maximum number of broadcasters.';
              });
              break;
            default:
              reasonMessage = 'Connection state changed: $reason';
          }
          
          _addDebugLog(reasonMessage);
          
          // Handle connection states
          switch (state) {
            case ConnectionStateType.connectionStateDisconnected:
              _addDebugLog('🔴 Disconnected');
              if (reason != ConnectionChangedReasonType.connectionChangedLeaveChannel) {
                setState(() {
                  _joined = false;
                });
              }
              break;
              
            case ConnectionStateType.connectionStateConnecting:
              _addDebugLog('🔄 Connecting...');
              // Clear errors when attempting to reconnect
              if (_errorMessage != null && _errorMessage!.contains('Connection failed')) {
                setState(() {
                  _errorMessage = null;
                });
              }
              break;
              
            case ConnectionStateType.connectionStateConnected:
              _addDebugLog('✅ Connection established');
              // If we're connected but not marked as joined, mark as joined
              if (!_joined && reason == ConnectionChangedReasonType.connectionChangedJoinSuccess) {
                _addDebugLog('Marking as joined based on connection state');
                setState(() {
                  _joined = true;
                  _errorMessage = null;
                });
              }
              break;
              
            case ConnectionStateType.connectionStateReconnecting:
              _addDebugLog('🔄 Reconnecting...');
              break;
              
            case ConnectionStateType.connectionStateFailed:
              _addDebugLog('⚠️ Connection failed');
              // Error message already set above based on reason
              if (_errorMessage == null) {
                setState(() {
                  _joined = false;
                  _errorMessage = 'Connection failed. Reason: $reason';
                });
              }
              break;
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          _addDebugLog('⚠️ Token will expire soon, refreshing...');
          // Refresh token when it's about to expire
          _refreshToken();
        },
        onLocalAudioStateChanged: (RtcConnection connection, LocalAudioStreamState state, LocalAudioStreamReason reason) {
          _addDebugLog('Local audio state: $state (reason: $reason)');
          if (state == LocalAudioStreamState.localAudioStreamStateFailed) {
            _addDebugLog('❌ Local audio stream failed: $reason');
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Local audio stream failed: $reason';
            });
          } else if (state == LocalAudioStreamState.localAudioStreamStateRecording) {
            _addDebugLog('🎤 Local audio recording started');
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _addDebugLog('👤 User joined: UID $remoteUid (elapsed: ${elapsed}ms)');
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _addDebugLog('👤 User offline: UID $remoteUid (reason: $reason)');
        },
        onNetworkQuality: (RtcConnection connection, int remoteUid, QualityType txQuality, QualityType rxQuality) {
          // Log network quality periodically (every 5 seconds max)
          if (remoteUid == 0) {
            final now = DateTime.now();
            if (_lastNetworkQualityLog == null || 
                now.difference(_lastNetworkQualityLog!).inSeconds >= 5) {
              _lastNetworkQualityLog = now;
              _addDebugLog('📊 Network quality - TX: $txQuality, RX: $rxQuality');
            }
          }
        },
      ),
    );

    _addDebugLog('Enabling video...');
    await _engine.enableVideo();
    _addDebugLog('Setting client role to broadcaster...');
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    _addDebugLog('Starting preview...');
    await _engine.startPreview();
    _addDebugLog('Preview started');

    setState(() {
      _engineInitialized = true;
    });
  }

  Future<void> _joinChannel() async {
    _addDebugLog('Joining channel: $_channelName');
    _addDebugLog('Using UID: $_uid');
    _addDebugLog('Token length: ${_token?.length ?? 0}');
    
    // Validate channel name (Agora allows: a-z, A-Z, 0-9, !, #, $, %, &, (, ), +, -, :, ;, <, =, ., >, ?, @, [, ], ^, _, {, }, |, ~, space)
    if (_channelName != null) {
      final validChannelPattern = RegExp(r'^[a-zA-Z0-9!#$%&()+.\-:;<=>?@\[\]^_{|}~ ]+$');
      if (!validChannelPattern.hasMatch(_channelName!)) {
        _addDebugLog('⚠️ WARNING: Channel name contains invalid characters');
      }
      if (_channelName!.length > 64) {
        _addDebugLog('⚠️ WARNING: Channel name exceeds 64 characters');
      }
    }
    
    // Add a small delay to ensure engine is fully ready
    await Future.delayed(const Duration(milliseconds: 500));
    _addDebugLog('Delay completed, attempting join...');
    
    String? lastError;
    
    // For Testing Mode (empty token), try empty token first
    // For Secure Mode (has token), try with token first
    final isTestingMode = _token == null || _token!.isEmpty;
    
    if (isTestingMode) {
      _addDebugLog('🔧 Testing Mode detected (no token required)');
    } else {
      _addDebugLog('🔒 Secure Mode detected (using token)');
    }
    
    // Try joining
    try {
      _addDebugLog('Attempt 1: Joining channel...');
      if (!isTestingMode && _token != null && _token!.isNotEmpty) {
        final previewLength = _token!.length > 50 ? 50 : _token!.length;
        _addDebugLog('Token preview: ${_token!.substring(0, previewLength)}...');
      }
      _addDebugLog('Channel: $_channelName, UID: $_uid');
      
      await _engine.joinChannel(
        token: _token ?? '',
        channelId: _channelName!,
        uid: _uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _addDebugLog('Join channel request sent');
      _addDebugLog('Waiting for connection to establish...');
      
      // Wait a bit to see if connection succeeds
      await Future.delayed(const Duration(seconds: 5));
      
      // Check if we're connected
      if (_joined) {
        _addDebugLog('✅ Successfully joined channel');
        return;
      } else {
        _addDebugLog('⚠️ Still not joined after 5 seconds');
        // Check connection state
        final connectionState = await _engine.getConnectionState();
        _addDebugLog('Current connection state: $connectionState');
        // Don't throw error yet, let connection state callback handle it
        return;
      }
    } catch (e, stackTrace) {
      lastError = e.toString();
      _addDebugLog('ERROR joining channel with token: $e');
      _addDebugLog('Stack trace: ${stackTrace.toString().substring(0, 200)}');
      
      // If it's error -17, it might be a token or App ID issue
      if (e.toString().contains('-17')) {
        _addDebugLog('⚠️ Error -17: This usually means:');
        _addDebugLog('1. Token is invalid or expired');
        _addDebugLog('2. App ID is invalid or not activated in Agora Console');
        _addDebugLog('3. Token authentication is required but token format is wrong');
        _addDebugLog('4. Check Agora Console -> Your Project -> Check if App ID is active');
      }
    }
    
    // Try with empty token
    try {
      _addDebugLog('Attempt 2: Joining with empty token...');
      await _engine.joinChannel(
        token: '',
        channelId: _channelName!,
        uid: _uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _addDebugLog('✅ Successfully joined with empty token');
      return;
    } catch (e2) {
      lastError = e2.toString();
      _addDebugLog('ERROR joining with empty token: $e2');
    }
    
    // Try with UID 0 (Agora auto-assigns)
    try {
      _addDebugLog('Attempt 3: Joining with UID 0 (auto-assign)...');
      await _engine.joinChannel(
        token: '',
        channelId: _channelName!,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _addDebugLog('✅ Successfully joined with UID 0');
      setState(() {
        _uid = 0;
      });
      return;
    } catch (e3) {
      lastError = e3.toString();
      _addDebugLog('ERROR joining with UID 0: $e3');
    }
    
    // Try with simplified channel name
    try {
      final simpleChannel = 'test_channel_${DateTime.now().millisecondsSinceEpoch}';
      _addDebugLog('Attempt 4: Joining with simplified channel: $simpleChannel');
      await _engine.joinChannel(
        token: '',
        channelId: simpleChannel,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      _addDebugLog('✅ Successfully joined with simplified channel');
      setState(() {
        _channelName = simpleChannel;
        _uid = 0;
      });
      return;
    } catch (e4) {
      lastError = e4.toString();
      _addDebugLog('ERROR joining with simplified channel: $e4');
    }
    
    throw Exception('All join attempts failed. Last error: $lastError. Check Agora console settings and network connection.');
  }

  Future<void> _refreshToken() async {
    try {
      _addDebugLog('Refreshing token...');
      final tokenResponse = await _apiService.generateLiveToken(
        channelName: _channelName,
      );
      final data = tokenResponse.data['data'] ?? tokenResponse.data;
      final newToken = data['token']?.toString();
      
      if (newToken != null && _engineInitialized) {
        _token = newToken;
        await _engine.renewToken(newToken);
        _addDebugLog('✅ Token refreshed successfully');
      } else {
        _addDebugLog('⚠️ Failed to refresh token');
      }
    } catch (e) {
      _addDebugLog('❌ Error refreshing token: $e');
    }
  }

  Future<void> _leaveChannel() async {
    try {
      if (_engineInitialized) {
        _addDebugLog('Leaving channel...');
        await _engine.leaveChannel();
        await _engine.stopPreview();
        await _engine.release();
        _addDebugLog('Channel left and engine released');
      }
    } catch (e) {
      _addDebugLog('Error during cleanup: $e');
      // Ignore cleanup errors.
    }
  }

  Future<void> _endLiveSession() async {
    setState(() {
      _ending = true;
    });
    
    // End session on backend
    if (_channelName != null) {
      try {
        await _apiService.endLiveSession(channelName: _channelName!);
        _addDebugLog('✅ Live session ended on backend');
      } catch (e) {
        _addDebugLog('⚠️ Failed to end session on backend: $e');
        // Continue anyway
      }
    }
    
    await _leaveChannel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _endLiveSession,
        ),
        actions: [
          if (_joined)
            TextButton(
              onPressed: _ending ? null : _endLiveSession,
              child: const Text(
                'End',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: (!_joined || _ending)
          ? null
          : FloatingActionButton.extended(
              onPressed: _endLiveSession,
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.stop),
              label: const Text('End Live'),
            ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Stack(
        children: [
          Center(
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          if (_showDebug) _buildDebugPanel(),
        ],
      );
    }

    if (!_engineInitialized || !_joined) {
      return Stack(
        children: [
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          if (_showDebug) _buildDebugPanel(),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
        if (_showDebug) _buildDebugPanel(),
      ],
    );
  }

  Widget _buildDebugPanel() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🔴 Live Debug',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showDebug = false;
                    });
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDebugSection('App Configuration', [
                      'App ID: ${AppConfig.agoraAppId}',
                      'App ID Length: ${AppConfig.agoraAppId.length}',
                    ]),
                    _buildDebugSection('Session Info', [
                      'Channel: ${_channelName ?? "N/A"}',
                      'UID: $_uid',
                      'Token: ${_token != null ? "${_token!.substring(0, 30)}... (${_token!.length} chars)" : "N/A"}',
                    ]),
                    _buildDebugSection('Status', [
                      'Engine Initialized: $_engineInitialized',
                      'Joined: $_joined',
                      'Ending: $_ending',
                    ]),
                    if (_errorMessage != null)
                      _buildDebugSection('Error', [
                        _errorMessage!,
                      ]),
                    _buildDebugSection('Debug Logs', _debugLogs.isEmpty ? ['No logs yet'] : _debugLogs),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Clear Logs'),
                  onPressed: () {
                    setState(() {
                      _debugLogs.clear();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

