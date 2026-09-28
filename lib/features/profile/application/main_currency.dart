import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../data/profile_repository.dart';

/// The user's main currency: totals, budgets and caps are in it.
final mainCurrencyProvider = Provider<Currency>(
  (ref) => Currencies.byCode(
    ref.watch(profileProvider).value?.currencyCode ?? 'USD',
  ),
);
