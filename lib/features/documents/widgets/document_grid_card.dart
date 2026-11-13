import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/document.dart';
import 'document_thumb.dart';

/// Library grid card: a large page preview with just enough metadata.
class DocumentGridCard extends StatelessWidget {
  const DocumentGridCard({
    super.key,
    required this.document,
    required this.onTap,
    this.heroTag,
  });

  final Document document;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.ink.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 0.82,
                child: DocumentThumb(
                  document: document,
                  radius: 16,
                  heroTag: heroTag,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      document.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label(context).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  if (document.amount != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      Formats.amount(document.amount),
                      style: AppType.numeric(context, size: 12.5),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${(document.merchant?.trim().isNotEmpty ?? false) ? document.merchant! : document.category.label}  ·  ${Formats.shortDate(document.documentDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.caption(context)
                    .copyWith(fontSize: 11.5, color: colors.inkTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
