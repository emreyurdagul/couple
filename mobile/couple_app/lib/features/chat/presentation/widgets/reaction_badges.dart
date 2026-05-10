import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/message_models.dart';

/// Bubble altında reaction rozetleri — emoji × count.
class ReactionBadges extends StatelessWidget {
  const ReactionBadges({
    super.key,
    required this.reactions,
    required this.myUserId,
    this.onTapBadge,
  });

  final List<Reaction> reactions;
  final String myUserId;
  final void Function(String emoji)? onTapBadge;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final byEmoji = <String, List<Reaction>>{};
    for (final r in reactions) {
      byEmoji.putIfAbsent(r.emoji, () => []).add(r);
    }

    final entries = byEmoji.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: entries.map((e) {
          final count = e.value.length;
          final hasMine = e.value.any((r) => r.userId == myUserId);
          return _Badge(
            emoji: e.key,
            count: count,
            mine: hasMine,
            onTap: onTapBadge == null ? null : () => onTapBadge!(e.key),
          );
        }).toList(),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.emoji,
    required this.count,
    required this.mine,
    this.onTap,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = mine ? AppColors.stamp.withValues(alpha: 0.10) : AppColors.paperDeep;
    final border = mine ? AppColors.stamp : AppColors.rule;
    final textColor = mine ? AppColors.stamp : AppColors.inkSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              if (count > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
