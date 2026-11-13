import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/carbon_texture.dart';
import '../../core/widgets/pb_button.dart';
import '../../core/widgets/pb_logo.dart';
import '../../core/widgets/pb_reveal.dart';
import '../../data/settings/settings_controller.dart';

/// First-launch experience: full-dark, textured, typographic.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.darkBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Stack(
          children: [
            const Positioned.fill(child: _TexturedBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = math.max(
                    AppSpace.xl,
                    (constraints.maxWidth - 560) / 2,
                  );

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpace.md),
                            child: PbReveal(
                              index: 0,
                              child: PbWordmark(
                                fontSize: 19,
                                color: AppColors.darkInk,
                                markSize: 30,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.xxl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PbReveal(
                                  index: 1,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 2,
                                        color: AppColors.lime,
                                      ),
                                      const SizedBox(width: AppSpace.sm),
                                      Text(
                                        'YOUR PERSONAL DOCUMENT VAULT',
                                        style: AppType.overline(context)
                                            .copyWith(
                                              color: AppColors.lime,
                                              fontSize: 10,
                                              letterSpacing: 1.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpace.lg),
                                PbReveal(
                                  index: 2,
                                  child: Text(
                                    'A quiet place for\nevery document.',
                                    style: AppType.display(context).copyWith(
                                      fontSize: 43,
                                      height: 1.08,
                                      letterSpacing: -1.6,
                                      color: AppColors.darkInk,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpace.lg),
                                PbReveal(
                                  index: 3,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 340,
                                    ),
                                    child: Text(
                                      'Receipts, warranties, invoices and '
                                      'everything in between — stored privately '
                                      'on your device and always within reach.',
                                      style: AppType.body(context).copyWith(
                                        fontSize: 15.5,
                                        height: 1.55,
                                        color: AppColors.darkInkSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PbReveal(
                                index: 4,
                                child: PbButton(
                                  label: 'Get started',
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    context
                                        .read<SettingsController>()
                                        .completeOnboarding();
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpace.md),
                              PbReveal(
                                index: 5,
                                child: Center(
                                  child: Text(
                                    'Private by design  ·  No account needed',
                                    style: AppType.caption(context).copyWith(
                                      color: AppColors.darkInkTertiary,
                                      fontSize: 11.5,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.sm),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carbon weave fading from the top, with one restrained lime glow.
class _TexturedBackdrop extends StatelessWidget {
  const _TexturedBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 420,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0.0, 0.9],
            ).createShader(rect),
            child: const CarbonTexture(opacity: 0.05),
          ),
        ),
        Positioned(
          top: -160,
          right: -120,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.lime.withValues(alpha: 0.07),
                  AppColors.lime.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -180,
          bottom: -220,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.035),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
