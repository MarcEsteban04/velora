import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/island_toast.dart';
import '../core/navigation/app_navigator.dart';
import '../core/storage/app_preferences.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/scene_schedule.dart';
import '../core/time/app_clock.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import 'app_gate.dart';

/// The app root. It resolves the scene (by the time of day when set to
/// Automatic) and repaints every screen when the scene changes.
class VeloraApp extends ConsumerStatefulWidget {
  const VeloraApp({super.key});

  @override
  ConsumerState<VeloraApp> createState() => _VeloraAppState();
}

class _VeloraAppState extends ConsumerState<VeloraApp>
    with WidgetsBindingObserver {
  Scene? _shown;
  AppFont? _shownFont;
  AppAccent? _shownAccent;

  /// Fires at the next Day, Afternoon or Night boundary under Automatic.
  Timer? _sceneTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sceneTimer?.cancel();
    super.dispose();
  }

  /// Back from the background, maybe hours later: pick the scene again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Scene _resolve(Appearance appearance) => switch (appearance) {
    Appearance.day => Scene.day,
    Appearance.afternoon => Scene.afternoon,
    Appearance.night => Scene.night,
    Appearance.automatic => SceneSchedule.at(AppClock.now()),
  };

  void _scheduleNextScene(Appearance appearance) {
    _sceneTimer?.cancel();
    _sceneTimer = null;
    if (appearance != Appearance.automatic) return;
    final now = AppClock.now();
    // A second late, so the boundary hour has certainly begun.
    final wait =
        SceneSchedule.nextChange(now).difference(now) +
        const Duration(seconds: 1);
    _sceneTimer = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  /// Colours are read from the active palette during build, so after a
  /// switch every element rebuilds once, keeping all state and routes.
  void _repaintEverything() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      (context as Element).visitChildren(visit);
      SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    // A new time zone can mean a new time of day.
    ref.watch(timeZoneProvider);
    final scene = _resolve(appearance);
    _scheduleNextScene(appearance);
    // Fonts are read from AppTypography while building, like colours.
    final font = ref.watch(fontProvider);
    AppTypography.font = font;
    // So is the theme colour.
    final accent = ref.watch(accentProvider);
    AppColors.accentChoice = accent;
    final theme = AppTheme.forPalette(Palette.of(scene));
    if ((_shown != null && _shown != scene) ||
        (_shownFont != null && _shownFont != font) ||
        (_shownAccent != null && _shownAccent != accent)) {
      _repaintEverything();
    }
    _shown = scene;
    _shownFont = font;
    _shownAccent = accent;

    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: appNavigatorKey,
      // The lock sits above the navigator, so it covers every route.
      // Toasts sit above everything, the lock screen included, and outlive
      // the screen that showed them.
      builder: (context, child) =>
          IslandToastHost(child: AppLockGate(child: child!)),
      home: const AppGate(),
    );
  }
}
