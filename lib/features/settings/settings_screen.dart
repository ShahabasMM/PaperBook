import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pb_dialog.dart';
import '../../core/widgets/pb_logo.dart';
import '../../core/widgets/pb_sheet.dart';
import '../../core/widgets/pb_toast.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/settings/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();
    final repository = context.watch<DocumentRepository>();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.sm,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: AppType.headline(context).copyWith(fontSize: 27),
                ),
                const SizedBox(height: AppSpace.xxl),
                const _SectionLabel('APPEARANCE'),
                const SizedBox(height: AppSpace.sm),
                _SegmentedControl<ThemeMode>(
                  value: settings.themeMode,
                  options: const {
                    ThemeMode.system: 'System',
                    ThemeMode.light: 'Light',
                    ThemeMode.dark: 'Dark',
                  },
                  onChanged: settings.setThemeMode,
                ),
                const SizedBox(height: AppSpace.xxl),
                const _SectionLabel('LIBRARY'),
                const SizedBox(height: AppSpace.sm),
                _SegmentedControl<DocumentViewMode>(
                  value: settings.viewMode,
                  options: const {
                    DocumentViewMode.list: 'List',
                    DocumentViewMode.grid: 'Grid',
                  },
                  onChanged: settings.setViewMode,
                ),
                const SizedBox(height: AppSpace.sm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        label: 'Documents',
                        value: repository.count == 1
                            ? '1 saved'
                            : '${repository.count} saved',
                      ),
                      _SettingsRow(
                        label: 'Storage used',
                        value: Formats.fileSize(repository.totalFileSize),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
                const _SectionLabel('DATA'),
                const SizedBox(height: AppSpace.sm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: _SettingsRow(
                    label: 'Clear all documents',
                    subtitle: 'Permanently remove every document and file from this device',
                    destructive: true,
                    showChevron: true,
                    onTap: () => _clearAll(context, repository),
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
                const _SectionLabel('ABOUT'),
                const SizedBox(height: AppSpace.sm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        label: 'About PaperBook',
                        showChevron: true,
                        onTap: () => _showAbout(context),
                      ),
                      const _SettingsRow(
                        label: 'Version',
                        value: '1.0.0',
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.huge),
                Center(
                  child: Column(
                    children: [
                      Opacity(
                        opacity: 0.5,
                        child: PbWordmark(
                          fontSize: 14,
                          markSize: 22,
                          color: colors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Private by design. Always yours.',
                        style: AppType.caption(context)
                            .copyWith(fontSize: 11, color: colors.inkTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAll(
    BuildContext context,
    DocumentRepository repository,
  ) async {
    final count = repository.count;
    if (count == 0) {
      PbToast.show(context, 'There are no documents to clear.');
      return;
    }

    final confirmed = await showPbDialog(
      context: context,
      title: 'Delete all documents?',
      message:
          'This permanently removes $count ${count == 1 ? 'document' : 'documents'} '
          'and every attached file from this device. Your app settings are kept.',
      confirmLabel: 'Delete all',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !context.mounted) return;

    await repository.clearAll();
    if (!context.mounted) return;
    PbToast.show(context, 'All documents removed', kind: PbToastKind.success);
  }

  Future<void> _showAbout(BuildContext context) {
    return showPbSheet<void>(
      context: context,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return PbSheetFrame(
          title: 'About PaperBook',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpace.xs),
              const Center(child: PbLogoMark(size: 46)),
              const SizedBox(height: AppSpace.md),
              Center(
                child: PbWordmark(
                  fontSize: 20,
                  showMark: false,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: AppType.caption(sheetContext).copyWith(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'A private, offline-first home for receipts, warranties and '
                'the everyday documents that matter.',
                style: AppType.body(sheetContext)
                    .copyWith(color: colors.inkSecondary, height: 1.6),
              ),
              const SizedBox(height: AppSpace.lg),
              _AboutFact(
                icon: Icons.phone_iphone_rounded,
                label: 'Stored on this device',
              ),
              _AboutFact(
                icon: Icons.person_off_outlined,
                label: 'No account required',
              ),
              _AboutFact(
                icon: Icons.lock_outline_rounded,
                label: 'Never uploaded anywhere',
              ),
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      },
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

class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.curve,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == value ? colors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.base,
                    style: AppType.label(context).copyWith(
                      fontSize: 12.5,
                      fontWeight: entry.key == value
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: entry.key == value
                          ? colors.background
                          : colors.inkSecondary,
                    ),
                    child: Text(entry.value),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.subtitle,
    this.value,
    this.onTap,
    this.showChevron = false,
    this.showDivider = true,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool showDivider;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = destructive ? colors.danger : colors.ink;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.label(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppType.caption(context)
                        .copyWith(fontSize: 11.5, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: AppType.bodySmall(context).copyWith(fontSize: 12.5),
            ),
          if (showChevron) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: destructive ? colors.danger : colors.inkTertiary,
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        if (onTap == null)
          content
        else
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashFactory: NoSplash.splashFactory,
              highlightColor: foreground.withValues(alpha: 0.03),
              child: content,
            ),
          ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppSpace.md,
            endIndent: AppSpace.md,
            color: colors.border,
          ),
      ],
    );
  }
}

class _AboutFact extends StatelessWidget {
  const _AboutFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.inkTertiary),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: AppType.bodySmall(context).copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
