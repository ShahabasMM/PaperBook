import 'package:flutter/material.dart';

import 'app_colors.dart';

/// PaperBook type system.
///
/// Space Grotesk carries brand, headings and prominent labels.
/// Inter carries body copy and numerical detail.
abstract final class AppType {
  static const brand = 'SpaceGrotesk';
  static const bodyFamily = 'Inter';

  static const _display = TextStyle(
    fontFamily: brand,
    fontSize: 38,
    height: 1.12,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.1,
    color: AppColors.ink,
  );

  static const _headline = TextStyle(
    fontFamily: brand,
    fontSize: 28,
    height: 1.16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    color: AppColors.ink,
  );

  static const _title = TextStyle(
    fontFamily: brand,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.35,
    color: AppColors.ink,
  );

  static const _titleSmall = TextStyle(
    fontFamily: brand,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static const _body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    height: 1.48,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: AppColors.ink,
  );

  static const _bodySmall = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13.5,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
    color: AppColors.inkSecondary,
  );

  static const _label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: AppColors.ink,
  );

  static const _caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
    color: AppColors.inkSecondary,
  );

  static const _overline = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 10.5,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: AppColors.inkSecondary,
  );

  // Public accessors with theme-aware colour. ---------------------------------

  static TextStyle display(BuildContext context) =>
      _display.copyWith(color: _text(context));
  static TextStyle headline(BuildContext context) =>
      _headline.copyWith(color: _text(context));
  static TextStyle title(BuildContext context) =>
      _title.copyWith(color: _text(context));
  static TextStyle titleSmall(BuildContext context) =>
      _titleSmall.copyWith(color: _text(context));
  static TextStyle body(BuildContext context) =>
      _body.copyWith(color: _text(context));
  static TextStyle bodySmall(BuildContext context) =>
      _bodySmall.copyWith(color: _secondary(context));
  static TextStyle label(BuildContext context) =>
      _label.copyWith(color: _text(context));
  static TextStyle caption(BuildContext context) =>
      _caption.copyWith(color: _secondary(context));
  static TextStyle overline(BuildContext context) =>
      _overline.copyWith(color: _secondary(context));

  static Color _text(BuildContext context) =>
      isDark(context) ? AppColors.darkInk : AppColors.ink;
  static Color _secondary(BuildContext context) =>
      isDark(context) ? AppColors.darkInkSecondary : AppColors.inkSecondary;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Numeric style with tabular figures for aligned amounts.
  static TextStyle numeric(BuildContext context, {double size = 15}) =>
      _body.copyWith(
        color: _text(context),
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: -0.2,
      );

  static TextTheme textTheme(BuildContext context) => TextTheme(
    displayLarge: display(context),
    displayMedium: headline(context),
    displaySmall: title(context),
    headlineMedium: titleSmall(context),
    titleMedium: label(context),
    bodyLarge: body(context),
    bodyMedium: bodySmall(context),
    labelLarge: label(context),
    labelMedium: caption(context),
    labelSmall: overline(context),
  );
}
