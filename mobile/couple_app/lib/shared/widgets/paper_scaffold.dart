import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';
import 'paper_texture.dart';

/// Defter sayfası gibi davranan Scaffold.
/// — kâğıt zemin + hafif grain doku
/// — opsiyonel sayfa numarası footer
/// — opsiyonel "kâğıt çizgileri" zemin (defter satırları)
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.pageNumber,
    this.lined = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.safeArea = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final int? pageNumber;
  final bool lined;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          // Hafif kâğıt grain
          const Positioned.fill(
            child: IgnorePointer(child: PaperTexture()),
          ),
          if (lined)
            const Positioned.fill(
              child: IgnorePointer(child: _LinedPaperOverlay()),
            ),
          Positioned.fill(
            child: SafeArea(
              top: safeArea,
              bottom: safeArea,
              child: Padding(padding: padding, child: body),
            ),
          ),
          if (pageNumber != null)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '·  ${pageNumber!.toString().padLeft(2, '0')}  ·',
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      color: AppColors.inkMute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinedPaperOverlay extends StatelessWidget {
  const _LinedPaperOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LinesPainter());
  }
}

class _LinesPainter extends CustomPainter {
  static const _lineGap = 32.0;
  static const _topPadding = 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ruleSoft
      ..strokeWidth = 0.6;
    var y = _topPadding;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += _lineGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
