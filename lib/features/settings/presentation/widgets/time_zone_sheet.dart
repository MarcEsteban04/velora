import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock.dart';
import '../../../../core/widgets/selectable_tile.dart';

/// Picks a time zone: the Philippines first, zones matching the phone's
/// current offset next, then every zone, searchable by city, region or
/// offset ("GMT+8"). Returns the zone name, or null if dismissed.
abstract final class TimeZoneSheet {
  static Future<String?> show(BuildContext context, String current) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _Sheet(current: current),
      );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.current});

  final String current;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  String _query = '';

  late final List<String> _all = AppClock.zones
      .where((z) => z.contains('/') && !z.startsWith('Etc/'))
      .toList();

  /// Zones at the phone's offset, when that differs from the chosen one:
  /// handy when travelling. Research stations don't make useful picks.
  late final List<String> _phone = () {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == AppClock.offsetOf(widget.current)) return <String>[];
    return _all
        .where(
          (z) =>
              !z.startsWith('Antarctica/') &&
              !z.startsWith('Arctic/') &&
              AppClock.offsetOf(z) == offset,
        )
        .take(4)
        .toList();
  }();

  bool _matches(String z) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return z.toLowerCase().replaceAll('_', ' ').contains(q) ||
        AppClock.gmtLabel(AppClock.offsetOf(z)).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final results = _all.where(_matches).toList();
    final showSuggested = _query.isEmpty;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Time zone', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Decides what “today” is, and when days, weeks and months '
                  'start for your history, budgets and streaks.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Search a city or GMT+8',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final head = <Widget>[
                        if (showSuggested) ...[
                          section('Suggested'),
                          _ZoneTile(
                            zone: AppClock.defaultZone,
                            caption: 'Philippines',
                            selected: widget.current == AppClock.defaultZone,
                          ),
                          for (final z in _phone)
                            _ZoneTile(
                              zone: z,
                              caption: 'Same time as your phone',
                              selected: widget.current == z,
                            ),
                          section('All time zones'),
                        ],
                        if (results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No time zone matches “$_query”.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium,
                            ),
                          ),
                      ];
                      // Rows are built as they scroll in: there are hundreds.
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: head.length + results.length,
                        itemBuilder: (context, i) => i < head.length
                            ? head[i]
                            : _ZoneTile(
                                zone: results[i - head.length],
                                selected:
                                    widget.current == results[i - head.length],
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, required this.selected, this.caption});

  final String zone;
  final bool selected;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offset = AppClock.offsetOf(zone);
    final time = DateFormat('h:mm a')
        .format(DateTime.now().toUtc().add(offset));
    final city = AppClock.cityOf(zone);
    final sub = [
      caption ?? AppClock.regionOf(zone),
      AppClock.gmtLabel(offset),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableTile(
        selected: selected,
        semanticLabel: '$city, $sub, $time now',
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        radius: 18,
        onTap: () => Navigator.pop(context, zone),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city, style: text.titleMedium?.copyWith(fontSize: 14)),
                  Text(sub, style: text.labelMedium),
                ],
              ),
            ),
            Text(
              time,
              style: text.labelMedium?.copyWith(
                color: selected
                    ? AppColors.leafBright
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            SelectionDot(selected: selected),
          ],
        ),
      ),
    );
  }
}
