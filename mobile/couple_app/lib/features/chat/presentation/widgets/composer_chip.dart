import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/message_models.dart';

/// Input bar'ın üstünde — reply ya da edit modu açıkken gösterilen ince kâğıt şerit.
class ComposerChip extends StatelessWidget {
  const ComposerChip({
    super.key,
    required this.label,
    required this.preview,
    required this.accent,
    required this.onClose,
  });

  final String label;
  final String preview;
  final Color accent;
  final VoidCallback onClose;

  factory ComposerChip.reply({
    required Message target,
    required VoidCallback onClose,
  }) {
    final preview = target.isDeleted
        ? '(silinmiş mesaj)'
        : (target.content?.trim().isNotEmpty == true
            ? target.content!
            : '(medya)');
    return ComposerChip(
      label: 'yanıtlanan',
      preview: preview,
      accent: AppColors.stamp,
      onClose: onClose,
    );
  }

  factory ComposerChip.edit({
    required Message target,
    required VoidCallback onClose,
  }) {
    return ComposerChip(
      label: 'düzenleniyor',
      preview: target.content ?? '',
      accent: AppColors.leaf,
      onClose: onClose,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    color: AppColors.inkMute,
                  ),
                ),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            color: AppColors.inkMute,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
