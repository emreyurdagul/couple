import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/paper_card.dart';
import '../../../shared/widgets/paper_scaffold.dart';
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
      // empty state aşağıda gösterilecek
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _endCouple() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sayfanı kapatmak ister misin?'),
        content: const Text(
          'Tüm chat ve konum geçmişiniz iki tarafa da görünmez olur. '
          'Yeniden eşleşirseniz tarihler temiz başlar.',
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
              minimumSize: const Size(120, 44),
            ),
            child: const Text('kapat'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(coupleRepositoryProvider).endCouple();
    await ref.read(authControllerProvider.notifier).handleCoupleEnded();
  }

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      pageNumber: _calculatePageNumber(),
      lined: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(context),
    );
  }

  int _calculatePageNumber() {
    final created = _info?.createdAt;
    if (created == null) return 1;
    return DateTime.now().difference(created).inDays + 1;
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(
          partnerName: _info?.partnerDisplayName ?? '—',
          onEnd: _endCouple,
          onLogout: () =>
              ref.read(authControllerProvider.notifier).logout(),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_info != null)
          _MetricLine(since: _info!.createdAt)
        else
          _MetricLine.empty(),
        const SizedBox(height: AppSpacing.lg),
        _StreamCard(
          icon: '✦',
          color: AppColors.stamp,
          title: 'Mesajlar',
          subtitle: 'Birlikte yazın — sayfa hep açık.',
          onTap: () => context.go('/chat'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StreamCard(
          icon: '◊',
          color: AppColors.leaf,
          title: 'Konum',
          subtitle: 'Yakında — birbirinizi göreceksiniz.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _StreamCard(
          icon: '✧',
          color: AppColors.inkSoft,
          title: 'Anılar & plan',
          subtitle: 'Yakında — ortak takviminiz açılacak.',
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.partnerName,
    required this.onEnd,
    required this.onLogout,
  });

  final String partnerName;
  final VoidCallback onEnd;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.paperDeep,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.rule),
          ),
          child: Text(
            'B',
            style: GoogleFonts.fraunces(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: AppColors.ink,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(-12, 0),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.stamp,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.stampDeep),
            ),
            child: Text(
              partnerName.isNotEmpty ? partnerName.characters.first : '·',
              style: GoogleFonts.fraunces(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: AppColors.paper,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'partnerin',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  color: AppColors.inkMute,
                ),
              ),
              Text(
                partnerName,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sayfayı kapat',
          icon: const Icon(Icons.bookmark_remove_outlined, size: 22),
          color: AppColors.inkSoft,
          onPressed: onEnd,
        ),
        IconButton(
          tooltip: 'Çıkış',
          icon: const Icon(Icons.logout, size: 20),
          color: AppColors.inkSoft,
          onPressed: onLogout,
        ),
      ],
    );
  }
}

/// Tek satır kompakt metric — birlikte gün sayısı + tarih.
/// Header altında ölü alan oluşturmadan günlük bağlamı verir.
class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.since}) : _empty = false;
  const _MetricLine.empty()
      : since = null,
        _empty = true;

  final DateTime? since;
  final bool _empty;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateLabel(DateTime.now());
    if (_empty || since == null) {
      return Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.ruleSoft)),
          const SizedBox(width: AppSpacing.sm),
          Text(dateLabel, style: AppText.label(context)),
        ],
      );
    }

    final days = DateTime.now().difference(since!).inDays;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$days',
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w400,
            color: AppColors.stamp,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'gün birlikte',
          style: GoogleFonts.fraunces(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Container(height: 1, color: AppColors.ruleSoft)),
        const SizedBox(width: AppSpacing.sm),
        Text(dateLabel, style: AppText.label(context)),
      ],
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      tone: PaperTone.deep,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              icon,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                color: color,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(context)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.bodySoft(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  const months = [
    'oca', 'şub', 'mar', 'nis', 'may', 'haz',
    'tem', 'ağu', 'eyl', 'eki', 'kas', 'ara',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}'.toUpperCase();
}
