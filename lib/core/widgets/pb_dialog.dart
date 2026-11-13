import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'pb_button.dart';

/// PaperBook confirmation dialog. Resolves to `true` when confirmed.
Future<bool> showPbDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: context.isDark ? 0.6 : 0.3),
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: destructive
                          ? colors.dangerSoft
                          : colors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: destructive ? colors.danger : colors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                Text(
                  title,
                  style: AppType.title(context).copyWith(fontSize: 19),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  message,
                  style: AppType.bodySmall(context).copyWith(height: 1.5),
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: PbButton(
                        label: cancelLabel,
                        variant: PbButtonVariant.muted,
                        size: PbButtonSize.medium,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: PbButton(
                        label: confirmLabel,
                        variant: destructive
                            ? PbButtonVariant.destructive
                            : PbButtonVariant.primary,
                        size: PbButtonSize.medium,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  return result ?? false;
}

Future<bool> confirmDeleteDocument(BuildContext context) {
  return showPbDialog(
    context: context,
    title: 'Delete document?',
    message:
        'This removes the document and its attached file from PaperBook. '
        'This action cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
    icon: Icons.delete_outline_rounded,
  );
}
