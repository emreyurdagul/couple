import 'package:flutter/material.dart';

/// "Defter" tasarım dilinin renk paleti.
class AppColors {
  // Kâğıt — ana zemin
  static const paper = Color(0xFFFBF6EE);
  static const paperDeep = Color(0xFFF3ECDD); // ikincil zemin / kart sırtı
  static const paperEdge = Color(0xFFE8DEC8); // kenar/gölge

  // Mürekkep — metinler
  static const ink = Color(0xFF22201D);
  static const inkSoft = Color(0xFF5D5851);
  static const inkMute = Color(0xFF8C857B);

  // Damga — birincil aksent
  static const stamp = Color(0xFFC46B5C);
  static const stampDeep = Color(0xFF9E5446);

  // Yaprak — ikincil aksent (durum, başarı)
  static const leaf = Color(0xFF7E8B6F);

  // Çizgi — defter rule line
  static const rule = Color(0xFFE0D6C2);
  static const ruleSoft = Color(0xFFEFE8D8);

  // Hata
  static const error = Color(0xFFA8442B);
}

class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 22.0;
  static const xl = 32.0;
}

class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 36.0;
  static const xxl = 56.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const med = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 560);
  static const pageTurn = Duration(milliseconds: 480);

  // Defter hissi — yumuşak başlangıç-bitiş
  static const curve = Cubic(0.32, 0.08, 0.24, 1.0);
  static const curveOut = Cubic(0.16, 1.0, 0.30, 1.0);
}

class AppElevation {
  /// Kâğıt sayfaları gölgesiz; sadece kenar çizgi + hafif iç doku.
  /// Drop shadow gerektiğinde küçük ve sıcak (ink rengiyle).
  static List<BoxShadow> page = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> sheet = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, -6),
    ),
  ];
}
