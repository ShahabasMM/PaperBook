import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Section title with an optional quiet text action.
class PbSectionHeader extends StatelessWidget {
  const PbSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppType.titleSmall(context))),
          ?trailing,
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.inkSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xs,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: AppType.label(context)
                        .copyWith(fontSize: 12.5, color: colors.inkSecondary),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: colors.inkSecondary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Page-level header used by pushed screens.
class PbTopBar extends StatelessWidget {
  const PbTopBar({
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
    this.centerTitle = false,
    this.transparent = false,
  });

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool centerTitle;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      color: transparent ? Colors.transparent : colors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: onBack == null
                      ? null
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: onBack,
                              splashFactory: NoSplash.splashFactory,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 22,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: title == null
                      ? const SizedBox.shrink()
                      : Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: centerTitle
                              ? TextAlign.center
                              : TextAlign.left,
                          style: AppType.titleSmall(context)
                              .copyWith(fontSize: 16),
                        ),
                ),
                for (final action in actions) ...[
                  action,
                  const SizedBox(width: AppSpace.xs),
                ],
                if (actions.isNotEmpty) const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
