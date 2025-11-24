import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class TajStarsGiftModal extends StatefulWidget {
  final int postId;
  final int receiverId;
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

class _TajStarsGiftModalState extends State<TajStarsGiftModal>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();

  bool _loadingGifts = false;
  bool _walletLoading = false;
  bool _sendingGift = false;
  bool _showCelebration = false;
  bool _isAnonymous = false;
  String? _errorMessage;
  String? _walletError;
  String? _successMessage;
  double? _walletBalance;
  List<Map<String, dynamic>> _availableGifts = [];
  Map<String, dynamic>? _selectedGift;
  int _giftQuantity = 1;

  final List<int> _quantityPresets = [1, 5, 10];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    _loadGiftCatalog();
    _loadWalletBalance();
  }

  Future<void> _loadGiftCatalog() async {
    setState(() {
      _loadingGifts = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getGifts();
      final payload = response.data;
      final gifts = _normalizeGiftPayload(payload);
      if (mounted) {
        setState(() {
          _availableGifts = gifts;
          if (gifts.isNotEmpty) {
            _selectedGift ??= gifts.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableGifts = [];
          _errorMessage = 'Unable to load gifts. Pull to refresh.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingGifts = false;
        });
      }
    }
  }

  Future<void> _loadWalletBalance() async {
    setState(() {
      _walletLoading = true;
      _walletError = null;
    });
    try {
      final response = await _apiService.getWallet();
      final balance = _extractWalletBalance(response.data);
      if (mounted) {
        setState(() {
          _walletBalance = balance;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletError = 'Unable to fetch wallet balance';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _walletLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _normalizeGiftPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((gift) => Map<String, dynamic>.from(gift))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      if (payload['data'] is List) {
        return (payload['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList();
      }
      if (payload['gifts'] is List) {
        return (payload['gifts'] as List)
            .whereType<Map<String, dynamic>>()
            .map((gift) => Map<String, dynamic>.from(gift))
            .toList();
      }
    }
    return [];
  }

  double? _extractWalletBalance(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final root = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : payload;
      final walletData = root['wallet'] is Map<String, dynamic>
          ? root['wallet'] as Map<String, dynamic>
          : root;
      final dynamic value = walletData['tajstarsCoins'] ??
          walletData['tajstars_balance'] ??
          walletData['coins'] ??
          walletData['tajstars'];
      return _parseDouble(value);
    }
    if (payload is num) return payload.toDouble();
    return null;
  }

  double _calculateTotalCost() {
    final price = _selectedGift != null
        ? _parseDouble(_selectedGift!['price']) ?? 0
        : 0;
    return price * _giftQuantity.toDouble();
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;
    final giftId = _parseInt(_selectedGift!['id']);
    if (giftId == null) {
      setState(() => _errorMessage = 'Invalid gift selection.');
      return;
    }

    final totalCost = _calculateTotalCost();

    setState(() {
      _sendingGift = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.sendGift(
        giftId: giftId,
        receiverId: widget.receiverId,
        postId: widget.postId,
        quantity: _giftQuantity,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        isAnonymous: _isAnonymous,
      );

      final payload = response.data;
      final success = payload is Map<String, dynamic>
          ? (payload['success'] != false)
          : true;
      if (!success) {
        final message = payload['message'] ?? 'Unable to send gift.';
        setState(() {
          _errorMessage = message.toString();
        });
        return;
      }

      final remainingBalance = payload['data']?['remaining_balance'] ??
          payload['remaining_balance'];
      if (mounted) {
        setState(() {
          _walletBalance =
              _parseDouble(remainingBalance) ?? _walletBalance ?? 0.0;
        });
      }

      _playCelebration(totalCost);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send gift. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingGift = false;
        });
      }
    }
  }

  void _playCelebration(double giftValue) {
    setState(() {
      _showCelebration = true;
      _successMessage =
          'Sent ${_selectedGift?['name'] ?? 'gift'} (${giftValue.toStringAsFixed(0)} TajStars)';
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pop({
        'giftName': _selectedGift?['name'] ?? 'TajStars',
        'giftValue': giftValue,
      });
    });
  }

  Future<void> _refreshGiftData() async {
    await Future.wait([
      _loadGiftCatalog(),
      _loadWalletBalance(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _calculateTotalCost();
    final hasSufficientBalance = _walletBalance == null ||
        (_walletBalance ?? 0) >= totalCost;

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.purple.withOpacity(0.35),
                Colors.blue.withOpacity(0.18),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    _buildHandleBar(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshGiftData,
                        color: Colors.amber,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 16),
                            _buildWalletSummary(),
                            if (_walletError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _walletError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SlideTransition(
                              position: _slideAnimation,
                              child: ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildGiftGrid(),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildQuantitySelector(),
                            const SizedBox(height: 16),
                            _buildMessageField(),
                            const SizedBox(height: 24),
                            if (!hasSufficientBalance && _walletBalance != null)
                              _buildBalanceWarning(totalCost),
                            _buildSendButton(
                              totalCost,
                              hasSufficientBalance,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: _loadGiftCatalog,
                                child: const Text(
                                  'Reload gifts',
                                  style: TextStyle(color: Colors.amber),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showCelebration) _buildCelebrationOverlay(),
      ],
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.amber, Colors.orange],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.fromARGB(180, 255, 215, 0),
                        Color.fromARGB(0, 255, 215, 0),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.amber,
                    size: 56,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Send TajStars',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Show ${widget.receiverName} some love ✨',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.receiverAvatar != null
                      ? NetworkImage(widget.receiverAvatar!)
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: widget.receiverAvatar == null
                      ? Text(
                          widget.receiverName.isNotEmpty
                              ? widget.receiverName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Every TajStar boosts their earnings',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.postThumbnail != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.postThumbnail!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child:
                            const Icon(Icons.play_arrow, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSummary() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(0.25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.blue],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.savings_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _walletLoading
                      ? 'Fetching balance...'
                      : '${(_walletBalance ?? 0).toStringAsFixed(0)} TajStars',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Available balance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _walletLoading ? null : _loadWalletBalance,
            icon: Icon(
              Icons.refresh,
              color: _walletLoading ? Colors.grey : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    if (_loadingGifts) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    if (_availableGifts.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.card_giftcard, color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          const Text(
            'No gifts available right now.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _availableGifts.length,
      itemBuilder: (context, index) {
        final gift = _availableGifts[index];
        final isSelected = identical(gift, _selectedGift);
        final rarity = gift['rarity']?.toString() ?? 'common';
        final price = _parseDouble(gift['price']) ?? 0;
        return GestureDetector(
          onTap: () => setState(() => _selectedGift = gift),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.amber
                    : Colors.white.withOpacity(0.15),
                width: isSelected ? 2.5 : 1,
              ),
              color: isSelected
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.04),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        rarity.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.workspace_premium,
                      color: isSelected ? Colors.amber : Colors.white54,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  gift['name']?.toString() ?? 'Mystery Gift',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(0)} TajStars',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quantity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _quantityPresets.map((value) {
            final selected = _giftQuantity == value;
            return ChoiceChip(
              label: Text('$value'),
              selected: selected,
              onSelected: (_) => setState(() => _giftQuantity = value),
              selectedColor: Colors.amber,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white,
              ),
              backgroundColor: Colors.white.withOpacity(0.1),
            );
          }).toList(),
        ),
        Slider(
          value: _giftQuantity.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          activeColor: Colors.amber,
          label: '$_giftQuantity',
          onChanged: (value) => setState(() {
            _giftQuantity = value.round().clamp(1, 50);
          }),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message (optional)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _messageController,
          maxLength: 120,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: Colors.white54),
            hintText: 'Send a note with your gift...',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: _isAnonymous,
              activeColor: Colors.amber,
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value ?? false;
                });
              },
            ),
            const Text(
              'Send anonymously',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceWarning(double totalCost) {
    final deficit = totalCost - (_walletBalance ?? 0);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You need ${deficit.toStringAsFixed(0)} more TajStars to send this gift.',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(double totalCost, bool hasBalance) {
    final buttonEnabled =
        _selectedGift != null && !_sendingGift && hasBalance;
    final label = _selectedGift == null
        ? 'Select a gift'
        : hasBalance
            ? 'Send ${_selectedGift?['name'] ?? 'Gift'}'
            : 'Insufficient balance';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: buttonEnabled
            ? const LinearGradient(
                colors: [Colors.amber, Colors.orange],
              )
            : null,
        color: buttonEnabled ? null : Colors.white.withOpacity(0.15),
      ),
      child: ElevatedButton(
        onPressed: buttonEnabled ? _sendGift : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: _sendingGift
            ? const CircularProgressIndicator(color: Colors.black)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_selectedGift != null && hasBalance) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${totalCost.toStringAsFixed(0)} TajStars',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildCelebrationOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _showCelebration ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _successMessage ?? 'Gift Sent!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

