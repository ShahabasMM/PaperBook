import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum PbIconButtonStyle { plain, filled, outlined }

/// Compact icon action with an accessible 44pt touch target.
class PbIconButton extends StatelessWidget {
  const PbIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style = PbIconButtonStyle.filled,
    this.size = 40,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final PbIconButtonStyle style;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = switch (style) {
      PbIconButtonStyle.filled => colors.surfaceMuted,
      PbIconButtonStyle.outlined => Colors.transparent,
      PbIconButtonStyle.plain => Colors.transparent,
    };

    final button = Material(
      color: background,
      shape: style == PbIconButtonStyle.outlined
          ? CircleBorder(side: BorderSide(color: colors.border))
          : const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.ink.withValues(alpha: 0.04),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: AppIconSize.md, color: color ?? colors.ink),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
