import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pb_chip.dart';
import '../../../core/widgets/pb_sheet.dart';
import '../../../data/models/document.dart';
import '../../../data/models/document_category.dart';

class LibraryFilterResult {
  const LibraryFilterResult({
    required this.category,
    required this.warrantiedOnly,
  });

  final DocumentCategory? category;
  final bool warrantiedOnly;
}

/// Minimal sort picker.
Future<DocumentSort?> showSortSheet(
  BuildContext context, {
  required DocumentSort current,
  String title = 'Sort documents',
  List<DocumentSort> sorts = DocumentSort.values,
}) {
  return showPbSheet<DocumentSort>(
    context: context,
    builder: (sheetContext) {
      return PbSheetFrame(
        title: title,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in sorts)
              _SortOption(
                label: sort.label,
                selected: sort == current,
                onTap: () => Navigator.of(sheetContext).pop(sort),
              ),
            const SizedBox(height: AppSpace.xs),
          ],
        ),
      );
    },
  );
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.ink.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppType.body(context).copyWith(
                    color: selected ? colors.ink : colors.inkSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDFFF00),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Color(0xFF171717),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter sheet: category and warranty presence.
Future<LibraryFilterResult?> showFilterSheet(
  BuildContext context, {
  required DocumentCategory? category,
  required bool warrantiedOnly,
  required Map<DocumentCategory, int> categoryCounts,
}) {
  return showPbSheet<LibraryFilterResult>(
    context: context,
    builder: (sheetContext) {
      return _FilterSheet(
        initialCategory: category,
        initialWarrantiedOnly: warrantiedOnly,
        categoryCounts: categoryCounts,
      );
    },
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initialCategory,
    required this.initialWarrantiedOnly,
    required this.categoryCounts,
  });

  final DocumentCategory? initialCategory;
  final bool initialWarrantiedOnly;
  final Map<DocumentCategory, int> categoryCounts;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DocumentCategory? _category = widget.initialCategory;
  late bool _warrantiedOnly = widget.initialWarrantiedOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PbSheetFrame(
      title: 'Filter',
      subtitle: 'Narrow the library to what you need.',
      trailing: TextButton(
        onPressed: () {
          setState(() {
            _category = null;
            _warrantiedOnly = false;
          });
        },
        style: TextButton.styleFrom(
          foregroundColor: colors.inkSecondary,
          splashFactory: NoSplash.splashFactory,
        ),
        child: Text(
          'Reset',
          style: AppType.label(context)
              .copyWith(fontSize: 12.5, color: colors.inkSecondary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CATEGORY',
            style: AppType.overline(context)
                .copyWith(fontSize: 10, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              PbChip(
                label: 'All',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final category in DocumentCategory.values)
                PbChip(
                  label: category.label,
                  selected: _category == category,
                  count: widget.categoryCounts[category] ?? 0,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            'HIGHLIGHTS',
            style: AppType.overline(context)
                .copyWith(fontSize: 10, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpace.xs),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Warranty details',
                        style: AppType.label(
                          context,
                        ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Only documents with a warranty end date',
                        style: AppType.caption(context)
                            .copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _warrantiedOnly,
                  activeTrackColor: const Color(0xFFDFFF00),
                  activeThumbColor: const Color(0xFF171717),
                  inactiveTrackColor: colors.surfaceMuted,
                  onChanged: (value) => setState(() => _warrantiedOnly = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                LibraryFilterResult(
                  category: _category,
                  warrantiedOnly: _warrantiedOnly,
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ),
        ],
      ),
    );
  }
}
