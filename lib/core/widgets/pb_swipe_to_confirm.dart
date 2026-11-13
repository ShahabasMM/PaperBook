import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Glassy swipe track that confirms an action only when the handle is dragged
/// all the way from left to right.
class PbSwipeToConfirm extends StatefulWidget {
  const PbSwipeToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.busyLabel = 'Saving…',
    this.enabled = true,
    this.height = 62,
  });

  final String label;
  final Future<void> Function() onConfirmed;
  final String busyLabel;
  final bool enabled;
  final double height;

  @override
  State<PbSwipeToConfirm> createState() => _PbSwipeToConfirmState();
}

class _PbSwipeToConfirmState extends State<PbSwipeToConfirm>
    with SingleTickerProviderStateMixin {
  /// How far across the track the handle must travel before it saves.
  static const _threshold = 0.86;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
  )..addListener(_handleTick);

  double _value = 0;
  double _animationStart = 0;
  double _animationTarget = 0;
  double _maxDrag = 1;
  bool _busy = false;
  bool _dragging = false;

  bool get _canInteract => widget.enabled && !_busy;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    if (!mounted) return;
    final curved = AppMotion.emphasized.transform(_controller.value);
    setState(() {
      _value = _animationStart + (_animationTarget - _animationStart) * curved;
    });
  }

  void _animateTo(double target) {
    _controller.stop();
    _animationStart = _value;
    _animationTarget = target;
    _controller.forward(from: 0);
  }

  void _onDragStart(DragStartDetails details) {
    if (!_canInteract) return;
    _controller.stop();
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_canInteract) return;
    setState(() {
      _value = (_value + details.delta.dx / _maxDrag).clamp(0.0, 1.0);
    });
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!_canInteract) return;
    setState(() => _dragging = false);

    if (_value >= _threshold) {
      await _confirm();
    } else {
      _animateTo(0);
    }
  }

  void _onDragCancel() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    _animateTo(0);
  }

  Future<void> _confirm() async {
    if (!_canInteract) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    _animateTo(1);

    try {
      await widget.onConfirmed();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _animateTo(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final radius = BorderRadius.circular(widget.height / 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final handleSize = widget.height - 10;
        _maxDrag = math.max(1, constraints.maxWidth - widget.height);
        final handleLeft = 5 + _value * _maxDrag;

        return Semantics(
          label: widget.label,
          button: true,
          enabled: _canInteract,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _onDragCancel,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(
                        alpha: isDark ? 0.55 : 0.62,
                      ),
                      borderRadius: radius,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.09)
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Lime trail that follows the handle.
                        Positioned(
                          left: 5,
                          top: 5,
                          bottom: 5,
                          width: handleSize + _value * _maxDrag,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                handleSize / 2,
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.lime.withValues(alpha: 0.24),
                                  AppColors.lime.withValues(alpha: 0.06),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Soft glass sheen across the track.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: isDark ? 0.05 : 0.32,
                                    ),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.height,
                            ),
                            child: AnimatedOpacity(
                              opacity: _busy
                                  ? 1
                                  : (1 - _value * 1.5).clamp(0.0, 1.0),
                              duration: AppMotion.fast,
                              child: Text(
                                _busy ? widget.busyLabel : widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppType.label(context).copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.inkSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          left: handleLeft,
                          width: handleSize,
                          height: handleSize,
                          child: AnimatedScale(
                            scale: _dragging ? 1.04 : 1,
                            duration: AppMotion.fast,
                            curve: Curves.easeOut,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.lime.withValues(
                                      alpha: 0.38,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation(
                                          AppColors.onAccent,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      _value >= 0.99
                                          ? Icons.check_rounded
                                          : Icons.arrow_forward_rounded,
                                      size: 22,
                                      color: AppColors.onAccent,
                                    ),
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
        );
      },
    );
  }
}
