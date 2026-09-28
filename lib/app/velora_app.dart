import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/island_toast.dart';
import '../core/navigation/app_navigator.dart';
import '../core/storage/app_preferences.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import 'app_gate.dart';

/// The app root. It resolves the Day or Night scene (following the phone
/// when set to Automatic) and repaints every screen when the scene changes.
class VeloraApp extends ConsumerStatefulWidget {
  const VeloraApp({super.key});

  @override
  ConsumerState<VeloraApp> createState() => _VeloraAppState();
}

class _VeloraAppState extends ConsumerState<VeloraApp>
    with WidgetsBindingObserver {
  Scene? _shown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone switched light/dark: matters when set to Automatic.
  @override
  void didChangePlatformBrightness() => setState(() {});

  Scene _resolve(Appearance appearance) => switch (appearance) {
    Appearance.day => Scene.day,
    Appearance.night => Scene.night,
    Appearance.automatic =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.light
          ? Scene.day
          : Scene.night,
  };

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
    final scene = _resolve(ref.watch(appearanceProvider));
    final theme = AppTheme.forPalette(
      scene == Scene.day ? Palette.dayPalette : Palette.nightPalette,
    );
    if (_shown != null && _shown != scene) _repaintEverything();
    _shown = scene;

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
