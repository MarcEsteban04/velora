import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/selectable_tile.dart';

/// Picks the app's typeface, each option shown in its own letters. Returns
/// the choice, or null when dismissed.
abstract final class FontSheet {
  static Future<AppFont?> show(BuildContext context, AppFont current) =>
      showModalBottomSheet<AppFont>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Font', style: text.headlineSmall),
                  const SizedBox(height: 4),
                  Text('The letters Velora speaks in.', style: text.bodyMedium),
                  const SizedBox(height: 16),
                  for (final option in AppFont.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableTile(
                        selected: option == current,
                        semanticLabel: '${option.label}: ${option.description}',
                        onTap: () => Navigator.pop(context, option),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                'Aa',
                                style: TextStyle(
                                  fontFamily: option.display,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  color: AppColors.accentBright,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      fontFamily: option.display,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${option.description} · ₱1,250.00',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: option.body,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SelectionDot(selected: option == current),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
