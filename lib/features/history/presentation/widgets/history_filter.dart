import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_button.dart';
import '../../../accounts/domain/account.dart';
import '../../../transactions/domain/category.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/category_style.dart';

/// What History shows: a kind, and optionally some accounts and categories.
/// Empty sets mean "all".
class HistoryFilter {
  const HistoryFilter({
    this.kind,
    this.accountIds = const {},
    this.categoryIds = const {},
  });

  final TransactionKind? kind;
  final Set<String> accountIds;
  final Set<String> categoryIds;

  bool get isEmpty => kind == null && accountIds.isEmpty && categoryIds.isEmpty;

  int get count =>
      (kind == null ? 0 : 1) + accountIds.length + categoryIds.length;

  bool matches(Transaction t) {
    if (kind != null && t.kind != kind) return false;
    if (accountIds.isNotEmpty &&
        !accountIds.contains(t.accountId) &&
        !accountIds.contains(t.toAccountId)) {
      return false;
    }
    if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
      return false;
    }
    return true;
  }

  HistoryFilter copyWith({
    TransactionKind? Function()? kind,
    Set<String>? accountIds,
    Set<String>? categoryIds,
  }) => HistoryFilter(
    kind: kind == null ? this.kind : kind(),
    accountIds: accountIds ?? this.accountIds,
    categoryIds: categoryIds ?? this.categoryIds,
  );

  /// Opens the filter sheet. Returns the new filter, or null if dismissed.
  static Future<HistoryFilter?> edit(
    BuildContext context, {
    required HistoryFilter current,
    required List<Account> accounts,
    required List<Category> categories,
  }) => showModalBottomSheet<HistoryFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(
      initial: current,
      accounts: accounts,
      categories: categories,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.accounts,
    required this.categories,
  });

  final HistoryFilter initial;
  final List<Account> accounts;
  final List<Category> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HistoryFilter _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cats = widget.categories
        .where((c) => !c.hidden && (_f.kind == null || c.kind == _f.kind))
        .toList();

    Widget label(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Text(
        s.toUpperCase(),
        style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
      ),
    );

    Widget chip({
      required String text,
      required bool selected,
      required VoidCallback onTap,
      Widget? avatar,
      Color? color,
    }) => FilterChip(
      label: Text(text),
      avatar: avatar,
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(onTap),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontSize: 13,
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      selectedColor: (color ?? AppColors.accentBright).withValues(alpha: 0.22),
      backgroundColor: AppColors.surface.withValues(alpha: 0.6),
      side: BorderSide(
        color: selected
            ? (color ?? AppColors.accentBright)
            : AppColors.hairline(0.08),
      ),
      shape: const StadiumBorder(),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Filter', style: text.headlineSmall)),
                  if (!_f.isEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _f = const HistoryFilter()),
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              label('Type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (name, kind) in [
                    ('All', null),
                    ('Expenses', TransactionKind.expense),
                    ('Income', TransactionKind.income),
                    ('Transfers', TransactionKind.transfer),
                  ])
                    chip(
                      text: name,
                      selected: _f.kind == kind,
                      color: kind?.color,
                      onTap: () => _f = _f.copyWith(
                        kind: () => kind,
                        // Categories of another kind no longer apply.
                        categoryIds: kind == null
                            ? _f.categoryIds
                            : {
                                for (final id in _f.categoryIds)
                                  if (widget.categories.any(
                                    (c) => c.id == id && c.kind == kind,
                                  ))
                                    id,
                              },
                      ),
                    ),
                ],
              ),
              if (widget.accounts.length > 1) ...[
                label('Accounts'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in widget.accounts)
                      chip(
                        text: a.name,
                        selected: _f.accountIds.contains(a.id),
                        onTap: () => _f = _f.copyWith(
                          accountIds: _f.accountIds.contains(a.id)
                              ? ({..._f.accountIds}..remove(a.id))
                              : {..._f.accountIds, a.id},
                        ),
                      ),
                  ],
                ),
              ],
              if (_f.kind != TransactionKind.transfer && cats.isNotEmpty) ...[
                label('Categories'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in cats)
                      chip(
                        text: c.name,
                        selected: _f.categoryIds.contains(c.id),
                        color: c.colorValue,
                        avatar: Icon(c.iconData, size: 16, color: c.colorValue),
                        onTap: () => _f = _f.copyWith(
                          categoryIds: _f.categoryIds.contains(c.id)
                              ? ({..._f.categoryIds}..remove(c.id))
                              : {..._f.categoryIds, c.id},
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              PressableButton(
                label: 'Show results',
                onPressed: () => Navigator.pop(context, _f),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
