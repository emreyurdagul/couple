import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/paper_card.dart';
import '../../../shared/widgets/paper_scaffold.dart';
import '../../../shared/widgets/stamp_button.dart';
import '../data/couple_models.dart';
import '../data/couple_repository.dart';

class InviteCreateScreen extends ConsumerStatefulWidget {
  const InviteCreateScreen({super.key});

  @override
  ConsumerState<InviteCreateScreen> createState() => _InviteCreateScreenState();
}

class _InviteCreateScreenState extends ConsumerState<InviteCreateScreen> {
  CoupleInvite? _invite;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await ref.read(coupleRepositoryProvider).createInvite();
      if (!mounted) return;
      setState(() => _invite = invite);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _readableError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      pageNumber: 3,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          color: AppColors.ink,
          onPressed: () => context.go('/couple'),
        ),
        title: Text('Davet', style: AppText.title(context)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      body: _busy && _invite == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _create)
              : _invite == null
                  ? const SizedBox()
                  : _InviteBody(invite: _invite!),
    );
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({required this.invite});
  final CoupleInvite invite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Bu kodu',
          style: AppText.headline(context),
        ),
        Text(
          'paylaş.',
          style: AppText.headline(context).copyWith(color: AppColors.stamp),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Partnerin uygulamayı açtığında "Daveti kabul et" — '
          'kodu yazar veya QR\'ı okur.',
          style: AppText.subtitle(context),
        ),
        const SizedBox(height: AppSpacing.xl),
        // QR kâğıt sayfası
        Center(
          child: PaperCard(
            tone: PaperTone.deep,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: Colors.white,
              child: QrImageView(
                data: invite.code,
                size: 220,
                backgroundColor: Colors.white,
                dataModuleStyle: const QrDataModuleStyle(
                  color: AppColors.ink,
                  dataModuleShape: QrDataModuleShape.square,
                ),
                eyeStyle: const QrEyeStyle(
                  color: AppColors.ink,
                  eyeShape: QrEyeShape.square,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Kod — defter satırı
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.rule, width: 1),
            ),
          ),
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Center(
            child: SelectableText(
              invite.code.split('').join(' '),
              style: GoogleFonts.fraunces(
                fontSize: 40,
                fontWeight: FontWeight.w400,
                color: AppColors.ink,
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'geçerli: ${_formatExpiry(invite.expiresAt)}',
            style: GoogleFonts.caveat(
              fontSize: 18,
              color: AppColors.inkMute,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        StampButton(
          label: 'Kodu kopyala',
          icon: Icons.content_copy_rounded,
          tone: StampTone.outline,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: invite.code));
            messenger.showSnackBar(
              const SnackBar(content: Text('Kod kopyalandı')),
            );
          },
        ),
      ],
    );
  }
}

String _formatExpiry(DateTime expiresAt) {
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.isNegative) return 'süresi doldu';
  final h = remaining.inHours;
  final m = remaining.inMinutes.remainder(60);
  if (h > 0) return '$h saat $m dk';
  return '$m dk';
}

String _readableError(DioException e) {
  final data = e.response?.data;
  if (e.response?.statusCode == 409 &&
      data is Map &&
      data['error'] == 'already_in_active_couple') {
    return 'Zaten aktif bir eşleşmen var.';
  }
  if (e.type == DioExceptionType.connectionError) {
    return 'Sunucuya bağlanılamadı.';
  }
  return 'Davet oluşturulamadı.';
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppText.body(context), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          StampButton(label: 'Tekrar dene', onPressed: onRetry),
        ],
      ),
    );
  }
}
