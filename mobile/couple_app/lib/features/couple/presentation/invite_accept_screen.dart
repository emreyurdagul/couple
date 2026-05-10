import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/journal_field.dart';
import '../../../shared/widgets/paper_scaffold.dart';
import '../../../shared/widgets/stamp_button.dart';
import '../../auth/state/auth_controller.dart';
import '../data/couple_repository.dart';

class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key});

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _codeCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tab.dispose();
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _submit(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Kod 6 karakter olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(coupleRepositoryProvider).acceptInvite(code);
      await ref.read(authControllerProvider.notifier).rotateAfterCoupleChange();
      if (!mounted) return;
      context.go('/');
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
      padding: EdgeInsets.zero,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          color: AppColors.ink,
          onPressed: () => context.go('/couple'),
        ),
        title: Text('Daveti kabul et', style: AppText.title(context)),
        bottom: TabBar(
          controller: _tab,
          dividerColor: AppColors.ruleSoft,
          tabs: const [
            Tab(icon: Icon(Icons.dialpad, size: 18), text: 'KOD'),
            Tab(icon: Icon(Icons.qr_code_scanner, size: 18), text: 'QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ManualCodeTab(
            controller: _codeCtl,
            busy: _busy,
            error: _error,
            onSubmit: () => _submit(_codeCtl.text),
          ),
          _QrScanTab(
            busy: _busy,
            error: _error,
            onDetected: (code) => _submit(code),
          ),
        ],
      ),
    );
  }
}

class _ManualCodeTab extends StatelessWidget {
  const _ManualCodeTab({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kodu yaz.',
            style: AppText.headline(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Partnerinin sayfasından aldığın 6 haneli kodu gir.',
            style: AppText.subtitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          JournalField(
            controller: controller,
            label: 'davet kodu',
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: GoogleFonts.fraunces(
              fontSize: 36,
              fontWeight: FontWeight.w400,
              letterSpacing: 6,
              color: AppColors.ink,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          StampButton(
            label: 'Eşleş',
            onPressed: busy ? null : onSubmit,
            busy: busy,
          ),
        ],
      ),
    );
  }
}

class _QrScanTab extends StatefulWidget {
  const _QrScanTab({
    required this.busy,
    required this.error,
    required this.onDetected,
  });
  final bool busy;
  final String? error;
  final void Function(String code) onDetected;

  @override
  State<_QrScanTab> createState() => _QrScanTabState();
}

class _QrScanTabState extends State<_QrScanTab> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || widget.busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    _handled = true;
    widget.onDetected(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Sayfanı oku.',
            style: AppText.headline(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Partnerinin QR kodunu çerçeveye al.',
            style: AppText.subtitle(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _scanner, onDetect: _onDetect),
                  // Hafif çerçeve
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.paper.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                  ),
                  if (widget.busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (widget.error != null)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          widget.error!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _readableError(DioException e) {
  final data = e.response?.data;
  final code = e.response?.statusCode;
  if (code == 404) return 'Kod bulunamadı veya kullanılmış.';
  if (code == 400 && data is Map) {
    if (data['error'] == 'invite_expired') return 'Bu davetin süresi dolmuş.';
    if (data['error'] == 'cannot_accept_own_invite') {
      return 'Kendi davetini kabul edemezsin.';
    }
  }
  if (code == 409 && data is Map &&
      data['error'] == 'one_of_users_already_in_couple') {
    return 'İki kullanıcıdan biri zaten bir eşleşmede.';
  }
  if (e.type == DioExceptionType.connectionError) {
    return 'Sunucuya bağlanılamadı.';
  }
  return 'Davet kabul edilemedi.';
}
