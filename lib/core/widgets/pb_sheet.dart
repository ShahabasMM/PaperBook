import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Opens a modal sheet that respects the keyboard and never exceeds 92% height.
Future<T?> showPbSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: context.colors.surface,
    barrierColor: Colors.black.withValues(alpha: context.isDark ? 0.55 : 0.32),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
          ),
          child: builder(sheetContext),
        ),
      );
    },
  );
}

/// Shared sheet frame: drag handle, title block and safe bottom padding.
class PbSheetFrame extends StatelessWidget {
  const PbSheetFrame({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      0,
      AppSpace.gutter,
      0,
    ),
    this.scrollable = true,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: AppType.title(context)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 5),
                        Text(subtitle!, style: AppType.bodySmall(context)),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        Flexible(
          child: scrollable
              ? SingleChildScrollView(padding: contentPadding, child: child)
              : Padding(padding: contentPadding, child: child),
        ),
        SizedBox(height: bottomInset > 0 ? bottomInset : AppSpace.lg),
      ],
    );
  }
}
