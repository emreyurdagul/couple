import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';

/// Defter satırı tipinde input — alt çizgi, italic serif label.
/// Mevcut TextFormField'i sarar, app theme'in InputDecoration'ını
/// kullanır ama label/hint stilini bu dilin tipografisine bağlar.
class JournalField extends StatelessWidget {
  const JournalField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.validator,
    this.onChanged,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.onFieldSubmitted,
    this.style,
    this.autofocus = false,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? style;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      validator: validator,
      onChanged: onChanged,
      maxLength: maxLength,
      textAlign: textAlign,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofocus: autofocus,
      cursorColor: AppColors.stamp,
      cursorWidth: 1.4,
      style: style ??
          GoogleFonts.inter(
            fontSize: 16,
            color: AppColors.ink,
            height: 1.4,
          ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
    );
  }
}
