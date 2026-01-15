import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:go_router/go_router.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  int _unreadCount = 0;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_loadingMore) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _loading = true;
      });

      final response = await _apiService.getNotifications(limit: 20);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
          _unreadCount = response.data['unread_count'] ?? 0;
          _loading = false;
          _currentPage = 1;
          _hasMore = _notifications.length >= 20;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      print('[NOTIFICATION] Error loading notifications: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_loadingMore || !_hasMore) return;

    try {
      setState(() {
        _loadingMore = true;
      });

      final nextPage = _currentPage + 1;
      final response = await _apiService.getNotifications(limit: 20);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newNotifications = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
        
        if (newNotifications.isEmpty) {
          setState(() {
            _hasMore = false;
            _loadingMore = false;
          });
          return;
        }

        setState(() {
          _notifications.addAll(newNotifications);
          _currentPage = nextPage;
          _hasMore = newNotifications.length >= 20;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      print('[NOTIFICATION] Error loading more notifications: $e');
      setState(() {
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _unreadCount = response.data['data']['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      print('[NOTIFICATION] Error loading unread count: $e');
    }
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    try {
      final response = await _apiService.markNotificationAsRead(notificationId);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          _notifications[index]['is_read'] = true;
          _notifications[index]['read_at'] = response.data['data']['read_at'];
          if (_unreadCount > 0) {
            _unreadCount--;
          }
        });
      }
    } catch (e) {
      print('[NOTIFICATION] Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await _apiService.markAllNotificationsAsRead();
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          for (var notification in _notifications) {
            notification['is_read'] = true;
          }
          _unreadCount = 0;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[NOTIFICATION] Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(int notificationId, int index) async {
    try {
      final response = await _apiService.deleteNotification(notificationId);
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        setState(() {
          final wasUnread = _notifications[index]['is_read'] == false;
          _notifications.removeAt(index);
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
        });
      }
    } catch (e) {
      print('[NOTIFICATION] Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatTimeAgo(dynamic timeAgo, dynamic createdAt) {
    // If time_ago is already a formatted string from backend, use it directly
    if (timeAgo != null && timeAgo is String && timeAgo.isNotEmpty) {
      // Backend returns human-readable strings like "2 minutes ago", "3 hours ago"
      // But sometimes it might be in a different format, so we check
      if (!timeAgo.contains('T') && !timeAgo.contains('-')) {
        // It's likely already formatted, use it
        return timeAgo;
      }
    }
    
    // Otherwise, parse created_at and format it
    String? dateString;
    if (createdAt != null) {
      dateString = createdAt.toString();
    } else if (timeAgo != null) {
      dateString = timeAgo.toString();
    }
    
    if (dateString == null || dateString.isEmpty) return 'Just now';
    
    try {
      // Handle different date formats
      DateTime date;
      if (dateString.contains('T')) {
        // ISO 8601 format: "2024-01-15T10:30:00.000000Z"
        date = DateTime.parse(dateString);
      } else if (dateString.contains('-')) {
        // Date format: "2024-01-15 10:30:00"
        date = DateTime.parse(dateString);
      } else {
        // If it's not a parseable date, return as is or "Just now"
        return timeAgo?.toString() ?? 'Just now';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 30) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      // If parsing fails, try to use time_ago as is, or return "Just now"
      if (timeAgo != null && timeAgo is String) {
        return timeAgo;
      }
      return 'Just now';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'video_upload':
        return Icons.video_library;
      case 'earning':
        return Icons.attach_money;
      case 'staking':
        return Icons.lock;
      case 'mining':
        return Icons.diamond;
      case 'referral':
        return Icons.person_search;
      case 'video_gift':
        return Icons.card_giftcard;
      case 'lp_staking':
        return Icons.account_balance;
      case 'lp_rewards':
        return Icons.stars;
      case 'mining_deposit':
        return Icons.account_balance_wallet;
      case 'mining_rewards':
        return Icons.auto_awesome;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'follow':
        return Colors.blue;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.amber;
      case 'video_upload':
        return Colors.purple;
      case 'earning':
        return Colors.green;
      case 'staking':
        return Color(0xFFB875FB);
      case 'mining':
        return Colors.cyan;
      case 'referral':
        return Colors.teal;
      case 'video_gift':
        return Colors.pink;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.amber),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: Colors.amber,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                            ),
                          ),
                        );
                      }

                      final notification = _notifications[index];
                      final isRead = notification['is_read'] == true;
                      final type = notification['type']?.toString();
                      final title = notification['title']?.toString() ?? 'Notification';
                      final message = notification['message']?.toString() ?? '';
                      final timeAgo = _formatTimeAgo(notification['time_ago'], notification['created_at']);
                      final notificationId = notification['id'] as int?;

                      return Dismissible(
                        key: Key('notification_${notification['id']}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          if (notificationId != null) {
                            _deleteNotification(notificationId, index);
                          }
                        },
                        child: InkWell(
                          onTap: () {
                            if (!isRead && notificationId != null) {
                              _markAsRead(notificationId, index);
                            }
                            // TODO: Navigate to relevant screen based on notification type and data
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.05),
                              border: Border(
                                left: BorderSide(
                                  color: isRead
                                      ? Colors.transparent
                                      : _getNotificationColor(type),
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _getNotificationColor(type)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    _getNotificationIcon(type),
                                    color: _getNotificationColor(type),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          message,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

