import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/document_repository.dart';
import 'data/settings/settings_controller.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/shell/app_navigation.dart';
import 'features/shell/app_shell.dart';

class PaperBookApp extends StatelessWidget {
  const PaperBookApp({
    super.key,
    required this.repository,
    required this.settings,
  });

  final DocumentRepository repository;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: repository),
        ChangeNotifierProvider(create: (_) => AppNavigationController()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, preferences, _) {
          return MaterialApp(
            title: 'PaperBook',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: preferences.themeMode,
            scrollBehavior: const _PbScrollBehavior(),
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: isDark
                    ? SystemUiOverlayStyle.light.copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: const Color(0xFF101010),
                        systemNavigationBarIconBrightness: Brightness.light,
                      )
                    : SystemUiOverlayStyle.dark.copyWith(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: const Color(0xFFF7F8F5),
                        systemNavigationBarIconBrightness: Brightness.dark,
                      ),
                child: MediaQuery.withClampedTextScaling(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.35,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

/// Switches between first-run welcome and the app shell with a soft fade.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<SettingsController, bool>(
      (settings) => settings.onboarded,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: onboarded
          ? const AppShell(key: ValueKey('shell'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}

class _PbScrollBehavior extends MaterialScrollBehavior {
  const _PbScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
