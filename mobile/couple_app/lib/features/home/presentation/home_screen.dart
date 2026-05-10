import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/auth_controller.dart';
import '../../couple/data/couple_models.dart';
import '../../couple/data/couple_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CoupleInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final info = await ref.read(coupleRepositoryProvider).getMyCouple();
      if (!mounted) return;
      setState(() => _info = info);
    } on DioException {
      // ignore - aşağıda gösterilecek
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _endCouple() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eşleşmeyi sonlandır'),
        content: const Text(
            'Tüm chat ve konum geçmişiniz iki tarafa da görünmez olacak. '
            'Yeniden eşleşirseniz tarihler temiz başlar. Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sonlandır'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(coupleRepositoryProvider).endCouple();
    // Refresh tokenları sunucuda revoke edildi → lokali temizle, login'e dön.
    await ref.read(authControllerProvider.notifier).handleCoupleEnded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Couple'),
        actions: [
          IconButton(
            tooltip: 'Eşleşmeyi sonlandır',
            icon: const Icon(Icons.heart_broken_outlined),
            onPressed: _endCouple,
          ),
          IconButton(
            tooltip: 'Çıkış',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Partner', style: theme.textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Text(
                              _info?.partnerDisplayName ?? '—',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _info != null
                                  ? 'Eşleşme: ${_formatDate(_info!.createdAt)}'
                                  : 'Eşleşme bilgisi yok',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Chat ve konum yakında.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}
