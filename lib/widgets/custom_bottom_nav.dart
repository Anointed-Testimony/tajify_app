import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'create_content_modal.dart';

const Color _primaryColor = Color(0xFFB875FB);
const Color _primaryColorLight = Color(0xFFE84BC4);

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
  });

  static const Color themeColor = _primaryColor;
  static const Color backgroundColor = Color(0xFF232323);
  static const Color inactiveColor = Colors.white70; // White for inactive icons
  static const Color activeColor = _primaryColor; // Primary color for active icon

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/connect');
        break;
      case 2:
        context.go('/market');
        break;
      case 3:
        context.go('/earn');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                    index: 0,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.people_alt_outlined,
                    activeIcon: Icons.people_alt,
                    label: 'Connect',
                    index: 1,
                  ),
                  // Spacer for the floating button
                  const SizedBox(width: 56),
                  _buildNavItem(
                    context: context,
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront,
                    label: 'Market',
                    index: 2,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.auto_graph_outlined,
                    activeIcon: Icons.auto_graph,
                    label: 'Earn',
                    index: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating plus button positioned in the center
        Positioned(
          left: MediaQuery.of(context).size.width / 2 - 28,
          top: -10,
          child: _buildFloatingPlusButton(context),
        ),
      ],
    );
  }

  Widget _buildFloatingPlusButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showCreateContentModal(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _primaryColor,
              _primaryColorLight,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white70,
            ],
          ).createShader(bounds),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(context, index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

