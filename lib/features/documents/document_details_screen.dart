import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/folder_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pb_chip.dart';
import '../../core/widgets/pb_dialog.dart';
import '../../core/widgets/pb_icon_button.dart';
import '../../core/widgets/pb_section_header.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';
import '../../data/models/document_folder.dart';
import '../../data/models/document_page.dart';
import '../../data/repositories/document_repository.dart';
import '../add/document_form_screen.dart';
import 'document_actions.dart';
import 'document_viewer_screen.dart';
import 'widgets/document_thumb.dart';

class DocumentDetailsScreen extends StatelessWidget {
  const DocumentDetailsScreen({
    super.key,
    required this.documentId,
    this.heroTag,
  });

  final int documentId;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DocumentRepository>();
    final document = repository.findById(documentId);
    final folder = repository.findFolderById(document?.folderId);

    if (document == null) {
      return const _MissingDocumentScreen();
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          PbTopBar(
            onBack: () => Navigator.of(context).maybePop(),
            actions: [
              PbIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit document',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DocumentFormScreen(existing: document),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                AppSpace.xxxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpace.maxContentWidth,
                  ),
                  child: _DetailsBody(
                    document: document,
                    folder: folder,
                    pages: repository.pagesFor(document),
                    heroTag: heroTag,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.document,
    required this.folder,
    required this.pages,
    this.heroTag,
  });

  final Document document;
  final DocumentFolder? folder;
  final List<DocumentPage> pages;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpace.xs),
        _Preview(
          document: document,
          previewPath: pages.isEmpty ? null : pages.first.scanPath,
          heroTag: heroTag,
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: AppType.headline(
                      context,
                    ).copyWith(fontSize: 25, letterSpacing: -0.6, height: 1.18),
                  ),
                  if (document.merchant?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 5),
                    Text(
                      document.merchant!,
                      style: AppType.body(context)
                          .copyWith(color: colors.inkSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (document.amount != null) ...[
              const SizedBox(width: AppSpace.md),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  Formats.amount(document.amount),
                  style: AppType.numeric(
                    context,
                    size: 22,
                  ).copyWith(fontFamily: 'SpaceGrotesk', letterSpacing: -0.6),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            PbTag(label: document.category.label, icon: document.category.icon),
            if (folder != null)
              PbTag(
                label: folder!.name,
                icon: FolderIcons.forName(folder!.name),
              ),
            PbTag(
              label: document.fileType == DocumentFileType.pdf
                  ? 'PDF'
                  : document.fileType == DocumentFileType.image
                  ? 'Image'
                  : 'No file',
              icon: document.fileType == DocumentFileType.pdf
                  ? Icons.picture_as_pdf_outlined
                  : document.fileType == DocumentFileType.image
                  ? Icons.image_outlined
                  : Icons.notes_rounded,
            ),
            if (document.pageCount > 1)
              PbTag(
                label: '${document.pageCount} pages',
                icon: Icons.auto_awesome_motion_outlined,
              ),
            PbTag(label: Formats.date(document.documentDate)),
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        if (document.hasWarranty || document.hasReturnWindow) ...[
          const _SectionLabel('PROTECTION'),
          const SizedBox(height: AppSpace.sm),
          if (document.hasWarranty)
            _ProtectionCard(
              icon: Icons.verified_user_outlined,
              label: 'Warranty',
              until: document.warrantyUntil!,
              active: document.warrantyActive,
              activeLabel: 'Active',
              inactiveLabel: 'Expired',
              footnote: document.warrantyActive
                  ? '${document.daysUntil(document.warrantyUntil!)} days remaining'
                  : 'Coverage has ended',
            ),
          if (document.hasWarranty && document.hasReturnWindow)
            const SizedBox(height: AppSpace.xs),
          if (document.hasReturnWindow)
            _ProtectionCard(
              icon: Icons.assignment_return_outlined,
              label: 'Return window',
              until: document.returnBy!,
              active: document.returnWindowOpen,
              activeLabel: 'Open',
              inactiveLabel: 'Closed',
              footnote: document.returnWindowOpen
                  ? '${document.daysUntil(document.returnBy!)} days left to return'
                  : 'Return window has passed',
            ),
          const SizedBox(height: AppSpace.xl),
        ],
        const _SectionLabel('INFORMATION'),
        const SizedBox(height: AppSpace.xs),
        _MetaRow(
          label: 'Document date',
          value: Formats.longDate(document.documentDate),
        ),
        _MetaRow(label: 'Added', value: Formats.date(document.createdAt)),
        _MetaRow(label: 'Category', value: document.category.label),
        if (folder != null) _MetaRow(label: 'Folder', value: folder!.name),
        if (document.hasFile)
          _MetaRow(
            label: 'File',
            value:
                '${document.fileType == DocumentFileType.pdf ? 'PDF' : 'Image'}  ·  ${Formats.fileSize(document.fileSize)}'
                '${document.pageCount > 1 ? '  ·  ${document.pageCount} pages' : ''}',
          ),
        if (document.notes?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpace.xl),
          const _SectionLabel('NOTES'),
          const SizedBox(height: AppSpace.xs),
          Text(
            document.notes!,
            style: AppType.body(context)
                .copyWith(color: colors.inkSecondary, height: 1.65),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            if (document.hasFile)
              Expanded(
                child: _ActionTile(
                  icon: Icons.download_outlined,
                  label: 'Download',
                  onTap: () => downloadDocument(context, document),
                ),
              ),
            if (document.hasFile) const SizedBox(width: AppSpace.xs),
            if (document.hasFile)
              Expanded(
                child: _ActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () => shareDocument(context, document),
                ),
              ),
            if (document.hasFile) const SizedBox(width: AppSpace.xs),
            Expanded(
              child: _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                destructive: true,
                onTap: () => _delete(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDeleteDocument(context);
    if (!confirmed || !context.mounted) return;

    final repository = context.read<DocumentRepository>();
    final navigator = Navigator.of(context);
    await repository.delete(document);
    if (!context.mounted) return;
    PbToast.show(context, 'Document deleted');
    navigator.maybePop();
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.document,
    required this.previewPath,
    this.heroTag,
  });

  final Document document;
  final String? previewPath;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final height = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(240.0, 430.0)
        .toDouble();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentViewerScreen(
            document: document,
            heroTag: heroTag,
            previewSource: previewPath,
          ),
        ),
      ),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
          color: colors.surfaceMuted,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (document.hasFile)
              DocumentThumb(
                document: document,
                previewPath: previewPath,
                radius: 0,
                showBorder: false,
                heroTag: heroTag,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      document.category.icon,
                      size: 34,
                      color: colors.inkTertiary,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text('No file attached', style: AppType.caption(context)),
                  ],
                ),
              ),
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.ink.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_full_rounded,
                      size: 12,
                      color: colors.background,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Open',
                      style: AppType.caption(context).copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: colors.background,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppType.overline(context)
          .copyWith(fontSize: 10, letterSpacing: 1.4),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: AppType.bodySmall(context).copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.label(context)
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({
    required this.icon,
    required this.label,
    required this.until,
    required this.active,
    required this.activeLabel,
    required this.inactiveLabel,
    required this.footnote,
  });

  final IconData icon;
  final String label;
  final DateTime until;
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active ? AppColors.lime : colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.onAccent : colors.inkSecondary,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.overline(context)
                            .copyWith(fontSize: 9.5, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF8A9A00)
                            : colors.inkTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        active ? activeLabel : inactiveLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption(context).copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? (context.isDark
                                    ? AppColors.lime
                                    : const Color(0xFF6F7A00))
                              : colors.inkTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label == 'Warranty'
                      ? 'Until ${Formats.longDate(until)}'
                      : 'Return by ${Formats.longDate(until)}',
                  style: AppType.label(context)
                      .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  footnote,
                  style: AppType.caption(context)
                      .copyWith(fontSize: 11.5, color: colors.inkTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
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
      color: destructive ? colors.dangerSoft : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: foreground.withValues(alpha: 0.04),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppType.caption(context).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingDocumentScreen extends StatelessWidget {
  const _MissingDocumentScreen();

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
                    'This document is no longer available',
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
