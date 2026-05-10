import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';

/// Damga görünümlü buton — terra cotta dolgu, ince yazı, tıklayınca hafif
/// "basılma" hissi (scale + opacity).
class StampButton extends StatefulWidget {
  const StampButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
    this.tone = StampTone.solid,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final StampTone tone;

  @override
  State<StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<StampButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.busy;
    final solid = widget.tone == StampTone.solid;

    final fg = solid ? AppColors.paper : AppColors.ink;
    final bg = solid ? AppColors.stamp : Colors.transparent;
    final border =
        solid ? AppColors.stampDeep : AppColors.ink;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _setPressed(true),
        onTapUp: disabled ? null : (_) => _setPressed(false),
        onTapCancel: disabled ? null : () => _setPressed(false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            height: 56,
            decoration: BoxDecoration(
              color: disabled ? AppColors.paperDeep : bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: disabled ? AppColors.rule : border,
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: solid ? AppColors.paper : AppColors.ink,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: disabled ? AppColors.inkMute : fg),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: disabled ? AppColors.inkMute : fg,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum StampTone { solid, outline }
