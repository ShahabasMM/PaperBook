import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_button.dart';
import '../../core/widgets/pb_dialog.dart';
import '../../core/widgets/pb_empty_state.dart';
import '../../core/widgets/pb_icon_button.dart';
import '../../core/widgets/pb_section_header.dart';
import '../../core/widgets/pb_sheet.dart';
import '../../core/widgets/pb_sort_button.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';
import '../../data/models/document_folder.dart';
import '../../data/repositories/document_repository.dart';
import '../add/add_document_sheet.dart';
import '../documents/document_details_screen.dart';
import '../documents/filter_sort_sheets.dart';
import '../documents/widgets/document_list_tile.dart';
import 'create_folder_sheet.dart';
import 'widgets/folder_icon_badge.dart';

enum _FolderAction { rename, delete }

class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folderId});

  final int folderId;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  DocumentSort _sort = DocumentSort.newest;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DocumentRepository>();
    final folder = repository.findFolderById(widget.folderId);
    if (folder == null) return const _MissingFolderScreen();

    final documents = repository.query(folderId: widget.folderId, sort: _sort);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          PbTopBar(
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              PbIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'Folder options',
                style: PbIconButtonStyle.plain,
                onPressed: () => _openActions(context, folder),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                AppSpace.xl,
              ),
              children: [
                _FolderHeader(
                  folder: folder,
                  count: repository.documentCountInFolder(folder.id),
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        documents.length == 1
                            ? '1 document'
                            : '${documents.length} documents',
                        style: AppType.caption(context).copyWith(fontSize: 12),
                      ),
                    ),
                    PbSortButton(
                      label: _sort.shortLabel,
                      onTap: () => _openSort(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                if (documents.isEmpty)
                  PbEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No documents yet',
                    message:
                        'Add the first one and it will stay grouped inside '
                        'this folder.',
                    compact: true,
                  )
                else
                  for (var index = 0; index < documents.length; index++)
                    DocumentListTile(
                      document: documents[index],
                      heroTag: 'folder-${folder.id}-${documents[index].id}',
                      showDivider: index < documents.length - 1,
                      onTap: () => _openDocument(context, documents[index]),
                    ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.colors.background,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.sm,
                  AppSpace.gutter,
                  AppSpace.sm,
                ),
                child: PbButton(
                  label: 'Add document',
                  icon: Icons.add_rounded,
                  onPressed: () =>
                      showAddDocumentSheet(context, folderId: folder.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSort(BuildContext context) async {
    final result = await showSortSheet(
      context,
      current: _sort,
      sorts: const [
        DocumentSort.newest,
        DocumentSort.oldest,
        DocumentSort.titleAsc,
      ],
    );
    if (result != null && mounted) {
      setState(() => _sort = result);
    }
  }

  void _openDocument(BuildContext context, Document document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(
          documentId: document.id!,
          heroTag: 'folder-${widget.folderId}-${document.id}',
        ),
      ),
    );
  }

  Future<void> _openActions(BuildContext context, DocumentFolder folder) async {
    final action = await showPbSheet<_FolderAction>(
      context: context,
      builder: (sheetContext) {
        return PbSheetFrame(
          title: folder.name,
          subtitle: 'Rename this folder or remove it.',
          scrollable: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionTile(
                icon: Icons.edit_outlined,
                label: 'Rename folder',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_FolderAction.rename),
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete folder',
                destructive: true,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_FolderAction.delete),
              ),
              const SizedBox(height: AppSpace.xs),
            ],
          ),
        );
      },
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _FolderAction.rename:
        final renamed = await showFolderFormSheet(context, folder: folder);
        if (renamed != null && context.mounted) {
          PbToast.show(context, 'Folder renamed', kind: PbToastKind.success);
        }
      case _FolderAction.delete:
        await _deleteFolder(context, folder);
    }
  }

  Future<void> _deleteFolder(
    BuildContext context,
    DocumentFolder folder,
  ) async {
    final repository = context.read<DocumentRepository>();
    final count = repository.documentCountInFolder(folder.id);
    final confirmed = await showPbDialog(
      context: context,
      title: 'Delete folder?',
      message: count == 0
          ? 'The folder “${folder.name}” will be removed.'
          : 'The folder “${folder.name}” will be removed. Its $count '
                '${count == 1 ? 'document stays' : 'documents stay'} in '
                'PaperBook and become unfiled.',
      confirmLabel: 'Delete folder',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context);
    await repository.deleteFolder(folder);
    if (!context.mounted) return;
    PbToast.show(context, 'Folder deleted');
    navigator.maybePop();
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({required this.folder, required this.count});

  final DocumentFolder folder;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FolderIconBadge(name: folder.name, size: 58),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                folder.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.headline(context)
                    .copyWith(fontSize: 25, letterSpacing: -0.6, height: 1.16),
              ),
              const SizedBox(height: 5),
              Text(
                count == 1 ? '1 document' : '$count documents',
                style: AppType.bodySmall(context)
                    .copyWith(fontSize: 12.5, color: colors.inkTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = destructive ? colors.danger : colors.ink;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: foreground.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xs,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: destructive ? colors.dangerSoft : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: foreground),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppType.label(context).copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingFolderScreen extends StatelessWidget {
  const _MissingFolderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          PbTopBar(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 30,
                    color: context.colors.inkTertiary,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'This folder is no longer available',
                    style: AppType.bodySmall(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
