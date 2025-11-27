import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/storage_service.dart';
import '../widgets/tajify_top_bar.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Top bar state
  int _notificationUnreadCount = 0;
  Timer? _notificationTimer;
  int _messagesUnreadCount = 0;
  StreamSubscription<int>? _messagesCountSubscription;
  String? _currentUserAvatar;
  String _currentUserInitial = 'U';
  Map<String, dynamic>? _currentUserProfile;

  // Market data
  List<Map<String, dynamic>> _marketItems = [];
  bool _loadingItems = true;
  bool _loadingMore = false;
  String? _itemsError;
  int _currentPage = 1;
  int _lastPage = 1;
  final int _perPage = 12;

  final List<Map<String, dynamic>> _categories = const [
    {
      'id': 'digital-products',
      'label': 'Digital',
      'icon': Icons.cloud_download_outlined,
    },
    {
      'id': 'tickets-vouchers',
      'label': 'Tickets',
      'icon': Icons.confirmation_number_outlined,
    },
    {
      'id': 'job-offerings',
      'label': 'Jobs',
      'icon': Icons.work_outline,
    },
  ];

  String _activeCategory = 'digital-products';
  String? _selectedTag;
  bool? _isPaidFilter;
  String _searchQuery = '';

  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadUserProfile();
    _loadNotificationUnreadCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadNotificationUnreadCount());
    _initializeFirebaseAndLoadMessagesCount();
    _fetchMarketItems(reset: true);
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _messagesCountSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isUserVerified {
    final status = _currentUserProfile?['citizenship_status']?.toString().toLowerCase();
    return status == 'verified' || status == 'vip';
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && !_loadingItems && _currentPage < _lastPage) {
        _fetchMarketItems(reset: false);
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
      // ignored
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
      // ignored
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
      // ignored
    }
  }

  Future<void> _fetchMarketItems({required bool reset}) async {
    if (reset) {
      setState(() {
        _loadingItems = true;
        _itemsError = null;
        _currentPage = 1;
        _lastPage = 1;
        _marketItems = [];
      });
    } else {
      setState(() {
        _loadingMore = true;
        _itemsError = null;
        _currentPage += 1;
      });
    }

    try {
      final response = await _apiService.getMarketItems(
        category: _activeCategory,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        isPaid: _isPaidFilter,
        page: _currentPage,
        perPage: _perPage,
      );

      final raw = response.data;
      if (raw['success'] != true) {
        throw Exception(raw['message'] ?? 'Failed to load market items');
      }

      final data = raw['data'];
      List<dynamic> itemsList = [];
      int currentPage = _currentPage;
      int lastPage = _lastPage;

      if (data is Map<String, dynamic>) {
        if (data['data'] is List) {
          itemsList = data['data'] as List<dynamic>;
        }
        currentPage = data['current_page'] is int ? data['current_page'] as int : currentPage;
        lastPage = data['last_page'] is int ? data['last_page'] as int : lastPage;
      } else if (data is List) {
        itemsList = data;
      }

      final mapped = itemsList
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        if (reset) {
          _marketItems = mapped;
        } else {
          final existingUuids = _marketItems.map((e) => e['uuid']).toSet();
          final newOnes = mapped.where((item) => !existingUuids.contains(item['uuid'])).toList();
          _marketItems.addAll(newOnes);
        }
        _currentPage = currentPage;
        _lastPage = lastPage;
        _extractTags();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _itemsError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingItems = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _extractTags() {
    final tags = <String>{};
    for (final item in _marketItems) {
      final rawTags = item['tags'];
      if (rawTags is List) {
        for (final tag in rawTags) {
          if (tag is String && tag.isNotEmpty) {
            tags.add(tag);
          }
        }
      }
    }
    setState(() {
      _availableTags = tags.toList()..sort();
    });
  }

  List<Map<String, dynamic>> get _displayItems {
    if (_selectedTag == null || _selectedTag == 'all') return _marketItems;
    return _marketItems.where((item) {
      final rawTags = item['tags'];
      if (rawTags is List) {
        return rawTags.map((tag) => tag.toString()).contains(_selectedTag);
      }
      return false;
    }).toList();
  }

  Future<void> _refresh() async {
    await _fetchMarketItems(reset: true);
  }

  void _changeCategory(String category) {
    if (_activeCategory == category) return;
    setState(() {
      _activeCategory = category;
      _selectedTag = null;
      _isPaidFilter = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchMarketItems(reset: true);
  }

  void _applyTag(String? tag) {
    setState(() {
      if (tag == null || tag == 'all') {
        _selectedTag = null;
      } else {
        _selectedTag = tag;
      }
    });
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
    _fetchMarketItems(reset: true);
  }

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final uuid = item['uuid']?.toString();
    if (uuid == null) return;

    final index = _marketItems.indexWhere((element) => element['uuid'] == uuid);
    if (index == -1) return;

    final currentLikes = (_marketItems[index]['likes_count'] ?? 0) as int;
    setState(() {
      _marketItems[index]['likes_count'] = currentLikes + 1;
    });

    try {
      final response = await _apiService.toggleMarketItemLike(uuid);
      final data = response.data;
      if (data['success'] == true) {
        final likes = data['data']?['likes_count'] ?? currentLikes + 1;
        if (mounted) {
          setState(() {
            _marketItems[index]['likes_count'] = likes;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _marketItems[index]['likes_count'] = currentLikes;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _marketItems[index]['likes_count'] = currentLikes;
        });
      }
    }
  }

  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _searchQuery);
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Search Market', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search listings...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
            onSubmitted: (value) {
              Navigator.of(context).pop();
              _applySearch(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                controller.dispose();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _applySearch(controller.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Filter',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _filterOptionTile(
                label: 'All listings',
                selected: _isPaidFilter == null,
                onTap: () {
                  setState(() => _isPaidFilter = null);
                  Navigator.of(context).pop();
                  _fetchMarketItems(reset: true);
                },
              ),
              _filterOptionTile(
                label: 'Paid listings',
                selected: _isPaidFilter == true,
                onTap: () {
                  setState(() => _isPaidFilter = true);
                  Navigator.of(context).pop();
                  _fetchMarketItems(reset: true);
                },
              ),
              _filterOptionTile(
                label: 'Free listings',
                selected: _isPaidFilter == false,
                onTap: () {
                  setState(() => _isPaidFilter = false);
                  Navigator.of(context).pop();
                  _fetchMarketItems(reset: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterOptionTile({required String label, required bool selected, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.amber : Colors.white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected ? const Icon(Icons.check_circle, color: Colors.amber) : null,
    );
  }

  void _showCreateListingSheet() {
    if (_activeCategory == 'job-offerings' && !_isUserVerified) {
      _showSnack('Only verified citizens can create job offerings', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final titleController = TextEditingController();
        final descriptionController = TextEditingController();
        final tagsController = TextEditingController();
        final priceController = TextEditingController();
        final locationController = TextEditingController();
        final availabilityController = TextEditingController();
        final requirementsController = TextEditingController();
        final salaryController = TextEditingController();
        DateTime? eventDate;

        String category = _activeCategory;
        bool isPaid = false;
        String paymentMethod = 'tajstars';
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (titleController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
                _showSnack('Title and description are required', isError: true);
                return;
              }

              if (category == 'job-offerings' && !_isUserVerified) {
                _showSnack('Only verified citizens can create job offerings', isError: true);
                return;
              }

              double? price;
              if (isPaid) {
                price = double.tryParse(priceController.text.trim());
                if (price == null) {
                  _showSnack('Enter a valid price', isError: true);
                  return;
                }
              }

              setSheetState(() => submitting = true);

              final payload = <String, dynamic>{
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'category': category,
                'is_paid': isPaid,
                'tags': tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList(),
              };

              if (category == 'tickets-vouchers') {
                if (locationController.text.trim().isNotEmpty) {
                  payload['location'] = locationController.text.trim();
                }
                if (eventDate != null) {
                  payload['event_date'] = eventDate!.toIso8601String();
                }
              }

              if (category == 'job-offerings') {
                if (locationController.text.trim().isNotEmpty) {
                  payload['location'] = locationController.text.trim();
                }
                if (availabilityController.text.trim().isNotEmpty) {
                  payload['availability'] = availabilityController.text.trim();
                }
                if (requirementsController.text.trim().isNotEmpty) {
                  payload['requirements'] = requirementsController.text.trim();
                }
                if (salaryController.text.trim().isNotEmpty) {
                  payload['salary'] = salaryController.text.trim();
                }
              }

              if (isPaid && price != null) {
                payload['payment_methods'] = [
                  {
                    'method': paymentMethod,
                    'enabled': true,
                    'price': price,
                  },
                ];
              }

              try {
                final response = await _apiService.createMarketItem(payload);
                if (response.data['success'] == true) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    _showSnack('Listing created successfully');
                    _fetchMarketItems(reset: true);
                  }
                } else {
                  throw Exception(response.data['message'] ?? 'Unable to create listing');
                }
              } catch (e) {
                _showSnack(e.toString(), isError: true);
                setSheetState(() => submitting = false);
              }
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now.add(const Duration(days: 1)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setSheetState(() {
                  eventDate = picked;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
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
                          const Text(
                            'New Listing',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: submitting ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: category,
                        dropdownColor: const Color(0xFF1E1E1E),
                        decoration: _inputDecoration('Category'),
                        items: _categories
                            .map(
                              (cat) => DropdownMenuItem<String>(
                                value: cat['id']?.toString(),
                                child: Text(cat['label']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                if (value == 'job-offerings' && !_isUserVerified) {
                                  _showSnack('Only verified citizens can create job offerings', isError: true);
                                  return;
                                }
                                setSheetState(() {
                                  category = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        enabled: !submitting,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        enabled: !submitting,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Description'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsController,
                        enabled: !submitting,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Tags (comma separated)'),
                      ),
                      const SizedBox(height: 12),
                      if (category != 'digital-products')
                        TextField(
                          controller: locationController,
                          enabled: !submitting,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(category == 'job-offerings' ? 'Job Location' : 'Event Location'),
                        ),
                      if (category == 'job-offerings') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: availabilityController,
                          enabled: !submitting,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Availability'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: requirementsController,
                          enabled: !submitting,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Requirements'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: salaryController,
                          enabled: !submitting,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Salary'),
                        ),
                      ],
                      if (category == 'tickets-vouchers') ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: submitting ? null : pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event, color: Colors.white70),
                                const SizedBox(width: 12),
                                Text(
                                  eventDate == null ? 'Select event date' : '${eventDate!.toLocal()}'.split(' ')[0],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        value: isPaid,
                        activeColor: Colors.amber,
                        title: const Text('Paid listing', style: TextStyle(color: Colors.white)),
                        onChanged: submitting
                            ? null
                            : (value) {
                                setSheetState(() {
                                  isPaid = value;
                                });
                              },
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          dropdownColor: const Color(0xFF1E1E1E),
                          decoration: _inputDecoration('Payment Token'),
                          items: const [
                            DropdownMenuItem(value: 'tajstars', child: Text('TAJSTARS', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'taji', child: Text('TAJI', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'usdt', child: Text('USDT', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: submitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setSheetState(() => paymentMethod = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: priceController,
                          enabled: !submitting,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Price'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(submitting ? 'Publishing...' : 'Publish Listing'),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
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
        borderSide: const BorderSide(color: Colors.amber),
      ),
    );
  }

  Future<void> _showMyListings() async {
    try {
      final response = await _apiService.getUserMarketItems(category: _activeCategory);
      final raw = response.data;
      if (raw['success'] == true) {
        final data = raw['data'];
        List<Map<String, dynamic>> listings = [];
        if (data is Map<String, dynamic> && data['data'] is List) {
          listings = (data['data'] as List).whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data is List) {
          listings = data.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
        }

        if (listings.isEmpty) {
          _showSnack('You have no listings in this category');
          return;
        }

        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'My Listings',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: listings.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white24, height: 1),
                      itemBuilder: (context, index) {
                        final item = listings[index];
                        return ListTile(
                          onTap: () {
                            Navigator.of(context).pop();
                            _showItemDetails(item);
                          },
                          title: Text(item['title']?.toString() ?? 'Untitled', style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            item['description']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            item['is_paid'] == true ? 'Paid' : 'Free',
                            style: TextStyle(color: item['is_paid'] == true ? Colors.amber : Colors.greenAccent),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        throw Exception(raw['message'] ?? 'Unable to fetch listings');
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final images = item['images'] is List ? (item['images'] as List).whereType<Map<String, dynamic>>().toList() : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['title']?.toString() ?? 'Listing',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              final url = images[index]['image_url']?.toString();
                              if (url == null || url.isEmpty) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.white, size: 40),
                                  ),
                                );
                              }
                              return Container(
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(url, fit: BoxFit.cover),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.storefront, color: Colors.white, size: 40),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(item['description']?.toString() ?? '', style: const TextStyle(color: Colors.white70, height: 1.4)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _detailChip(Icons.category, item['category']?.toString() ?? ''),
                          if (item['is_paid'] == true)
                            _detailChip(Icons.monetization_on, 'Paid'),
                          if (item['location'] != null && item['location'].toString().isNotEmpty)
                            _detailChip(Icons.location_on, item['location'].toString()),
                          if (item['availability'] != null && item['availability'].toString().isNotEmpty)
                            _detailChip(Icons.calendar_today, item['availability'].toString()),
                          if (item['salary'] != null && item['salary'].toString().isNotEmpty)
                            _detailChip(Icons.attach_money, item['salary'].toString()),
                          if (item['event_date'] != null)
                            _detailChip(Icons.event, DateTime.tryParse(item['event_date'].toString())?.toLocal().toString().split(' ').first ?? ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (item['tags'] is List && (item['tags'] as List).isNotEmpty) ...[
                        const Text('Tags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: (item['tags'] as List)
                              .map((tag) => tag.toString())
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor: const Color(0xFF2D2D2D),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (item['requirements'] != null && item['requirements'].toString().isNotEmpty) ...[
                        const Text('Requirements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(item['requirements'].toString(), style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _toggleLike(item);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Like (${item['likes_count'] ?? 0})'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showSnack('Thanks for your interest!');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(
                          item['category'] == 'job-offerings'
                              ? 'Apply'
                              : item['is_paid'] == true
                                  ? 'Purchase'
                                  : 'Get Access',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailChip(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF2D2D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
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

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isActive = _activeCategory == category['id'];
          return ChoiceChip(
            selected: isActive,
            onSelected: (_) => _changeCategory(category['id']!),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  category['icon'] as IconData? ?? Icons.category_outlined,
                  size: 18,
                  color: isActive ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(category['label'] ?? ''),
              ],
            ),
            selectedColor: Colors.amber,
            backgroundColor: const Color(0xFF1D1D1D),
            labelStyle: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: _categories.length,
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search listings...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white.withOpacity(0.7)),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch('');
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.filter_alt_outlined, color: _isPaidFilter == null ? Colors.white.withOpacity(0.7) : Colors.amber),
                    onPressed: _showFilterSheet,
                  ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.amber),
              ),
            ),
            onSubmitted: _applySearch,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateListingSheet,
                icon: const Icon(Icons.add),
                label: const Text('List an Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showMyListings,
                icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
                label: const Text('My Listings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilters() {
    if (_availableTags.isEmpty) return const SizedBox.shrink();
    final tags = ['all', ..._availableTags];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final tag = tags[index];
          final isActive = _selectedTag == null && tag == 'all' || _selectedTag == tag;
          return ChoiceChip(
            selected: isActive,
            onSelected: (_) => _applyTag(tag == 'all' ? null : tag),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(tag == 'all' ? 'All tags' : tag),
            ),
            selectedColor: Colors.amber,
            backgroundColor: const Color(0xFF1D1D1D),
            labelStyle: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tags.length,
      ),
    );
  }

  Widget _buildContent() {
    if (_activeCategory == 'job-offerings' && !_isUserVerified) {
      return _buildVerificationGate();
    }

    if (_loadingItems && _marketItems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)),
      );
    }

    if (_itemsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_itemsError!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchMarketItems(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_displayItems.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty ? 'No listings match your search' : 'No listings yet in this category',
        Icons.storefront_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.amber,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _displayItems.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _displayItems.length) {
            return const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.amber)),
            );
          }
          final item = _displayItems[index];
          return _buildMarketCard(item);
        },
      ),
    );
  }

  Widget _buildVerificationGate() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF8C00)]),
            ),
            child: const Icon(Icons.verified_user, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verified citizens only',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade your account to verified status to browse and publish job opportunities.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Upgrade account'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCard(Map<String, dynamic> item) {
    final images = item['images'] is List ? (item['images'] as List) : [];
    final coverImage = item['cover_image_url'] ??
        (images.isNotEmpty ? (images.first is Map ? images.first['image_url'] : null) : null);
    final bool isJob = item['category'] == 'job-offerings';

    return GestureDetector(
      onTap: () => _showItemDetails(item),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D1D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: coverImage != null && coverImage.toString().isNotEmpty
                    ? Image.network(coverImage.toString(), fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _categories.firstWhere((c) => c['id'] == item['category'], orElse: () => _categories[0])['icon'] as IconData? ?? Icons.storefront_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? 'Untitled',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['description']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isJob
                                    ? (item['salary']?.toString().isNotEmpty == true ? item['salary'].toString() : 'Negotiable')
                                    : item['is_paid'] == true
                                        ? _formatPaymentMethods(item['payment_methods'])
                                        : 'Free',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: item['is_paid'] == true ? Colors.amber : Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite, color: Colors.white.withOpacity(0.6), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  (item['likes_count'] ?? 0).toString(),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => _toggleLike(item),
                              child: Icon(
                                Icons.favorite_border,
                                color: Colors.white.withOpacity(0.6),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPaymentMethods(dynamic methods) {
    if (methods is List && methods.isNotEmpty) {
      final parsed = methods.whereType<Map>().map((method) {
        final currency = method['method']?.toString().toUpperCase() ?? 'TOKEN';
        final price = method['price']?.toString() ?? '';
        return '$currency $price';
      }).join(' · ');
      return parsed;
    }
    return 'Paid';
  }


  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white12,
            child: Icon(icon, color: Colors.white70, size: 32),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF0F0F0F),
      selectedItemColor: Colors.amber,
      unselectedItemColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: 2,
      onTap: (index) {
        if (index == 0) {
          context.go('/connect');
        } else if (index == 1) {
          context.go('/channel');
        } else if (index == 3) {
          context.go('/earn');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Connect'),
        BottomNavigationBarItem(icon: Icon(Icons.live_tv_outlined), label: 'Channel'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), label: 'Market'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_graph_outlined), label: 'Earn'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
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
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            TajifyTopBar(
              onSearch: _openSearchDialog,
              onNotifications: () => context.push('/notifications').then((_) => _loadNotificationUnreadCount()),
              onMessages: () => context.push('/messages').then((_) => _initializeFirebaseAndLoadMessagesCount()),
              onAdd: () => context.go('/create'),
              onAvatarTap: () => context.go('/profile'),
              notificationCount: _notificationUnreadCount,
              messageCount: _messagesUnreadCount,
              avatarUrl: _currentUserAvatar,
              displayLetter: _currentUserInitial,
            ),
            _buildCategoryTabs(),
            _buildSearchRow(),
            _buildTagFilters(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}