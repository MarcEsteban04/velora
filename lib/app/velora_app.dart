import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_gate.dart';

class VeloraApp extends StatelessWidget {
  const VeloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppGate(),
    );
  }
}
