import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Theme-aware palette access: `context.colors.ink`.
extension PbThemeContext on BuildContext {
  PbPalette get colors => Theme.of(this).extension<PbPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  TextTheme get text => Theme.of(this).textTheme;
  MediaQueryData get mq => MediaQuery.of(this);
}

@immutable
class PbPalette extends ThemeExtension<PbPalette> {
  const PbPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.border,
    required this.danger,
    required this.dangerSoft,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color border;
  final Color danger;
  final Color dangerSoft;

  static const light = PbPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    ink: AppColors.ink,
    inkSecondary: AppColors.inkSecondary,
    inkTertiary: AppColors.inkTertiary,
    border: AppColors.border,
    danger: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
  );

  static const dark = PbPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceMuted: AppColors.darkSurfaceMuted,
    ink: AppColors.darkInk,
    inkSecondary: AppColors.darkInkSecondary,
    inkTertiary: AppColors.darkInkTertiary,
    border: AppColors.darkBorder,
    danger: AppColors.darkDanger,
    dangerSoft: AppColors.darkDangerSoft,
  );

  @override
  PbPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? border,
    Color? danger,
    Color? dangerSoft,
  }) {
    return PbPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      border: border ?? this.border,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  PbPalette lerp(ThemeExtension<PbPalette>? other, double t) {
    if (other is! PbPalette) return this;
    return PbPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, PbPalette.light);
  static ThemeData dark() => _build(Brightness.dark, PbPalette.dark);

  static ThemeData _build(Brightness brightness, PbPalette palette) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.lime,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.lime,
      onSecondary: AppColors.onAccent,
      error: palette.danger,
      onError: isDark ? AppColors.darkBackground : Colors.white,
      surface: palette.background,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.surfaceMuted,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: AppType.bodyFamily,
        bodyColor: palette.ink,
        displayColor: palette.ink,
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.ink,
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.32),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppType.brand,
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: palette.ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppType.bodyFamily,
          fontSize: 14.5,
          height: 1.5,
          color: palette.inkSecondary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lime,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.ink,
        selectionColor: AppColors.lime.withValues(alpha: 0.5),
        selectionHandleColor: palette.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          textStyle: const TextStyle(
            fontFamily: AppType.bodyFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PbPageTransitionsBuilder(),
          TargetPlatform.iOS: PbPageTransitionsBuilder(),
          TargetPlatform.macOS: PbPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Smooth fade-through page transition: no bounce, no heavy parallax.
class PbPageTransitionsBuilder extends PageTransitionsBuilder {
  const PbPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
