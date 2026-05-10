import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/paper_card.dart';
import '../../../shared/widgets/paper_scaffold.dart';
import '../../../shared/widgets/wordmark.dart';
import '../../auth/state/auth_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaperScaffold(
      pageNumber: 2,
      body: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Wordmark(size: 22),
              IconButton(
                tooltip: 'Çıkış',
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout, size: 20),
                color: AppColors.inkSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(child: const TwoPensMark(size: 84)),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Bir defter,',
            style: AppText.display(context),
          ),
          Text(
            'iki kalem.',
            style: AppText.display(context).copyWith(color: AppColors.stamp),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Partnerinle ortak sayfanı aç. '
            'Biri davet eder, diğeri okur — ve birlikte yazmaya başlarsın.',
            style: AppText.subtitle(context),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _OnboardingCard(
            mark: '✦',
            markColor: AppColors.stamp,
            title: 'Ben başlatayım',
            subtitle: 'Bir kod ve QR yarat, partnerinle paylaş.',
            onTap: () => context.go('/couple/invite'),
          ),
          const SizedBox(height: AppSpacing.md),
          _OnboardingCard(
            mark: '✧',
            markColor: AppColors.leaf,
            title: 'O bana verdi',
            subtitle: 'Kodu yaz veya QR\'ı oku.',
            onTap: () => context.go('/couple/accept'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'davet 24 saat boyunca geçerli',
              style: GoogleFonts.caveat(
                fontSize: 16,
                color: AppColors.inkMute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.mark,
    required this.markColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String mark;
  final Color markColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: markColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              mark,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                color: markColor,
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
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.arrow_forward, size: 18, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
