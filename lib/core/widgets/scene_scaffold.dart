import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'dusk_backdrop.dart';

/// A pushed screen over the valley scene: a back button, an optional
/// eyebrow above the title, header actions, and a scrolling body.
class SceneScaffold extends StatelessWidget {
  const SceneScaffold({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.actions = const [],
    this.onRefresh,
  });

  final String title;

  /// A small label above the title, for example "PLAN".
  final String? eyebrow;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(
                      eyebrow!.toUpperCase(),
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        color: AppColors.leafBright,
                      ),
                    ),
                  Text(title, style: text.headlineSmall),
                ],
              ),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(
        color: AppColors.leafBright,
        backgroundColor: AppColors.surfaceRaised,
        onRefresh: onRefresh!,
        child: list,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: DuskBackdrop(showMoon: false)),
          Positioned.fill(
            child: ColoredBox(color: AppColors.night.withValues(alpha: 0.72)),
          ),
          SafeArea(bottom: false, child: list),
        ],
      ),
    );
  }
}
