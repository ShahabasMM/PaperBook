import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:ui' as ui;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// A full calendar year heatmap (January–December) with responsive cells.
///
/// Cells have a minimum size for visibility. On narrow screens the heatmap
/// scrolls horizontally. Month labels run along the top.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key, required this.activity, this.today});

  /// Documents added per date. Keys must be date-only values.
  final Map<DateTime, int> activity;

  /// Injectable clock, useful for deterministic rendering and tests.
  final DateTime? today;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  int? _activeIndex;

  void _dismiss() {
    if (_activeIndex != null) {
      setState(() => _activeIndex = null);
    }
  }

  void _updateActive(
    Offset position,
    _HeatmapLayout layout,
    DateTime firstDay,
    DateTime today,
  ) {
    final index = layout.indexAt(position);
    final day = firstDay.add(Duration(days: index));
    final next = day.isAfter(today) ? null : index;
    if (next != _activeIndex) {
      setState(() => _activeIndex = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(widget.today ?? DateTime.now());
    final year = today.year;

    // Start from Monday of the week containing Jan 1
    final jan1 = DateTime(year, 1, 1);
    final firstDay = jan1.subtract(
      Duration(days: jan1.weekday - DateTime.monday),
    );
    // End on Sunday of the week containing Dec 31
    final dec31 = DateTime(year, 12, 31);
    final lastDay = dec31.add(Duration(days: DateTime.sunday - dec31.weekday));
    final totalDays = lastDay.difference(firstDay).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    return TapRegion(
      onTapOutside: (_) => _dismiss(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: AppColors.heatBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.heatBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _HeatmapLayout.forWidth(constraints.maxWidth, weeks);

            final counts = List<int>.generate(totalDays, (index) {
              final day = firstDay.add(Duration(days: index));
              if (day.isAfter(today)) return -1;
              return widget.activity[day] ?? 0;
            });

            final activeIndex = _activeIndex;
            final activeDay = activeIndex == null || activeIndex >= totalDays
                ? null
                : firstDay.add(Duration(days: activeIndex));

            final heatmapWidth = layout.width;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: heatmapWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month labels row
                    SizedBox(
                      height: 22,
                      child: CustomPaint(
                        painter: _MonthLabelPainter(
                          firstDay: firstDay,
                          layout: layout,
                          weeks: weeks,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Heatmap
                    SizedBox(
                      height: layout.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: MouseRegion(
                              onHover: (event) => _updateActive(
                                event.localPosition,
                                layout,
                                firstDay,
                                today,
                              ),
                              onExit: (_) => _dismiss(),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _updateActive(
                                  details.localPosition,
                                  layout,
                                  firstDay,
                                  today,
                                ),
                                child: CustomPaint(
                                  painter: _HeatmapPainter(
                                    counts: counts,
                                    layout: layout,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (activeIndex != null &&
                              activeDay != null &&
                              !activeDay.isAfter(today))
                            _Tooltip(
                              label: DateFormat('MMMM d, yyyy').format(activeDay),
                              index: activeIndex,
                              layout: layout,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.label,
    required this.index,
    required this.layout,
  });

  final String label;
  final int index;
  final _HeatmapLayout layout;

  static const _width = 140.0;
  static const _height = 26.0;

  @override
  Widget build(BuildContext context) {
    final column = index ~/ 7;
    final row = index % 7;
    final dotLeft = column * (layout.cell + layout.gap);
    final dotTop = row * (layout.cell + layout.gap);

    final maxLeft = (layout.width - _width).clamp(0.0, double.infinity);
    final left = (dotLeft + layout.cell / 2 - _width / 2)
        .clamp(0.0, maxLeft)
        .toDouble();
    final top = dotTop >= _height + 8
        ? dotTop - _height - 6
        : dotTop + layout.cell + 6;

    return Positioned(
      left: left,
      top: top,
      width: _width,
      height: _height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.lime.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppType.bodyFamily,
                fontSize: 10.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                color: AppColors.lime,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({required this.counts, required this.layout});

  final List<int> counts;
  final _HeatmapLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final radius = Radius.circular(layout.cell * 0.28);

    for (var index = 0; index < counts.length; index++) {
      final count = counts[index];
      // Future days are intentionally left empty.
      if (count < 0) continue;

      final column = index ~/ 7;
      final row = index % 7;
      final rect = Rect.fromLTWH(
        column * (layout.cell + layout.gap),
        row * (layout.cell + layout.gap),
        layout.cell,
        layout.cell,
      );

      paint.color = _colorFor(count);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) {
    return oldDelegate.layout.cell != layout.cell ||
        oldDelegate.layout.gap != layout.gap ||
        oldDelegate.layout.weeks != layout.weeks ||
        !_sameCounts(oldDelegate.counts, counts);
  }

  static bool _sameCounts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  static Color _colorFor(int count) {
    if (count <= 0) return AppColors.heatEmpty;
    if (count == 1) return AppColors.heatLevel1;
    if (count == 2) return AppColors.heatLevel2;
    if (count == 3) return AppColors.heatLevel3;
    return AppColors.heatLevel4;
  }
}

class _MonthLabelPainter extends CustomPainter {
  const _MonthLabelPainter({
    required this.firstDay,
    required this.layout,
    required this.weeks,
  });

  final DateTime firstDay;
  final _HeatmapLayout layout;
  final int weeks;

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    var currentMonth = firstDay.month;
    var monthStartColumn = 0;

    for (var week = 0; week <= weeks; week++) {
      final weekStart = firstDay.add(Duration(days: week * 7));
      if (weekStart.month != currentMonth) {
        // Draw label for the previous month
        final monthWidth =
            (week - monthStartColumn) * (layout.cell + layout.gap);
        final x =
            monthStartColumn * (layout.cell + layout.gap) + monthWidth / 2;

        textPainter.text = TextSpan(
          text: _monthShort[currentMonth - 1],
          style: const TextStyle(
            fontFamily: AppType.bodyFamily,
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.darkInkSecondary,
          ),
        );
        textPainter.layout(minWidth: 0, maxWidth: monthWidth);
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, 4));

        currentMonth = weekStart.month;
        monthStartColumn = week;
      }
    }

    // Draw label for the last month
    final monthWidth = (weeks - monthStartColumn) * (layout.cell + layout.gap);
    final x = monthStartColumn * (layout.cell + layout.gap) + monthWidth / 2;
    textPainter.text = TextSpan(
      text: _monthShort[currentMonth - 1],
      style: const TextStyle(
        fontFamily: AppType.bodyFamily,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: AppColors.darkInkSecondary,
      ),
    );
    textPainter.layout(minWidth: 0, maxWidth: monthWidth);
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, 4));
  }

  @override
  bool shouldRepaint(_MonthLabelPainter oldDelegate) {
    return oldDelegate.layout.cell != layout.cell ||
        oldDelegate.layout.gap != layout.gap ||
        oldDelegate.layout.weeks != layout.weeks ||
        oldDelegate.firstDay != firstDay;
  }
}

class _HeatmapLayout {
  const _HeatmapLayout({
    required this.width,
    required this.weeks,
    required this.cell,
    required this.gap,
  });

  /// Creates a layout that always fits within [availableWidth].
  ///
  /// Cell size is calculated to fit all weeks exactly within the available width.
  factory _HeatmapLayout.forWidth(double availableWidth, int weeks) {
    const gap = 4.0;
    const minCell = 14.0; // Minimum cell size for good visibility
    const maxCell = 32.0; // Maximum cell size on wide screens

    final available = availableWidth.isFinite && availableWidth > 0
        ? availableWidth
        : 320.0;

    // Calculate ideal cell size to fit all weeks in available width
    final idealCell = (available - (weeks - 1) * gap) / weeks;

    // Use minimum cell size, allowing horizontal scroll if needed
    final cell = idealCell.clamp(minCell, maxCell);
    final width = weeks * cell + (weeks - 1) * gap;

    return _HeatmapLayout(width: width, weeks: weeks, cell: cell, gap: gap);
  }

  final double width;
  final int weeks;
  final double cell;
  final double gap;

  double get height => cell * 7 + gap * 6;

  int indexAt(Offset position) {
    final column = (position.dx / (cell + gap))
        .floor()
        .clamp(0, weeks - 1)
        .toInt();
    final row = (position.dy / (cell + gap)).floor().clamp(0, 6).toInt();
    return column * 7 + row;
  }
}

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
