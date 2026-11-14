import 'package:flutter/material.dart';

/// Semantic color tokens adapting automatically across Light and Dark themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color surfaceCanvas;
  final Color surfaceCard;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primarySoft;
  final Color accentCyan;
  final Color accentTeal;
  final Color success;
  final Color warning;
  final Color danger;
  final Color codeBg;
  final Color codeText;
  final Color chartGrid;
  final Color gaugeTrack;
  final Color heroStart;
  final Color heroEnd;
  final Color shadow;

  const AppColors({
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primarySoft,
    required this.accentCyan,
    required this.accentTeal,
    required this.success,
    required this.warning,
    required this.danger,
    required this.codeBg,
    required this.codeText,
    required this.chartGrid,
    required this.gaugeTrack,
    required this.heroStart,
    required this.heroEnd,
    required this.shadow,
  });

  static const AppColors light = AppColors(
    surfaceCanvas: Color(0xFFF3F6FB),
    surfaceCard: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF8FAFC),
    surfaceSubtle: Color(0xFFE9EFF8),
    border: Color(0xFFDDE5F0),
    borderStrong: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    primary: Color(0xFF2563EB),
    primarySoft: Color(0xFFE0ECFF),
    accentCyan: Color(0xFF0284C7),
    accentTeal: Color(0xFF0D9488),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    codeBg: Color(0xFFF1F5F9),
    codeText: Color(0xFF0F172A),
    chartGrid: Color(0xFFE2E8F0),
    gaugeTrack: Color(0xFFE2E8F0),
    heroStart: Color(0xFFE8F0FE),
    heroEnd: Color(0xFFE6FAF5),
    shadow: Color(0x0D0F172A),
  );

  static const AppColors dark = AppColors(
    surfaceCanvas: Color(0xFF0B1120),
    surfaceCard: Color(0xFF131C31),
    surfaceElevated: Color(0xFF19243D),
    surfaceSubtle: Color(0xFF0F172A),
    border: Color(0xFF23304C),
    borderStrong: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    primary: Color(0xFF3B82F6),
    primarySoft: Color(0xFF172554),
    accentCyan: Color(0xFF38BDF8),
    accentTeal: Color(0xFF2DD4BF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    codeBg: Color(0xFF090E1A),
    codeText: Color(0xFFBAE6FD),
    chartGrid: Color(0xFF1E293B),
    gaugeTrack: Color(0xFF24324D),
    heroStart: Color(0xFF15223D),
    heroEnd: Color(0xFF0F2933),
    shadow: Color(0x40000000),
  );

  @override
  AppColors copyWith({
    Color? surfaceCanvas,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? primarySoft,
    Color? accentCyan,
    Color? accentTeal,
    Color? success,
    Color? warning,
    Color? danger,
    Color? codeBg,
    Color? codeText,
    Color? chartGrid,
    Color? gaugeTrack,
    Color? heroStart,
    Color? heroEnd,
    Color? shadow,
  }) {
    return AppColors(
      surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accentCyan: accentCyan ?? this.accentCyan,
      accentTeal: accentTeal ?? this.accentTeal,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      codeBg: codeBg ?? this.codeBg,
      codeText: codeText ?? this.codeText,
      chartGrid: chartGrid ?? this.chartGrid,
      gaugeTrack: gaugeTrack ?? this.gaugeTrack,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      codeBg: Color.lerp(codeBg, other.codeBg, t)!,
      codeText: Color.lerp(codeText, other.codeText, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      gaugeTrack: Color.lerp(gaugeTrack, other.gaugeTrack, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Convenience accessor for semantic [AppColors] from any widget [BuildContext].
extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

/// Builds the cohesive Light and Dark [ThemeData] definitions for ThingLarp.
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light, AppColors.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark, AppColors.dark);

  static ThemeData _buildTheme(Brightness brightness, AppColors colors) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      secondary: colors.accentTeal,
      surface: colors.surfaceCard,
      error: colors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.surfaceCanvas,
      cardColor: colors.surfaceCard,
      dividerColor: colors.border,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceCanvas,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        dividerColor: colors.border,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.border),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textSecondary),
        bodySmall: TextStyle(color: colors.textTertiary),
      ),
    );
  }
}
