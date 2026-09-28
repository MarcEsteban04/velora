import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// A frosted, floating tab bar with a raised "+" in the middle.
///
/// - A glowing pill slides to the active tab.
/// - The "+" turns into a "×" while quick actions are open.
/// - Setting [visible] to false slides the bar out of the way (while
///   scrolling down).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    required this.addOpen,
    this.visible = true,
  }) : assert(destinations.length == 4);

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool addOpen;
  final bool visible;

  static const barHeight = 70.0;
  static const _centerGap = 76.0;
  static const _pillWidth = 56.0;

  /// The space scrolling content should leave at the bottom so nothing hides
  /// behind the bar.
  static double reservedHeight(BuildContext context) =>
      barHeight + 40 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 12.0);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: visible || addOpen ? Offset.zero : const Offset(0, 1.6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              height: barHeight + 24,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  _Bar(
                    destinations: destinations,
                    currentIndex: currentIndex,
                    onSelect: onSelect,
                  ),
                  Positioned(
                    top: 0,
                    child: _AddButton(open: addOpen, onTap: onAdd),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(30));

    return Container(
      height: FloatingNavBar.barHeight,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: AppColors.surface.withValues(alpha: 0.72),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot =
                    (constraints.maxWidth - FloatingNavBar._centerGap) / 4;
                double slotLeft(int i) =>
                    i * slot + (i >= 2 ? FloatingNavBar._centerGap : 0);

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      left:
                          slotLeft(currentIndex) +
                          (slot - FloatingNavBar._pillWidth) / 2,
                      top: 9,
                      width: FloatingNavBar._pillWidth,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.leaf.withValues(alpha: 0.22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.leafBright.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      Positioned(
                        left: slotLeft(i),
                        top: 0,
                        bottom: 0,
                        width: slot,
                        child: _Tab(
                          destination: destinations[i],
                          selected: i == currentIndex,
                          onTap: () => onSelect(i),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.leafBright : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: '${destination.label} tab',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(destination.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'Close quick actions' : 'Add: open quick actions',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: open
                  ? const [AppColors.surfaceRaised, AppColors.surface]
                  : const [AppColors.leafBright, AppColors.leafShadow],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: open ? 0.14 : 0.22),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (open ? Colors.black : AppColors.leaf).withValues(
                  alpha: 0.5,
                ),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.textPrimary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
