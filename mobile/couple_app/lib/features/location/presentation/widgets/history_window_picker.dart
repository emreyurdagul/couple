import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';
import '../../state/location_controller.dart';

/// Defter dili segmented control — 1s / 24s / 7g.
class HistoryWindowPicker extends StatelessWidget {
  const HistoryWindowPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final HistoryWindow value;
  final ValueChanged<HistoryWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        border: Border.all(color: AppColors.rule),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: HistoryWindow.values.map((w) {
          final selected = w == value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(w),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.stamp : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                w.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                  color: selected ? AppColors.paper : AppColors.inkSoft,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
