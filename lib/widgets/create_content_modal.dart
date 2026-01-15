import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ContentType {
  tubeShorts,
  tubeMax,
  tubePrime,
  private,
}

Future<ContentType?> showCreateContentModal(BuildContext context) {
  return showModalBottomSheet<ContentType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Create Content',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ContentOptionTile(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFB875FB), Color(0xFFE84BC4)],
                ),
                icon: Icons.videocam,
                title: 'Tube Shorts',
                description: 'Short vertical videos with filters',
                onTap: () {
                  Navigator.pop(sheetContext, ContentType.tubeShorts);
                  Future.microtask(() => context.go('/create', extra: {'type': 'Tube Short'}));
                },
              ),
              const SizedBox(height: 12),
              _ContentOptionTile(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                ),
                icon: Icons.movie,
                title: 'Tube Max',
                description: 'Longer videos & content',
                onTap: () {
                  Navigator.pop(sheetContext, ContentType.tubeMax);
                  Future.microtask(() => context.go('/create', extra: {'type': 'Tube Max'}));
                },
              ),
              const SizedBox(height: 12),
              _ContentOptionTile(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                ),
                icon: Icons.movie_filter,
                title: 'Tube Prime',
                description: 'Feature films & movies',
                onTap: () {
                  Navigator.pop(sheetContext, ContentType.tubePrime);
                  Future.microtask(() => context.go('/create', extra: {'type': 'Tube Prime'}));
                },
              ),
              const SizedBox(height: 12),
              _ContentOptionTile(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFF1744), Color(0xFFE91E63)],
                ),
                icon: Icons.lock,
                title: 'Private',
                description: 'Exclusive subscriber content',
                onTap: () {
                  Navigator.pop(sheetContext, ContentType.private);
                  Future.microtask(() => context.go('/create', extra: {'type': 'Private'}));
                },
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      );
    },
  );
}

class _ContentOptionTile extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ContentOptionTile({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

