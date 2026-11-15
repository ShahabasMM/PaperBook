import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The PaperBook monogram: the open-book mark (no background).
class PbLogoMark extends StatelessWidget {
  const PbLogoMark({super.key, this.size = 36, this.color});

  final double size;

  /// Optional tint. Defaults to the theme ink so the mark stays legible on
  /// both the light paper background and the dark carbon background.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PaperBook logo',
      image: true,
      child: Image.asset(
        'assets/logo/paperbook_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        color: color ?? context.colors.ink,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (context, error, stackTrace) =>
            _PbLogoMarkFallback(size: size),
      ),
    );
  }
}

/// Shown if the brand asset is ever missing (e.g. in a stripped-down build).
class _PbLogoMarkFallback extends StatelessWidget {
  const _PbLogoMarkFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'P',
      style: TextStyle(
        fontFamily: AppType.brand,
        fontSize: size * 0.62,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.lime,
      ),
    );
  }
}

class PbWordmark extends StatelessWidget {
  const PbWordmark({
    super.key,
    this.fontSize = 18,
    this.color,
    this.markSize,
    this.showMark = true,
    this.gap = AppSpace.sm,
  });

  final double fontSize;
  final Color? color;
  final double? markSize;
  final bool showMark;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          PbLogoMark(size: markSize ?? fontSize * 1.45),
          SizedBox(width: gap),
        ],
        Text(
          'PaperBook',
          style: TextStyle(
            fontFamily: AppType.brand,
            fontSize: fontSize,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
