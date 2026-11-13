import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Search field used on the dashboard and library.
///
/// Works in two modes: tappable (navigates to a dedicated search screen) or
/// live (filters as the user types).
class PbSearchBar extends StatefulWidget {
  const PbSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search documents',
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.readOnly = false,
    this.showClear = false,
  });

  final TextEditingController? controller;
  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool readOnly;
  final bool showClear;

  @override
  State<PbSearchBar> createState() => _PbSearchBarState();
}

class _PbSearchBarState extends State<PbSearchBar> {
  TextEditingController? _internal;

  TextEditingController get _controller =>
      widget.controller ?? (_internal ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _internal?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.showClear) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasText = _controller.text.isNotEmpty;

    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.readOnly ? widget.onTap : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: AppIconSize.md,
                color: colors.inkSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: widget.readOnly
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.hint,
                          style: AppType.body(context)
                              .copyWith(color: colors.inkTertiary),
                        ),
                      )
                    : TextField(
                        controller: _controller,
                        focusNode: null,
                        autofocus: widget.autofocus,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        textInputAction: TextInputAction.search,
                        cursorWidth: 1.5,
                        style: AppType.body(context),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: widget.hint,
                          hintStyle: AppType.body(context)
                              .copyWith(color: colors.inkTertiary),
                        ),
                      ),
              ),
              if (widget.showClear && hasText)
                IconButton(
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                    setState(() {});
                  },
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: colors.inkTertiary,
                  ),
                  tooltip: 'Clear search',
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
