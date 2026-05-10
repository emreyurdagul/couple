import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/paper_scaffold.dart';
import '../../auth/state/auth_controller.dart';
import '../data/message_models.dart';
import '../state/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtl = TextEditingController();
  final _scrollCtl = ScrollController();

  @override
  void dispose() {
    _inputCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  String? _myUserId() {
    final auth = ref.read(authControllerProvider);
    return auth is AuthSignedIn ? auth.session.userId : null;
  }

  Future<void> _send() async {
    final text = _inputCtl.text;
    if (text.trim().isEmpty) return;
    _inputCtl.clear();
    await ref.read(chatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtl.hasClients) return;
      _scrollCtl.animateTo(
        _scrollCtl.position.maxScrollExtent,
        duration: AppMotion.med,
        curve: AppMotion.curveOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen<ChatState>(chatControllerProvider, (_, next) {
      if (next.messages.isNotEmpty) _scrollToBottom();
    });

    final myId = _myUserId();

    return PaperScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          color: AppColors.ink,
          onPressed: () => context.go('/'),
        ),
        title: Text('Mesajlar', style: AppText.title(context)),
        actions: [
          if (state.connection == ChatConnectionState.connecting)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
              ),
            )
          else if (state.connection == ChatConnectionState.disconnected)
            IconButton(
              tooltip: 'Yeniden bağlan',
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.error,
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).retryConnect(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (state.error != null) _ErrorStrip(state.error!),
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        controller: _scrollCtl,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) {
                          final m = state.messages[i];
                          final mine = m.senderId == myId ||
                              m.senderId == '__me__';
                          final showDay = i == 0 ||
                              !_sameDay(
                                state.messages[i - 1].createdAt,
                                m.createdAt,
                              );
                          return Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (showDay) _DayDivider(date: m.createdAt),
                              _Bubble(message: m, mine: mine),
                              const SizedBox(height: AppSpacing.xs),
                            ],
                          );
                        },
                      ),
          ),
          if (state.partnerTyping) _TypingHint(),
          _InputBar(
            controller: _inputCtl,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width * 0.78;
    final fill = mine ? AppColors.stamp : AppColors.paperDeep;
    final fg = mine ? AppColors.paper : AppColors.ink;
    final align =
        mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.xs),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
            bottomRight: Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(AppRadius.xs),
          );
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Column(
      crossAxisAlignment: align,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: mine
                  ? null
                  : Border.all(color: AppColors.rule, width: 1),
            ),
            child: Text(
              message.content ?? '',
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.4,
                color: fg,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: AppColors.inkMute,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                _DeliveryDot(message: message),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryDot extends StatelessWidget {
  const _DeliveryDot({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final status = message.deliveryStatus;
    final read = message.readAt != null;
    final IconData icon;
    final Color color;
    if (status == MessageDeliveryStatus.sending) {
      icon = Icons.schedule;
      color = AppColors.inkMute;
    } else if (status == MessageDeliveryStatus.failed) {
      icon = Icons.error_outline;
      color = AppColors.error;
    } else if (read) {
      icon = Icons.done_all;
      color = AppColors.leaf;
    } else {
      icon = Icons.check;
      color = AppColors.inkMute;
    }
    return Icon(icon, size: 11, color: color);
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final today = DateTime.now();
    String label;
    if (_sameDay(today, local)) {
      label = 'bugün';
    } else if (_sameDay(today.subtract(const Duration(days: 1)), local)) {
      label = 'dün';
    } else {
      label = DateFormat('d MMM y', 'tr').format(local);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.ruleSoft)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: GoogleFonts.fraunces(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.inkMute,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Container(height: 1, color: AppColors.ruleSoft)),
        ],
      ),
    );
  }
}

class _TypingHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'yazıyor…',
          style: GoogleFonts.caveat(
            fontSize: 16,
            color: AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'İlk satırı sen yaz —\nbu sayfa boş kalmasın.',
          textAlign: TextAlign.center,
          style: AppText.headline(context).copyWith(
            color: AppColors.inkMute,
          ),
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.error.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.ruleSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'bir şeyler yaz…',
                  hintStyle: GoogleFonts.fraunces(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkMute,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: AppColors.stamp,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onSend,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.paper,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}
