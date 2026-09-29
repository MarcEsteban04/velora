import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../data/update_repository.dart';
import '../domain/app_release.dart';

/// A new version: what's in it, then download and hand it to Android's
/// installer. Installing over the app keeps its data and PIN.
abstract final class UpdateSheet {
  static Future<void> show(BuildContext context, UpdateAvailable update) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _UpdateSheet(update: update),
      );
}

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.update});

  final UpdateAvailable update;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  InstallProgress? _progress;
  bool _starting = false;
  StreamSubscription<InstallProgress>? _sub;

  AppRelease get _release => widget.update.release;

  @override
  void dispose() {
    // The download carries on natively; only stop listening.
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    final toast = Toast.of(context);
    setState(() => _starting = true);
    try {
      final url = await ref
          .read(updateRepositoryProvider)
          .downloadUrl(_release);
      if (!mounted) return;
      _sub = ref
          .read(updateInstallerProvider)
          .install(url, _release)
          .listen(
            (p) {
              if (!mounted) return;
              if (p is InstallFailed) toast.error(p.message);
              if (p is HandedToInstaller) HapticFeedback.mediumImpact();
              setState(() {
                _progress = p;
                _starting = false;
              });
            },
            onError: (Object error) {
              if (!mounted) return;
              toast.error(friendlyError(error, action: 'download the update'));
              setState(() {
                _progress = null;
                _starting = false;
              });
            },
          );
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'download the update'));
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = _progress;
    final busy = _starting || progress is Downloading;
    final size = _release.sizeLabel;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Velora ${_release.versionName} is ready',
              style: text.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              ['You have ${widget.update.installed.name}', ?size].join(' · '),
              style: text.labelMedium,
            ),
            if (_release.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.hairline(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHAT’S NEW',
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_release.notes, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (progress is Downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.fraction == 0 ? null : progress.fraction,
                  minHeight: 8,
                  color: AppColors.accentBright,
                  backgroundColor: AppColors.hairline(0.1),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading… ${(progress.fraction * 100).round()}%',
                textAlign: TextAlign.center,
                style: text.labelMedium,
              ),
              const SizedBox(height: 14),
            ],
            PressableButton(
              label: switch (progress) {
                HandedToInstaller() => 'Open the installer again',
                InstallFailed() => 'Try again',
                _ when busy => 'Downloading…',
                _ => 'Download and install',
              },
              icon: Icons.system_update_rounded,
              onPressed: busy ? null : _install,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.accentBright,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    progress is HandedToInstaller
                        ? 'Tap Update in Android’s installer to finish.'
                        : 'Your data and PIN stay as they are.',
                    style: text.labelMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
