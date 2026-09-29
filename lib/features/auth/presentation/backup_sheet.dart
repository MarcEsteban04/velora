import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../data/auth_repository.dart';
import '../domain/backup_status.dart';
import 'widgets/auth_fields.dart';

/// "Back up your space": adds an email and password to this space, so
/// signing in on another phone opens it with everything in it.
abstract final class BackupSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _BackupSheet(),
  );
}

class _BackupSheet extends ConsumerStatefulWidget {
  const _BackupSheet();

  @override
  ConsumerState<_BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends ConsumerState<_BackupSheet> {
  late final _email = TextEditingController(
    text: switch (ref.read(backupStatusProvider)) {
      PendingBackup(:final email) => email,
      _ => '',
    },
  );
  final _password = TextEditingController();
  bool _busy = false;

  /// Editing the email again after a link was sent.
  bool _changingEmail = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      isPlausibleEmail(_email.text) &&
      _password.text.length >= minPasswordLength;

  Future<void> _run(Future<BackupStatus> Function(AuthRepository) step) async {
    if (!_valid || _busy) return;
    final toast = Toast.of(context);
    setState(() => _busy = true);
    try {
      final status = await step(ref.read(authRepositoryProvider));
      ref.invalidate(backupStatusProvider);
      if (!mounted) return;
      switch (status) {
        case LinkedBackup(:final email):
          HapticFeedback.mediumImpact();
          toast.show(
            'Backed up. Sign in with $email on any phone.',
            icon: Icons.cloud_done_rounded,
          );
          Navigator.pop(context);
        case PendingBackup():
          setState(() => _changingEmail = false);
          toast.show('Not confirmed yet. Open the link in your email first.');
        case NoBackup():
          toast.error('That didn’t go through. Please try again.');
      }
    } on Object catch (error) {
      toast.error(authError(error, action: 'back up your space'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = ref.watch(backupStatusProvider);

    final List<Widget> body = switch (status) {
      LinkedBackup(:final email) => [
        Text('Your space is backed up', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'On a new phone, tap “I already have a space” and sign in with '
          '$email. Your PIN stays on each phone, so you’ll set it there.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 18),
        PressableButton(label: 'Done', onPressed: () => Navigator.pop(context)),
      ],
      PendingBackup(:final email) when !_changingEmail => [
        Text('Check your email', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'We sent a link to $email. Open it, then come back and finish '
          'here.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          isNew: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: () => _run((a) => a.finishBackup(_password.text)),
        ),
        const SizedBox(height: 18),
        PressableButton(
          label: _busy ? 'Checking…' : 'I opened the link',
          icon: Icons.mark_email_read_rounded,
          onPressed: _valid && !_busy
              ? () => _run((a) => a.finishBackup(_password.text))
              : null,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _changingEmail = true),
            child: const Text('Use a different email'),
          ),
        ),
      ],
      _ => [
        Text('Back up your space', style: text.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Add an email and password. Sign in with them on any phone to open '
          'this same space, with all your accounts and history.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        AutofillGroup(
          child: Column(
            children: [
              EmailField(
                controller: _email,
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              PasswordField(
                controller: _password,
                isNew: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: () =>
                    _run((a) => a.backUp(_email.text.trim(), _password.text)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PressableButton(
          label: _busy ? 'Backing up…' : 'Back up',
          icon: Icons.cloud_upload_rounded,
          onPressed: _valid && !_busy
              ? () => _run((a) => a.backUp(_email.text.trim(), _password.text))
              : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.lock_rounded, size: 14, color: AppColors.accentBright),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Your PIN never leaves this phone.',
                style: text.labelMedium,
              ),
            ),
          ],
        ),
      ],
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      ),
    );
  }
}
