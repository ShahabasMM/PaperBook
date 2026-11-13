import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pb_empty_state.dart';
import '../../core/widgets/pb_icon_button.dart';
import '../../core/widgets/pb_search_bar.dart';
import '../../core/widgets/pb_section_header.dart';
import '../../data/models/document.dart';
import '../../data/repositories/document_repository.dart';
import 'document_details_screen.dart';
import 'widgets/document_list_tile.dart';

/// Dedicated search surface with live results across titles, merchants,
/// notes and categories.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<DocumentRepository>();
    final results = _query.trim().isEmpty
        ? const <Document>[]
        : repository.query(search: _query);
    final recent = repository.recent(limit: 6);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xs,
                AppSpace.xs,
                AppSpace.gutter,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  PbIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    style: PbIconButtonStyle.plain,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: PbSearchBar(
                      controller: _controller,
                      autofocus: true,
                      showClear: true,
                      hint: 'Search titles, merchants, notes',
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty
                  ? _EmptyQuery(recent: recent)
                  : results.isEmpty
                  ? PbEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results',
                      message:
                          'Nothing matches “${_query.trim()}”. Try a '
                          'different word or check the spelling.',
                    )
                  : _Results(query: _query.trim(), results: results),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.query, required this.results});

  final String query;
  final List<Document> results;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.xs),
            child: Text(
              results.length == 1
                  ? '1 result for “$query”'
                  : '${results.length} results for “$query”',
              style: AppType.caption(context).copyWith(fontSize: 12),
            ),
          );
        }
        final document = results[index - 1];
        return DocumentListTile(
          document: document,
          heroTag: 'search-${document.id}',
          showDivider: index < results.length,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DocumentDetailsScreen(
                documentId: document.id!,
                heroTag: 'search-${document.id}',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyQuery extends StatelessWidget {
  const _EmptyQuery({required this.recent});

  final List<Document> recent;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return const PbEmptyState(
        icon: Icons.search_rounded,
        title: 'Search your vault',
        message: 'Find a document by its title, merchant, notes or category.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.sm,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        const PbSectionHeader(title: 'Recently added'),
        const SizedBox(height: AppSpace.xs),
        for (var index = 0; index < recent.length; index++)
          DocumentListTile(
            document: recent[index],
            heroTag: 'search-${recent[index].id}',
            showDivider: index < recent.length - 1,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DocumentDetailsScreen(
                  documentId: recent[index].id!,
                  heroTag: 'search-${recent[index].id}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
