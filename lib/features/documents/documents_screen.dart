import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_chip.dart';
import '../../core/widgets/pb_empty_state.dart';
import '../../core/widgets/pb_icon_button.dart';
import '../../core/widgets/pb_reveal.dart';
import '../../core/widgets/pb_search_bar.dart';
import '../../core/widgets/pb_sort_button.dart';
import '../../data/models/document.dart';
import '../../data/models/document_category.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/settings/settings_controller.dart';
import '../add/add_document_sheet.dart';
import '../shell/app_navigation.dart';
import 'document_details_screen.dart';
import 'filter_sort_sheets.dart';
import 'search_screen.dart';
import 'widgets/document_grid_card.dart';
import 'widgets/document_list_tile.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  DocumentSort _sort = DocumentSort.newest;
  bool _warrantiedOnly = false;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DocumentRepository>();
    final navigation = context.watch<AppNavigationController>();
    final settings = context.watch<SettingsController>();
    final category = navigation.libraryCategory;
    final categoryCounts = repository.categoryCounts;

    final documents = repository.query(
      category: category,
      sort: _sort,
      warrantiedOnly: _warrantiedOnly,
    );
    final filtersActive = category != null || _warrantiedOnly;
    final isGrid = settings.viewMode == DocumentViewMode.grid;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = math.max(
            AppSpace.gutter,
            (constraints.maxWidth - AppSpace.maxContentWidth) / 2,
          );
          final contentWidth = constraints.maxWidth - sidePadding * 2;
          final columns = contentWidth >= 620 ? 3 : 2;
          final cardWidth = (contentWidth - (columns - 1) * 12) / columns;

          return Stack(
            children: [
              RefreshIndicator(
                color: context.colors.ink,
                backgroundColor: context.colors.surface,
                onRefresh: () async {
                  try {
                    await repository.load();
                  } catch (_) {
                    // Keep the current view; errors are non-blocking.
                  }
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding,
                        AppSpace.sm,
                        sidePadding,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: PbReveal(
                          index: 0,
                          child: _Header(
                            total: repository.count,
                            shown: documents.length,
                            filtersActive: filtersActive,
                            sort: _sort,
                            warrantiedOnly: _warrantiedOnly,
                            categoryCounts: categoryCounts,
                            selectedCategory: category,
                            onQueryChanged: (value) =>
                                navigation.setLibraryCategory(value),
                            onSearch: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SearchScreen(),
                              ),
                            ),
                            onToggleView: () => settings.setViewMode(
                              isGrid
                                  ? DocumentViewMode.list
                                  : DocumentViewMode.grid,
                            ),
                            isGrid: isGrid,
                            onSort: () => _openSort(context),
                            onFilter: () => _openFilters(category),
                          ),
                        ),
                      ),
                    ),
                    if (repository.count == 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sidePadding,
                          ),
                          child: PbEmptyState(
                            icon: Icons.folder_open_outlined,
                            title: 'Your vault is empty',
                            message:
                                'Add your first document to start building '
                                'your personal archive.',
                            actionLabel: 'Add document',
                            onAction: () => showAddDocumentSheet(context),
                          ),
                        ),
                      )
                    else if (documents.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sidePadding,
                          ),
                          child: PbEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching documents',
                            message:
                                'Nothing matches these filters. Try another '
                                'category or clear the filters.',
                            actionLabel: 'Clear filters',
                            onAction: () => _clearFilters(context),
                          ),
                        ),
                      )
                    else if (isGrid)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          AppSpace.md,
                          sidePadding,
                          96,
                        ),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 20,
                                mainAxisExtent: cardWidth / 0.82 + 52,
                              ),
                          itemCount: documents.length,
                          itemBuilder: (context, index) {
                            final document = documents[index];
                            final heroTag = 'documents-${document.id}';
                            return DocumentGridCard(
                              document: document,
                              heroTag: heroTag,
                              onTap: () =>
                                  _openDocument(context, document, heroTag),
                            );
                          },
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          sidePadding,
                          AppSpace.xs,
                          sidePadding,
                          96,
                        ),
                        sliver: SliverList.builder(
                          itemCount: documents.length,
                          itemBuilder: (context, index) {
                            final document = documents[index];
                            final heroTag = 'documents-${document.id}';
                            return DocumentListTile(
                              document: document,
                              heroTag: heroTag,
                              showDivider: index < documents.length - 1,
                              onTap: () =>
                                  _openDocument(context, document, heroTag),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (repository.count > 0)
                Positioned(
                  right: sidePadding,
                  bottom: AppSpace.lg,
                  child: _AddFab(onTap: () => showAddDocumentSheet(context)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSort(BuildContext context) async {
    final result = await showSortSheet(context, current: _sort);
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  Future<void> _openFilters(DocumentCategory? category) async {
    final repository = context.read<DocumentRepository>();
    final result = await showFilterSheet(
      context,
      category: category,
      warrantiedOnly: _warrantiedOnly,
      categoryCounts: repository.categoryCounts,
    );
    if (result == null || !mounted) return;
    setState(() => _warrantiedOnly = result.warrantiedOnly);
    context.read<AppNavigationController>().setLibraryCategory(result.category);
  }

  void _clearFilters(BuildContext context) {
    setState(() => _warrantiedOnly = false);
    context.read<AppNavigationController>().setLibraryCategory(null);
  }

  void _openDocument(BuildContext context, Document document, String heroTag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DocumentDetailsScreen(documentId: document.id!, heroTag: heroTag),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.shown,
    required this.filtersActive,
    required this.sort,
    required this.warrantiedOnly,
    required this.categoryCounts,
    required this.selectedCategory,
    required this.onQueryChanged,
    required this.onSearch,
    required this.onToggleView,
    required this.isGrid,
    required this.onSort,
    required this.onFilter,
  });

  final int total;
  final int shown;
  final bool filtersActive;
  final DocumentSort sort;
  final bool warrantiedOnly;
  final Map<DocumentCategory, int> categoryCounts;
  final DocumentCategory? selectedCategory;
  final ValueChanged<DocumentCategory?> onQueryChanged;
  final VoidCallback onSearch;
  final VoidCallback onToggleView;
  final bool isGrid;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Documents',
                style: AppType.headline(context).copyWith(fontSize: 27),
              ),
            ),
            PbIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onPressed: onSearch,
            ),
            const SizedBox(width: AppSpace.xs),
            PbIconButton(
              icon: isGrid
                  ? Icons.view_agenda_outlined
                  : Icons.grid_view_rounded,
              tooltip: isGrid ? 'List view' : 'Grid view',
              onPressed: onToggleView,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        PbSearchBar(hint: 'Search documents', readOnly: true, onTap: onSearch),
        const SizedBox(height: AppSpace.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              PbChip(
                label: 'All',
                selected: selectedCategory == null,
                count: total,
                onTap: () => onQueryChanged(null),
              ),
              for (final category in DocumentCategory.values) ...[
                const SizedBox(width: AppSpace.xs),
                PbChip(
                  label: category.label,
                  icon: category.icon,
                  selected: selectedCategory == category,
                  count: categoryCounts[category] ?? 0,
                  onTap: () => onQueryChanged(category),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: Text(
                filtersActive
                    ? '$shown of $total documents'
                    : total == 1
                    ? '1 document'
                    : '$total documents',
                style: AppType.caption(context).copyWith(fontSize: 12),
              ),
            ),
            PbSortButton(label: sort.shortLabel, onTap: onSort),
            const SizedBox(width: AppSpace.xs),
            _FilterButton(active: warrantiedOnly, onTap: onFilter),
          ],
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: active ? AppColors.lime : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: active ? Colors.transparent : colors.border,
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            size: 16,
            color: active ? AppColors.onAccent : colors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _AddFab extends StatelessWidget {
  const _AddFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Add document',
      child: Material(
        color: AppColors.lime,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add_rounded, size: 24, color: AppColors.onAccent),
          ),
        ),
      ),
    );
  }
}
