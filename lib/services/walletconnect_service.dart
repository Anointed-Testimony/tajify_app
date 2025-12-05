import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wallet_connect_v2/wallet_connect_v2.dart';

class WalletConnectService {
  WalletConnectService._();
  static final WalletConnectService instance = WalletConnectService._();

  final WalletConnectV2 _client = WalletConnectV2();

  bool _initialized = false;
  bool _relayConnected = false;

  Session? _activeSession;
  String? _sessionTopic;
  String? _connectedAddress;

  Completer<String?>? _connectionCompleter;
  Completer<String>? _pendingTxCompleter;
  Completer<void>? _relayCompleter;

  _InitConfig? _config;

  bool get isConnected =>
      _sessionTopic != null &&
      _activeSession != null &&
      (_activeSession?.namespaces['eip155']?.accounts.isNotEmpty ?? false);

  String? get connectedAddress => _connectedAddress;

  Future<void> initialize({
    required String projectId,
    required String appName,
    required String appUrl,
    required String appIcon,
    String? redirectScheme,
  }) async {
    _config = _InitConfig(
      projectId: projectId,
      appName: appName,
      appUrl: appUrl,
      appIcon: appIcon,
      redirectScheme: redirectScheme,
    );
    if (_initialized) return;
    await _performInit(_config!);
  }

  Future<void> _performInit(_InitConfig config) async {
    if (_initialized) return;

    final metadata = AppMetadata(
      name: config.appName,
      description: '${config.appName} WalletConnect client',
      url: config.appUrl,
      icons: [config.appIcon],
      redirect: config.redirectScheme,
    );

    _client.onConnectionStatus = (status) {
      _relayConnected = status;
      if (status) {
        _relayCompleter?.complete();
      }
    };

    _client.onSessionSettle = _handleSessionSettle;
    _client.onSessionDelete = (_) => _clearSession();
    _client.onSessionRejection = (_) =>
        _completeConnectionWithError('Wallet rejected the connection');
    _client.onSessionResponse = _handleSessionResponse;
    _client.onEventError = (code, message) {
      debugPrint('❌ [WalletConnect] $code - $message');
      if (code == 'init_core_error' ||
          code == 'connect_error' ||
          code == 'create_pair_error') {
        _relayConnected = false;
        _relayCompleter = null;
      }
      if (code == 'create_pair_error') {
        final friendly = message.isNotEmpty
            ? message
            : 'Unable to start WalletConnect session. Check your connection.';
        _completeConnectionWithError(friendly);
      }
    };

    try {
      await _client.init(
        projectId: config.projectId,
        appMetadata: metadata,
      );
      await _connectRelay();
      _initialized = true;
    } catch (e) {
      throw Exception(_mapNetworkError(e));
    }
  }

  Future<void> _connectRelay() async {
    if (_relayConnected) return;
    _relayCompleter = Completer<void>();
    try {
      await _client.connect();
    } catch (e) {
      _relayCompleter = null;
      throw Exception(_mapNetworkError(e));
    }

    await _relayCompleter!.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw Exception(
          'Unable to reach WalletConnect relay. Please check your internet connection.',
        );
      },
    );
    _relayCompleter = null;
  }

  Future<String?> connectWallet(BuildContext context,
      {int chainId = 56}) async {
    await _ensureInitialized();

    if (isConnected) {
      return _connectedAddress;
    }

    if (_connectionCompleter != null &&
        !(_connectionCompleter?.isCompleted ?? true)) {
      return _connectionCompleter!.future;
    }

    _connectionCompleter = Completer<String?>();

    final namespaces = {
      'eip155': ProposalNamespace(
        chains: ['eip155:$chainId'],
        methods: [
          'eth_sendTransaction',
          'eth_signTransaction',
          'personal_sign',
          'eth_signTypedData'
        ],
        events: ['chainChanged', 'accountsChanged'],
      ),
    };

    try {
      await _connectRelay();
      final uri = await _client.createPair(namespaces: namespaces);
      if (uri == null) {
        throw Exception('Unable to create WalletConnect session.');
      }
      await _showPairSheet(context, uri);
      final result = await _connectionCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () =>
            throw Exception('Wallet connection timed out, please try again.'),
      );
      _connectionCompleter = null;
      return result;
    } catch (e) {
      _completeConnectionWithError(_mapNetworkError(e));
      rethrow;
    }
  }

  Future<String> signAndSendTransaction({
    required String rpcUrl,
    required String to,
    required String from,
    required BigInt value,
    required String data,
    required int chainId,
    required BigInt gasPrice,
    required BigInt gasLimit,
    required int nonce,
  }) async {
    await _ensureInitialized();

    if (!isConnected || _sessionTopic == null) {
      throw Exception('Wallet not connected');
    }

    if (_pendingTxCompleter != null &&
        !(_pendingTxCompleter?.isCompleted ?? true)) {
      throw Exception('Another transaction is awaiting confirmation');
    }

    final txParams = {
      'from': from,
      'to': to,
      'value': _toHex(value),
      'data': data,
      'gas': _toHex(gasLimit),
      'gasPrice': _toHex(gasPrice),
      'nonce': _toHex(BigInt.from(nonce)),
    };

    _pendingTxCompleter = Completer<String>();

    try {
      await _client.sendRequest(
        request: Request(
          method: 'eth_sendTransaction',
          chainId: 'eip155:$chainId',
          topic: _sessionTopic!,
          params: [txParams],
        ),
      );
    } catch (e) {
      _pendingTxCompleter = null;
      throw Exception(_mapNetworkError(e));
    }

    return _pendingTxCompleter!.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pendingTxCompleter = null;
        throw Exception('Transaction approval timed out.');
      },
    );
  }

  Future<void> disconnect() async {
    if (_sessionTopic != null) {
      await _client.disconnectSession(topic: _sessionTopic!);
    }
    _clearSession();
  }

  void _handleSessionSettle(Session session) {
    _activeSession = session;
    _sessionTopic = session.topic;

    final accounts = session.namespaces['eip155']?.accounts ?? [];
    if (accounts.isEmpty) return;

    final address = accounts.first.split(':').last;
    _connectedAddress = address;

    if (!(_connectionCompleter?.isCompleted ?? true)) {
      _connectionCompleter?.complete(address);
    }
  }

  void _clearSession() {
    _activeSession = null;
    _sessionTopic = null;
    _connectedAddress = null;
  }

  void _completeConnectionWithError(String message) {
    if (!(_connectionCompleter?.isCompleted ?? true)) {
      _connectionCompleter?.completeError(Exception(message));
    }
    _connectionCompleter = null;
  }

  Future<void> _showPairSheet(BuildContext context, String uri) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open your WalletConnect compatible wallet and scan or open the link below.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  uri,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: uri));
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('WalletConnect URI copied')),
                        );
                      },
                      child: const Text('Copy Link'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final launched = await launchUrl(
                          Uri.parse(uri),
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched && sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Unable to open wallet application. Please open it manually.'),
                            ),
                          );
                        }
                      },
                      child: const Text('Open Wallet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Keep this sheet open until your wallet confirms the request.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSessionResponse(SessionResponse response) {
    if (_pendingTxCompleter == null ||
        (_pendingTxCompleter?.isCompleted ?? true)) {
      return;
    }

    try {
      final decoded = jsonDecode(response.results);
      if (decoded is String) {
        _pendingTxCompleter?.complete(decoded);
      } else if (decoded is Map) {
        final message = decoded['message'] ?? 'Transaction rejected';
        _pendingTxCompleter?.completeError(Exception(message.toString()));
      } else {
        _pendingTxCompleter?.completeError(Exception('Unknown wallet response'));
      }
    } catch (_) {
      _pendingTxCompleter
          ?.completeError(Exception('Failed to parse wallet response'));
    } finally {
      _pendingTxCompleter = null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final config = _config;
    if (config == null) {
      throw Exception('WalletConnect has not been configured');
    }
    await _performInit(config);
  }

  String _mapNetworkError(Object error) {
    final message = error.toString();
    if (message.contains('UnknownHostException') ||
        message.contains('Unable to resolve host')) {
      return 'Unable to reach WalletConnect relay. Please check your internet connection or VPN.';
    }
    if (error is PlatformException &&
        (error.code == 'init_core_error' ||
            error.code == 'connect_error' ||
            error.code == 'create_pair_error')) {
      return error.message ??
          'WalletConnect relay connection failed. Please check your connection.';
    }
    return message;
  }

  String _toHex(BigInt value) => '0x${value.toRadixString(16)}';
}

class _InitConfig {
  final String projectId;
  final String appName;
  final String appUrl;
  final String appIcon;
  final String? redirectScheme;

  const _InitConfig({
    required this.projectId,
    required this.appName,
    required this.appUrl,
    required this.appIcon,
    this.redirectScheme,
  });
}

