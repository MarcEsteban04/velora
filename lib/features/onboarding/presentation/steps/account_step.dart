import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/account_type_style.dart';
import '../../../accounts/presentation/widgets/account_card.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/selectable_tile.dart';
import '../widgets/step_layout.dart';

class AccountStep extends ConsumerStatefulWidget {
  const AccountStep({super.key});

  @override
  ConsumerState<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends ConsumerState<AccountStep> {
  late final OnboardingDraft _initial = ref.read(onboardingControllerProvider);
  late final _nameController = TextEditingController(
    text: _initial.accountName,
  );
  late final _balanceController = TextEditingController(
    text: Money.toInputText(_initial.openingBalanceMinor, _initial.currency),
  );

  /// Once the user types their own name, switching type stops overwriting it.
  bool get _nameIsCustom {
    final current = _nameController.text.trim();
    return current.isNotEmpty &&
        !AccountType.values.any((t) => t.defaultName == current);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _selectType(AccountType type) {
    final notifier = ref.read(onboardingControllerProvider.notifier);
    if (_nameIsCustom) {
      notifier.setAccountType(type);
    } else {
      _nameController.text = type.defaultName;
      notifier.setAccountType(type, name: type.defaultName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final currency = draft.currency;
    final text = Theme.of(context).textTheme;

    return StepLayout(
      children: [
        const SizedBox(height: 16),
        const StepHeader(
          title: 'Set up your first account',
          subtitle: 'Start with the one you use most. You can add more later.',
        ),
        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          scaleFrom: 0.94,
          child: AccountCard(
            name: draft.accountName.trim(),
            type: draft.accountType,
            currency: currency,
            balanceMinor: draft.openingBalanceMinor,
          ),
        ),
        const FieldLabel('Account type'),
        Row(
          children: [
            for (final (i, type) in AccountType.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SelectableTile(
                  selected: draft.accountType == type,
                  semanticLabel: '${type.label} account',
                  onTap: () => _selectType(type),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  radius: 18,
                  child: Column(
                    children: [
                      Icon(
                        type.icon,
                        color: draft.accountType == type
                            ? AppColors.leafBright
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        type.label,
                        maxLines: 1,
                        style: text.labelMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const FieldLabel('Account name'),
        TextField(
          controller: _nameController,
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: text.titleMedium,
          decoration: InputDecoration(
            hintText: draft.accountType.defaultName,
            prefixIcon: const Icon(Icons.edit_rounded, size: 20),
          ),
          onChanged: notifier.setAccountName,
        ),
        const FieldLabel('Starting balance'),
        TextField(
          controller: _balanceController,
          keyboardType: TextInputType.numberWithOptions(
            decimal: currency.decimalDigits > 0,
          ),
          inputFormatters: [MoneyInputFormatter(currency.decimalDigits)],
          style: text.titleMedium?.copyWith(fontSize: 20),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 10),
              child: Text(
                currency.symbol,
                style: text.titleMedium?.copyWith(
                  color: AppColors.leafBright,
                  fontSize: 20,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(),
          ),
          onChanged: (v) =>
              notifier.setOpeningBalance(Money.parseMinor(v, currency)),
        ),
        const SizedBox(height: 12),
        Text(
          'A rough number is fine. You can adjust it anytime.',
          style: text.labelMedium,
        ),
      ],
    );
  }
}
