import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/attachment_source.dart';
import '../../core/utils/folder_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pb_chip.dart';
import '../../core/widgets/pb_section_header.dart';
import '../../core/widgets/pb_swipe_to_confirm.dart';
import '../../core/widgets/pb_text_field.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/models/document.dart';
import '../../data/models/document_category.dart';
import '../../data/models/scan_bundle.dart';
import '../../data/repositories/document_repository.dart';
import '../documents/document_viewer_screen.dart';
import '../documents/widgets/document_thumb.dart';
import '../folders/create_folder_sheet.dart';
import '../scan/scan_pdf_service.dart';

/// Creates or edits a document. Used for camera captures, uploads, PDFs and
/// manual entries, preserving a consistent review step for every path.
class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({
    super.key,
    this.existing,
    this.initialTitle = '',
    this.sourcePath,
    this.initialFileType = DocumentFileType.none,
    this.initialFileSize = 0,
    this.initialFolderId,
    this.scanPages = const [],
  });

  final Document? existing;
  final String initialTitle;
  final String? sourcePath;
  final DocumentFileType initialFileType;
  final int initialFileSize;
  final int? initialFolderId;

  /// Scanner pages to persist. When non-empty, saving writes a private bundle
  /// containing every original capture, every processed scan and one PDF.
  final List<ScanPageDraft> scanPages;

  bool get isEditing => existing != null;

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  late DateTime _documentDate;
  late int? _folderId;
  int? _scanBytes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(
      text: existing?.title ?? widget.initialTitle,
    );
    _amountController = TextEditingController(
      text: existing?.amount == null ? '' : _amountText(existing!.amount!),
    );
    _documentDate = existing?.documentDate ?? DateTime.now();
    _folderId = existing?.folderId ?? widget.initialFolderId;
    if (widget.scanPages.isNotEmpty) {
      _measureScan();
    }
  }

  Future<void> _measureScan() async {
    var total = 0;
    for (final page in widget.scanPages) {
      for (final source in [page.originalPath, page.cropPath]) {
        final inline = AttachmentSource.inlineByteLength(source);
        if (inline != null) {
          total += inline;
          continue;
        }
        final file = File(source);
        if (await file.exists()) total += await file.length();
      }
    }
    if (mounted) setState(() => _scanBytes = total);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? get _previewPath {
    if (widget.scanPages.isNotEmpty) {
      return widget.scanPages.first.cropPath;
    }
    return widget.sourcePath ?? widget.existing?.filePath;
  }

  DocumentFileType get _previewType => widget.scanPages.isNotEmpty
      ? DocumentFileType.image
      : widget.existing?.fileType ?? widget.initialFileType;

  int get _displayFileSize =>
      widget.existing?.fileSize ?? _scanBytes ?? widget.initialFileSize;

  Document _previewDocument() {
    final existing = widget.existing;
    if (existing != null) return existing;
    return Document(
      title: _titleController.text.isEmpty
          ? 'Document preview'
          : _titleController.text,
      documentDate: _documentDate,
      category: DocumentCategory.other,
      filePath: _previewPath,
      fileType: _previewType,
      fileSize: _displayFileSize,
      pageCount: widget.scanPages.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final repository = context.read<DocumentRepository>();
    final title = _titleController.text.trim();
    final amount = _amountController.text.trim().isEmpty
        ? null
        : Formats.parseAmount(_amountController.text);

    try {
      final Document saved;
      final existing = widget.existing;

      if (existing != null) {
        saved = await repository.update(
          existing.copyWith(
            title: title,
            amount: amount,
            clearAmount: amount == null,
            documentDate: _documentDate,
            folderId: _folderId,
            clearFolder: _folderId == null,
          ),
        );
      } else {
        final draft = Document(
          title: title,
          amount: amount,
          documentDate: _documentDate,
          category: DocumentCategory.other,
          folderId: _folderId,
          fileType: widget.initialFileType,
          fileSize: widget.initialFileSize,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (widget.scanPages.isNotEmpty) {
          saved = await _saveScan(draft, repository);
        } else {
          saved = await repository.add(
            draft,
            attachmentSourcePath: widget.sourcePath,
          );
        }
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      PbToast.show(
        context,
        widget.isEditing ? 'Document updated' : 'Saved to PaperBook',
        kind: PbToastKind.success,
      );
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      PbToast.show(
        context,
        'Could not save the document. Please try again.',
        kind: PbToastKind.error,
      );
    }
  }

  /// Builds the multi-page PDF, then lets the repository copy every page and
  /// the PDF into one private bundle. The temporary PDF is removed afterwards.
  ///
  /// Browser scans keep their pages inline, so no filesystem or temporary
  /// directory is involved there: the PDF is generated in memory and stored as
  /// a data URL alongside the pages.
  Future<Document> _saveScan(
    Document draft,
    DocumentRepository repository,
  ) async {
    final inline = AttachmentSource.isInline(widget.scanPages.first.cropPath);

    if (inline) {
      final pdfBytes = await const ScanPdfService().buildPdfBytes(
        imageSources: [for (final page in widget.scanPages) page.cropPath],
      );
      return repository.addScanned(
        draft,
        bundle: ScanBundle(
          pages: widget.scanPages,
          pdfPath: AttachmentSource.dataUrl(pdfBytes, 'application/pdf'),
        ),
      );
    }

    final temporary = await getTemporaryDirectory();
    final pdfPath = await const ScanPdfService().buildPdf(
      imagePaths: [for (final page in widget.scanPages) page.cropPath],
      outputDirectory: Directory(p.join(temporary.path, 'paperbook_scan_pdfs')),
      fileName: 'scan_${DateTime.now().microsecondsSinceEpoch}.pdf',
    );

    try {
      return await repository.addScanned(
        draft,
        bundle: ScanBundle(pages: widget.scanPages, pdfPath: pdfPath),
      );
    } finally {
      final file = File(pdfPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // Temporary PDFs are best-effort cleanup.
        }
      }
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1960),
      lastDate: DateTime(now.year + 40),
      helpText: 'Select a date',
    );
    if (picked != null) onChanged(picked);
  }

  Future<void> _createFolder() async {
    final folder = await showFolderFormSheet(context);
    if (folder != null && mounted) {
      setState(() => _folderId = folder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repository = context.watch<DocumentRepository>();
    final hasPreview =
        _previewPath != null && _previewType != DocumentFileType.none;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          PbTopBar(
            title: widget.isEditing ? 'Edit document' : 'Review document',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.xs,
                  AppSpace.gutter,
                  AppSpace.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPreview) ...[
                          _PreviewCard(
                            document: _previewDocument(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DocumentViewerScreen(
                                  document: _previewDocument(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Row(
                            children: [
                              PbTag(
                                label: _previewType == DocumentFileType.pdf
                                    ? 'PDF'
                                    : 'Image',
                                icon: _previewType == DocumentFileType.pdf
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                              ),
                              if (widget.scanPages.length > 1) ...[
                                const SizedBox(width: AppSpace.xs),
                                PbTag(
                                  label: '${widget.scanPages.length} pages',
                                  icon: Icons.auto_awesome_motion_outlined,
                                ),
                              ],
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                Formats.fileSize(_displayFileSize),
                                style: AppType.caption(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                        const _FieldLabel('DETAILS'),
                        const SizedBox(height: AppSpace.sm),
                        PbTextField(
                          label: 'Document name',
                          controller: _titleController,
                          hint: 'e.g. Apple Store receipt',
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Give this document a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpace.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PbTextField(
                                label: 'Price',
                                controller: _amountController,
                                hint: '0.00',
                                prefixIcon: Icons.attach_money_rounded,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                validator: (value) {
                                  final raw = value?.trim() ?? '';
                                  if (raw.isEmpty) return null;
                                  final parsed = Formats.parseAmount(raw);
                                  if (parsed == null || parsed < 0) {
                                    return 'Enter a valid price';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            Expanded(
                              child: _DateField(
                                label: 'Document date',
                                value: _documentDate,
                                onTap: () => _pickDate(
                                  initial: _documentDate,
                                  onChanged: (date) {
                                    if (date != null) {
                                      setState(() => _documentDate = date);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Row(
                          children: [
                            const Expanded(child: _FieldLabel('FOLDER')),
                            TextButton.icon(
                              onPressed: _createFolder,
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
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                                size: 15,
                              ),
                              label: Text(
                                'New folder',
                                style: AppType.label(context).copyWith(
                                  fontSize: 12,
                                  color: colors.inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Wrap(
                          spacing: AppSpace.xs,
                          runSpacing: AppSpace.xs,
                          children: [
                            PbChip(
                              label: 'No folder',
                              icon: Icons.folder_off_outlined,
                              selected: _folderId == null,
                              onTap: () => setState(() => _folderId = null),
                            ),
                            for (final folder in repository.folders)
                              PbChip(
                                label: folder.name,
                                icon: FolderIcons.forName(folder.name),
                                selected: _folderId == folder.id,
                                onTap: () =>
                                    setState(() => _folderId = folder.id),
                              ),
                          ],
                        ),
                        if (repository.folders.isEmpty) ...[
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Create a folder to keep repeated bills together.',
                            style: AppType.caption(context).copyWith(
                              fontSize: 11.5,
                              color: colors.inkTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.background,
              border: Border(top: BorderSide(color: colors.border)),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: PbSwipeToConfirm(
                      label: widget.isEditing
                          ? 'Swipe to save changes'
                          : 'Swipe to save',
                      busyLabel: 'Saving…',
                      onConfirmed: _save,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _amountText(double amount) {
    if (amount % 1 == 0) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppType.overline(context).copyWith(
        fontSize: 10,
        letterSpacing: 1.4,
        color: context.colors.inkSecondary,
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPdf = document.fileType == DocumentFileType.pdf;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: (MediaQuery.sizeOf(context).height * 0.32)
            .clamp(210.0, 330.0)
            .toDouble(),
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: isPdf
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: AspectRatio(
                          aspectRatio: 0.72,
                          child: DocumentThumb(
                            document: document,
                            radius: 6,
                            showBorder: false,
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.file(
                          File(document.filePath!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.inkTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              right: AppSpace.sm,
              bottom: AppSpace.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                      'Preview',
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppSpace.xs),
          child: Text(
            label,
            style: AppType.overline(context)
                .copyWith(letterSpacing: 0.7, color: colors.inkSecondary),
          ),
        ),
        Material(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: colors.inkSecondary,
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      value == null ? 'Select' : Formats.date(value!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(context).copyWith(
                        fontSize: 13.5,
                        color: value == null ? colors.inkTertiary : colors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
