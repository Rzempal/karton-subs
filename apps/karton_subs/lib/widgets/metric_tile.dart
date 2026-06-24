import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'frost_card.dart';

/// Kafel metryki: ikona (akcent semantyczny) + etykieta + kwota.
/// Opcjonalna „delta-pill" (np. `+4%`) w kolorze semantycznym.
/// Wzorzec: docs/design.md → „Kafel metryki".
class MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  /// Opcjonalna pigułka delty (np. zmiana procentowa).
  final String? deltaLabel;
  final Color? deltaColor;
  final Color? deltaBg;

  const MetricTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.deltaLabel,
    this.deltaColor,
    this.deltaBg,
  });

  @override
  Widget build(BuildContext context) {
    return FrostCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: AppRadii.metric,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              if (deltaLabel != null) _DeltaPill(deltaLabel!, deltaColor!, deltaBg!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _DeltaPill(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
