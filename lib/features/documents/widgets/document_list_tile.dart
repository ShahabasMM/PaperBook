import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/document.dart';
import 'document_thumb.dart';

/// Dense library row: preview, title, merchant and date, amount aligned right.
class DocumentListTile extends StatelessWidget {
  const DocumentListTile({
    super.key,
    required this.document,
    required this.onTap,
    this.showDivider = true,
    this.heroTag,
  });

  final Document document;
  final VoidCallback onTap;
  final bool showDivider;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: colors.ink.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  DocumentThumb(
                    document: document,
                    width: 52,
                    height: 64,
                    radius: 10,
                    heroTag: heroTag,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                document.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.label(context).copyWith(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Text(
                              Formats.amount(document.amount),
                              style: AppType.numeric(context, size: 13.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (document.merchant?.trim().isNotEmpty ?? false)
                              ? document.merchant!
                              : document.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodySmall(context)
                              .copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              Formats.date(document.documentDate),
                              style: AppType.caption(context).copyWith(
                                fontSize: 11,
                                color: colors.inkTertiary,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 7),
                              width: 2.5,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: colors.inkTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                document.category.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.caption(context).copyWith(
                                  fontSize: 11,
                                  color: colors.inkTertiary,
                                ),
                              ),
                            ),
                            if (document.warrantyActive) ...[
                              const SizedBox(width: AppSpace.xs),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB8D400),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Container(height: 1, color: colors.border),
          ),
      ],
    );
  }
}
