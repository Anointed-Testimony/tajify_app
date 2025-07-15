import 'package:flutter/material.dart';

class CustomToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback? onDismiss;

  const CustomToast({
    Key? key,
    required this.message,
    required this.type,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: type == ToastType.success 
            ? Colors.green.withOpacity(0.9)
            : Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: type == ToastType.success 
              ? Colors.green.shade300
              : Colors.red.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            type == ToastType.success ? Icons.check_circle : Icons.error,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}

enum ToastType {
  success,
  error,
}

class ToastService {
  static void showToast(
    BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: CustomToast(
            message: message,
            type: type,
            onDismiss: () {
              overlayEntry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  static void showSuccessToast(BuildContext context, String message) {
    showToast(context, message: message, type: ToastType.success);
  }

  static void showErrorToast(BuildContext context, String message) {
    showToast(context, message: message, type: ToastType.error);
  }
} 