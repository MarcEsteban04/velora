import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dusk_backdrop.dart';

/// The shared frame for PIN screens: the dusk scene behind a dark scrim, with
/// content centred, scrollable and at most 420 wide.
class LockScaffold extends StatelessWidget {
  const LockScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.night,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: DuskBackdrop()),
            Positioned.fill(
              child: ColoredBox(color: AppColors.night.withValues(alpha: 0.72)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
