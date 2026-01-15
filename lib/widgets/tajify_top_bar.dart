import 'package:flutter/material.dart';

const Color _primaryColor = Color(0xFFCA24A5);
const Color _primaryColorLight = Color(0xFFE84BC4);

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
    this.showAddButton = false,
    this.showAvatar = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    // Debug logging
    debugPrint('🔍 TajifyTopBar - avatarUrl: $avatarUrl');
    debugPrint('🔍 TajifyTopBar - avatarUrl is null: ${avatarUrl == null}');
    debugPrint('🔍 TajifyTopBar - avatarUrl isEmpty: ${avatarUrl?.isEmpty ?? true}');
    debugPrint('🔍 TajifyTopBar - displayLetter: $displayLetter');
    
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
            if (showAvatar)
              Container(
                height: 24,
                width: 1.2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.grey[600],
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
                      colors: [_primaryColor, _primaryColorLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? Image.network(
                            avatarUrl!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                debugPrint('✅ TajifyTopBar - Image loaded successfully: $avatarUrl');
                                return child;
                              }
                              debugPrint('⏳ TajifyTopBar - Loading image: $avatarUrl');
                              return Container(
                                width: 32,
                                height: 32,
                                color: Colors.transparent,
                                child: Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ TajifyTopBar - Image error for URL: $avatarUrl');
                              debugPrint('❌ TajifyTopBar - Error: $error');
                              debugPrint('❌ TajifyTopBar - StackTrace: $stackTrace');
                              return Container(
                                width: 32,
                                height: 32,
                                color: Colors.transparent,
                                child: Center(
                                  child: Text(
                                    displayLetter.isNotEmpty ? displayLetter[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            width: 32,
                            height: 32,
                            color: Colors.transparent,
                            child: Center(
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

