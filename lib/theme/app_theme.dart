import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full palette mirroring src/theme.ts
class AppColors {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceAlt2;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderLight;
  final Color success;
  final Color warning;
  final Color danger;
  final List<Color> gradient;
  final List<Color> gradientSoft;
  final Color overlay;
  final bool isDark;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceAlt2,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.success,
    required this.warning,
    required this.danger,
    required this.gradient,
    required this.gradientSoft,
    required this.overlay,
    required this.isDark,
  });

  static const light = AppColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFF7ED),
    surfaceAlt2: Color(0xFFFFEDD5),
    primary: Color(0xFFF97316),
    primaryDark: Color(0xFFEA580C),
    primaryLight: Color(0xFFFB923C),
    accent: Color(0xFFFB923C),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFF1F5F9),
    borderLight: Color(0xFFF8FAFC),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    gradient: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
    gradientSoft: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
    overlay: Color(0x800F172A),
    isDark: false,
  );

  static const dark = AppColors(
    background: Color(0xFF0A0A0B),
    surface: Color(0xFF17171A),
    surfaceAlt: Color(0xFF1F1F23),
    surfaceAlt2: Color(0xFF27272A),
    primary: Color(0xFFFB923C),
    primaryDark: Color(0xFFF97316),
    primaryLight: Color(0xFFFDBA74),
    accent: Color(0xFFFB923C),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    border: Color(0xFF27272A),
    borderLight: Color(0xFF1F1F23),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    gradient: [Color(0xFFFDBA74), Color(0xFFF97316), Color(0xFFEA580C)],
    gradientSoft: [Color(0xFF1F1F23), Color(0xFF27272A)],
    overlay: Color(0xB3000000),
    isDark: true,
  );
}

/// Design tokens (mirrors radius + spacing in src/theme.ts)
class Radii {
  static const sm = 10.0, md = 14.0, lg = 18.0, xl = 22.0, xxl = 28.0;
}

class Gaps {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
}

class Shadows {
  static List<BoxShadow> card(AppColors c) => [
        BoxShadow(
          color: (c.isDark ? Colors.black : const Color(0xFF0F172A)).withOpacity(c.isDark ? 0.3 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
  static List<BoxShadow> strong(AppColors c) => [
        BoxShadow(
          color: const Color(0xFFF97316).withOpacity(0.3),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Global logo URL — keep in sync with RN app
const kLogoAssetPath = 'assets/images/logo.png';

/// MaterialApp themes
class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
      primary: c.primary,
      surface: c.surface,
      error: c.danger,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: scheme.copyWith(
        secondary: c.accent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: c.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: c.textPrimary,
        ),
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? const Color(0xFF17171A) : const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: c.textPrimary),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
        errorStyle: TextStyle(color: c.danger, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      // Expose palette via extension so widgets can read it via Theme.of(context).extension<AppColors>()
      extensions: <ThemeExtension<dynamic>>[_AppColorsExt(c)],
    );
  }
}

class _AppColorsExt extends ThemeExtension<_AppColorsExt> {
  final AppColors colors;
  _AppColorsExt(this.colors);

  @override
  ThemeExtension<_AppColorsExt> copyWith({AppColors? colors}) =>
      _AppColorsExt(colors ?? this.colors);

  @override
  ThemeExtension<_AppColorsExt> lerp(ThemeExtension<_AppColorsExt>? other, double t) => this;
}

/// Sugar: context.appColors — use anywhere in the widget tree
extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<_AppColorsExt>()?.colors ?? AppColors.light;
}
