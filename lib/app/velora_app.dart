import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/welcome/presentation/welcome_screen.dart';

class VeloraApp extends StatelessWidget {
  const VeloraApp({super.key});

  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scaffoldMessengerKey: _messengerKey,
      home: WelcomeScreen(
        // Onboarding is the next screen to build; for now, confirm the tap.
        onGetStarted: () => _messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Onboarding is coming next!')),
          ),
      ),
    );
  }
}
