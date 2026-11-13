import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum PbToastKind { info, success, error }

/// Lightweight overlay toast. One at a time, auto-dismissing, never blocking.
abstract final class PbToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    PbToastKind kind = PbToastKind.info,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _timer?.cancel();
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastHost(
        message: message,
        kind: kind,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (entry.mounted) entry.remove();
      if (_current == entry) _current = null;
    });
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.kind,
    required this.onDismissed,
  });

  final String message;
  final PbToastKind kind;
  final VoidCallback onDismissed;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 160),
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final background = isDark ? AppColors.darkInk : AppColors.ink;
    final foreground = isDark ? AppColors.darkBackground : AppColors.background;
    final icon = switch (widget.kind) {
      PbToastKind.success => Icons.check_circle_outline_rounded,
      PbToastKind.error => Icons.error_outline_rounded,
      PbToastKind.info => Icons.info_outline_rounded,
    };
    final iconColor = switch (widget.kind) {
      PbToastKind.success => AppColors.lime,
      PbToastKind.error => isDark ? AppColors.danger : const Color(0xFFFFB4AB),
      PbToastKind.info =>
        isDark ? AppColors.inkTertiary : AppColors.darkInkSecondary,
    };

    return Positioned(
      left: AppSpace.gutter,
      right: AppSpace.gutter,
      bottom: MediaQuery.paddingOf(context).bottom + 92,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, child) {
            return Opacity(
              opacity: _curve.value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - _curve.value)),
                child: child,
              ),
            );
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 17, color: iconColor),
                      const SizedBox(width: AppSpace.xs),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppType.label(context).copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
