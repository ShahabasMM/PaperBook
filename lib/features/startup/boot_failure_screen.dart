import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_theme.dart';

/// Shown only if startup fails before the app can mount.
///
/// Keeping this screen dependency-free guarantees the user sees an explanation
/// instead of an endless blank launch screen.
class BootFailureScreen extends StatelessWidget {
  const BootFailureScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PaperBook',
                      style: TextStyle(
                        fontFamily: AppType.brand,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: AppColors.darkInk,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    Container(width: 22, height: 2, color: AppColors.lime),
                    const SizedBox(height: AppSpace.lg),
                    const Text(
                      'PaperBook could not start.',
                      style: TextStyle(
                        fontFamily: AppType.brand,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: AppColors.darkInk,
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    const Text(
                      'Your documents are safe. Close and reopen the app to try '
                      'again. If this keeps happening, the details below will '
                      'help you report it.',
                      style: TextStyle(
                        fontFamily: AppType.bodyFamily,
                        fontSize: 14.5,
                        height: 1.55,
                        color: AppColors.darkInkSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: SelectableText(
                        error.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.darkInkSecondary,
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
  }
}
