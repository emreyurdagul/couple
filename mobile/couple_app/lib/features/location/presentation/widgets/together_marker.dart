import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/tokens.dart';

/// İki kullanıcı 50m içindeyken tek "biz" imleci.
class TogetherMarker extends StatelessWidget {
  const TogetherMarker({super.key, this.myInitial = '·', this.partnerInitial = '·'});

  final String myInitial;
  final String partnerInitial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _Avatar(
                color: AppColors.paperDeep,
                borderColor: AppColors.rule,
                textColor: AppColors.ink,
                label: myInitial,
              ),
              Positioned(
                left: 18,
                child: _Avatar(
                  color: AppColors.stamp,
                  borderColor: AppColors.stampDeep,
                  textColor: AppColors.paper,
                  label: partnerInitial,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.rule),
            ),
            child: Text(
              'biz',
              style: GoogleFonts.caveat(
                fontSize: 14,
                color: AppColors.stampDeep,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.color,
    required this.borderColor,
    required this.textColor,
    required this.label,
  });

  final Color color;
  final Color borderColor;
  final Color textColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        label.characters.first,
        style: GoogleFonts.fraunces(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}
