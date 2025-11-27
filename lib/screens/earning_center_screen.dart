import 'dart:async';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'paystack_screen.dart';

import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajify_top_bar.dart';

class EarningCenterScreen extends StatefulWidget {
  const EarningCenterScreen({Key? key}) : super(key: key);

  @override
  State<EarningCenterScreen> createState() => _EarningCenterScreenState();
}

class _EarningCenterScreenState extends State<EarningCenterScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final dio.Dio _publicDio = dio.Dio(
    dio.BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  late final AnimationController _heroController;
  late final Animation<double> _heroFade;
  
  // Notification state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  
  // Messages state
  int _messagesUnreadCount = 0;
  StreamSubscription? _messagesCountSubscription;
  
  // User info
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  Map<String, dynamic>? _currentUserProfile;

  // Earn data
  Map<String, dynamic>? _walletPayload;
  Map<String, dynamic>? _earningCenter;
  List<dynamic> _recentEarnings = [];
  List<dynamic> _earningHistory = [];
  List<dynamic> _banks = [];

  bool _loadingDashboard = true;
  bool _loadingHistory = true;
  bool _refreshing = false;
  String? _dashboardError;

  String _activeTab = 'methods';
  String _historyFilter = 'all';

  double? _tajiPriceUsd;
  double? _usdToNgn;
  double? _bnbPriceUsd;

  // Wallet connection
  String? _walletAddress;
  double? _walletTajiBalance;
  bool _loadingWalletBalance = false;
  
  // Crypto payment state
  String _cryptoType = 'bnb';
  String _network = 'bsc';

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeInOut);

    _loadInitialData();
    _loadNotificationUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNotificationUnreadCount());
    _initializeFirebaseAndLoadMessagesCount();
    _loadUserProfile();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingDashboard = true;
      _loadingHistory = true;
      if (!_refreshing) {
        _dashboardError = null;
      }
    });

    try {
      await Future.wait([
        _fetchWallet(),
        _fetchEarningCenter(),
        _fetchRecentEarnings(),
        _fetchHistory(filter: _historyFilter),
        _fetchExchangeRates(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _dashboardError = e.toString();
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingDashboard = false;
        _loadingHistory = false;
      });
      // Only animate if controller is still valid and mounted
      if (mounted && _heroController.isAnimating == false) {
        try {
          _heroController.forward(from: 0);
        } catch (e) {
          // Ignore hero animation errors
          print('Hero animation error (ignored): $e');
        }
      }
    }
  }

  Future<void> _fetchWallet() async {
    print('[WALLET DEBUG] Starting _fetchWallet()');
    try {
      final response = await _apiService.getWallet();
      print('[WALLET DEBUG] Wallet API response status: ${response.statusCode}');
      print('[WALLET DEBUG] Wallet API response data: ${response.data}');
      
      final payload = response.data['data'] ?? response.data;
      final walletData = payload is Map<String, dynamic> ? payload : null;
      print('[WALLET DEBUG] Extracted walletData: $walletData');

      if (mounted) {
        setState(() {
          _walletPayload = walletData;
          // Check if wallet address is connected
          final wallet = walletData?['wallet'];
          print('[WALLET DEBUG] Wallet object: $wallet');
          
          final address = wallet?['wallet_address']?.toString();
          print('[WALLET DEBUG] Extracted wallet_address: $address');
          print('[WALLET DEBUG] Address is null: ${address == null}');
          print('[WALLET DEBUG] Address is empty: ${address?.isEmpty ?? true}');
          
          if (address != null && address.isNotEmpty) {
            print('[WALLET DEBUG] ✅ Wallet address found: $address');
            _walletAddress = address;
            _fetchWalletTajiBalance();
          } else {
            print('[WALLET DEBUG] ❌ No wallet address connected');
            _walletAddress = null;
            _walletTajiBalance = null;
          }
        });
      }
    } catch (e) {
      print('[WALLET DEBUG] ❌ Error in _fetchWallet(): $e');
      print('[WALLET DEBUG] Error stack: ${e.toString()}');
      if (mounted && _dashboardError == null) {
        setState(() {
          _dashboardError = e.toString();
        });
      }
    }
  }

  Future<void> _fetchWalletTajiBalance() async {
    print('[WALLET DEBUG] Starting _fetchWalletTajiBalance()');
    print('[WALLET DEBUG] Current _walletAddress: $_walletAddress');
    
    if (_walletAddress == null || _walletAddress!.isEmpty) {
      print('[WALLET DEBUG] ❌ Cannot fetch balance: wallet address is null or empty');
      return;
    }
    
    print('[WALLET DEBUG] Fetching TAJI balance for address: $_walletAddress');
    setState(() {
      _loadingWalletBalance = true;
    });

    try {
      print('[WALLET DEBUG] Calling getTajiBalanceFromWallet API...');
      print('[WALLET DEBUG] Using external BSC RPC endpoint to query blockchain directly');
      print('[WALLET DEBUG] TAJI Token Contract: 0xF1b6059dbC8B44Ca90C5D2bE77e0cBea3b1965fe');
      print('[WALLET DEBUG] Wallet Address: $_walletAddress');
      final response = await _apiService.getTajiBalanceFromWallet(_walletAddress!);
      print('[WALLET DEBUG] Balance API response status: ${response.statusCode}');
      print('[WALLET DEBUG] Balance API response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final balance = response.data['data']?['balance'];
        print('[WALLET DEBUG] Extracted balance from response: $balance');
        print('[WALLET DEBUG] Balance type: ${balance.runtimeType}');
        
        final parsedBalance = balance != null 
            ? (balance is num ? balance.toDouble() : double.tryParse(balance.toString()) ?? 0.0)
            : 0.0;
        print('[WALLET DEBUG] Parsed balance: $parsedBalance');
        
        if (mounted) {
          setState(() {
            _walletTajiBalance = parsedBalance;
          });
          print('[WALLET DEBUG] ✅ Successfully set _walletTajiBalance to: $_walletTajiBalance');
        }
      } else {
        print('[WALLET DEBUG] ❌ API response indicates failure');
        print('[WALLET DEBUG] Response success: ${response.data['success']}');
        print('[WALLET DEBUG] Response message: ${response.data['message']}');
      }
    } catch (e) {
      print('[WALLET DEBUG] ❌ Error fetching wallet TAJI balance: $e');
      print('[WALLET DEBUG] Error type: ${e.runtimeType}');
      print('[WALLET DEBUG] Error details: ${e.toString()}');
      if (e is dio.DioException) {
        print('[WALLET DEBUG] DioException type: ${e.type}');
        print('[WALLET DEBUG] DioException message: ${e.message}');
        print('[WALLET DEBUG] DioException response: ${e.response?.data}');
      }
      if (mounted) {
        setState(() {
          _walletTajiBalance = 0;
        });
        print('[WALLET DEBUG] Set _walletTajiBalance to 0 due to error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingWalletBalance = false;
        });
        print('[WALLET DEBUG] Set _loadingWalletBalance to false');
      }
    }
  }

  Future<void> _fetchEarningCenter() async {
    try {
      final response = await _apiService.getEarningCenter();
      final data = response.data['data'] ?? response.data;
      if (mounted) {
        setState(() {
          _earningCenter = data is Map<String, dynamic> ? data : null;
        });
      }
    } catch (e) {
      if (mounted && _dashboardError == null) {
        setState(() {
          _dashboardError = e.toString();
        });
      }
    }
  }

  Future<void> _fetchRecentEarnings({int limit = 8}) async {
    try {
      final response = await _apiService.getRecentEarnings(limit: limit);
      final data = response.data['data'] ?? response.data;
      if (mounted) {
        setState(() {
          _recentEarnings = data is List ? data : [];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recentEarnings = [];
        });
      }
    }
  }

  Future<void> _fetchHistory({required String filter}) async {
    try {
      final response = await _apiService.getRecentEarnings(limit: 60);
      final payload = response.data['data'] ?? response.data;
      if (payload is List) {
        final filtered = _filterHistory(payload, filter);
        if (mounted) {
          setState(() {
            _earningHistory = filtered;
            _historyFilter = filter;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _earningHistory = [];
          _dashboardError ??= e.toString();
        });
      }
    }
  }

  List<dynamic> _filterHistory(List<dynamic> history, String filter) {
    if (filter == 'all') return history;
    final now = DateTime.now();
    return history.where((entry) {
      final createdAt = entry['created_at'];
      final date = createdAt != null ? DateTime.tryParse(createdAt.toString()) : null;
      if (date == null) return false;
      switch (filter) {
        case 'today':
          return date.year == now.year && date.month == now.month && date.day == now.day;
        case 'week':
          return date.isAfter(now.subtract(const Duration(days: 7)));
        case 'month':
          return date.year == now.year && date.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final response = await _apiService.getTajiPrice();
      final priceData = response.data['data'] ?? response.data;
      final price = _parseDouble(priceData?['price']);

      double? usdToNgn;
      final fxResponse = await _publicDio.get('https://open.er-api.com/v6/latest/USD');
      final fxBody = fxResponse.data;
      if (fxBody is Map && fxBody['result'] == 'success') {
        final rates = fxBody['rates'];
        if (rates is Map && rates['NGN'] != null) {
          usdToNgn = _parseDouble(rates['NGN']);
        }
      }

      // Fetch BNB price from CoinGecko
      double? bnbPrice;
      try {
        final bnbResponse = await _publicDio.get('https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd');
        final bnbData = bnbResponse.data;
        if (bnbData is Map && bnbData['binancecoin'] != null && bnbData['binancecoin']['usd'] != null) {
          bnbPrice = _parseDouble(bnbData['binancecoin']['usd']);
        }
      } catch (_) {
        // Fallback BNB price if fetch fails
        bnbPrice = 600.0;
      }

      if (mounted) {
        setState(() {
          _tajiPriceUsd = price;
          _usdToNgn = usdToNgn;
          _bnbPriceUsd = bnbPrice;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tajiPriceUsd ??= 0;
          _usdToNgn ??= 0;
          _bnbPriceUsd ??= 600.0; // Fallback BNB price
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profile = response.data['data'];
        if (mounted) {
          setState(() {
            _currentUserProfile = profile;
            final name = profile?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = profile?['profile_avatar']?.toString();
          });
        }
        return;
      }
    } catch (_) {
      // ignored
    }

    // fallback to storage
      try {
        final name = await _storageService.getUserName();
        final avatar = await _storageService.getUserProfilePicture();
        if (mounted) {
          setState(() {
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = avatar;
          });
        }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _initializeFirebaseAndLoadMessagesCount() async {
    try {
      await FirebaseService.initialize();
      await FirebaseService.initializeAuth();
      
        final response = await _apiService.get('/auth/me');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final userId = response.data['data']['id'] as int?;
        if (userId != null && FirebaseService.isInitialized) {
          _messagesCountSubscription?.cancel();
          _messagesCountSubscription = FirebaseService.getUnreadCountStream(userId).listen((count) {
                if (mounted) {
                  setState(() {
                    _messagesUnreadCount = count;
                  });
                }
              });
            }
          }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadNotificationUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count');
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _notificationUnreadCount = response.data['data']['count'] ?? 0;
          });
        }
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _heroController.dispose();
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    super.dispose();
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double get _tajstarsBalance {
    final wallet = _walletPayload?['wallet'] ?? _walletPayload;
    return _parseDouble(wallet?['coins'] ?? wallet?['tajstars_balance']);
  }

  double get _tajiBalance {
    final wallet = _walletPayload?['wallet'] ?? _walletPayload;
    return _parseDouble(wallet?['taji_balance']);
  }

  double get _usdtBalance {
    final wallet = _walletPayload?['wallet'] ?? _walletPayload;
    return _parseDouble(wallet?['usdt_balance']);
  }

  String _formatFiat(double amount, {String symbol = '₦'}) {
    if (amount >= 1000000) return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _formatToken(double amount, {String suffix = 'TAJSTARS'}) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M $suffix';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K $suffix';
    return '${amount.toStringAsFixed(2)} $suffix';
  }

  String _formatTajiBalance(double amount) {
    // Format with 2 decimal places and comma separators
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    
    // Add comma separators to integer part
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += ',';
      }
      formattedInteger += integerPart[i];
    }
    
    return '$formattedInteger.$decimalPart';
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadInitialData();
    if (mounted) {
      setState(() => _refreshing = false);
    }
  }

  void _openFundWalletSheet() {
    final amountController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (modalContext) {
        String currency = 'taji';
        String method = 'usdt_wallet'; // Default to USDT wallet for TAJI
        bool submitting = false;
        String amountText = '';

        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            // Calculate total with fee for TAJI
            // Returns total in USD, then we convert to the selected crypto (BNB or USDT)
            double? calculateTotalUsd() {
              if (currency != 'taji' || amountText.isEmpty) return null;
              final tajiAmount = double.tryParse(amountText);
              if (tajiAmount == null || tajiAmount <= 0) return null;
              final tajiPriceUsdt = _tajiPriceUsd ?? 0.000004173047451608; // Fallback price
              final requiredUsdt = tajiAmount * tajiPriceUsdt;
              final feeUsdt = requiredUsdt * 0.03; // 3% fee
              return requiredUsdt + feeUsdt;
            }

            // Calculate total with fee for USDT
            double? calculateUsdtTotal() {
              if (currency != 'usdt' || amountText.isEmpty) return null;
              final usdtAmount = double.tryParse(amountText);
              if (usdtAmount == null || usdtAmount <= 0) return null;
              final feeUsdt = usdtAmount * 0.03; // 3% fee
              return usdtAmount + feeUsdt; // Total = amount + fee
            }

            // Calculate total with fee for USDT Paystack (convert to Naira)
            Map<String, dynamic>? getUsdtPaystackBreakdown() {
              if (currency != 'usdt' || method != 'paystack' || amountText.isEmpty) return null;
              final usdtAmount = double.tryParse(amountText);
              if (usdtAmount == null || usdtAmount <= 0) return null;
              
              // Add 3% fee
              final feeUsdt = usdtAmount * 0.03;
              final totalUsdt = usdtAmount + feeUsdt;
              
              // Convert to Naira (using USD rate, fallback to 1500)
              final usdToNgnRate = 1500.0; // Fallback rate
              final totalNaira = totalUsdt * usdToNgnRate;
              
              return {
                'usdt_amount': usdtAmount,
                'fee_usdt': feeUsdt,
                'total_usdt': totalUsdt,
                'total_naira': totalNaira,
                'exchange_rate': usdToNgnRate,
              };
            }

            // Get breakdown for display (in selected crypto: BNB or USDT)
            Map<String, dynamic>? getCryptoBreakdown() {
              if (currency == 'taji') {
                final totalUsd = calculateTotalUsd();
                if (totalUsd == null) return null;
                
                // Determine which crypto to show
                String displayCrypto = 'usdt';
                double cryptoPriceUsd = 1.0; // USDT is ~$1
                
                if (method == 'crypto' && _cryptoType == 'bnb') {
                  displayCrypto = 'bnb';
                  // Use BNB price (fetch or fallback)
                  cryptoPriceUsd = _bnbPriceUsd ?? 600.0; // Fallback BNB price
                }
                
                // Convert USD total to selected crypto
                final totalCrypto = totalUsd / cryptoPriceUsd;
                final requiredCrypto = totalCrypto / 1.03; // Reverse calculate required
                final feeCrypto = totalCrypto - requiredCrypto;
                
                return {
                  'required': requiredCrypto,
                  'fee': feeCrypto,
                  'total': totalCrypto,
                  'crypto': displayCrypto,
                };
              } else if (currency == 'usdt' && method == 'crypto') {
                final totalUsdt = calculateUsdtTotal();
                if (totalUsdt == null) return null;
                
                // Determine which crypto to show
                String displayCrypto = 'usdt';
                double cryptoPriceUsd = 1.0; // USDT is ~$1
                
                if (_cryptoType == 'bnb') {
                  displayCrypto = 'bnb';
                  // Use BNB price (fetch or fallback)
                  cryptoPriceUsd = _bnbPriceUsd ?? 600.0; // Fallback BNB price
                }
                
                // For USDT funding, if paying with BNB, convert to BNB
                // If paying with USDT, it's 1:1
                final baseAmount = totalUsdt / 1.03; // Base USDT amount
                final feeAmount = totalUsdt - baseAmount; // Fee amount
                
                if (displayCrypto == 'bnb') {
                  // Convert to BNB
                  final baseBnb = baseAmount / cryptoPriceUsd;
                  final feeBnb = feeAmount / cryptoPriceUsd;
                  final totalBnb = totalUsdt / cryptoPriceUsd;
                  
                  return {
                    'required': baseBnb,
                    'fee': feeBnb,
                    'total': totalBnb,
                    'crypto': displayCrypto,
                    'base_usdt': baseAmount,
                    'fee_usdt': feeAmount,
                  };
                } else {
                  // USDT to USDT (1:1)
                  return {
                    'required': baseAmount,
                    'fee': feeAmount,
                    'total': totalUsdt,
                    'crypto': displayCrypto,
                  };
                }
              }
              return null;
            }

            final cryptoBreakdown = getCryptoBreakdown();
            final usdtPaystackBreakdown = getUsdtPaystackBreakdown();

            Future<void> submit() async {
              print('🔵 [TAJI FUNDING DEBUG] Submit button pressed');
              print('🔵 [TAJI FUNDING DEBUG] Currency: $currency');
              print('🔵 [TAJI FUNDING DEBUG] Amount text: ${amountController.text}');
              
              final amount = double.tryParse(amountController.text.trim());
              print('🔵 [TAJI FUNDING DEBUG] Parsed amount: $amount');
              
              if (amount == null || amount <= 0) {
                print('❌ [TAJI FUNDING DEBUG] Invalid amount');
                _showSnack('Enter a valid amount', isError: true);
                return;
              }
              
              setSheetState(() => submitting = true);
              print('🔵 [TAJI FUNDING DEBUG] Submitting...');
              
              try {
                dio.Response response;
                if (currency == 'taji') {
                  if (method == 'crypto') {
                    // TAJI funding via Crypto payment
                    print('🔵 [TAJI FUNDING DEBUG] Calling generateCryptoDepositAddress');
                    print('🔵 [TAJI FUNDING DEBUG] Amount: $amount, Crypto: $_cryptoType, Network: $_network');
                    
                    try {
                      response = await _apiService.generateCryptoDepositAddress(
                        tajiAmount: amount,
                        cryptoType: _cryptoType,
                        network: _network,
                      );
                      print('✅ [TAJI FUNDING DEBUG] Deposit address generated');
                      print('🔵 [TAJI FUNDING DEBUG] Response data: ${response.data}');
                      
                      final data = response.data['data'] ?? response.data;
                      if (!mounted) return;
                      
                      // Show deposit address modal
                      Navigator.of(modalContext).pop();
                      _showCryptoDepositAddress(data);
                      
                    } catch (apiError) {
                      print('❌ [TAJI FUNDING DEBUG] Failed to generate deposit address');
                      print('❌ [TAJI FUNDING DEBUG] Error: $apiError');
                      rethrow;
                    }
                    return; // Exit early for crypto payment
                  } else {
                    // TAJI funding via USDT wallet
                    print('🔵 [TAJI FUNDING DEBUG] Calling fundTajiViaUsdt with amount: $amount');
                    print('🔵 [TAJI FUNDING DEBUG] TAJI price USD: $_tajiPriceUsd');
                    
                    try {
                      response = await _apiService.fundTajiViaUsdt(amount);
                      print('✅ [TAJI FUNDING DEBUG] API call successful');
                      print('🔵 [TAJI FUNDING DEBUG] Response status: ${response.statusCode}');
                      print('🔵 [TAJI FUNDING DEBUG] Response data: ${response.data}');
                    } catch (apiError) {
                      print('❌ [TAJI FUNDING DEBUG] API call failed');
                      print('❌ [TAJI FUNDING DEBUG] Error type: ${apiError.runtimeType}');
                      print('❌ [TAJI FUNDING DEBUG] Error message: $apiError');
                      if (apiError is dio.DioException) {
                        print('❌ [TAJI FUNDING DEBUG] DioException type: ${apiError.type}');
                        print('❌ [TAJI FUNDING DEBUG] DioException message: ${apiError.message}');
                        print('❌ [TAJI FUNDING DEBUG] DioException response: ${apiError.response?.data}');
                        print('❌ [TAJI FUNDING DEBUG] DioException status code: ${apiError.response?.statusCode}');
                      }
                      rethrow;
                    }
                  }
                } else {
                  // USDT funding
                  if (method == 'crypto') {
                    // USDT funding via Crypto payment
                    print('🔵 [USDT FUNDING DEBUG] Calling generateUsdtCryptoDepositAddress');
                    print('🔵 [USDT FUNDING DEBUG] Amount: $amount, Crypto: $_cryptoType, Network: $_network');
                    
                    try {
                      response = await _apiService.generateUsdtCryptoDepositAddress(
                        usdtAmount: amount,
                        cryptoType: _cryptoType,
                        network: _network,
                      );
                      print('✅ [USDT FUNDING DEBUG] Deposit address generated');
                      print('🔵 [USDT FUNDING DEBUG] Response data: ${response.data}');
                      
                      final data = response.data['data'] ?? response.data;
                      if (!mounted) return;
                      
                      // Show deposit address modal
                      Navigator.of(modalContext).pop();
                      _showCryptoDepositAddress(data);
                      
                    } catch (apiError) {
                      print('❌ [USDT FUNDING DEBUG] Failed to generate deposit address');
                      print('❌ [USDT FUNDING DEBUG] Error: $apiError');
                      rethrow;
                    }
                    return; // Exit early for crypto payment
                  } else {
                    // USDT funding via Paystack
                    print('🔵 [USDT FUNDING DEBUG] Calling initializeWalletFunding');
                    print('🔵 [USDT FUNDING DEBUG] Currency: $currency, Amount: $amount, Method: $method');
                    
                    try {
                      response = await _apiService.initializeWalletFunding(
                        currency: currency,
                        amount: amount,
                        paymentMethod: method,
                      );
                      print('✅ [USDT FUNDING DEBUG] API call successful');
                      print('🔵 [USDT FUNDING DEBUG] Response status: ${response.statusCode}');
                      print('🔵 [USDT FUNDING DEBUG] Response data: ${response.data}');
                    } catch (apiError) {
                      print('❌ [USDT FUNDING DEBUG] API call failed');
                      print('❌ [USDT FUNDING DEBUG] Error type: ${apiError.runtimeType}');
                      print('❌ [USDT FUNDING DEBUG] Error message: $apiError');
                      if (apiError is dio.DioException) {
                        print('❌ [USDT FUNDING DEBUG] DioException type: ${apiError.type}');
                        print('❌ [USDT FUNDING DEBUG] DioException message: ${apiError.message}');
                        print('❌ [USDT FUNDING DEBUG] DioException response: ${apiError.response?.data}');
                        print('❌ [USDT FUNDING DEBUG] DioException status code: ${apiError.response?.statusCode}');
                      }
                      rethrow;
                    }
                  }
                }
                
                final data = response.data['data'] ?? response.data;
                print('🔵 [TAJI FUNDING DEBUG] Extracted data: $data');
                print('🔵 [TAJI FUNDING DEBUG] Response success: ${response.data['success']}');
                print('🔵 [TAJI FUNDING DEBUG] Response message: ${response.data['message']}');
                
                if (!mounted) {
                  print('⚠️ [TAJI FUNDING DEBUG] Widget not mounted, returning');
                  return;
                }
                
                Navigator.of(modalContext).pop();
                
                if (currency == 'taji') {
                  print('✅ [TAJI FUNDING DEBUG] TAJI funding successful');
                  _showSnack('TAJI funded successfully from USDT wallet');
                  
                  // Wait a moment for backend to process the transaction
                  await Future.delayed(const Duration(milliseconds: 500));
                  
                  // Force refresh wallet data to get updated USDT balance
                  print('🔵 [TAJI FUNDING DEBUG] Refreshing wallet data...');
                  await _fetchWallet();
                  
                  // Also refresh the full dashboard
                  print('🔵 [TAJI FUNDING DEBUG] Reloading initial data...');
                  _loadInitialData();
                } else {
                  print('✅ [TAJI FUNDING DEBUG] USDT funding initialized');
                  _showSnack('Funding initialized successfully');
                  if (data is Map && data['authorization_url'] != null) {
                    print('🔵 [TAJI FUNDING DEBUG] Opening authorization URL: ${data['authorization_url']}');
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => PaystackScreen(
                          url: data['authorization_url'].toString(),
                        ),
                      ),
                    );
                  }
                  
                  // Refresh wallet data for USDT funding too
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _fetchWallet();
                  _loadInitialData();
                }
                
                print('✅ [TAJI FUNDING DEBUG] Process completed successfully');
              } catch (e) {
                print('❌ [TAJI FUNDING DEBUG] Exception caught in submit');
                print('❌ [TAJI FUNDING DEBUG] Exception type: ${e.runtimeType}');
                print('❌ [TAJI FUNDING DEBUG] Exception message: $e');
                print('❌ [TAJI FUNDING DEBUG] Exception toString: ${e.toString()}');
                if (e is dio.DioException) {
                  print('❌ [TAJI FUNDING DEBUG] DioException details:');
                  print('   - Type: ${e.type}');
                  print('   - Message: ${e.message}');
                  print('   - Request path: ${e.requestOptions.path}');
                  print('   - Request data: ${e.requestOptions.data}');
                  print('   - Response status: ${e.response?.statusCode}');
                  print('   - Response data: ${e.response?.data}');
                }
                setSheetState(() => submitting = false);
                _showSnack(e.toString(), isError: true);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_circle_outline, color: Colors.amber),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Fund Wallet',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Select Wallet', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('TAJI', currency == 'taji', () => setSheetState(() => currency = 'taji')),
                          _chip('USDT', currency == 'usdt', () => setSheetState(() => currency = 'usdt')),
                        ],
                      ),
                      // Show payment method for TAJI (USDT wallet or Crypto)
                      if (currency == 'taji') ...[
                        const SizedBox(height: 16),
                        Text('Payment Method', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('USDT Wallet', method == 'usdt_wallet', () => setSheetState(() => method = 'usdt_wallet')),
                            _chip('Crypto', method == 'crypto', () => setSheetState(() => method = 'crypto')),
                          ],
                        ),
                      ],
                      // Show payment method for USDT
                      if (currency == 'usdt') ...[
                        const SizedBox(height: 16),
                        Text('Payment Method', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('Paystack', method == 'paystack', () => setSheetState(() => method = 'paystack')),
                            _chip('Crypto', method == 'crypto', () => setSheetState(() => method = 'crypto')),
                          ],
                        ),
                      ],
                      // Show crypto options for TAJI crypto payment
                      if (currency == 'taji' && method == 'crypto') ...[
                        const SizedBox(height: 16),
                        Text('Crypto Type', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('BNB', _cryptoType == 'bnb', () => setSheetState(() {
                              _cryptoType = 'bnb';
                              _network = 'bsc'; // BNB is only on BSC
                            })),
                            _chip('USDT', _cryptoType == 'usdt', () => setSheetState(() => _cryptoType = 'usdt')),
                          ],
                        ),
                        // Only show network selection for USDT (BNB is always on BSC)
                        if (_cryptoType == 'usdt') ...[
                          const SizedBox(height: 16),
                          Text('Network', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip('BSC', _network == 'bsc', () => setSheetState(() => _network = 'bsc')),
                              _chip('Ethereum', _network == 'ethereum', () => setSheetState(() => _network = 'ethereum')),
                              _chip('Polygon', _network == 'polygon', () => setSheetState(() => _network = 'polygon')),
                            ],
                          ),
                        ],
                      ],
                      // Show crypto options for USDT crypto payment
                      if (currency == 'usdt' && method == 'crypto') ...[
                        const SizedBox(height: 16),
                        Text('Crypto Type', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _chip('BNB', _cryptoType == 'bnb', () => setSheetState(() {
                              _cryptoType = 'bnb';
                              _network = 'bsc'; // BNB is only on BSC
                            })),
                            _chip('USDT', _cryptoType == 'usdt', () => setSheetState(() => _cryptoType = 'usdt')),
                          ],
                        ),
                        // Only show network selection for USDT (BNB is always on BSC)
                        if (_cryptoType == 'usdt') ...[
                          const SizedBox(height: 16),
                          Text('Network', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip('BSC', _network == 'bsc', () => setSheetState(() => _network = 'bsc')),
                              _chip('Ethereum', _network == 'ethereum', () => setSheetState(() => _network = 'ethereum')),
                              _chip('Polygon', _network == 'polygon', () => setSheetState(() => _network = 'polygon')),
                            ],
                          ),
                        ],
                      ],
                      // Show info for TAJI funding via USDT wallet
                      if (currency == 'taji' && method == 'usdt_wallet') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'TAJI funding is done via your USDT wallet balance',
                                  style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        autofocus: false,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          setSheetState(() {
                            amountText = value;
                          });
                        },
                        onTap: () {
                          // Ensure cursor is visible when tapped
                          amountController.selection = TextSelection.fromPosition(
                            TextPosition(offset: amountController.text.length),
                          );
                        },
                        decoration: InputDecoration(
                          labelText: currency == 'taji' ? 'TAJI Amount' : 'Amount',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      // Show breakdown for USDT Paystack funding
                      if (currency == 'usdt' && method == 'paystack' && usdtPaystackBreakdown != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'USDT Amount:',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    '${(usdtPaystackBreakdown['usdt_amount'] as double).toStringAsFixed(8)} USDT',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fee (3%):',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    '${(usdtPaystackBreakdown['fee_usdt'] as double).toStringAsFixed(8)} USDT',
                                    style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total USDT:',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    '${(usdtPaystackBreakdown['total_usdt'] as double).toStringAsFixed(8)} USDT',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total to Pay (NGN):',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '₦${(usdtPaystackBreakdown['total_naira'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Show total with fee for TAJI or USDT crypto funding
                      if (cryptoBreakdown != null && ((currency == 'taji' && method == 'crypto') || (currency == 'usdt' && method == 'crypto'))) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    currency == 'taji' ? 'TAJI Amount:' : 'USDT Amount:',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    currency == 'taji' 
                                        ? '${amountText.isEmpty ? '0' : amountText} TAJI'
                                        : '${(cryptoBreakdown['base_usdt'] as double? ?? cryptoBreakdown['required'] as double).toStringAsFixed(8)} USDT',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Required ${(cryptoBreakdown['crypto'] as String).toUpperCase()}:',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    '${(cryptoBreakdown['required'] as double).toStringAsFixed(8)} ${(cryptoBreakdown['crypto'] as String).toUpperCase()}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Fee (3%):',
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  Text(
                                    '${(cryptoBreakdown['fee'] as double).toStringAsFixed(8)} ${(cryptoBreakdown['crypto'] as String).toUpperCase()}',
                                    style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total to Send:',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${(cryptoBreakdown['total'] as double).toStringAsFixed(8)} ${(cryptoBreakdown['crypto'] as String).toUpperCase()}',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: submitting ? null : submit,
                          child: Text(submitting ? 'Processing...' : 'Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Dispose controller when modal is closed - safely dispose
      try {
        amountController.dispose();
      } catch (e) {
        // Ignore disposal errors if already disposed
      }
    });
  }

  void _openConvertSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final amountController = TextEditingController();
        String mode = 'tajstars-naira';
        bool submitting = false;
        final modes = [
          {'value': 'tajstars-usdt', 'label': 'TAJSTARS → USDT'},
          {'value': 'usdt-tajstars', 'label': 'USDT → TAJSTARS'},
        ];

        Future<void> submitConversion(StateSetter setSheetState) async {
          final amount = double.tryParse(amountController.text.trim());
          if (amount == null || amount <= 0) {
            _showSnack('Enter a valid amount', isError: true);
            return;
          }
          setSheetState(() => submitting = true);
          try {
            if (mode == 'tajstars-usdt') {
              await _apiService.convertTajstarsToUsdt({'amount': amount});
            } else {
              await _apiService.convertUsdtToTajstars({'amount': amount});
            }
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSnack('Conversion successful');
            _loadInitialData();
          } catch (e) {
            setSheetState(() => submitting = false);
            _showSnack(e.toString(), isError: true);
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Convert Tokens',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...modes.map(
                      (entry) => RadioListTile<String>(
                        dense: true,
                        value: entry['value']!,
                        groupValue: mode,
                        onChanged: (value) => setSheetState(() => mode = value ?? mode),
                        activeColor: Colors.amber,
                        title: Text(entry['label']!, style: const TextStyle(color: Colors.white)),
                        tileColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: submitting ? null : () => submitConversion(setSheetState),
                        child: Text(submitting ? 'Converting...' : 'Convert'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ensureBanksLoaded() async {
    if (_banks.isNotEmpty) return;
    final response = await _apiService.getWalletBanks();
    final data = response.data['data'] ?? response.data;
    if (mounted) {
      setState(() {
        _banks = data is List ? data : [];
      });
    }
  }

  void _openWithdrawSheet() async {
    try {
      await _ensureBanksLoaded();
    } catch (e) {
      _showSnack('Unable to load bank list: $e', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        String currency = 'usdt';
        String? bankCode;
        String? bankName;
        final amountController = TextEditingController();
        final accountController = TextEditingController();
        String? accountName;
        bool validating = false;
        bool submitting = false;

        Future<void> validateAccount(StateSetter setSheetState) async {
          if (bankCode == null) {
            _showSnack('Select a bank first', isError: true);
            return;
          }
          if (accountController.text.trim().length != 10) {
            _showSnack('Enter a valid 10-digit account number', isError: true);
            return;
          }
          setSheetState(() => validating = true);
          try {
            final response = await _apiService.validateBankAccount(
              accountNumber: accountController.text.trim(),
              bankCode: bankCode!,
            );
            final data = response.data['data'] ?? response.data;
            if (mounted) {
              setSheetState(() {
                accountName = data?['account_name']?.toString();
              });
            }
          } catch (e) {
            _showSnack(e.toString(), isError: true);
          } finally {
            setSheetState(() => validating = false);
          }
        }

        Future<void> submitWithdrawal(StateSetter setSheetState) async {
          final amount = double.tryParse(amountController.text.trim());
          if (amount == null || amount <= 0) {
            _showSnack('Enter a valid amount', isError: true);
            return;
          }
          if (bankCode == null || bankName == null) {
            _showSnack('Select a bank', isError: true);
            return;
          }
          if (accountController.text.trim().length != 10) {
            _showSnack('Enter a valid account number', isError: true);
            return;
          }
          if ((accountName ?? '').isEmpty) {
            _showSnack('Validate account first', isError: true);
            return;
          }
          setSheetState(() => submitting = true);
          try {
            await _apiService.createWithdrawal(
              amount: amount,
              currencyType: currency,
              bankCode: bankCode!,
              bankName: bankName!,
              accountNumber: accountController.text.trim(),
              accountName: accountName!,
            );
            if (!mounted) return;
            Navigator.of(context).pop();
            _showSnack('Withdrawal request submitted');
            _loadInitialData();
          } catch (e) {
            setSheetState(() => submitting = false);
            _showSnack(e.toString(), isError: true);
          }
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined, color: Colors.amber),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Withdraw Funds',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('USDT', currency == 'usdt', () => setSheetState(() => currency = 'usdt')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: bankCode,
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Select Bank',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        items: _banks
                            .map(
                              (bank) => DropdownMenuItem<String>(
                                value: bank['code']?.toString(),
                                child: Text(bank['name']?.toString() ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            bankCode = value;
                            bankName = _banks.firstWhere(
                              (bank) => bank['code'].toString() == value,
                              orElse: () => {},
                            )['name']?.toString();
                            accountName = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: accountController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: 'Account Number',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setSheetState(() => accountName = null),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              accountName ?? 'Account name will appear after validation',
                              style: TextStyle(color: accountName == null ? Colors.white38 : Colors.greenAccent),
                            ),
                          ),
                          TextButton(
                            onPressed: validating ? null : () => validateAccount(setSheetState),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.amber,
                            ),
                            child: Text(validating ? 'Validating...' : 'Validate'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: submitting ? null : () => submitWithdrawal(setSheetState),
                          child: Text(submitting ? 'Submitting...' : 'Submit request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openConnectWalletSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final addressController = TextEditingController();
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final address = addressController.text.trim();
              print('[WALLET DEBUG] Connect wallet submit called');
              print('[WALLET DEBUG] Input address: $address');
              print('[WALLET DEBUG] Address length: ${address.length}');
              print('[WALLET DEBUG] Address starts with 0x: ${address.startsWith('0x')}');
              
              if (address.isEmpty) {
                print('[WALLET DEBUG] ❌ Address is empty');
                _showSnack('Enter a wallet address', isError: true);
                return;
              }
              
              // Validate Ethereum address format
              if (!address.startsWith('0x') || address.length != 42) {
                print('[WALLET DEBUG] ❌ Invalid address format');
                print('[WALLET DEBUG] Expected: starts with 0x and length 42');
                print('[WALLET DEBUG] Got: starts with ${address.startsWith('0x')}, length ${address.length}');
                _showSnack('Invalid wallet address format', isError: true);
                return;
              }

              print('[WALLET DEBUG] ✅ Address format valid, connecting...');
              setSheetState(() => submitting = true);
              try {
                print('[WALLET DEBUG] Calling connectWallet API...');
                final response = await _apiService.connectWallet(address);
                print('[WALLET DEBUG] Connect wallet response status: ${response.statusCode}');
                print('[WALLET DEBUG] Connect wallet response data: ${response.data}');
                
                if (response.data['success'] == true) {
                  print('[WALLET DEBUG] ✅ Wallet connected successfully');
                  if (!mounted) {
                    print('[WALLET DEBUG] Widget not mounted, returning');
                    return;
                  }
                  Navigator.of(context).pop();
                  _showSnack('Wallet connected successfully');
                  print('[WALLET DEBUG] Refreshing wallet data...');
                  await _fetchWallet();
                  await _fetchWalletTajiBalance();
                  print('[WALLET DEBUG] Wallet data refreshed');
                } else {
                  print('[WALLET DEBUG] ❌ Connect wallet failed');
                  print('[WALLET DEBUG] Response message: ${response.data['message']}');
                  throw Exception(response.data['message'] ?? 'Failed to connect wallet');
                }
              } catch (e) {
                print('[WALLET DEBUG] ❌ Error connecting wallet: $e');
                print('[WALLET DEBUG] Error type: ${e.runtimeType}');
                print('[WALLET DEBUG] Error details: ${e.toString()}');
                if (e is dio.DioException) {
                  print('[WALLET DEBUG] DioException type: ${e.type}');
                  print('[WALLET DEBUG] DioException message: ${e.message}');
                  print('[WALLET DEBUG] DioException response: ${e.response?.data}');
                }
                setSheetState(() => submitting = false);
                _showSnack(e.toString(), isError: true);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.amber),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Connect Wallet',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Enter your wallet address to view your TAJI balance',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          labelText: 'Wallet Address',
                          hintText: '0x...',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'monospace'),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: submitting ? null : submit,
                          child: Text(submitting ? 'Connecting...' : 'Connect Wallet'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.amber,
      backgroundColor: const Color(0xFF2D2D2D), // Dark background for unselected chips
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showCryptoDepositAddress(Map<String, dynamic> data) {
    final depositAddress = data['deposit_address'] ?? '';
    final requiredAmount = data['required_amount'] ?? '0';
    final cryptoType = data['crypto_type'] ?? 'BNB';
    final network = data['network'] ?? 'bsc';
    final paymentRef = data['payment_reference'] ?? '';
    final expiresAt = data['expires_at'] ?? '';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Send Payment', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send exactly $requiredAmount $cryptoType to:', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  depositAddress,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text('Network: ${network.toUpperCase()}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('Payment expires: ${expiresAt}', style: TextStyle(color: Colors.amber.shade300, fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _checkAndProcessCryptoPayment(paymentRef),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('I Have Sent Payment'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndProcessCryptoPayment(String paymentRef) async {
    print('🔵 [CRYPTO PAYMENT DEBUG] Starting payment check...');
    print('🔵 [CRYPTO PAYMENT DEBUG] Payment reference: $paymentRef');
    
    try {
      print('🔵 [CRYPTO PAYMENT DEBUG] Calling checkCryptoPaymentStatus API...');
      final response = await _apiService.checkCryptoPaymentStatus(paymentRef);
      
      print('✅ [CRYPTO PAYMENT DEBUG] API response received');
      print('🔵 [CRYPTO PAYMENT DEBUG] Response status code: ${response.statusCode}');
      print('🔵 [CRYPTO PAYMENT DEBUG] Full response data: ${response.data}');
      
      final data = response.data['data'] ?? response.data;
      print('🔵 [CRYPTO PAYMENT DEBUG] Extracted data: $data');
      print('🔵 [CRYPTO PAYMENT DEBUG] Payment received: ${data['payment_received']}');
      print('🔵 [CRYPTO PAYMENT DEBUG] Status: ${data['status']}');
      print('🔵 [CRYPTO PAYMENT DEBUG] Received amount: ${data['received_amount']}');
      print('🔵 [CRYPTO PAYMENT DEBUG] Required amount: ${data['required_amount']}');
      
      if (data['payment_received'] == true || data['status'] == 'paid') {
        print('✅ [CRYPTO PAYMENT DEBUG] Payment confirmed! Processing...');
        
        // Process payment
        print('🔵 [CRYPTO PAYMENT DEBUG] Calling processCryptoPayment API...');
        final processResponse = await _apiService.processCryptoPayment(paymentRef);
        
        print('✅ [CRYPTO PAYMENT DEBUG] Process payment response received');
        print('🔵 [CRYPTO PAYMENT DEBUG] Process response status: ${processResponse.statusCode}');
        print('🔵 [CRYPTO PAYMENT DEBUG] Process response data: ${processResponse.data}');
        
        if (processResponse.data['success'] == true) {
          print('✅ [CRYPTO PAYMENT DEBUG] Payment processed successfully!');
          if (!mounted) return;
          Navigator.of(context).pop(); // Close dialog
          
          // Determine if this was TAJI or USDT funding based on response
          final responseData = processResponse.data['data'] ?? {};
          if (responseData.containsKey('taji_amount')) {
            _showSnack('TAJI funded successfully via crypto payment');
          } else if (responseData.containsKey('usdt_amount')) {
            _showSnack('USDT funded successfully via crypto payment');
          } else {
            _showSnack('Payment processed successfully');
          }
          
          await Future.delayed(const Duration(milliseconds: 500));
          await _fetchWallet();
          _loadInitialData();
        } else {
          print('❌ [CRYPTO PAYMENT DEBUG] Payment processing failed');
          print('❌ [CRYPTO PAYMENT DEBUG] Error message: ${processResponse.data['message']}');
          _showSnack(processResponse.data['message'] ?? 'Payment processing failed', isError: true);
        }
      } else {
        print('⚠️ [CRYPTO PAYMENT DEBUG] Payment not yet confirmed');
        print('⚠️ [CRYPTO PAYMENT DEBUG] Payment received flag: ${data['payment_received']}');
        print('⚠️ [CRYPTO PAYMENT DEBUG] Status: ${data['status']}');
        _showSnack('Payment not yet confirmed. Please wait a moment and try again.', isError: true);
      }
    } catch (e) {
      print('❌ [CRYPTO PAYMENT DEBUG] Exception caught in _checkAndProcessCryptoPayment');
      print('❌ [CRYPTO PAYMENT DEBUG] Exception type: ${e.runtimeType}');
      print('❌ [CRYPTO PAYMENT DEBUG] Exception message: $e');
      print('❌ [CRYPTO PAYMENT DEBUG] Exception toString: ${e.toString()}');
      
      if (e is dio.DioException) {
        print('❌ [CRYPTO PAYMENT DEBUG] DioException details:');
        print('   - Type: ${e.type}');
        print('   - Message: ${e.message}');
        print('   - Request path: ${e.requestOptions.path}');
        print('   - Request data: ${e.requestOptions.data}');
        print('   - Response status: ${e.response?.statusCode}');
        print('   - Response data: ${e.response?.data}');
      }
      
      _showSnack('Failed to check payment: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Color _methodAccent(String? signature) {
    switch (signature) {
      case 'from-green-500 to-emerald-500':
        return Colors.greenAccent;
      case 'from-blue-500 to-cyan-500':
        return Colors.cyanAccent;
      case 'from-amber-500 to-orange-500':
        return Colors.orangeAccent;
      case 'from-purple-500 to-pink-500':
        return Colors.purpleAccent;
      default:
        return Colors.amberAccent;
    }
  }

  IconData _methodIcon(String? iconKey) {
    switch (iconKey) {
      case 'farming':
        return Icons.savings_outlined;
      case 'gifts':
        return Icons.card_giftcard;
      case 'referral':
        return Icons.group_add_outlined;
      default:
        return Icons.flash_on_outlined;
    }
  }

  IconData _historyIcon(String? type) {
    switch (type) {
      case 'lp_rewards':
        return Icons.auto_graph;
      case 'referral_reward':
        return Icons.group;
      case 'mining_rewards':
        return Icons.construction;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: FloatingActionButton(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          onPressed: () => context.go('/home'),
          child: const Icon(Icons.home, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SafeArea(
        child: Column(
          children: [
            TajifyTopBar(
              onSearch: () => context.push('/search'),
              onNotifications: () => context.push('/notifications').then((_) => _loadNotificationUnreadCount()),
              onMessages: () => context.push('/messages').then((_) => _initializeFirebaseAndLoadMessagesCount()),
              onAdd: () => context.go('/create'),
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserAvatar,
              displayLetter: _currentUserProfile?['name'] != null && _currentUserProfile!['name'].toString().isNotEmpty
                  ? _currentUserProfile!['name'].toString()[0].toUpperCase()
                  : _currentUserInitial,
            ),
            Expanded(
              child: RefreshIndicator(
                color: Colors.amber,
                onRefresh: _onRefresh,
                child: _buildBody(),
              ),
            ),
            BottomNavigationBar(
              backgroundColor: const Color(0xFF0D0D0D),
              selectedItemColor: Colors.amber,
              unselectedItemColor: Colors.white70,
              type: BottomNavigationBarType.fixed,
              currentIndex: 3,
              onTap: (index) {
                if (index == 0) {
                  context.go('/connect');
                } else if (index == 1) {
                  context.go('/channel');
                } else if (index == 2) {
                  context.go('/market');
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Connect'),
                BottomNavigationBarItem(icon: Icon(Icons.live_tv_outlined), label: 'Channel'),
                BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Market'),
                BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), label: 'Earn'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingDashboard && !_refreshing) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    if (_dashboardError != null && _earningCenter == null && !_refreshing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              Text(
                'Unable to load earning data.\n$_dashboardError',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: AnimatedBuilder(
        animation: _heroFade,
        builder: (context, child) {
          return Opacity(
            opacity: _heroFade.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 20),
                _buildWalletCards(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                if (_recentEarnings.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildRecentEarnings(),
                ],
                const SizedBox(height: 24),
                _buildTabs(),
                const SizedBox(height: 16),
                _activeTab == 'methods' ? _buildMethods() : _buildHistory(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard() {
    final stats = _earningCenter?['stats'] ?? {};
    final monthlyChange = _parseDouble(stats['monthly_percentage_change']);
    final today = _parseDouble(stats['today_earnings']);
    
    // Calculate total portfolio value
    final tajstarsValue = _tajstarsBalance * 0.01; // USD value (TAJSTARS/USD = $0.01)
    final tajiValue = _tajiPriceUsd != null ? (_walletTajiBalance ?? _tajiBalance) * _tajiPriceUsd! : 0;
    final usdtValue = _usdtBalance;
    final totalPortfolioValue = tajstarsValue + tajiValue + usdtValue;
    
    // TAJISTARS/USD rate
    const double tajstarsPriceUsd = 0.01;

    return Container(
                  decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Portfolio Overview', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '\$${totalPortfolioValue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      monthlyChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${monthlyChange >= 0 ? '+' : ''}${monthlyChange.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Text('Today', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _formatToken(today, suffix: 'TAJSTARS'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAJSTARS/USD', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                      Text(
                      '\$${tajstarsPriceUsd.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TAJI Price', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      _tajiPriceUsd != null ? '\$${_tajiPriceUsd!.toStringAsFixed(6)}' : 'fetching...',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCards() {
    // TAJSTARS to USD conversion: 1 TAJSTARS = 0.01 USD
    final tajstarsUsdValue = _tajstarsBalance * 0.01;
    
    // Determine TAJI wallet display
    final bool hasWalletAddress = _walletAddress != null && _walletAddress!.isNotEmpty;
    print('[WALLET DEBUG] _buildWalletCards() called');
    print('[WALLET DEBUG] hasWalletAddress: $hasWalletAddress');
    print('[WALLET DEBUG] _walletAddress: $_walletAddress');
    print('[WALLET DEBUG] _walletTajiBalance: $_walletTajiBalance');
    print('[WALLET DEBUG] _tajiBalance (from wallet payload): $_tajiBalance');
    print('[WALLET DEBUG] _loadingWalletBalance: $_loadingWalletBalance');
    
    final double tajiDisplayBalance = hasWalletAddress && _walletTajiBalance != null 
        ? _walletTajiBalance! 
        : _tajiBalance;
    print('[WALLET DEBUG] tajiDisplayBalance (final): $tajiDisplayBalance');
    
    final String tajiSecondary = hasWalletAddress && _walletTajiBalance != null
        ? (_tajiPriceUsd != null ? '\$${(_walletTajiBalance! * (_tajiPriceUsd ?? 0)).toStringAsFixed(2)}' : '')
        : (_tajiPriceUsd != null ? '\$${(_tajiBalance * (_tajiPriceUsd ?? 0)).toStringAsFixed(2)}' : '');
    print('[WALLET DEBUG] tajiSecondary: $tajiSecondary');
    
    final cards = [
      {
        'title': 'TAJISTARS Wallet',
        'value': '${_formatTajiBalance(_tajstarsBalance)} TAJISTARS',
        'secondary': '\$${tajstarsUsdValue.toStringAsFixed(2)}',
        'accent': Colors.amber,
      },
      {
        'title': 'TAJI Wallet',
        'value': '${_formatTajiBalance(tajiDisplayBalance)} TAJI',
        'secondary': tajiSecondary,
        'accent': Colors.cyanAccent,
        'hasWallet': hasWalletAddress,
      },
      {
        'title': 'USDT Wallet',
        'value': '${_usdtBalance.toStringAsFixed(2)} USDT',
        'secondary': '',
        'accent': Colors.greenAccent,
      },
    ];

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final card = cards[index];
          return Container(
            width: 220,
                              decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (card['accent'] as Color).withOpacity(0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(card['title'] as String, style: const TextStyle(color: Colors.white54)),
                    ),
                    if (index == 1) // TAJI Wallet
                      (card['hasWallet'] as bool? ?? false)
                          ? const SizedBox.shrink()
                          : GestureDetector(
                              onTap: () => _openConnectWalletSheet(),
                              child: Icon(
                                Icons.add,
                                color: (card['accent'] as Color),
                                size: 20,
                              ),
                                  ),
                                ],
                              ),
                const Spacer(),
                Text(
                  card['value'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if ((card['secondary'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card['secondary'] as String,
                    style: TextStyle(color: (card['accent'] as Color)),
                  ),
                ],
              ],
                                      ),
                                    );
                                  },
      ),
    );
  }

  Widget _buildQuickActions() {
    Widget action(String title, IconData icon, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 70,
                                          decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.amber),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        action('Fund', Icons.account_balance_wallet_outlined, _openFundWalletSheet),
        const SizedBox(width: 12),
        action('Withdraw', Icons.payments_outlined, _openWithdrawSheet),
        const SizedBox(width: 12),
        action('Convert', Icons.swap_horiz, _openConvertSheet),
        const SizedBox(width: 12),
        action('History', Icons.history, () => setState(() => _activeTab = 'history')),
      ],
    );
  }


  Widget _buildRecentEarnings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent earnings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentEarnings.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final earning = _recentEarnings[index] as Map<String, dynamic>;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                      earning['method']?.toString() ?? 'Earning',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      earning['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const Spacer(),
                                              Text(
                      earning['amount']?.toString() ?? '',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(6),
      child: Row(
                                          children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'methods'),
              child: Container(
                height: 40,
                                              decoration: BoxDecoration(
                  color: _activeTab == 'methods' ? Colors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                                              ),
                alignment: Alignment.center,
                                              child: Text(
                  'Earn Center',
                  style: TextStyle(color: _activeTab == 'methods' ? Colors.black : Colors.white70),
                                                ),
                                              ),
                                            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = 'history'),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _activeTab == 'history' ? Colors.amber : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'History',
                  style: TextStyle(color: _activeTab == 'history' ? Colors.black : Colors.white70),
                ),
              ),
            ),
                                        ),
                                      ],
                                    ),
    );
  }

  Widget _buildMethods() {
    final methods = _earningCenter?['earning_methods'] as List<dynamic>? ?? [];
    if (methods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
        child: const Text(
          'Launch a video and earn from gifts, LP staking and more.\nNew methods land automatically once your wallet qualifies.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final method = methods[index] as Map<String, dynamic>;
        final color = _methodAccent(method['color']?.toString());
        return Container(
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(_methodIcon(method['icon']?.toString()), color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(method['name']?.toString() ?? 'Method', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      method['description']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(method['earnings']?.toString() ?? '--', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    method['status']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
                          ),
                        );
                      },
                    );
  }

  Widget _buildHistory() {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'This Month', 'value': 'month'},
      {'label': 'This Week', 'value': 'week'},
      {'label': 'Today', 'value': 'today'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: filters
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter['label']!),
                    selected: _historyFilter == filter['value'],
                    onSelected: (_) => _fetchHistory(filter: filter['value']!),
                    selectedColor: Colors.amber,
                    labelStyle: TextStyle(
                      color: _historyFilter == filter['value'] ? Colors.black : Colors.white,
                      fontWeight: _historyFilter == filter['value'] ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        if (_loadingHistory)
          const Center(child: CircularProgressIndicator(color: Colors.amber))
        else if (_earningHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
            child: const Center(
              child: Text('No earning history yet. Keep creating and gifting to start earning.', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _earningHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = _earningHistory[index] as Map<String, dynamic>;
              final createdAt = entry['created_at']?.toString();
              final date = createdAt != null ? DateTime.tryParse(createdAt) : null;
              return Container(
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_historyIcon(entry['type']?.toString()), color: Colors.amber),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry['method']?.toString() ?? 'Earning', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            entry['description']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          if (date != null)
                            Text(
                              '${date.year}/${date.month}/${date.day}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry['amount']?.toString() ?? '',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
              );
            },
      ),
      ],
    );
  }
} 