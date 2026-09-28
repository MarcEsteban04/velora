import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/velora_mascot.dart';

/// The latest transactions. For now there are none yet, so it shows a warm
/// nudge toward the "+" button.
class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
}
