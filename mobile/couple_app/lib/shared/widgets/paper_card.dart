import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Kâğıt kartı — sade ince kontur, hafif iç krema rengi, gölgesiz.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.tone = PaperTone.plain,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final PaperTone tone;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      PaperTone.plain => AppColors.paper,
      PaperTone.deep => AppColors.paperDeep,
      PaperTone.stamp => AppColors.stamp,
    };
    final border = borderColor ??
        (tone == PaperTone.stamp ? AppColors.stampDeep : AppColors.rule);

    final body = AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: 1.0),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.stamp.withValues(alpha: 0.06),
        highlightColor: AppColors.stamp.withValues(alpha: 0.03),
        child: body,
      ),
    );
  }
}

enum PaperTone { plain, deep, stamp }
