import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'pb_logo.dart';

/// Three softly pulsing dots — the app's only loading motif.
class PbDotsLoader extends StatefulWidget {
  const PbDotsLoader({super.key, this.size = 6, this.color});

  final double size;
  final Color? color;

  @override
  State<PbDotsLoader> createState() => _PbDotsLoaderState();
}

class _PbDotsLoaderState extends State<PbDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colors.inkSecondary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) SizedBox(width: widget.size * 0.9),
              Opacity(
                opacity: 0.25 + 0.75 * _dotValue(index, _controller.value),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double _dotValue(int index, double progress) {
    final shifted = (progress + index * 0.16) % 1.0;
    final wave = shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2;
    return Curves.easeInOut.transform(wave);
  }
}

/// Branded boot/loading screen.
class PbSplashLoader extends StatelessWidget {
  const PbSplashLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return ColoredBox(
      color: isDark ? const Color(0xFF101010) : context.colors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PbLogoMark(size: 48),
            const SizedBox(height: AppSpace.lg),
            Text('PaperBook', style: AppType.title(context)),
            const SizedBox(height: AppSpace.lg),
            PbDotsLoader(color: isDark ? Colors.white38 : null),
          ],
        ),
      ),
    );
  }
}
