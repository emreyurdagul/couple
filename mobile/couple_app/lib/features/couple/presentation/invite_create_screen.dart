import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Davet kodu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/couple'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _busy && _invite == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _create)
                  : _invite == null
                      ? const SizedBox()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bu kodu partnerinle paylaş',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: QrImageView(
                                  data: _invite!.code,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SelectableText(
                              _invite!.code,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Geçerli: ${_formatExpiry(_invite!.expiresAt)}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.copy),
                              label: const Text('Kodu kopyala'),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await Clipboard.setData(
                                    ClipboardData(text: _invite!.code));
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Kod kopyalandı')),
                                );
                              },
                            ),
                          ],
                        ),
        ),
      ),
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
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}
