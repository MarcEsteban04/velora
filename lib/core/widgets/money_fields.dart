import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../money/currency.dart';
import '../money/money.dart';
import '../theme/app_colors.dart';
import '../time/app_clock.dart';

/// A labelled amount in [currency], e.g. "$ 1,250.00".
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.currency,
    required this.label,
    this.helper,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final Currency currency;
  final String label;
  final String? helper;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCaption(label),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [MoneyInputFormatter(currency.decimalDigits)],
          style: text.headlineSmall?.copyWith(fontSize: 22),
          decoration: InputDecoration(
            prefixText: '${currency.symbol} ',
            prefixStyle: text.headlineSmall?.copyWith(
              fontSize: 22,
              color: AppColors.textMuted,
            ),
            hintText: Money.toInputText(0, currency),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
          ),
          onChanged: onChanged,
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(helper!, style: text.labelMedium),
          ),
      ],
    );
  }
}

/// A small caps caption above a field.
class FieldCaption extends StatelessWidget {
  const FieldCaption(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(fontSize: 11, letterSpacing: 1.4),
    ),
  );
}

/// Today, Yesterday, or a picked date. [value] is a calendar day.
class DayChoice extends StatelessWidget {
  const DayChoice({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final other = value != today && value != yesterday;

    Widget chip(String text, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(text),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCaption(label),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('Today', value == today, () => onChanged(today)),
            chip('Yesterday', value == yesterday, () => onChanged(yesterday)),
            chip(
              other ? DateFormat('MMM d, y').format(value) : 'Pick a date',
              other,
              () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value,
                  firstDate: DateTime(today.year - 5),
                  lastDate: today,
                );
                if (picked != null) onChanged(picked);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// "₱61.24", a rate per one unit, for example per $1.
String rateLabel(double rate, Currency to) =>
    '${to.symbol}${NumberFormat('#,##0.00').format(rate)}';

/// A calendar day at the current time of day, so entries sort naturally.
DateTime atNow(DateTime day) {
  final now = AppClock.now();
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return now;
  return DateTime(day.year, day.month, day.day, 12);
}
