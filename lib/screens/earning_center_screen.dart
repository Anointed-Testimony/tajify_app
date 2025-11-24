import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../widgets/tajify_top_bar.dart';

class EarningCenterScreen extends StatefulWidget {
  const EarningCenterScreen({Key? key}) : super(key: key);

  @override
  State<EarningCenterScreen> createState() => _EarningCenterScreenState();
}

class _EarningCenterScreenState extends State<EarningCenterScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  // Notification state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  
  // Messages state
  int _messagesUnreadCount = 0;
  StreamSubscription? _messagesCountSubscription;
  
  // User profile state
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  Map<String, dynamic>? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    
    // Load notification unread count
    _loadNotificationUnreadCount();
    
    // Set up periodic refresh for notification count
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotificationUnreadCount();
    });
    
    // Initialize Firebase and load messages count
    _initializeFirebaseAndLoadMessagesCount();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response.statusCode == 200 && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _currentUserProfile = response.data['data'];
            final name = _currentUserProfile?['name']?.toString();
            if (name != null && name.isNotEmpty) {
              _currentUserInitial = name[0].toUpperCase();
            }
            _currentUserAvatar = _currentUserProfile?['profile_avatar']?.toString();
          });
        }
      }
    } catch (e) {
      // Fallback to local storage
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
      } catch (e2) {
        // ignore silently
      }
    }
  }

  Future<void> _initializeFirebaseAndLoadMessagesCount() async {
    try {
      await FirebaseService.initialize();
      await FirebaseService.initializeAuth();
      
      // Get current user ID from API
      try {
        final response = await _apiService.get('/auth/me');
        if (response.statusCode == 200 && response.data['success'] == true) {
          final userId = response.data['data']['id'] as int?;
          if (userId != null && mounted) {
            if (FirebaseService.isInitialized) {
              _messagesCountSubscription = FirebaseService.getUnreadCountStream(userId)
                  .listen((count) {
                if (mounted) {
                  setState(() {
                    _messagesUnreadCount = count;
                  });
                }
              });
            }
          }
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
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
    } catch (e) {
      // ignore silently
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earningMethods = [
      {
        'title': 'Tajify LP Farming',
        'desc': 'Stake TAJI-TRP pairs for a share of 20% platform fees.',
        'icon': Icons.savings_outlined,
        'color': Colors.green,
        'reward': '20% APY',
      },
      {
        'title': 'Taji Mining Farm',
        'desc': 'Virtual "mines" yielding TAJI at up to 20% APY.',
        'icon': Icons.emoji_objects_outlined,
        'color': Colors.orange,
        'reward': '20% APY',
      },
      {
        'title': 'TRP Refer2Earn',
        'desc': 'Multi-level TRP referral rewards for creators & fans.',
        'icon': Icons.group_add_outlined,
        'color': Colors.blue,
        'reward': 'Up to 50%',
      },
      {
        'title': 'TRP Rewards',
        'desc': 'Activity-based TRP earnings (view, comment, share).',
        'icon': Icons.stars_outlined,
        'color': Colors.purple,
        'reward': 'Variable',
      },
      {
        'title': 'TRP Milestone Grants',
        'desc': 'Monthly leaderboard grants for top performers.',
        'icon': Icons.emoji_events_outlined,
        'color': Colors.amber,
        'reward': 'Monthly',
      },
      {
        'title': 'TRP Airdrops',
        'desc': 'Hourly micro-drops for active users.',
        'icon': Icons.air_outlined,
        'color': Colors.cyan,
        'reward': 'Hourly',
      },
      {
        'title': 'MicroGig2Earn',
        'desc': 'Click/Watch/Follow/Download/Share tasks for TRP payouts.',
        'icon': Icons.task_alt_outlined,
        'color': Colors.teal,
        'reward': 'Per Task',
      },
      {
        'title': 'Brand Affiliate Commissions',
        'desc': 'Up to 50% on referred product sales.',
        'icon': Icons.attach_money_outlined,
        'color': Colors.indigo,
        'reward': '50%',
      },
      {
        'title': 'ADBOARD Revenue Share',
        'desc': 'Creators earn up to 80% of placement fees.',
        'icon': Icons.pie_chart_outline,
        'color': Colors.red,
        'reward': '80%',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF232323),
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
      body: SafeArea(
        child: Column(
          children: [
            TajifyTopBar(
              onSearch: () => context.push('/search'),
              onNotifications: () {
                context.push('/notifications').then((_) {
                  _loadNotificationUnreadCount();
                });
              },
              onMessages: () {
                context.push('/messages').then((_) {
                  _initializeFirebaseAndLoadMessagesCount();
                });
              },
              onAdd: () => context.go('/create'),
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserAvatar,
              displayLetter: _currentUserProfile?['name'] != null &&
                      _currentUserProfile!['name'].toString().isNotEmpty
                  ? _currentUserProfile!['name'].toString()[0].toUpperCase()
                  : _currentUserInitial,
            ),
            // Header Section
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurpleAccent.withOpacity(0.8), Colors.purple.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Earning Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          fontFamily: 'Ebrima',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Discover multiple ways to earn TAJI & TRP tokens',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontFamily: 'Ebrima',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Earning Methods List
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: earningMethods.length,
                  itemBuilder: (context, index) {
                    final method = earningMethods[index];
                    return AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final delay = index * 0.1;
                        final animationValue = (_animationController.value - delay).clamp(0.0, 1.0);
                        
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - animationValue)),
                          child: Opacity(
                            opacity: animationValue,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: method['color'] as Color,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (method['color'] as Color).withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Coming soon: ${method['title']}'),
                                        backgroundColor: method['color'] as Color,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: (method['color'] as Color).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            method['icon'] as IconData,
                                            color: method['color'] as Color,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                method['title'] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                  fontFamily: 'Ebrima',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                method['desc'] as String,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                  fontFamily: 'Ebrima',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (method['color'] as Color).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                method['reward'] as String,
                                                style: TextStyle(
                                                  color: method['color'] as Color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white.withOpacity(0.5),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            // Bottom Navigation Bar
            BottomNavigationBar(
              backgroundColor: const Color(0xFF232323),
              selectedItemColor: Colors.amber,
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
              currentIndex: 3, // Earn tab
              onTap: (int index) {
                if (index == 0) {
                  context.go('/connect');
                } else if (index == 1) {
                  context.go('/channel');
                } else if (index == 3) {
                  return; // Already on earn screen
                }
                // Add navigation for other tabs as needed
              },
            ),
          ],
        ),
      ),
    );
  }
} 