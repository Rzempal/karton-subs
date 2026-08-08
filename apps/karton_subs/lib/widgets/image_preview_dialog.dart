import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Pełnoekranowy podgląd zdjęcia paragonu (z zoomem). Otwierany z miniaturki
/// pozycji „Do zatwierdzenia" oraz z formularza edycji rozpoznanego paragonu —
/// żeby porównać rozpoznane pola ze źródłem.
///
/// [onCrop] (opcjonalne) dokłada przycisk „Przytnij". Podaje go tylko podgląd
/// pozycji oczekującej — zdjęcie zapisanego paragonu jest już zamknięte.
class ImagePreviewDialog extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onCrop;

  const ImagePreviewDialog({
    super.key,
    required this.imagePath,
    this.onCrop,
  });

  static Future<void> show(
    BuildContext context,
    String imagePath, {
    VoidCallback? onCrop,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ImagePreviewDialog(imagePath: imagePath, onCrop: onCrop),
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
          // Przycięcie zdjęcia — zamyka podgląd i oddaje sterowanie ekranowi,
          // bo natywny ekran uCrop otwiera się nad aplikacją.
          if (onCrop != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onCrop!();
                  },
                  icon: const Icon(LucideIcons.crop, size: 18),
                  label: const Text('Przytnij'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
