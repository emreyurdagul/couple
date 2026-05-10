import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Çok hafif bir noise/grain dokusu — kâğıt hissi için.
/// Performance için `RepaintBoundary` ile sarmala, ya da CustomPaint
/// shouldRepaint=false bırak; texture sadece widget boyu değişince
/// yeniden hesaplanır.
class PaperTexture extends StatelessWidget {
  const PaperTexture({
    super.key,
    this.intensity = 0.04,
    this.density = 1400,
  });

  /// 0..1 — taneciklerin opaklığı.
  final double intensity;

  /// Ne kadar tanecik. 1000-2000 arası dengeli.
  final int density;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GrainPainter(intensity: intensity, density: density),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.intensity, required this.density});

  final double intensity;
  final int density;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic seed → render her frame'de farklı görünüp titremesin.
    final rand = Random(7);
    final paint = Paint()..color = AppColors.ink.withValues(alpha: intensity);

    for (var i = 0; i < density; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 0.6 + 0.2;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) =>
      old.intensity != intensity || old.density != density;
}
