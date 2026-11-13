import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/folder_icons.dart';

/// Folder icon used anywhere a folder is shown.
///
/// The icon follows the folder name automatically, so renaming a folder from
/// "Petrol" to "Fuel" updates every surface without extra state.
class FolderIconBadge extends StatelessWidget {
  const FolderIconBadge({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Icon(
      FolderIcons.forName(name),
      size: size,
      color: color ?? colors.ink,
    );
  }
}
