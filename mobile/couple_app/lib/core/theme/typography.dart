import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// "Defter" dilinin tipografi sistemi.
/// — Fraunces (italic, başlıklar) — romantik, el-yazımsı
/// — Inter (gövde) — sade, okunaklı
/// — Caveat (dekoratif mikro-metin) — el yazısı
class AppText {
  static TextStyle display(BuildContext context) => GoogleFonts.fraunces(
        fontSize: 44,
        height: 1.05,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );

  static TextStyle headline(BuildContext context) => GoogleFonts.fraunces(
        fontSize: 32,
        height: 1.10,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: AppColors.ink,
      );

  static TextStyle title(BuildContext context) => GoogleFonts.fraunces(
        fontSize: 22,
        height: 1.18,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );

  static TextStyle subtitle(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSoft,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      );

  static TextStyle bodySoft(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.inkSoft,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        height: 1.3,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w500,
        color: AppColors.inkMute,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: AppColors.paper,
      );

  /// El yazısı dekoratif — tarih, page no, micro-prompt.
  static TextStyle hand(BuildContext context, {double size = 18}) =>
      GoogleFonts.caveat(
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSoft,
      );
}
