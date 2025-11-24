import 'package:flutter/material.dart';

class TajifyTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMessages;
  final VoidCallback? onAdd;
  final VoidCallback? onAvatarTap;
  final int notificationCount;
  final int messageCount;
  final String? avatarUrl;
  final String displayLetter;
  final bool showSearch;
  final bool showNotifications;
  final bool showMessages;
  final bool showAddButton;
  final bool showAvatar;
  final EdgeInsetsGeometry padding;

  const TajifyTopBar({
    super.key,
    this.showBackButton = false,
    this.onBack,
    this.onSearch,
    this.onNotifications,
    this.onMessages,
    this.onAdd,
    this.onAvatarTap,
    this.notificationCount = 0,
    this.messageCount = 0,
    this.avatarUrl,
    this.displayLetter = 'U',
    this.showSearch = true,
    this.showNotifications = true,
    this.showMessages = true,
    this.showAddButton = true,
    this.showAvatar = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            const Text(
              'Tajify',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (showSearch)
              _iconButton(
                icon: Icons.search,
                onTap: onSearch,
              ),
            if (showNotifications)
              _badgeButton(
                icon: Icons.notifications_none,
                count: notificationCount,
                onTap: onNotifications,
              ),
            if (showMessages)
              _badgeButton(
                icon: Icons.message_outlined,
                count: messageCount,
                onTap: onMessages,
              ),
            if (showAddButton || showAvatar)
              Container(
                height: 24,
                width: 1.2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.grey[600],
              ),
            if (showAddButton)
              _iconButton(
                icon: Icons.add,
                onTap: onAdd,
              ),
            if (showAvatar)
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.transparent,
                          backgroundImage: NetworkImage(avatarUrl!),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.transparent,
                          child: Text(
                            displayLetter.isNotEmpty ? displayLetter[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({required IconData icon, VoidCallback? onTap}) {
    return IconButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _badgeButton({required IconData icon, required int count, VoidCallback? onTap}) {
    return Stack(
      children: [
        _iconButton(icon: icon, onTap: onTap),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

