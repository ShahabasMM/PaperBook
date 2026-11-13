import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_button.dart';
import '../../core/widgets/pb_icon_button.dart';
import '../../core/widgets/pb_logo.dart';
import '../../core/widgets/pb_reveal.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document_folder.dart';
import '../../data/repositories/document_repository.dart';
import '../documents/search_screen.dart';
import '../folders/create_folder_sheet.dart';
import '../folders/folder_screen.dart';
import '../folders/widgets/folder_icon_badge.dart';
import 'widgets/activity_heatmap.dart';

/// Folder-first dashboard. The heatmap stays at the top; everything below it
/// is the folder grid, which replaces the old shortcuts and recent strip.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DocumentRepository>();
    final folders = repository.folders;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: context.colors.ink,
        backgroundColor: context.colors.surface,
        onRefresh: () async {
          try {
            await repository.load();
          } catch (_) {
            // The library surfaces its own errors; keep the dashboard calm.
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.sm,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpace.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PbReveal(
                    index: 0,
                    child: Row(
                      children: [
                        const PbWordmark(fontSize: 19, markSize: 29),
                        const Spacer(),
                        PbIconButton(
                          icon: Icons.search_rounded,
                          tooltip: 'Search documents',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SearchScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  PbReveal(
                    index: 1,
                    child: ActivityHeatmap(activity: repository.activityByDay),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  PbReveal(
                    index: 2,
                    child: _FolderHeader(
                      folderCount: folders.length,
                      onCreate: () => _createFolder(context),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  PbReveal(
                    index: 3,
                    child: folders.isEmpty
                        ? _EmptyFolderState(
                            onCreate: () => _createFolder(context),
                          )
                        : _FolderGrid(
                            folders: folders,
                            repository: repository,
                            onOpen: (folder) => _openFolder(context, folder),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createFolder(BuildContext context) async {
    final folder = await showFolderFormSheet(context);
    if (folder == null || !context.mounted) return;
    PbToast.show(context, 'Folder created', kind: PbToastKind.success);
  }

  void _openFolder(BuildContext context, DocumentFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FolderScreen(folderId: folder.id!),
      ),
    );
  }
}

class _FolderGrid extends StatelessWidget {
  const _FolderGrid({
    required this.folders,
    required this.repository,
    required this.onOpen,
  });

  final List<DocumentFolder> folders;
  final DocumentRepository repository;
  final ValueChanged<DocumentFolder> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680
            ? 4
            : constraints.maxWidth >= 440
            ? 3
            : 2;
        const gap = AppSpace.sm;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final folder in folders)
              SizedBox(
                width: width,
                child: _FolderTile(
                  folder: folder,
                  count: repository.documentCountInFolder(folder.id),
                  onTap: () => onOpen(folder),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.count,
    required this.onTap,
  });

  final DocumentFolder folder;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.ink.withValues(alpha: 0.025),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FolderIconBadge(name: folder.name, size: 54),
              const SizedBox(height: 9),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.label(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count == 1 ? '1 document' : '$count documents',
                textAlign: TextAlign.center,
                style: AppType.caption(context)
                    .copyWith(fontSize: 12, color: colors.inkTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFolderState extends StatelessWidget {
  const _EmptyFolderState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.xxl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.create_new_folder_outlined,
              size: 32,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'No folders yet',
            style: AppType.titleSmall(context).copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Create a folder for petrol, rent or groceries, then add the '
            'bills that belong there.',
            textAlign: TextAlign.center,
            style: AppType.bodySmall(context)
                .copyWith(fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: AppSpace.lg),
          PbButton(
            label: 'Create folder',
            icon: Icons.add_rounded,
            size: PbButtonSize.medium,
            fullWidth: false,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({required this.folderCount, required this.onCreate});

  final int folderCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Folders',
                style: AppType.title(context).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                folderCount == 1 ? '1 folder' : '$folderCount folders',
                style: AppType.caption(context)
                    .copyWith(fontSize: 13, color: colors.inkSecondary),
              ),
            ],
          ),
        ),
        PbButton(
          label: 'Add Folder',
          icon: Icons.add_rounded,
          size: PbButtonSize.medium,
          fullWidth: false,
          onPressed: onCreate,
        ),
      ],
    );
  }
}
