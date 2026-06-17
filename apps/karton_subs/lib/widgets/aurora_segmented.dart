import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pojedynczy segment przełącznika [AuroraSegmented].
class AuroraSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const AuroraSegment({required this.value, required this.label, this.icon});
}

/// Segmentowy przełącznik w stylu Aurora: kontener „frost", aktywny segment w
/// `--accent-gradient` z ciemnym tekstem ([AppColors.onAccent]). Wspólny dla
/// zakresu Osobisty/Domowy (Dashboard, Budżet) i filtra zakresu Subskrypcji.
class AuroraSegmented<T> extends StatelessWidget {
  final List<AuroraSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const AuroraSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.frost1,
        border: Border.all(color: AppColors.frostBorder),
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        children: [
          for (final seg in segments)
            Expanded(
              child: _Segment<T>(
                segment: seg,
                selected: seg.value == selected,
                onTap: () => onChanged(seg.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  final AuroraSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAccent : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (segment.icon != null) ...[
              Icon(segment.icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
