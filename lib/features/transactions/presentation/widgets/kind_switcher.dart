import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/transaction.dart';
import '../category_style.dart';

/// Expense | Income. A tinted pill slides to the active kind and matches the
/// screen's accent. Transfers have their own titled screen, so they aren't
/// an option here.
class KindSwitcher extends StatelessWidget {
  const KindSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final TransactionKind value;
  final ValueChanged<TransactionKind> onChanged;
  final bool enabled;

  static const kinds = [TransactionKind.expense, TransactionKind.income];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      height: 48,
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / kinds.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: w * kinds.indexOf(value),
                top: 0,
                bottom: 0,
                width: w,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: value.color,
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in kinds)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: k == value,
                        label: k.label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: enabled && k != value
                              ? () {
                                  HapticFeedback.selectionClick();
                                  onChanged(k);
                                }
                              : null,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: text.titleMedium!.copyWith(
                                fontSize: 15,
                                color: k == value
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              child: Text(k.label),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
