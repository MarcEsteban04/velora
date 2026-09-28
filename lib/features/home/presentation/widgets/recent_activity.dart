import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../../accounts/domain/account.dart';
import '../../../transactions/domain/category.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';

/// The latest transactions with a "See all" link to History. Before the
/// first one exists, it shows a warm nudge toward the + button.
class RecentActivity extends StatelessWidget {
  const RecentActivity({
    super.key,
    required this.transactions,
    required this.accounts,
    required this.categories,
    required this.hidden,
    required this.onSeeAll,
    required this.onOpen,
  });

  final List<Transaction> transactions;
  final Map<String, Account> accounts;
  final Map<String, Category> categories;
  final bool hidden;
  final VoidCallback onSeeAll;
  final ValueChanged<Transaction> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (transactions.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Row(
          children: [
            const VeloraMascot(pose: MascotPose.coin, size: 84, halo: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No transactions yet', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + below to log your first expense or income. It '
                    'takes about three seconds.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      radius: 24,
      child: Column(
        children: [
          for (final (i, t) in transactions.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 68,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            TransactionTile(
              transaction: t,
              accounts: accounts,
              categories: categories,
              hidden: hidden,
              showDate: true,
              onTap: () => onOpen(t),
            ),
          ],
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(foregroundColor: AppColors.leafBright),
            child: const Text('See all in History'),
          ),
        ],
      ),
    );
  }
}
