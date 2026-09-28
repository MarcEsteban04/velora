import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/storage/app_preferences.dart';
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

/// A frosted, floating tab bar, in one of two [style]s:
///
/// - Classic: a raised round "+" in the middle; a soft pill slides to the
///   active tab.
/// - Split: the four tabs in a pill, the active one in a rounded tile, and
///   a rounded-square "+" beside it.
///
/// The "+" turns into a "×" while quick actions are open. Setting
/// [visible] to false slides the bar out of the way (while scrolling down).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    required this.addOpen,
    this.visible = true,
    this.style = NavBarStyle.classic,
  }) : assert(destinations.length == 4);

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool addOpen;
  final bool visible;
  final NavBarStyle style;

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
            child: style == NavBarStyle.split
                ? _SplitNav(
                    destinations: destinations,
                    currentIndex: currentIndex,
                    onSelect: onSelect,
                    onAdd: onAdd,
                    addOpen: addOpen,
                  )
                : SizedBox(
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

/// The Split style: tabs in a pill, "+" as its own tile on the right.
class _SplitNav extends StatelessWidget {
  const _SplitNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    required this.addOpen,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final bool addOpen;

  static const _inset = 7.0;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(30));
    const height = FloatingNavBar.barHeight;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    color: AppColors.surface.withValues(alpha: 0.72),
                    border: Border.all(color: AppColors.hairline(0.09)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final slot = (constraints.maxWidth - _inset * 2) / 4;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 340),
                            curve: Curves.easeOutCubic,
                            left: _inset + currentIndex * slot,
                            top: _inset,
                            bottom: _inset,
                            width: slot,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(23),
                                color: AppColors.leaf.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          for (var i = 0; i < 4; i++)
                            Positioned(
                              left: _inset + i * slot,
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
          ),
          const SizedBox(width: 10),
          _AddButton(
            open: addOpen,
            onTap: onAdd,
            size: height,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ],
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

    return SizedBox(
      height: FloatingNavBar.barHeight,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: AppColors.surface.withValues(alpha: 0.72),
              border: Border.all(color: AppColors.hairline(0.09)),
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
  const _AddButton({
    required this.open,
    required this.onTap,
    this.size = 62,
    this.shape = const CircleBorder(),
  });

  final bool open;
  final VoidCallback onTap;
  final double size;
  final OutlinedBorder shape;

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
          width: size,
          height: size,
          decoration: ShapeDecoration(
            shape: shape.copyWith(
              side: BorderSide(
                color: Colors.white.withValues(alpha: open ? 0.14 : 0.22),
                width: 1.5,
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: open
                  ? [AppColors.surfaceRaised, AppColors.surface]
                  : [AppColors.leafBright, AppColors.leafShadow],
            ),
          ),
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Icon(
              Icons.add_rounded,
              color: open ? AppColors.textPrimary : AppColors.onBrand,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
