import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';

/// Uygulama logosu — italic serif "Couple" + alt çizgi.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Couple',
          style: GoogleFonts.fraunces(
            fontSize: size,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: c,
            letterSpacing: -0.6,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: size * 1.3,
          height: 1.4,
          color: c.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

/// İki kalemin sembolü — onboarding hero için minimal el-çizimsi ikon.
class TwoPensMark extends StatelessWidget {
  const TwoPensMark({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TwoPensPainter(),
      ),
    );
  }
}

class _TwoPensPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final stamp = Paint()
      ..color = AppColors.stamp
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Sol kalem (mürekkep)
    canvas.drawLine(
      Offset(w * 0.22, h * 0.18),
      Offset(w * 0.42, h * 0.78),
      ink,
    );
    // Sol uç (üçgen)
    final leftTip = Path()
      ..moveTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.36, h * 0.86)
      ..lineTo(w * 0.46, h * 0.84)
      ..close();
    canvas.drawPath(leftTip, ink);

    // Sağ kalem (damga)
    canvas.drawLine(
      Offset(w * 0.78, h * 0.18),
      Offset(w * 0.58, h * 0.78),
      stamp,
    );
    final rightTip = Path()
      ..moveTo(w * 0.58, h * 0.78)
      ..lineTo(w * 0.54, h * 0.84)
      ..lineTo(w * 0.64, h * 0.86)
      ..close();
    canvas.drawPath(rightTip, stamp);

    // Aralarındaki yumuşak ortak çizgi (deftere değen kâğıt çizgisi)
    final base = Paint()
      ..color = AppColors.rule
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(w * 0.20, h * 0.92),
      Offset(w * 0.80, h * 0.92),
      base,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
