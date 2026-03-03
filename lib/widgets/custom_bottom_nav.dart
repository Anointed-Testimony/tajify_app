import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _primary = Color(0xFFEA580C);

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/connect'); break;
      case 2: context.go('/market'); break;
      case 3: context.go('/earn'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _item(context, Icons.home_outlined, Icons.home_rounded, 'Home', 0),
                _item(context, Icons.people_outline_rounded, Icons.people_rounded, 'Connect', 1),
                const SizedBox(width: 52),
                _item(context, Icons.storefront_outlined, Icons.storefront_rounded, 'Market', 2),
                _item(context, Icons.trending_up_outlined, Icons.trending_up_rounded, 'Earn', 3),
              ],
            ),
            Positioned(
              left: MediaQuery.of(context).size.width / 2 - 26,
              top: -14,
              child: GestureDetector(
                onTap: () => context.go('/create'),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, IconData activeIcon, String label, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => _onTap(context, index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? _primary : Colors.white54,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? _primary : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
