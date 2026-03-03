import 'package:flutter/material.dart';

// Single brand color for clean UI
const Color kPrimary = Color(0xFFEA580C);

class TajifyTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMessages;
  final VoidCallback? onAvatarTap;
  final int notificationCount;
  final int messageCount;
  final String? avatarUrl;
  final String displayLetter;
  final bool showSearch;
  final bool showNotifications;
  final bool showMessages;
  final bool showAvatar;
  final bool showAddButton;
  final VoidCallback? onAdd;
  final EdgeInsetsGeometry padding;

  const TajifyTopBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.onSearch,
    this.onNotifications,
    this.onMessages,
    this.onAdd,
    this.showAddButton = true,
    this.onAvatarTap,
    this.notificationCount = 0,
    this.messageCount = 0,
    this.avatarUrl,
    this.displayLetter = 'U',
    this.showSearch = true,
    this.showNotifications = true,
    this.showMessages = true,
    this.showAvatar = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/tajify_icon.png',
                  height: 20,
                  width: 20,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Icon(Icons.videocam_rounded, color: kPrimary, size: 20),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tajify',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            _LivePill(),
            const SizedBox(width: 6),
            const Spacer(),
            if (showSearch)
              _iconBtn(Icons.search_rounded, onSearch, size: 22),
            if (showNotifications)
              _badgeBtn(Icons.notifications_none_rounded, notificationCount, onNotifications, size: 22),
            if (showMessages)
              _badgeBtn(Icons.chat_bubble_outline_rounded, messageCount, onMessages, size: 22),
            if (showAddButton && onAdd != null)
              _iconBtn(Icons.add_circle_outline, onAdd, size: 22),
            if (showAvatar) ...[
              Container(height: 20, width: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.white24),
              GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: kPrimary,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!.startsWith('http') ? avatarUrl! : 'https://api.tajify.com$avatarUrl')
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Text(
                          displayLetter.isNotEmpty ? displayLetter[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {double size = 20}) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 16, minHeight: size + 16),
      icon: Icon(icon, color: Colors.white, size: size),
    );
  }

  Widget _badgeBtn(IconData icon, int count, VoidCallback? onTap, {double size = 20}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _iconBtn(icon, onTap, size: size),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(48);
}

class _LivePill extends StatefulWidget {
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2 + _controller.value * 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red.withOpacity(0.6), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.8), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}
