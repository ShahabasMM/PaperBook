import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/pb_bottom_nav.dart';
import '../documents/documents_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import 'app_navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinations = [
    PbNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    PbNavItem(
      label: 'Documents',
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
    ),
    PbNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<AppNavigationController>();

    return Scaffold(
      body: IndexedStack(
        index: navigation.tabIndex,
        children: const [HomeScreen(), DocumentsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: PbBottomNav(
        items: _destinations,
        currentIndex: navigation.tabIndex,
        onSelected: navigation.selectTab,
      ),
    );
  }
}
