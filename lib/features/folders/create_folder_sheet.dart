import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_button.dart';
import '../../core/widgets/pb_sheet.dart';
import '../../core/widgets/pb_text_field.dart';
import '../../data/models/document_folder.dart';
import '../../data/repositories/document_repository.dart';
import 'widgets/folder_icon_badge.dart';

/// Creates a folder, or renames one when [folder] is supplied.
Future<DocumentFolder?> showFolderFormSheet(
  BuildContext context, {
  DocumentFolder? folder,
}) {
  return showPbSheet<DocumentFolder>(
    context: context,
    builder: (sheetContext) => _FolderFormSheet(folder: folder),
  );
}

class _FolderFormSheet extends StatefulWidget {
  const _FolderFormSheet({this.folder});

  final DocumentFolder? folder;

  @override
  State<_FolderFormSheet> createState() => _FolderFormSheetState();
}

class _FolderFormSheetState extends State<_FolderFormSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.folder?.name ?? '',
  );
  String? _error;
  bool _saving = false;

  bool get _isEditing => widget.folder != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _controller.text.trim();
    final repository = context.read<DocumentRepository>();
    if (name.isEmpty) {
      setState(() => _error = 'Give this folder a name');
      return;
    }

    final duplicate = repository.findFolderByName(name);
    if (duplicate != null && duplicate.id != widget.folder?.id) {
      setState(() => _error = 'A folder with this name already exists');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = _isEditing
          ? await repository.renameFolder(widget.folder!, name)
          : await repository.addFolder(name);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this folder. Try another name.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PbSheetFrame(
      title: _isEditing ? 'Rename folder' : 'Create folder',
      subtitle: _isEditing
          ? 'The icon follows the folder name automatically.'
          : 'Group repeated bills like petrol, rent or groceries.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              FolderIconBadge(name: _controller.text, size: 54),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'The folder icon is chosen automatically from the name.',
                  style: AppType.caption(context).copyWith(
                    fontSize: 11.5,
                    color: colors.inkTertiary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          PbTextField(
            label: 'Folder name',
            controller: _controller,
            hint: 'e.g. Petrol',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            errorText: _error,
            onChanged: (_) {
              setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.lg),
          PbButton(
            label: _isEditing ? 'Save name' : 'Create',
            icon: _isEditing
                ? Icons.check_rounded
                : Icons.create_new_folder_outlined,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
