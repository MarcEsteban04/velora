import 'package:flutter/material.dart';

import '../money/currency.dart';
import '../theme/app_colors.dart';

/// A searchable list of every supported currency. It returns the picked
/// currency, or null if the user dismisses the sheet.
class CurrencyPickerSheet extends StatefulWidget {
  const CurrencyPickerSheet({super.key, required this.selected});

  final Currency selected;

  static Future<Currency?> show(BuildContext context, Currency selected) =>
      showModalBottomSheet<Currency>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CurrencyPickerSheet(selected: selected),
      );

  @override
  State<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<CurrencyPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = _query.toLowerCase();
    final results = Currencies.all
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: text.bodyLarge?.copyWith(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search currencies',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        'No currencies match "$_query"',
                        style: text.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        final selected = c == widget.selected;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: selected
                                ? AppColors.accent.withValues(alpha: 0.25)
                                : AppColors.surfaceRaised,
                            child: Text(
                              c.symbol,
                              style: text.titleMedium?.copyWith(
                                fontSize: c.symbol.length > 2 ? 12 : 16,
                              ),
                            ),
                          ),
                          title: Text(c.code, style: text.titleMedium),
                          subtitle: Text(c.name, style: text.bodyMedium),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.accentBright,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
