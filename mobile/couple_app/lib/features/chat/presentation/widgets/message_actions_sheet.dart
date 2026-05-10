import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';
import '../../data/message_models.dart';

/// "Defter yaprağı" kâğıt sheet — bir mesaja uzun basınca çıkar.
/// 6 hızlı emoji satırı + 4 aksiyon (Reply, Copy, Edit, Delete) + "tüm emojiler".
class MessageActionsSheet extends StatefulWidget {
  const MessageActionsSheet({
    super.key,
    required this.message,
    required this.isMine,
    required this.canEdit,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final Message message;
  final bool isMine;
  final bool canEdit;
  final void Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final void Function(bool forBoth) onDelete;

  static Future<void> show({
    required BuildContext context,
    required Message message,
    required bool isMine,
    required bool canEdit,
    required void Function(String emoji) onReact,
    required VoidCallback onReply,
    required VoidCallback onCopy,
    required VoidCallback onEdit,
    required void Function(bool forBoth) onDelete,
  }) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageActionsSheet(
        message: message,
        isMine: isMine,
        canEdit: canEdit,
        onReact: onReact,
        onReply: onReply,
        onCopy: onCopy,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<MessageActionsSheet> createState() => _MessageActionsSheetState();
}

class _MessageActionsSheetState extends State<MessageActionsSheet> {
  static const _quickEmojis = ['❤️', '😂', '😮', '😢', '🙏', '🔥'];

  bool _showPicker = false;

  void _handleQuick(String emoji) {
    widget.onReact(emoji);
    if (mounted) Navigator.pop(context);
  }

  void _openPicker() => setState(() => _showPicker = true);

  void _handleAction(VoidCallback fn) {
    Navigator.pop(context);
    fn();
  }

  Future<void> _handleDelete() async {
    final navigator = Navigator.of(context);
    final bool? result;
    if (widget.isMine) {
      result = await _askDeleteScope(context);
    } else {
      final ok = await _confirmDeleteForMe(context);
      result = ok == true ? false : null;
    }
    if (!mounted) return;
    if (result == null) return;
    navigator.pop();
    widget.onDelete(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Hızlı emoji satırı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ..._quickEmojis.map(
                    (e) => InkWell(
                      onTap: () => _handleQuick(e),
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _openPicker,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.paperDeep,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.rule),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.add,
                          size: 18, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.ruleSoft),
            // Aksiyonlar
            _ActionRow(
              icon: Icons.reply_outlined,
              label: 'Yanıtla',
              onTap: () => _handleAction(widget.onReply),
            ),
            if (widget.message.type == MessageType.text &&
                widget.message.content != null)
              _ActionRow(
                icon: Icons.copy_outlined,
                label: 'Kopyala',
                onTap: () => _handleAction(widget.onCopy),
              ),
            if (widget.canEdit)
              _ActionRow(
                icon: Icons.edit_outlined,
                label: 'Düzenle',
                onTap: () => _handleAction(widget.onEdit),
              ),
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Sil',
              tone: _ActionTone.danger,
              onTap: _handleDelete,
            ),
            if (_showPicker)
              SizedBox(
                height: 300,
                child: ep.EmojiPicker(
                  onEmojiSelected: (_, emoji) => _handleQuick(emoji.emoji),
                  config: ep.Config(
                    height: 300,
                    emojiViewConfig: const ep.EmojiViewConfig(
                      backgroundColor: AppColors.paper,
                      columns: 8,
                    ),
                    categoryViewConfig: const ep.CategoryViewConfig(
                      backgroundColor: AppColors.paper,
                      indicatorColor: AppColors.stamp,
                      iconColor: AppColors.inkMute,
                      iconColorSelected: AppColors.stamp,
                    ),
                    bottomActionBarConfig: const ep.BottomActionBarConfig(
                      enabled: false,
                    ),
                    searchViewConfig: const ep.SearchViewConfig(
                      backgroundColor: AppColors.paper,
                      hintText: 'emoji ara…',
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

enum _ActionTone { neutral, danger }

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _ActionTone.neutral,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _ActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = tone == _ActionTone.danger
        ? AppColors.error
        : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _askDeleteScope(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mesajı sil?'),
      content: const Text('Sadece sende mi yoksa her iki tarafta da mı?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('sadece bende'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.paper,
          ),
          child: const Text('her ikisinde'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmDeleteForMe(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mesajı sil?'),
      content: const Text(
        'Bu mesaj yalnız sende silinecek. Partner görmeye devam eder.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.paper,
          ),
          child: const Text('sil'),
        ),
      ],
    ),
  );
}
