import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum PbButtonVariant { primary, secondary, muted, ghost, destructive }

enum PbButtonSize { medium, large }

/// The single button primitive used across PaperBook.
///
/// Press feedback is a 0.98 scale — no bounce, no ripple.
class PbButton extends StatefulWidget {
  const PbButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PbButtonVariant.primary,
    this.size = PbButtonSize.large,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PbButtonVariant variant;
  final PbButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  bool get _enabled => onPressed != null && !loading;

  @override
  State<PbButton> createState() => _PbButtonState();
}

class _PbButtonState extends State<PbButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget._enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = widget.size == PbButtonSize.large ? 54.0 : 46.0;

    final (background, foreground, border) = switch (widget.variant) {
      PbButtonVariant.primary => (
        AppColors.lime,
        AppColors.onAccent,
        Colors.transparent,
      ),
      PbButtonVariant.secondary => (
        Colors.transparent,
        colors.ink,
        colors.border,
      ),
      PbButtonVariant.muted => (
        colors.surfaceMuted,
        colors.ink,
        Colors.transparent,
      ),
      PbButtonVariant.ghost => (
        Colors.transparent,
        colors.inkSecondary,
        Colors.transparent,
      ),
      PbButtonVariant.destructive => (
        colors.dangerSoft,
        colors.danger,
        Colors.transparent,
      ),
    };

    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: AppIconSize.md, color: foreground),
          const SizedBox(width: AppSpace.xs),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: foreground,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: widget._enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget._enabled ? 1 : 0.45,
          duration: AppMotion.fast,
          child: Listener(
            onPointerDown: (_) => _setPressed(true),
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: Material(
              color: background,
              borderRadius: AppRadius.button,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget._enabled ? widget.onPressed : null,
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: height,
                  width: widget.fullWidth ? double.infinity : null,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.button,
                    border: Border.all(color: border),
                  ),
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
