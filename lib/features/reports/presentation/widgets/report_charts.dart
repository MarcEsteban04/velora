import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/month_report.dart';

/// Chart colours, checked for colour-blind separation, lightness and
/// contrast against each scene's card surface (the dataviz validator):
/// blue for money in, orange for money out. Green and orange failed for
/// red-green colour blindness, so the charts don't use the app's green.
abstract final class ReportColors {
  static Color get income => switch (AppColors.scene) {
    Scene.night => const Color(0xFF5B8DEF),
    Scene.day => const Color(0xFF2F6FD6),
    Scene.afternoon => const Color(0xFF2F66C4),
  };

  static Color get spending => switch (AppColors.scene) {
    Scene.night => const Color(0xFFD9772F),
    Scene.day => const Color(0xFFD1701F),
    Scene.afternoon => const Color(0xFFC7641A),
  };

  /// Context series (last month): recessive, never competing.
  static Color get baseline => AppColors.textMuted;

  static Color get grid => AppColors.hairline(0.1);
}

/// A clean top for an axis: a step of 1 to 5 times a power of ten, at or above
/// [max], with [ticks] steps.
({double top, double step}) niceScale(double max, {int ticks = 3}) {
  if (max <= 0) return (top: 1, step: 1);
  final raw = max / ticks;
  final power = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  // 1.5 and 3 too, so the top sits close to the data (4,350 → 4,500, not
  // 6,000) and the plot isn't a quarter empty.
  const steps = [1, 1.5, 2, 2.5, 3, 5, 10];
  final step = steps.map((m) => m * power).firstWhere((s) => s >= raw);
  return (top: step * ticks, step: step);
}

/// An axis tick: short enough for a narrow gutter (₱30k, ₱1.5M, ₱500).
String compactMoney(double v, Currency c) {
  final major = v / math.pow(10, c.decimalDigits);
  String trim(double x) =>
      x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  if (major >= 1e6) return '${c.symbol}${trim(major / 1e6)}M';
  if (major >= 1e3) return '${c.symbol}${trim(major / 1e3)}k';
  return '${c.symbol}${trim(major)}';
}

/// A legend entry: a short swatch and the series name, in text ink.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 11),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Spending pace: this month's running total against last month's.
// ---------------------------------------------------------------------------

/// This month's spending, day by day (accent), over last month's (gray
/// context). Drag across it to read any day.
class PaceChart extends StatefulWidget {
  const PaceChart({
    super.key,
    required this.report,
    required this.previous,
    required this.currency,
    required this.hidden,
  });

  final MonthReport report;
  final MonthReport? previous;
  final Currency currency;
  final bool hidden;

  @override
  State<PaceChart> createState() => _PaceChartState();
}

class _PaceChartState extends State<PaceChart> {
  /// The day being read (1-based), while a finger is on the chart.
  int? _day;

  static const _height = 150.0;
  static const _left = 44.0;

  int get _days => math.max(widget.report.days, widget.previous?.days ?? 0);

  void _read(Offset local, double width) {
    final plot = width - _left - 8;
    final t = ((local.dx - _left) / plot).clamp(0.0, 1.0);
    final day = (t * (_days - 1)).round() + 1;
    if (day != _day) {
      HapticFeedback.selectionClick();
      setState(() => _day = day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = widget.report;
    final p = widget.previous;
    String money(int m) => widget.hidden
        ? '${widget.currency.symbol}••••'
        : Money.short(m, widget.currency);

    final day = _day;
    final readout = day == null
        ? null
        : [
            'Day $day',
            if (day <= r.daysCounted) 'this month ${money(r.spentByDay(day))}',
            if (p != null && day <= p.days)
              'last month ${money(p.spentByDay(day))}',
          ].join(' · ');

    final byNow = p?.spentByDay(r.daysCounted);
    return Semantics(
      label: [
        'Spending so far ${money(r.spentMinor)} after ${r.daysCounted} days',
        if (byNow != null) 'last month by the same day ${money(byNow)}',
      ].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LegendDot(color: ReportColors.spending, label: 'This month'),
              if (p != null) ...[
                const SizedBox(width: 14),
                LegendDot(color: ReportColors.baseline, label: 'Last month'),
              ],
              const Spacer(),
              if (readout != null)
                Flexible(
                  flex: 3,
                  child: Text(
                    readout,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _read(d.localPosition, c.maxWidth),
              onHorizontalDragStart: (d) => _read(d.localPosition, c.maxWidth),
              onHorizontalDragUpdate: (d) => _read(d.localPosition, c.maxWidth),
              onTapUp: (_) => Future.delayed(
                const Duration(seconds: 2),
                () => mounted ? setState(() => _day = null) : null,
              ),
              onHorizontalDragEnd: (_) => setState(() => _day = null),
              child: CustomPaint(
                size: Size(c.maxWidth, _height),
                painter: _PacePainter(
                  current: r.cumulative,
                  previous: p?.cumulative ?? const [],
                  days: _days,
                  day: _day,
                  left: _left,
                  label: (v) =>
                      widget.hidden ? '•••' : compactMoney(v, widget.currency),
                  labelStyle: text.labelMedium!.copyWith(fontSize: 10),
                  accent: ReportColors.spending,
                  baseline: ReportColors.baseline,
                  grid: ReportColors.grid,
                  surface: AppColors.surface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: _left),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in [1, (_days / 2).round(), _days])
                  Text(
                    DateFormat('MMM d').format(
                      DateTime(
                        r.month.year,
                        r.month.month,
                        math.min(d, r.days),
                      ),
                    ),
                    style: text.labelMedium?.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PacePainter extends CustomPainter {
  _PacePainter({
    required this.current,
    required this.previous,
    required this.days,
    required this.day,
    required this.left,
    required this.label,
    required this.labelStyle,
    required this.accent,
    required this.baseline,
    required this.grid,
    required this.surface,
  });

  final List<int> current;
  final List<int> previous;
  final int days;
  final int? day;
  final double left;
  final String Function(double) label;
  final TextStyle labelStyle;
  final Color accent, baseline, grid, surface;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0, bottom = 4.0, right = 8.0;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;
    final maxV = [...current, ...previous].fold<int>(0, math.max).toDouble();
    final scale = niceScale(maxV);

    double x(int d) => left + (days <= 1 ? 0 : (d - 1) / (days - 1) * plotW);
    double y(num v) => top + plotH - (v / scale.top) * plotH;

    // Hairline grid with clean, comma'd ticks.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 0.0; v <= scale.top + 0.001; v += scale.step) {
      final gy = y(v);
      canvas.drawLine(
        Offset(left, gy),
        Offset(size.width - right, gy),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: label(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 6);
      tp.paint(canvas, Offset(left - 6 - tp.width, gy - tp.height / 2));
    }

    Path line(List<int> values) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final pt = Offset(x(i + 1), y(values[i]));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return path;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (previous.length > 1) {
      canvas.drawPath(
        line(previous),
        stroke..color = baseline.withValues(alpha: 0.7),
      );
    }
    if (current.isNotEmpty) {
      final path = line(current);
      // A faint wash under the current month.
      final area = Path.from(path)
        ..lineTo(x(current.length), y(0))
        ..lineTo(x(1), y(0))
        ..close();
      canvas.drawPath(area, Paint()..color = accent.withValues(alpha: 0.1));
      if (current.length > 1) canvas.drawPath(path, stroke..color = accent);
      // End dot with a ring in the surface colour.
      final end = Offset(x(current.length), y(current.last));
      canvas.drawCircle(end, 6, Paint()..color = surface);
      canvas.drawCircle(end, 4, Paint()..color = accent);
    }

    // The day being read: a crosshair and dots on each line.
    if (day case final d?) {
      final cx = x(d);
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, top + plotH),
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
      for (final (values, color) in [(previous, baseline), (current, accent)]) {
        if (d > values.length || values.isEmpty) continue;
        final pt = Offset(cx, y(values[d - 1]));
        canvas.drawCircle(pt, 6, Paint()..color = surface);
        canvas.drawCircle(pt, 4, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PacePainter old) =>
      old.current != current ||
      old.previous != previous ||
      old.day != day ||
      old.accent != accent ||
      old.surface != surface;
}

// ---------------------------------------------------------------------------
// Six months: money in and out side by side.
// ---------------------------------------------------------------------------

/// Paired columns per month, blue in and orange out. Tap a month to read
/// it; the selected month's pair stays solid while the others soften.
class FlowColumns extends StatefulWidget {
  const FlowColumns({
    super.key,
    required this.flows,
    required this.currency,
    required this.hidden,
    required this.selected,
  });

  final List<MonthFlow> flows;
  final Currency currency;
  final bool hidden;

  /// The month the report is on; highlighted until another is tapped.
  final DateTime selected;

  @override
  State<FlowColumns> createState() => _FlowColumnsState();
}

class _FlowColumnsState extends State<FlowColumns> {
  DateTime? _tapped;

  static const _height = 130.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final flows = widget.flows;
    final focus = _tapped ?? widget.selected;
    final picked = flows.where((f) => f.month == focus).firstOrNull;
    String money(int m) => widget.hidden
        ? '${widget.currency.symbol}••••'
        : Money.short(m, widget.currency);

    return Semantics(
      label: [
        for (final f in flows)
          '${DateFormat('MMMM').format(f.month)}: in ${money(f.incomeMinor)}, '
              'out ${money(f.spentMinor)}',
      ].join('; '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LegendDot(color: ReportColors.income, label: 'In'),
              const SizedBox(width: 14),
              LegendDot(color: ReportColors.spending, label: 'Out'),
              const Spacer(),
              if (picked != null)
                Flexible(
                  flex: 4,
                  child: Text(
                    '${DateFormat('MMM').format(picked.month)}: '
                    'kept ${money(picked.incomeMinor - picked.spentMinor)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final slot = c.maxWidth / math.max(1, flows.length);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final i = (d.localPosition.dx / slot).floor().clamp(
                    0,
                    flows.length - 1,
                  );
                  HapticFeedback.selectionClick();
                  setState(() => _tapped = flows[i].month);
                },
                child: CustomPaint(
                  size: Size(c.maxWidth, _height),
                  painter: _FlowPainter(
                    flows: flows,
                    focus: focus,
                    income: ReportColors.income,
                    spending: ReportColors.spending,
                    grid: ReportColors.grid,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final f in flows)
                Expanded(
                  child: Text(
                    DateFormat('MMM').format(f.month),
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(
                      fontSize: 10,
                      color: f.month == focus
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          if (picked != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'In ${money(picked.incomeMinor)}',
                  style: text.labelMedium?.copyWith(fontSize: 11),
                ),
                const SizedBox(width: 12),
                Text(
                  'Out ${money(picked.spentMinor)}',
                  style: text.labelMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.flows,
    required this.focus,
    required this.income,
    required this.spending,
    required this.grid,
  });

  final List<MonthFlow> flows;
  final DateTime focus;
  final Color income, spending, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (flows.isEmpty) return;
    final maxV = flows
        .expand((f) => [f.incomeMinor, f.spentMinor])
        .fold<int>(0, math.max)
        .toDouble();
    final scale = niceScale(maxV, ticks: 2);
    final base = size.height;
    canvas.drawLine(
      Offset(0, base - 0.5),
      Offset(size.width, base - 0.5),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    final slot = size.width / flows.length;
    // Two columns per month, at most 24 px each, 2 px apart.
    final bar = math.min(24.0, (slot - 14) / 2);
    for (final (i, f) in flows.indexed) {
      final soft = f.month != focus;
      final cx = slot * i + slot / 2;
      for (final (j, v, color) in [
        (0, f.incomeMinor, income),
        (1, f.spentMinor, spending),
      ]) {
        if (v <= 0) continue;
        final h = math.max(2.0, v / scale.top * (base - 4));
        final x0 = j == 0 ? cx - 1 - bar : cx + 1;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x0, base - h, bar, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = soft ? color.withValues(alpha: 0.45) : color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.flows != flows ||
      old.focus != focus ||
      old.income != income ||
      old.spending != spending;
}
