import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import 'app_gate.dart';

class VeloraApp extends StatelessWidget {
  const VeloraApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorKey: _navigatorKey,
      // The lock sits above the navigator, so it covers every route.
      builder: (context, child) => AppLockGate(
        onReset: () =>
            _navigatorKey.currentState?.popUntil((route) => route.isFirst),
        child: child!,
      ),
      home: const AppGate(),
    );
  }
}
