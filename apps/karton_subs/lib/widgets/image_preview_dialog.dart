import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Pełnoekranowy podgląd zdjęcia rachunku (z zoomem). Otwierany z miniaturki
/// pozycji „Do zatwierdzenia" oraz z formularza edycji rozpoznanego rachunku —
/// żeby porównać rozpoznane pola ze źródłem.
class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;

  const ImagePreviewDialog({super.key, required this.imagePath});

  static Future<void> show(BuildContext context, String imagePath) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ImagePreviewDialog(imagePath: imagePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          // Zoom + przesuwanie; tap w tło zamyka.
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Nie można wyświetlić zdjęcia',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
