import 'package:flutter/material.dart';

enum CreateVideoOption { record, upload }

Future<CreateVideoOption?> showCreateVideoOptionSheet(BuildContext context) {
  return showModalBottomSheet<CreateVideoOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final mediaQuery = MediaQuery.of(sheetContext);
      return Container(
        padding: mediaQuery.viewInsets,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.75,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Create Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How would you like to create your video?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CreateVideoOptionTile(
                    icon: Icons.videocam,
                    iconColor: Colors.redAccent,
                    title: 'Record with Camera',
                    description: 'Capture a new video with in-app camera tools',
                    onTap: () => Navigator.pop(
                      sheetContext,
                      CreateVideoOption.record,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CreateVideoOptionTile(
                    icon: Icons.photo_library,
                    iconColor: Colors.blueAccent,
                    title: 'Upload from Gallery',
                    description: 'Select an existing video from your device',
                    onTap: () => Navigator.pop(
                      sheetContext,
                      CreateVideoOption.upload,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _CreateVideoOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _CreateVideoOptionTile({
    required this.icon,
    required this.iconColor,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }
}

