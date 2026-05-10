import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/message_models.dart';

/// Bir mesajın "hangi mesaja yanıt" olduğunu gösteren küçük kâğıt parçası.
/// — Bubble içinde kullanılır (üstte, ana içeriğin tepesinde).
class QuotedPreview extends StatelessWidget {
  const QuotedPreview({
    super.key,
    required this.original,
    required this.mineColors,
    this.onTap,
  });

  final Message original;
  final bool mineColors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = mineColors
        ? AppColors.paper.withValues(alpha: 0.85)
        : AppColors.stamp;
    final fill = mineColors
        ? AppColors.stampDeep
        : AppColors.paper;
    final fg = mineColors ? AppColors.paper : AppColors.ink;

    final preview = original.isDeleted
        ? '(silinmiş mesaj)'
        : (original.content?.trim().isNotEmpty == true
            ? original.content!
            : _typeLabel(original.type));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'yanıtladığın mesaj',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  color: fg.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.3,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(MessageType t) => switch (t) {
      MessageType.image => '📷 fotoğraf',
      MessageType.voice => '🎙 ses notu',
      MessageType.system => '— sistem mesajı',
      _ => '(içerik)',
    };
