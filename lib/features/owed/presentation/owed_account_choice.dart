import 'package:flutter/material.dart';

import '../../../core/widgets/money_fields.dart';
import '../../accounts/domain/account.dart';

/// Which account the money left or went into, or none: chips for each
/// account, then "Not from an account", with a line on what it does.
class OwedAccountChoice extends StatelessWidget {
  const OwedAccountChoice({
    super.key,
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    required this.lending,
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  /// Lending out of an account (an expense) rather than paid back into
  /// one (income).
  final bool lending;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final selected = accounts.where((a) => a.id == selectedId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldCaption(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in accounts)
              ChoiceChip(
                label: Text(a.name),
                selected: a.id == selectedId,
                showCheckmark: false,
                onSelected: (_) => onChanged(a.id),
              ),
            ChoiceChip(
              label: Text(
                lending ? 'Not from an account' : 'Not into an account',
              ),
              selected: selected == null,
              showCheckmark: false,
              onSelected: (_) => onChanged(null),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Text(switch ((selected, lending)) {
            (null, _) => 'Velora just keeps count; no account changes.',
            (final a?, true) =>
              'Logged as an expense from ${a.name}, so its balance goes down.',
            (final a?, false) =>
              'Logged as income to ${a.name}, so its balance goes up.',
          }, style: text.labelMedium),
        ),
      ],
    );
  }
}
