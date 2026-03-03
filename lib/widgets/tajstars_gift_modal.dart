import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

/// Gift modal matching web: bottom sheet, gifts from API, balance, "Get more TajStars", send gift.
class TajStarsGiftModal extends StatefulWidget {
  final dynamic postId;
  final dynamic receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final String? postThumbnail;

  const TajStarsGiftModal({
    required this.postId,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    this.postThumbnail,
    super.key,
  });

  @override
  State<TajStarsGiftModal> createState() => _TajStarsGiftModalState();
}

class _TajStarsGiftModalState extends State<TajStarsGiftModal> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();

  bool _loading = false;
  bool _sending = false;
  bool _showSuccess = false;
  Map<String, dynamic>? _successGift;
  double? _balance;
  String? _walletError;
  List<Map<String, dynamic>> _gifts = [];
  Map<String, dynamic>? _selectedGift;

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _bg = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _walletError = null;
    });
    try {
      await Future.wait([_loadGifts(), _loadWallet()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGifts() async {
    try {
      final res = await _apiService.getGifts();
      final data = res.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      }
      if (mounted) {
        setState(() {
          _gifts = list.whereType<Map<String, dynamic>>().map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gifts = []);
    }
  }

  Future<void> _loadWallet() async {
    try {
      final res = await _apiService.getWallet();
      final data = res.data;
      if (data is Map && data['data'] is Map) {
        final w = data['data'] as Map<String, dynamic>;
        final b = w['tajstars_balance'];
        if (mounted) setState(() => _balance = _toDouble(b));
        return;
      }
      if (data is Map && data['tajstars_balance'] != null) {
        if (mounted) setState(() => _balance = _toDouble(data['tajstars_balance']));
      }
    } catch (_) {
      if (mounted) setState(() => _walletError = 'Could not load balance');
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  double _giftCost(Map<String, dynamic> g) {
    return _toDouble(g['cost']) ?? _toDouble(g['price']) ?? 0;
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;
    final cost = _giftCost(_selectedGift!);
    final bal = _balance ?? 0;
    if (bal < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient TajStars balance')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final giftId = _toInt(_selectedGift!['id']) ?? _toInt(_selectedGift!['_id']);
      if (giftId == null) throw Exception('Invalid gift');

      final res = await _apiService.sendGift(
        giftId: giftId,
        receiverId: widget.receiverId,
        postId: widget.postId,
        quantity: 1,
        message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
      );

      final data = res.data;
      if (data is Map && data['success'] == true) {
        final newBal = _toDouble(data['new_balance']);
        if (newBal != null && mounted) setState(() => _balance = newBal);
        if (mounted) {
          setState(() {
            _showSuccess = true;
            _successGift = _selectedGift;
          });
        }
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        final navigator = Navigator.of(context);
        navigator.pop({'sent': true, 'gift': _selectedGift});
      } else {
        throw Exception((data is Map ? data['message']?.toString() : null) ?? 'Failed to send gift');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openBuyTajStars() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _BuyTajStarsSheet(
        onSuccess: () {
          Navigator.of(ctx).pop();
          _loadWallet();
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess && _successGift != null) {
      return _buildSuccessOverlay();
    }

    final balance = _balance ?? 0;
    final cost = _selectedGift != null ? _giftCost(_selectedGift!) : 0.0;
    final canSend = _selectedGift != null && !_sending && balance >= cost;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.fromBorderSide(BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(balance),
          _buildRecipient(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _amber))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: _amber,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildGiftGrid(),
                    ),
                  ),
          ),
          _buildFooter(canSend, cost),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
    );
  }

  Widget _buildHeader(double balance) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, color: _amber, size: 22),
          const SizedBox(width: 8),
          const Text('Send a Gift', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFBBF24), size: 16),
                const SizedBox(width: 6),
                Text('${balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipient() {
    final name = widget.receiverName.startsWith('@') ? widget.receiverName : '@${widget.receiverName}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _amber.withOpacity(0.2),
            backgroundImage: widget.receiverAvatar != null && widget.receiverAvatar!.isNotEmpty
                ? NetworkImage(widget.receiverAvatar!.startsWith('http') ? widget.receiverAvatar! : 'https://api.tajify.com${widget.receiverAvatar}')
                : null,
            child: widget.receiverAvatar == null || widget.receiverAvatar!.isEmpty
                ? const Icon(Icons.person, color: _amber)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gifting to', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    if (_gifts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No gifts available', style: TextStyle(color: Colors.white54))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, i) {
        final g = _gifts[i];
        final selected = _selectedGift != null && (_toInt(g['id']) == _toInt(_selectedGift!['id']) || _toInt(g['_id']) == _toInt(_selectedGift!['_id']));
        final iconUrl = g['icon_url']?.toString();
        final name = g['name']?.toString() ?? 'Gift';
        final cost = _giftCost(g);
        return GestureDetector(
          onTap: () => setState(() => _selectedGift = g),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? _amber.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? _amber : Colors.transparent, width: 2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRect(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        if (iconUrl != null && iconUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              iconUrl.startsWith('http') ? iconUrl : 'https://api.tajify.com$iconUrl',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: _amber, size: 40),
                            ),
                          )
                        else
                          const Icon(Icons.card_giftcard, color: _amber, size: 40),
                        const SizedBox(height: 4),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on, color: Color(0xFFFBBF24), size: 10),
                            const SizedBox(width: 2),
                            Text('${cost.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                  ],
                ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(bool canSend, double cost) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0A0A0A), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _messageController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a message (optional)...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _openBuyTajStars,
                child: const Text('Get more TajStars', style: TextStyle(color: _amber, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: canSend ? _sendGift : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSend ? _amber : Colors.grey.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _sending
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Send Gift'),
                          SizedBox(width: 8),
                          Icon(Icons.send, size: 18),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    final g = _successGift!;
    final iconUrl = g['icon_url']?.toString();
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFEC4899), Color(0xFFF43F5E)]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 4),
                boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.5), blurRadius: 40)],
              ),
              child: Center(
                child: iconUrl != null && iconUrl.isNotEmpty
                    ? Image.network(iconUrl.startsWith('http') ? iconUrl : 'https://api.tajify.com$iconUrl', width: 96, height: 96, fit: BoxFit.contain)
                    : const Icon(Icons.card_giftcard, size: 80, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${g['name'] ?? 'Gift'} sent! ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to buy TajStars (matches web WalletModal). Node: /wallet/fund/initialize, open URL, /wallet/fund/verify.
class _BuyTajStarsSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onClose;

  const _BuyTajStarsSheet({required this.onSuccess, required this.onClose});

  @override
  State<_BuyTajStarsSheet> createState() => _BuyTajStarsSheetState();
}

class _BuyTajStarsSheetState extends State<_BuyTajStarsSheet> {
  final ApiService _apiService = ApiService();

  static const List<Map<String, dynamic>> _packages = [
    {'stars': 10, 'price': 150},
    {'stars': 50, 'price': 750},
    {'stars': 100, 'price': 1500},
    {'stars': 500, 'price': 7500},
    {'stars': 1000, 'price': 15000},
  ];

  bool _loading = false;
  String? _error;

  Future<void> _purchase(int stars, int priceNaira) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _apiService.initializeNairaFund(priceNaira.toDouble());
      final data = res.data;
      if (data is! Map || data['success'] != true) {
        setState(() => _error = 'Could not start payment');
        return;
      }
      final url = data['authorization_url']?.toString();
      final ref = data['reference']?.toString();
      if (url == null || url.isEmpty) {
        setState(() => _error = 'No payment URL returned');
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      _showVerifyDialog(ref, stars);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVerifyDialog(String? ref, int stars) {
    final refController = TextEditingController(text: ref ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Verify payment', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('After paying, paste the reference here to add $stars TajStars.', style: TextStyle(color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              decoration: InputDecoration(
                hintText: 'Reference',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final reference = refController.text.trim();
              if (reference.isEmpty) return;
              Navigator.of(ctx).pop();
              await _verify(reference, stars);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(String reference, int stars) async {
    try {
      final res = await _apiService.verifyNairaFund(reference);
      final data = res.data;
      if (data is Map && data['success'] == true) {
        widget.onSuccess();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${data['taj_stars'] ?? stars} TajStars!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text((data is Map ? data['message']?.toString() : null) ?? 'Verification failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Top Up TajStars', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close, color: Colors.white54)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          ..._packages.map((p) {
            final stars = p['stars'] as int;
            final price = p['price'] as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _loading ? null : () => _purchase(stars, price),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text('$stars', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$stars TajStars', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Best value', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('₦${price.toString()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Center(child: Text('Secured by Paystack', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))),
        ],
      ),
    );
  }
}
