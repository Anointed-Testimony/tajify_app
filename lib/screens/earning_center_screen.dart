import 'dart:async';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'paystack_screen.dart';

import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../services/walletconnect_service.dart';
import '../widgets/tajify_top_bar.dart';
import '../widgets/custom_bottom_nav.dart';

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
  double _heroOpacity = 0.0;
  VoidCallback? _heroOpacityListener;
  
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
    
    // Safely listen to animation changes
    _heroOpacityListener = () {
      if (mounted) {
        setState(() {
          _heroOpacity = _heroFade.value;
        });
      }
    };
    _heroFade.addListener(_heroOpacityListener!);

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
    if (mounted) {
      setState(() {
        _loadingHistory = true;
      });
    }
    try {
      final response = await _apiService.getWalletTransactions(limit: 100);
      final payload = response.data['data'] ?? response.data;
      if (payload is List) {
        final filtered = _filterHistory(payload, filter);
        if (mounted) {
          setState(() {
            _earningHistory = filtered;
            _historyFilter = filter;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _earningHistory = [];
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
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
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
            // Handle nested user object
            final user = profile?['user'] ?? profile;
            _currentUserProfile = user ?? profile;
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
    // Remove listener before disposing controller
    if (_heroOpacityListener != null) {
      try {
        _heroFade.removeListener(_heroOpacityListener!);
      } catch (e) {
        // Ignore if already disposed
      }
    }
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
    bool isModalOpen = true; // Track if modal is still open
    
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
              if (currency != 'usdt' || method != 'paystack' || amountText.isEmpty) {
                print('🔵 [PAYSTACK DEBUG] Breakdown calculation skipped - conditions not met');
                print('   - currency: $currency (expected: usdt)');
                print('   - method: $method (expected: paystack)');
                print('   - amountText empty: ${amountText.isEmpty}');
                return null;
              }
              
              print('🔵 [PAYSTACK DEBUG] Calculating Paystack breakdown');
              final usdtAmount = double.tryParse(amountText);
              if (usdtAmount == null || usdtAmount <= 0) {
                print('⚠️ [PAYSTACK DEBUG] Invalid amount: $amountText');
                return null;
              }
              
              print('🔵 [PAYSTACK DEBUG] USDT amount: $usdtAmount');
              
              // Add 3% fee
              final feeUsdt = usdtAmount * 0.03;
              final totalUsdt = usdtAmount + feeUsdt;
              
              print('🔵 [PAYSTACK DEBUG] Fee (3%): $feeUsdt USDT');
              print('🔵 [PAYSTACK DEBUG] Total USDT: $totalUsdt');
              
              // Convert to Naira using actual exchange rate from API
              final usdToNgnRate = _usdToNgn ?? 1500.0; // Use fetched rate or fallback
              final totalNaira = totalUsdt * usdToNgnRate;
              
              print('🔵 [PAYSTACK DEBUG] Exchange rate (from API): $usdToNgnRate');
              print('🔵 [PAYSTACK DEBUG] Total Naira: $totalNaira');
              
              final breakdown = {
                'usdt_amount': usdtAmount,
                'fee_usdt': feeUsdt,
                'total_usdt': totalUsdt,
                'total_naira': totalNaira,
                'exchange_rate': usdToNgnRate,
              };
              
              print('🔵 [PAYSTACK DEBUG] Breakdown calculated: $breakdown');
              return breakdown;
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
              
              // Add Paystack-specific debug when Paystack is selected
              if (currency == 'usdt' && method == 'paystack') {
                print('🔵 [PAYSTACK DEBUG] ========================================');
                print('🔵 [PAYSTACK DEBUG] Paystack funding submit initiated');
                print('🔵 [PAYSTACK DEBUG] Currency: $currency');
                print('🔵 [PAYSTACK DEBUG] Method: $method');
              }
              
              // Safely get amount text before async operations
              String amountTextValue = '';
              if (!isModalOpen) {
                // Modal closed, use state variable
                amountTextValue = amountText;
              } else {
                try {
                  amountTextValue = amountController.text.trim();
                } catch (e) {
                  // If controller is disposed, use state variable
                  amountTextValue = amountText;
                }
              }
              
              print('🔵 [TAJI FUNDING DEBUG] Amount text: $amountTextValue');
              
              final amount = double.tryParse(amountTextValue);
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
                    print('🔵 [PAYSTACK DEBUG] ========================================');
                    print('🔵 [PAYSTACK DEBUG] Starting Paystack funding flow');
                    print('🔵 [PAYSTACK DEBUG] Currency: $currency');
                    print('🔵 [PAYSTACK DEBUG] Amount: $amount');
                    print('🔵 [PAYSTACK DEBUG] Method: $method');
                    print('🔵 [PAYSTACK DEBUG] Calling initializeWalletFunding API');
                    
                    try {
                      print('🔵 [PAYSTACK DEBUG] API request parameters:');
                      print('   - currency: $currency');
                      print('   - amount: $amount');
                      print('   - paymentMethod: $method');
                      
                      response = await _apiService.initializeWalletFunding(
                        currency: currency,
                        amount: amount,
                        paymentMethod: method,
                      );
                      
                      print('✅ [PAYSTACK DEBUG] API call successful');
                      print('🔵 [PAYSTACK DEBUG] Response status code: ${response.statusCode}');
                      print('🔵 [PAYSTACK DEBUG] Full response data: ${response.data}');
                      
                      if (response.data is Map) {
                        final responseMap = response.data as Map;
                        print('🔵 [PAYSTACK DEBUG] Response success: ${responseMap['success']}');
                        print('🔵 [PAYSTACK DEBUG] Response message: ${responseMap['message']}');
                        
                        if (responseMap['data'] != null) {
                          final data = responseMap['data'];
                          if (data is Map) {
                            print('🔵 [PAYSTACK DEBUG] Response data keys: ${data.keys.toList()}');
                            if (data['authorization_url'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Authorization URL: ${data['authorization_url']}');
                            }
                            if (data['reference'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Payment reference: ${data['reference']}');
                            }
                            if (data['usdt_amount'] != null) {
                              print('🔵 [PAYSTACK DEBUG] USDT amount: ${data['usdt_amount']}');
                            }
                            if (data['fee_usdt'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Fee USDT: ${data['fee_usdt']}');
                            }
                            if (data['total_usdt'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Total USDT: ${data['total_usdt']}');
                            }
                            if (data['naira_amount'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Naira amount: ${data['naira_amount']}');
                            }
                            if (data['exchange_rate'] != null) {
                              print('🔵 [PAYSTACK DEBUG] Exchange rate: ${data['exchange_rate']}');
                            }
                          }
                        }
                      }
                    } catch (apiError) {
                      print('❌ [PAYSTACK DEBUG] API call failed');
                      print('❌ [PAYSTACK DEBUG] Error type: ${apiError.runtimeType}');
                      print('❌ [PAYSTACK DEBUG] Error message: $apiError');
                      if (apiError is dio.DioException) {
                        print('❌ [PAYSTACK DEBUG] DioException details:');
                        print('   - Type: ${apiError.type}');
                        print('   - Message: ${apiError.message}');
                        print('   - Request path: ${apiError.requestOptions.path}');
                        print('   - Request method: ${apiError.requestOptions.method}');
                        print('   - Request data: ${apiError.requestOptions.data}');
                        print('   - Response status: ${apiError.response?.statusCode}');
                        print('   - Response data: ${apiError.response?.data}');
                        print('   - Response headers: ${apiError.response?.headers}');
                      }
                      print('❌ [PAYSTACK DEBUG] ========================================');
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
                
                // Mark modal as closed before popping
                isModalOpen = false;
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
                  // USDT funding via Paystack
                  print('🔵 [PAYSTACK DEBUG] Processing Paystack funding response');
                  print('🔵 [PAYSTACK DEBUG] Extracted data: $data');
                  
                  _showSnack('Funding initialized successfully');
                  
                  if (data is Map && data['authorization_url'] != null) {
                    final authUrl = data['authorization_url'].toString();
                    print('🔵 [PAYSTACK DEBUG] Authorization URL found: $authUrl');
                    print('🔵 [PAYSTACK DEBUG] Checking if widget is mounted...');
                    
                    if (!mounted) {
                      print('⚠️ [PAYSTACK DEBUG] Widget not mounted, cannot open Paystack screen');
                      return;
                    }
                    
                    print('🔵 [PAYSTACK DEBUG] Opening Paystack checkout screen');
                    print('🔵 [PAYSTACK DEBUG] Navigating to PaystackScreen with URL: $authUrl');
                    
                    try {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) {
                            print('🔵 [PAYSTACK DEBUG] PaystackScreen widget created');
                            final reference = data['reference']?.toString() ?? '';
                            print('🔵 [PAYSTACK DEBUG] Payment reference: $reference');
                            return PaystackScreen(
                              url: authUrl,
                              paymentReference: reference,
                            );
                          },
                        ),
                      );
                      
                      print('🔵 [PAYSTACK DEBUG] Returned from PaystackScreen');
                      print('🔵 [PAYSTACK DEBUG] Result: $result');
                      
                      if (result == true) {
                        print('✅ [PAYSTACK DEBUG] Payment was successful!');
                        print('🔵 [PAYSTACK DEBUG] Refreshing wallet data...');
                        
                        // Show success message
                        _showSnack('Payment successful! Wallet updated.', isError: false);
                        
                        // Refresh wallet data immediately
                        try {
                          await _fetchWallet();
                          print('✅ [PAYSTACK DEBUG] Wallet data refreshed');
                        } catch (e) {
                          print('❌ [PAYSTACK DEBUG] Error refreshing wallet: $e');
                        }
                        
                        // Reload initial data
                        try {
                          _loadInitialData();
                          print('✅ [PAYSTACK DEBUG] Initial data reloaded');
                        } catch (e) {
                          print('❌ [PAYSTACK DEBUG] Error reloading initial data: $e');
                        }
                      } else {
                        print('🔵 [PAYSTACK DEBUG] Payment may have been cancelled or failed');
                      }
                    } catch (e) {
                      print('❌ [PAYSTACK DEBUG] Error opening PaystackScreen: $e');
                      print('❌ [PAYSTACK DEBUG] Error type: ${e.runtimeType}');
                    }
                  } else {
                    print('⚠️ [PAYSTACK DEBUG] No authorization_url found in response data');
                    print('⚠️ [PAYSTACK DEBUG] Data type: ${data.runtimeType}');
                    if (data is Map) {
                      print('⚠️ [PAYSTACK DEBUG] Data keys: ${data.keys.toList()}');
                    }
                  }
                  
                  // Refresh wallet data for USDT funding too
                  print('🔵 [PAYSTACK DEBUG] Refreshing wallet data after Paystack flow');
                  print('🔵 [PAYSTACK DEBUG] Waiting 500ms before refresh...');
                  await Future.delayed(const Duration(milliseconds: 500));
                  
                  print('🔵 [PAYSTACK DEBUG] Fetching wallet data...');
                  try {
                    await _fetchWallet();
                    print('✅ [PAYSTACK DEBUG] Wallet data fetched successfully');
                  } catch (e) {
                    print('❌ [PAYSTACK DEBUG] Error fetching wallet: $e');
                  }
                  
                  print('🔵 [PAYSTACK DEBUG] Reloading initial data...');
                  try {
                    _loadInitialData();
                    print('✅ [PAYSTACK DEBUG] Initial data reload triggered');
                  } catch (e) {
                    print('❌ [PAYSTACK DEBUG] Error reloading initial data: $e');
                  }
                  
                  print('🔵 [PAYSTACK DEBUG] Paystack funding flow completed');
                  print('🔵 [PAYSTACK DEBUG] ========================================');
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
                          const Icon(Icons.add_circle_outline, color: Color(0xFFB875FB)),
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
                          if (!isModalOpen) return; // Don't update if modal is closed
                          try {
                            setSheetState(() {
                              amountText = value;
                            });
                          } catch (e) {
                            // Ignore if modal is closed
                          }
                        },
                        onTap: () {
                          // Ensure cursor is visible when tapped - safely
                          if (!isModalOpen) return; // Don't access if modal is closed
                          try {
                            amountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: amountController.text.length),
                            );
                          } catch (e) {
                            // Ignore if controller is disposed
                          }
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
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
                                    style: TextStyle(color: Color(0xFFB875FB).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
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
                                    style: TextStyle(color: Color(0xFFB875FB).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
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
                            backgroundColor: Color(0xFFB875FB),
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
      // Mark modal as closed
      isModalOpen = false;
      // Dispose controller when modal is closed - safely dispose
      // Add a small delay to ensure all async operations complete
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          amountController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
      });
    });
  }

  void _openConvertSheet() {
    final amountController = TextEditingController();
    bool isModalOpen = true; // Track if modal is still open
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        String mode = 'tajstars-usdt'; // Default to TAJSTARS → USDT
        bool submitting = false;
        final modes = [
          {'value': 'tajstars-usdt', 'label': 'TAJSTARS → USDT'},
          {'value': 'usdt-tajstars', 'label': 'USDT → TAJSTARS'},
        ];

        Future<void> submitConversion(StateSetter setSheetState) async {
          if (!isModalOpen) return; // Don't submit if modal is closed
          
          // Safely get amount text
          String amountTextValue = '';
          if (!isModalOpen) {
            return; // Modal closed, can't proceed
          } else {
            try {
              amountTextValue = amountController.text.trim();
            } catch (e) {
              // Controller disposed, can't proceed
              return;
            }
          }
          
          final amount = double.tryParse(amountTextValue);
          if (amount == null || amount <= 0) {
            _showSnack('Enter a valid amount', isError: true);
            return;
          }
          if (!isModalOpen || !mounted) return; // Check again before async operation
          
          setSheetState(() => submitting = true);
          try {
            if (mode == 'tajstars-usdt') {
              await _apiService.convertTajstarsToUsdt({'amount': amount});
            } else {
              await _apiService.convertUsdtToTajstars({'amount': amount});
            }
            if (!mounted || !isModalOpen) return;
            
            // Mark modal as closed before popping
            isModalOpen = false;
            Navigator.of(context).pop();
            _showSnack('Conversion successful');
            _loadInitialData();
          } catch (e) {
            if (mounted && isModalOpen) {
              setSheetState(() => submitting = false);
              _showSnack(e.toString(), isError: true);
            }
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
                        const Icon(Icons.swap_horiz, color: Color(0xFFB875FB)),
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
                        activeColor: Color(0xFFB875FB),
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
                          borderSide: const BorderSide(color: Color(0xFFB875FB)),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        if (!isModalOpen) return;
                        try {
                          setSheetState(() {
                            // Trigger rebuild to update breakdown
                          });
                        } catch (e) {
                          // Ignore if modal is closed
                        }
                      },
                      onTap: () {
                        // Ensure cursor is visible when tapped - safely
                        if (!isModalOpen) return; // Don't access if modal is closed
                        try {
                          amountController.selection = TextSelection.fromPosition(
                            TextPosition(offset: amountController.text.length),
                          );
                        } catch (e) {
                          // Ignore if controller is disposed
                        }
                      },
                    ),
                    // Show breakdown for conversion
                    Builder(
                      builder: (context) {
                        final amountText = amountController.text.trim();
                        final amount = double.tryParse(amountText);
                        
                        if (amount == null || amount <= 0) {
                          return const SizedBox.shrink();
                        }
                        
                        // Calculate conversion based on mode
                        double? receivedAmount;
                        String rateText = '';
                        String fromCurrency = '';
                        String toCurrency = '';
                        
                        if (mode == 'tajstars-usdt') {
                          // TAJSTARS → USDT: 1 TAJSTARS = 0.007 USDT
                          receivedAmount = amount * 0.007;
                          rateText = '1 TAJSTARS = 0.007 USDT';
                          fromCurrency = 'TAJSTARS';
                          toCurrency = 'USDT';
                        } else if (mode == 'usdt-tajstars') {
                          // USDT → TAJSTARS: 1 USDT = 100 TAJSTARS
                          receivedAmount = amount * 100;
                          rateText = '1 USDT = 100 TAJSTARS';
                          fromCurrency = 'USDT';
                          toCurrency = 'TAJSTARS';
                        }
                        
                        if (receivedAmount == null) {
                          return const SizedBox.shrink();
                        }
                        
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Converting:',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                      ),
                                      Text(
                                        '${amount.toStringAsFixed(8)} $fromCurrency',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Exchange Rate:',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                      ),
                                      Text(
                                        rateText,
                                        style: TextStyle(color: Colors.blue.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white24, height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'You\'ll Receive:',
                                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${receivedAmount.toStringAsFixed(8)} $toCurrency',
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Color(0xFFB875FB),
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
    ).whenComplete(() {
      // Mark modal as closed
      isModalOpen = false;
      // Dispose controller when modal is closed - safely dispose
      // Add a small delay to ensure all async operations complete
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          amountController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
      });
    });
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

    final amountController = TextEditingController();
    final accountController = TextEditingController();
    bool isModalOpen = true; // Track if modal is still open
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        String currency = 'usdt';
        String? bankCode;
        String? bankName;
        String? accountName;
        bool validating = false;
        bool submitting = false;

        Future<void> validateAccount(StateSetter setSheetState) async {
          if (!isModalOpen) return; // Don't validate if modal is closed
          
          if (bankCode == null) {
            _showSnack('Select a bank first', isError: true);
            return;
          }
          // Safely get account number
          String accountNumber = '';
          if (!isModalOpen) {
            return; // Modal closed, can't proceed
          } else {
            try {
              accountNumber = accountController.text.trim();
            } catch (e) {
              // Controller disposed, can't proceed
              return;
            }
          }
          
          if (accountNumber.length != 10) {
            _showSnack('Enter a valid 10-digit account number', isError: true);
            return;
          }
          
          if (!isModalOpen || !mounted) return; // Check again before async operation
          
          setSheetState(() => validating = true);
          try {
            final response = await _apiService.validateBankAccount(
              accountNumber: accountNumber,
              bankCode: bankCode!,
            );
            final data = response.data['data'] ?? response.data;
            if (mounted && isModalOpen) {
              setSheetState(() {
                accountName = data?['account_name']?.toString();
              });
            }
          } catch (e) {
            if (mounted && isModalOpen) {
              _showSnack(e.toString(), isError: true);
            }
          } finally {
            if (mounted && isModalOpen) {
              setSheetState(() => validating = false);
            }
          }
        }

        Future<void> submitWithdrawal(StateSetter setSheetState) async {
          if (!isModalOpen) return; // Don't submit if modal is closed
          
          // Safely get amount and account number
          String amountTextValue = '';
          String accountNumberValue = '';
          if (!isModalOpen) {
            return; // Modal closed, can't proceed
          } else {
            try {
              amountTextValue = amountController.text.trim();
              accountNumberValue = accountController.text.trim();
            } catch (e) {
              // Controller disposed, can't proceed
              return;
            }
          }
          
          final amount = double.tryParse(amountTextValue);
          if (amount == null || amount <= 0) {
            _showSnack('Enter a valid amount', isError: true);
            return;
          }
          if (bankCode == null || bankName == null) {
            _showSnack('Select a bank', isError: true);
            return;
          }
          if (accountNumberValue.length != 10) {
            _showSnack('Enter a valid account number', isError: true);
            return;
          }
          if ((accountName ?? '').isEmpty) {
            _showSnack('Validate account first', isError: true);
            return;
          }
          // Calculate 3% fee for display (backend will also calculate and deduct)
          final fee = amount * 0.03;
          final totalAmount = amount + fee;
          
          // Check balance before submitting (need total amount including fee)
          if (currency == 'usdt') {
            final currentBalance = _walletPayload?['usdt_balance'] ?? 0.0;
            if (currentBalance < totalAmount) {
              _showSnack('Insufficient USDT balance. You need ${totalAmount.toStringAsFixed(8)} USDT (including 3% fee)', isError: true);
              setSheetState(() => submitting = false);
              return;
            }
          }
          
          setSheetState(() => submitting = true);
          try {
            await _apiService.createWithdrawal(
              amount: amount, // Send the withdrawal amount (without fee) - backend will calculate and deduct fee
              currencyType: currency,
              bankCode: bankCode!,
              bankName: bankName!,
              accountNumber: accountNumberValue,
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
                          const Icon(Icons.payments_outlined, color: Color(0xFFB875FB)),
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (!isModalOpen) return; // Don't update if modal is closed
                          try {
                            setSheetState(() {
                              accountName = null; // Clear account name when typing
                            });
                            
                            // Auto-validate when account number reaches 10 digits
                            if (value.trim().length == 10 && bankCode != null) {
                              // Small delay to ensure user finished typing
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (isModalOpen && mounted) {
                                  // Check again that it's still 10 digits and bank is selected
                                  try {
                                    final currentValue = accountController.text.trim();
                                    if (currentValue.length == 10 && bankCode != null) {
                                      validateAccount(setSheetState);
                                    }
                                  } catch (e) {
                                    // Controller disposed, ignore
                                  }
                                }
                              });
                            }
                          } catch (e) {
                            // Ignore if modal is closed
                          }
                        },
                        onTap: () {
                          // Ensure cursor is visible when tapped - safely
                          if (!isModalOpen) return; // Don't access if modal is closed
                          try {
                            accountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: accountController.text.length),
                            );
                          } catch (e) {
                            // Ignore if controller is disposed
                          }
                        },
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
                              foregroundColor: Color(0xFFB875FB),
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (!isModalOpen) return;
                          try {
                            setSheetState(() {
                              // Trigger rebuild to update breakdown
                            });
                          } catch (e) {
                            // Ignore if modal is closed
                          }
                        },
                        onTap: () {
                          // Ensure cursor is visible when tapped - safely
                          if (!isModalOpen) return; // Don't access if modal is closed
                          try {
                            amountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: amountController.text.length),
                            );
                          } catch (e) {
                            // Ignore if controller is disposed
                          }
                        },
                      ),
                      // Show breakdown for withdrawal
                      Builder(
                        builder: (context) {
                          final amountText = amountController.text.trim();
                          final amount = double.tryParse(amountText);
                          
                          if (amount == null || amount <= 0) {
                            return const SizedBox.shrink();
                          }
                          
                          // Calculate 3% fee
                          final fee = amount * 0.03;
                          final total = amount + fee;
                          
                          return Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(0xFFB875FB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFB875FB).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Withdrawal Amount:',
                                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                        ),
                                        Text(
                                          currency == 'usdt' 
                                              ? '${amount.toStringAsFixed(8)} USDT'
                                              : '₦${amount.toStringAsFixed(2)}',
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
                                          currency == 'usdt'
                                              ? '${fee.toStringAsFixed(8)} USDT'
                                              : '₦${fee.toStringAsFixed(2)}',
                                          style: TextStyle(color: Color(0xFFB875FB).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: Colors.white24, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total to Deduct:',
                                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          currency == 'usdt'
                                              ? '${total.toStringAsFixed(8)} USDT'
                                              : '₦${total.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFFB875FB), fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Color(0xFFB875FB),
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
    ).whenComplete(() {
      // Mark modal as closed
      isModalOpen = false;
      // Dispose controllers when modal is closed - safely dispose
      // Add a small delay to ensure all async operations complete
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          amountController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
        try {
          accountController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
      });
    });
  }

  void _openTransferSheet() {
    final amountController = TextEditingController();
    final emailController = TextEditingController();
    bool isModalOpen = true; // Track if modal is still open
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        String currency = 'usdt';
        bool submitting = false;
        String? recipientName;

        Future<void> validateRecipient(StateSetter setSheetState) async {
          if (!isModalOpen) return;
          
          // Safely get email
          String email = '';
          if (!isModalOpen) {
            return;
          } else {
            try {
              email = emailController.text.trim();
            } catch (e) {
              return;
            }
          }
          
          if (email.isEmpty) {
            _showSnack('Enter recipient email', isError: true);
            return;
          }
          
          if (!isModalOpen || !mounted) return;
          
          try {
            final response = await _apiService.validateRecipientEmail(email);
            final data = response.data['data'] ?? response.data;
            if (mounted && isModalOpen) {
              final hasWalletAddress = data?['has_wallet_address'] ?? false;
              
              // For TAJI transfers, wallet address is required
              if (currency == 'taji' && !hasWalletAddress) {
                setSheetState(() {
                  recipientName = null;
                });
                _showSnack('Recipient has not connected their wallet address', isError: true);
                return;
              }
              
              // User found and validated
              setSheetState(() {
                recipientName = data?['username']?.toString() ?? data?['name']?.toString();
              });
            }
          } catch (e) {
            if (mounted && isModalOpen) {
              setSheetState(() {
                recipientName = null;
              });
              
              // Check error message
              String errorMessage = '';
              if (e is dio.DioException && e.response != null) {
                errorMessage = e.response?.data?['message']?.toString() ?? e.toString();
              } else {
                errorMessage = e.toString();
              }
              
              _showSnack(errorMessage.contains('does not exist') ? 'Recipient not found' : errorMessage, isError: true);
            }
          }
        }

        Future<void> submitTransfer(StateSetter setSheetState) async {
          if (!isModalOpen) return;
          
          print('🔵 [TAJI FUNDING] ========================================');
          print('🔵 [TAJI FUNDING] Transfer submission started');
          print('🔵 [TAJI FUNDING] Currency: $currency');
          
          // Safely get amount and email
          String amountTextValue = '';
          String emailValue = '';
          if (!isModalOpen) {
            return;
          } else {
            try {
              amountTextValue = amountController.text.trim();
              emailValue = emailController.text.trim();
            } catch (e) {
              print('❌ [TAJI FUNDING] Error getting input values: $e');
              return;
            }
          }
          
          print('🔵 [TAJI FUNDING] Amount text: $amountTextValue');
          print('🔵 [TAJI FUNDING] Email: $emailValue');
          
          final amount = double.tryParse(amountTextValue);
          if (amount == null || amount <= 0) {
            print('❌ [TAJI FUNDING] Invalid amount: $amountTextValue');
            _showSnack('Enter a valid amount', isError: true);
            return;
          }
          
          if (emailValue.isEmpty) {
            print('❌ [TAJI FUNDING] Email is empty');
            _showSnack('Enter recipient email', isError: true);
            return;
          }
          
          if ((recipientName ?? '').isEmpty) {
            print('❌ [TAJI FUNDING] Recipient not validated');
            _showSnack('Validate recipient first', isError: true);
            return;
          }
          
          print('🔵 [TAJI FUNDING] Recipient name: $recipientName');
          
          if (!isModalOpen || !mounted) return;
          
          setSheetState(() => submitting = true);
          print('🔵 [TAJI FUNDING] Submitting state set to true');
          
          try {
            if (currency == 'usdt') {
              print('🔵 [TAJI FUNDING] Processing USDT transfer (not TAJI)');
              await _apiService.sendUsdt(
                recipientEmail: emailValue,
                amount: amount,
              );
            } else {
              // For TAJI, need wallet address
              print('🔵 [TAJI FUNDING] Starting TAJI transfer process');
              print('🔵 [TAJI FUNDING] Amount: $amount');
              print('🔵 [TAJI FUNDING] Recipient email: $emailValue');
              
              if (_walletAddress == null || _walletAddress!.isEmpty) {
                print('❌ [TAJI FUNDING] Sender wallet not connected');
                _showSnack('Please connect your wallet first', isError: true);
                setSheetState(() => submitting = false);
                return;
              }
              
              print('🔵 [TAJI FUNDING] Sender wallet: ${_walletAddress}');
              
              // Get recipient wallet address (validate again to get wallet)
              print('🔵 [TAJI FUNDING] Validating recipient email...');
              final validateResponse = await _apiService.validateRecipientEmail(emailValue);
              print('🔵 [TAJI FUNDING] Validation response status: ${validateResponse.statusCode}');
              print('🔵 [TAJI FUNDING] Validation response data: ${validateResponse.data}');
              
              final recipientData = validateResponse.data['data'] ?? validateResponse.data;
              final recipientWallet = recipientData?['wallet_address'];
              
              print('🔵 [TAJI FUNDING] Recipient wallet address: $recipientWallet');
              
              if (recipientWallet == null || recipientWallet.isEmpty) {
                print('❌ [TAJI FUNDING] Recipient has not connected a wallet');
                _showSnack('Recipient has not connected a wallet', isError: true);
                setSheetState(() => submitting = false);
                return;
              }
              
              print('🔵 [TAJI FUNDING] Calling sendTaji API...');
              print('🔵 [TAJI FUNDING] Request data: {');
              print('🔵 [TAJI FUNDING]   recipient_email: $emailValue,');
              print('🔵 [TAJI FUNDING]   recipient_wallet: $recipientWallet,');
              print('🔵 [TAJI FUNDING]   amount: $amount,');
              print('🔵 [TAJI FUNDING]   sender_wallet: ${_walletAddress}');
              print('🔵 [TAJI FUNDING] }');
              
              try {
                // Step 1: get prepared transaction
                final response = await _apiService.sendTaji(
                  recipientEmail: emailValue,
                  recipientWallet: recipientWallet,
                  amount: amount,
                  senderWallet: _walletAddress!,
                );
                
                print('✅ [TAJI FUNDING] API call successful');
                print('🔵 [TAJI FUNDING] Response status: ${response.statusCode}');
                print('🔵 [TAJI FUNDING] Response data: ${response.data}');
                
                if (response.data['success'] != true) {
                  print('❌ [TAJI FUNDING] Backend returned failure');
                  print('❌ [TAJI FUNDING] Message: ${response.data['message']}');
                  throw Exception(response.data['message'] ?? 'Failed to execute transaction');
                }
                
                final responseData = response.data['data'];
                final txHash = responseData['txHash'];
                
                if (txHash != null && txHash.toString().isNotEmpty) {
                  print('✅ [TAJI FUNDING] Transaction executed on-chain successfully!');
                  print('🔵 [TAJI FUNDING] Transaction hash: $txHash');
                  print('🔵 [TAJI FUNDING] Block number: ${responseData['blockNumber']}');
                } else {
                  print('⚠️ [TAJI FUNDING] Transaction prepared but NOT executed on-chain');
                  print('⚠️ [TAJI FUNDING] Using WalletConnect to sign and send transaction...');
                  
                  final txData = responseData['transaction'];
                  if (txData == null) {
                    throw Exception('Transaction data not found in response');
                  }
                  
                  final nonceHex = txData['nonce']?.toString() ?? '0x0';
                  final gasPriceHex = txData['gasPrice']?.toString() ?? '0x0';
                  final gasHex = txData['gas']?.toString() ?? '0x0';
                  final toAddress = txData['to']?.toString() ?? '';
                  final dataHex = txData['data']?.toString() ?? '0x';
                  final valueHex = txData['value']?.toString() ?? '0x0';
                  final chainId = responseData['chain_id'] ?? 56;
                  final rpcUrl = responseData['rpc_url'] ?? 'https://bsc-dataseed1.binance.org/';
                  
                  BigInt hexToBigInt(String hex) {
                    if (hex.startsWith('0x')) {
                      return BigInt.parse(hex.substring(2), radix: 16);
                    }
                    return BigInt.parse(hex, radix: 16);
                  }
                  
                  final nonce = hexToBigInt(nonceHex);
                  final gasPrice = hexToBigInt(gasPriceHex);
                  final gasLimit = hexToBigInt(gasHex);
                  final value = hexToBigInt(valueHex);
                  
                  final walletConnectService = WalletConnectService.instance;
                  
                  if (!walletConnectService.isConnected) {
                    setSheetState(() => submitting = false);
                    
                    final shouldConnect = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Connect Wallet'),
                        content: const Text('Open your wallet to approve this transfer.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Connect'),
                          ),
                        ],
                      ),
                    );
                    
                    if (shouldConnect != true) {
                      throw Exception('Wallet connection cancelled');
                    }
                    
                    final connectedAddress =
                        await walletConnectService.connectWallet(context, chainId: chainId);
                    
                    if (connectedAddress == null || connectedAddress.isEmpty) {
                      throw Exception('Failed to connect wallet');
                    }
                    
                    if (connectedAddress.toLowerCase() != _walletAddress!.toLowerCase()) {
                      throw Exception(
                          'Connected wallet does not match sender wallet.\nExpected: $_walletAddress\nConnected: $connectedAddress');
                    }
                    
                    setSheetState(() => submitting = true);
                  }
                  
                  final signedHash = await walletConnectService.signAndSendTransaction(
                    rpcUrl: rpcUrl,
                    to: toAddress,
                    from: _walletAddress!,
                    value: value,
                    data: dataHex,
                    chainId: chainId,
                    gasPrice: gasPrice,
                    gasLimit: gasLimit,
                    nonce: nonce.toInt(),
                  );
                  
                  print('✅ [TAJI FUNDING] Transaction signed and sent!');
                  print('🔵 [TAJI FUNDING] Transaction hash: $signedHash');
                  responseData['txHash'] = signedHash;
                }
              } catch (e) {
                print('❌ [TAJI FUNDING] Error in transfer process');
                print('❌ [TAJI FUNDING] Error type: ${e.runtimeType}');
                print('❌ [TAJI FUNDING] Error message: $e');
                rethrow;
              }
            }
            
            if (!mounted || !isModalOpen) return;
            
            print('✅ [TAJI FUNDING] Transfer completed successfully');
            print('🔵 [TAJI FUNDING] Closing modal and refreshing data');
            
            // Mark modal as closed before popping
            isModalOpen = false;
            Navigator.of(context).pop();
            _showSnack('Transfer successful');
            _loadInitialData();
            
            print('🔵 [TAJI FUNDING] ========================================');
          } catch (e) {
            print('❌ [TAJI FUNDING] Transfer failed');
            print('❌ [TAJI FUNDING] Error type: ${e.runtimeType}');
            print('❌ [TAJI FUNDING] Error message: $e');
            if (e is dio.DioException) {
              print('❌ [TAJI FUNDING] DioException details:');
              print('❌ [TAJI FUNDING]   Type: ${e.type}');
              print('❌ [TAJI FUNDING]   Message: ${e.message}');
              print('❌ [TAJI FUNDING]   Response: ${e.response?.data}');
              print('❌ [TAJI FUNDING]   Status code: ${e.response?.statusCode}');
            }
            print('🔵 [TAJI FUNDING] ========================================');
            
            if (mounted && isModalOpen) {
              setSheetState(() => submitting = false);
              _showSnack(e.toString(), isError: true);
            }
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
                          const Icon(Icons.send, color: Color(0xFFB875FB)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Transfer Funds',
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
                      Text('Select Currency', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('USDT', currency == 'usdt', () => setSheetState(() => currency = 'usdt')),
                          _chip('TAJI', currency == 'taji', () => setSheetState(() => currency = 'taji')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Recipient Email',
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (!isModalOpen) return;
                          try {
                            setSheetState(() {
                              recipientName = null; // Clear name when typing
                            });
                            
                            // Auto-validate when email looks complete (contains @ and .)
                            if (value.contains('@') && value.contains('.') && value.length > 5) {
                              // Small delay to ensure user finished typing
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (isModalOpen && mounted) {
                                  try {
                                    final currentEmail = emailController.text.trim();
                                    if (currentEmail.contains('@') && currentEmail.contains('.') && currentEmail.length > 5) {
                                      validateRecipient(setSheetState);
                                    }
                                  } catch (e) {
                                    // Controller disposed, ignore
                                  }
                                }
                              });
                            }
                          } catch (e) {
                            // Ignore if modal is closed
                          }
                        },
                        onTap: () {
                          if (!isModalOpen) return;
                          try {
                            emailController.selection = TextSelection.fromPosition(
                              TextPosition(offset: emailController.text.length),
                            );
                          } catch (e) {
                            // Ignore if controller is disposed
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recipientName ?? 'Recipient name will appear after validation',
                              style: TextStyle(color: recipientName == null ? Colors.white38 : Colors.greenAccent),
                            ),
                          ),
                          TextButton(
                            onPressed: () => validateRecipient(setSheetState),
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0xFFB875FB),
                            ),
                            child: const Text('Validate'),
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onTap: () {
                          if (!isModalOpen) return;
                          try {
                            amountController.selection = TextSelection.fromPosition(
                              TextPosition(offset: amountController.text.length),
                            );
                          } catch (e) {
                            // Ignore if controller is disposed
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Color(0xFFB875FB),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: submitting ? null : () => submitTransfer(setSheetState),
                          child: Text(submitting ? 'Transferring...' : 'Transfer'),
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
      // Mark modal as closed
      isModalOpen = false;
      // Dispose controllers when modal is closed - safely dispose
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          amountController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
        try {
          emailController.dispose();
        } catch (e) {
          // Ignore disposal errors if already disposed
        }
      });
    });
  }

  void _openConnectWalletSheet() {
    final addressController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              // Safely get address
              String address = '';
              try {
                address = addressController.text.trim();
              } catch (e) {
                // Controller disposed, can't proceed
                return;
              }
              
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
                          const Icon(Icons.account_balance_wallet, color: Color(0xFFB875FB)),
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
                            borderSide: const BorderSide(color: Color(0xFFB875FB)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Color(0xFFB875FB),
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
    ).whenComplete(() {
      // Dispose controller when modal is closed - safely dispose
      try {
        addressController.dispose();
      } catch (e) {
        // Ignore disposal errors if already disposed
      }
    });
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Color(0xFFB875FB),
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
              Text('Payment expires: ${expiresAt}', style: TextStyle(color: Color(0xFFB875FB).withOpacity(0.7), fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _checkAndProcessCryptoPayment(paymentRef),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFB875FB),
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
    // Get the root navigator context to show snackbar above modals
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    // Use ScaffoldMessenger with root context to ensure it appears above modals
    ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  Color _methodAccent(String key) {
    switch (key) {
      case 'lp':
        return const Color(0xFFB875FB);
      case 'mining':
        return const Color(0xFF00BFA6);
      case 'faucet':
        return const Color(0xFFFF7043);
      case 'stake':
        return const Color(0xFF66BB6A);
      case 'referral':
        return const Color(0xFFFF5F6D);
      default:
        return const Color(0xFFB875FB);
    }
  }

  IconData _methodIcon(String key) {
    switch (key) {
      case 'lp':
        return Icons.show_chart;
      case 'mining':
        return Icons.agriculture;
      case 'faucet':
        return Icons.water_drop_outlined;
      case 'stake':
        return Icons.lock_clock;
      case 'referral':
        return Icons.groups_2_outlined;
      default:
        return Icons.auto_graph_outlined;
    }
  }

  IconData _historyIcon(String? type) {
    switch (type) {
      case 'deposit':
        return Icons.download_outlined;
      case 'withdrawal':
        return Icons.upload_outlined;
      case 'transfer':
        return Icons.swap_horiz;
      case 'funding':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
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
                color: Color(0xFFB875FB),
                onRefresh: _onRefresh,
                child: _buildBody(),
              ),
            ),
            const CustomBottomNav(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingDashboard && !_refreshing) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB875FB)));
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
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFB875FB), foregroundColor: Colors.black),
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
      child: Opacity(
        opacity: _heroOpacity,
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
        'accent': Color(0xFFB875FB),
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
                Icon(icon, color: Color(0xFFB875FB)),
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
        action('Transfer', Icons.send, _openTransferSheet),
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
                  color: _activeTab == 'methods' ? Color(0xFFB875FB) : Colors.transparent,
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
                  color: _activeTab == 'history' ? Color(0xFFB875FB) : Colors.transparent,
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
    final features = [
      {
        'name': 'Tajify LP Staking',
        'description':
            'Stake TAJI & TAJISTAR to enhance Tajify liquidity and share 20% of all platform transaction fees.',
        'earnings': '20% fee pool',
        'status': 'Liquidity Boost',
        'key': 'lp',
      },
      {
        'name': 'Mining Farm',
        'description': 'Buy farm plots (5,000 TAJISTAR/plot) and earn 110 TAJISTAR weekly for 50 weeks.',
        'earnings': '110 TAJISTAR/week',
        'status': '50-week cycle',
        'key': 'mining',
      },
      {
        'name': 'Faucet',
        'description': 'Solve a captcha every hour and earn 1 TAJISTAR instantly.',
        'earnings': '1 TAJISTAR/hour',
        'status': 'Always on',
        'key': 'faucet',
      },
      {
        'name': 'Stake Farm',
        'description': 'Stake TAJI for up to 90 days and enjoy 15% APY with flexible exits.',
        'earnings': '15% APY',
        'status': 'Max tenure 90 days',
        'key': 'stake',
      },
      {
        'name': 'Refer & Earn',
        'description': 'Share your invite link and get 10 TAJISTAR for every friend who signs up.',
        'earnings': '10 TAJISTAR/referral',
        'status': 'Invite & grow',
        'key': 'referral',
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final feature = features[index];
        final color = _methodAccent(feature['key'] as String);
        return GestureDetector(
          onTap: () {
            final key = feature['key'] as String;
            if (key == 'mining') {
              _openMiningFarmSheet();
            } else if (key == 'faucet') {
              _openFaucetSheet();
            } else if (key == 'stake') {
              _openStakeFarmSheet();
            } else if (key == 'lp') {
              _openLpStakingSheet();
            } else if (key == 'referral') {
              _openReferralSheet();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_methodIcon(feature['key'] as String), color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (feature['description'] as String).length > 80
                            ? '${(feature['description'] as String).substring(0, 80)}...'
                            : feature['description'] as String,
                        style: const TextStyle(color: Colors.white70, height: 1.3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFaucetSheet() {
    _showSnack('Faucet feature coming soon!', isError: false);
  }

  void _openStakeFarmSheet() {
    _showSnack('Stake Farm feature coming soon!', isError: false);
  }

  void _openLpStakingSheet() {
    _showSnack('LP Staking feature coming soon!', isError: false);
  }

  void _openReferralSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return _ReferralSheetContent(
          apiService: _apiService,
          showSnack: _showSnack,
        );
      },
    );
  }

  void _openMiningFarmSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return _MiningFarmSheetContent(
          walletPayload: _walletPayload,
          apiService: _apiService,
          onRefresh: () {
            _loadInitialData();
            Navigator.pop(sheetContext);
          },
          showSnack: _showSnack,
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: filters
                .map(
                    (filter) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => _fetchHistory(filter: filter['value']!),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: _historyFilter == filter['value']
                                  ? Color(0xFFB875FB)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              filter['label']!,
                              style: TextStyle(
                                color: _historyFilter == filter['value']
                                    ? Colors.black
                                    : Colors.white70,
                                fontWeight: _historyFilter == filter['value']
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingHistory)
          const Center(child: CircularProgressIndicator(color: Color(0xFFB875FB)))
        else if (_earningHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
            child: const Center(
              child: Text('No history yet', style: TextStyle(color: Colors.white54)),
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
              final type = entry['transaction_type']?.toString() ?? 'transaction';
              final description = entry['description']?.toString();
              final amount = entry['amount']?.toString() ?? '';
              final rawCurrency = entry['currency'];
              final currency = rawCurrency == null ? '' : rawCurrency.toString().toUpperCase();
              final status = entry['status']?.toString() ?? '';
              return Container(
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                      child: Icon(_historyIcon(type), color: Color(0xFFB875FB)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (description != null && description.isNotEmpty)
                            Text(
                              description,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$amount $currency',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.toUpperCase(),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
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

class _MiningFarmSheetContent extends StatefulWidget {
  final Map<String, dynamic>? walletPayload;
  final ApiService apiService;
  final VoidCallback onRefresh;
  final Function(String, {required bool isError}) showSnack;

  const _MiningFarmSheetContent({
    required this.walletPayload,
    required this.apiService,
    required this.onRefresh,
    required this.showSnack,
  });

  @override
  State<_MiningFarmSheetContent> createState() => _MiningFarmSheetContentState();
}

class _MiningFarmSheetContentState extends State<_MiningFarmSheetContent> {
  Map<String, dynamic>? _miningFarmInfo;
  bool _loadingMiningFarm = true;
  int plotsToBuy = 1;
  bool purchasing = false;
  bool claiming = false;

  @override
  void initState() {
    super.initState();
    _loadMiningFarmInfo();
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _loadMiningFarmInfo() async {
    setState(() {
      _loadingMiningFarm = true;
    });
    
    try {
      final response = await widget.apiService.getMiningFarmInfo();
      print('[MINING FARM] API Response: ${response.data}');
      if (response.data['success'] == true) {
        setState(() {
          _miningFarmInfo = response.data['data'];
          _loadingMiningFarm = false;
        });
      } else {
        setState(() {
          _loadingMiningFarm = false;
        });
        widget.showSnack(response.data['message'] ?? 'Failed to load mining farm info', isError: true);
      }
    } catch (e) {
      print('[MINING FARM ERROR] $e');
      setState(() {
        _loadingMiningFarm = false;
      });
      widget.showSnack('Error loading mining farm: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveMining = _miningFarmInfo?['has_active_mining'] == true;
    final plotsPurchased = _miningFarmInfo?['plots_purchased'] ?? 0;
    final weeklyEarnings = _parseDouble(_miningFarmInfo?['weekly_earnings']) ?? 0.0;
    final weeksRemaining = _miningFarmInfo?['weeks_remaining'] ?? 0;
    final availableRewards = _parseDouble(_miningFarmInfo?['available_rewards']) ?? 0.0;
    final totalEarned = _parseDouble(_miningFarmInfo?['total_earned']) ?? 0.0;
    // Access coins from wallet object - walletPayload structure is {wallet: {coins: ...}}
    final wallet = widget.walletPayload?['wallet'] ?? widget.walletPayload;
    final tajistarBalance = _parseDouble(wallet?['coins'] ?? wallet?['tajstars_balance']) ?? 0.0;
    final plotPrice = 5000.0;
    
    Widget _buildInfoRow(String label, String value) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    
    return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Mining Farm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (_loadingMiningFarm)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
                      ),
                    )
                  else if (hasActiveMining) ...[
                    // Active Mining View
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00BFA6).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.agriculture, color: Color(0xFF00BFA6), size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Active Mining',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow('Plots Purchased', '$plotsPurchased'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Weekly Earnings', '${weeklyEarnings.toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Weeks Remaining', '$weeksRemaining weeks'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Available Rewards', '${availableRewards.toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Total Earned', '${totalEarned.toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 20),
                          if (availableRewards > 0)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: claiming ? null : () async {
                                  setState(() => claiming = true);
                                  try {
                                    final response = await widget.apiService.claimMiningRewards();
                                    if (response.data['success'] == true) {
                                      widget.showSnack('Rewards claimed successfully!', isError: false);
                                      widget.onRefresh();
                                    } else {
                                      widget.showSnack(response.data['message'] ?? 'Failed to claim rewards', isError: true);
                                    }
                                  } catch (e) {
                                    widget.showSnack('Error claiming rewards: $e', isError: true);
                                  } finally {
                                    setState(() => claiming = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BFA6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: claiming
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Claim Rewards',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Purchase View
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Purchase Mining Plots',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Buy farm plots at 5,000 TAJISTAR per plot and earn 110 TAJISTAR weekly for 50 weeks.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Text(
                                'Number of Plots:',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          if (plotsToBuy > 1) plotsToBuy--;
                                        });
                                      },
                                    ),
                                    Container(
                                      width: 60,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$plotsToBuy',
                                        style: const TextStyle(color: Colors.white, fontSize: 18),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          plotsToBuy++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Price per Plot', '${plotPrice.toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Total Cost', '${(plotsToBuy * plotPrice).toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Weekly Earnings', '${(plotsToBuy * 110).toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Your Balance', '${tajistarBalance.toStringAsFixed(2)} TAJISTAR'),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (purchasing || (plotsToBuy * plotPrice) > tajistarBalance) ? null : () async {
                                setState(() => purchasing = true);
                                try {
                                  // Calculate total TAJISTAR amount needed
                                  final totalTajistarAmount = plotsToBuy * plotPrice;
                                  
                                  // Generate a transaction hash (in real app, this would come from blockchain)
                                  final transactionHash = 'mining_${DateTime.now().millisecondsSinceEpoch}_${plotsToBuy}';
                                  
                                  final response = await widget.apiService.purchaseMiningPlots(
                                    plots: plotsToBuy,
                                    tajistarAmount: totalTajistarAmount,
                                    transactionHash: transactionHash,
                                  );
                                  
                                  if (response.data['success'] == true) {
                                    widget.showSnack('Mining plots purchased successfully!', isError: false);
                                    widget.onRefresh();
                                  } else {
                                    widget.showSnack(response.data['message'] ?? 'Failed to purchase plots', isError: true);
                                  }
                                } catch (e) {
                                  widget.showSnack('Error purchasing plots: $e', isError: true);
                                } finally {
                                  setState(() => purchasing = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (plotsToBuy * plotPrice) > tajistarBalance
                                    ? Colors.grey
                                    : const Color(0xFF00BFA6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: purchasing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      (plotsToBuy * plotPrice) > tajistarBalance
                                          ? 'Insufficient Balance'
                                          : 'Purchase ${plotsToBuy} Plot${plotsToBuy > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
  }
}

// Referral Sheet Content Widget
class _ReferralSheetContent extends StatefulWidget {
  final ApiService apiService;
  final Function(String, {required bool isError}) showSnack;

  const _ReferralSheetContent({
    required this.apiService,
    required this.showSnack,
  });

  @override
  State<_ReferralSheetContent> createState() => _ReferralSheetContentState();
}

class _ReferralSheetContentState extends State<_ReferralSheetContent> {
  String? _referralCode;
  int _totalReferrals = 0;
  int _monthlyReferrals = 0;
  double _totalEarnings = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _loading = true;
    });

    try {
      // Load referral code
      final linkResponse = await widget.apiService.getReferralLink();
      if (linkResponse.data['success'] == true) {
        setState(() {
          _referralCode = linkResponse.data['data']?['username'];
        });
      }

      // Load referral stats
      final statsResponse = await widget.apiService.getReferralStats();
      if (statsResponse.data['success'] == true) {
        final data = statsResponse.data['data'];
        setState(() {
          _totalReferrals = data['total_referrals'] ?? 0;
          _monthlyReferrals = data['monthly_referrals'] ?? 0;
          _totalEarnings = (data['total_earnings'] ?? 0).toDouble();
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
        widget.showSnack(statsResponse.data['message'] ?? 'Failed to load referral stats', isError: true);
      }
    } catch (e) {
      print('[REFERRAL ERROR] $e');
      setState(() {
        _loading = false;
      });
      widget.showSnack('Error loading referral data: $e', isError: true);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    widget.showSnack('Copied to clipboard!', isError: false);
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Refer & Earn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(color: Color(0xFFB875FB)),
              ),
            )
          else ...[
            // Referral Code Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFB875FB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB875FB).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_add, color: Color(0xFFB875FB), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Your Referral Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _referralCode ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Color(0xFFB875FB)),
                          onPressed: () {
                            if (_referralCode != null) {
                              _copyToClipboard(_referralCode!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Stats Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Total Referrals', '$_totalReferrals'),
                  const SizedBox(height: 12),
                  _buildInfoRow('This Month', '$_monthlyReferrals'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Total Earnings', '${_totalEarnings.toStringAsFixed(2)} TAJISTAR'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
} 