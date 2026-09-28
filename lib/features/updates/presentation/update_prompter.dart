import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../../core/widgets/island_toast.dart';
import '../../app_lock/application/app_lock_controller.dart';
import '../application/update_providers.dart';
import '../domain/app_release.dart';
import 'update_sheet.dart';

/// Checks for a new version once the app is unlocked, and mentions it once
/// per version. Settings > Check for updates is always there otherwise.
class UpdatePrompter extends ConsumerStatefulWidget {
  const UpdatePrompter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePrompter> createState() => _UpdatePrompterState();
}

class _UpdatePrompterState extends ConsumerState<UpdatePrompter> {
  static const _promptedKey = 'updates.promptedVersionCode';

  bool _checked = false;

  Future<void> _check() async {
    _checked = true;
    final UpdateCheck result;
    try {
      result = await ref.read(updateCheckProvider.future);
    } on Object {
      return; // Quietly: Settings shows the error when asked.
    }
    if (result is! UpdateAvailable || !mounted) return;
    final update = result;
    final prefs = ref.read(sharedPreferencesProvider);
    final code = update.release.versionCode;
    if (prefs.getInt(_promptedKey) == code) return;
    await prefs.setInt(_promptedKey, code);
    if (!mounted) return;
    Toast.of(context).show(
      'Velora ${update.release.versionName} is ready',
      tone: ToastTone.info,
      icon: Icons.system_update_rounded,
      action: ToastAction('Update', () => UpdateSheet.show(context, update)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = switch (ref.watch(appLockProvider).value) {
      final s? => s.hasPin && !s.locked,
      null => false,
    };
    if (unlocked && !_checked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
    return widget.child;
  }
}
