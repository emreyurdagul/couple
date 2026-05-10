import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.stamp,
      onPrimary: AppColors.paper,
      primaryContainer: AppColors.stampDeep,
      onPrimaryContainer: AppColors.paper,
      secondary: AppColors.leaf,
      onSecondary: AppColors.paper,
      secondaryContainer: AppColors.paperDeep,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.inkSoft,
      onTertiary: AppColors.paper,
      error: AppColors.error,
      onError: AppColors.paper,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.paperDeep,
      surfaceContainerHigh: AppColors.paperDeep,
      surfaceContainer: AppColors.paperDeep,
      surfaceContainerLow: AppColors.paper,
      surfaceContainerLowest: AppColors.paper,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.rule,
      outlineVariant: AppColors.ruleSoft,
      shadow: AppColors.ink,
      scrim: AppColors.ink,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
      inversePrimary: AppColors.paper,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      canvasColor: AppColors.paper,
      dividerColor: AppColors.rule,
      splashColor: AppColors.stamp.withValues(alpha: 0.08),
      highlightColor: AppColors.stamp.withValues(alpha: 0.04),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.stamp,
          foregroundColor: AppColors.paper,
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.ink, width: 1.2),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.stamp,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppSpacing.md,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.rule, width: 1.2),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.rule, width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.stamp, width: 1.6),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1.4),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1.6),
        ),
        labelStyle: GoogleFonts.fraunces(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: GoogleFonts.fraunces(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: AppColors.stamp,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.inkMute,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.error,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.rule,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontStyle: FontStyle.italic,
          color: AppColors.ink,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.inkSoft,
          height: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.paper,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.stamp,
        linearTrackColor: AppColors.rule,
        circularTrackColor: AppColors.rule,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.stamp,
        unselectedLabelColor: AppColors.inkSoft,
        indicatorColor: AppColors.stamp,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static ThemeData dark() => light(); // şimdilik aynı; defter dili aydınlık-zemin
}
