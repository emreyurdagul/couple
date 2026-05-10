import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
      // couple_id claim'ini almak için token'ı yenile
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daveti kabul et'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.dialpad), text: 'Kodu yaz'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR tara'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/couple'),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Partnerinin sana verdiği 6 haneli kodu gir.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Davet kodu',
              counterText: '',
            ),
            style: Theme.of(context).textTheme.displaySmall,
            autofocus: true,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Eşleş'),
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
    return Stack(
      children: [
        MobileScanner(controller: _scanner, onDetect: _onDetect),
        if (widget.busy)
          const Positioned.fill(
              child: ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator()))),
        if (widget.error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onErrorContainer)),
              ),
            ),
          ),
      ],
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
