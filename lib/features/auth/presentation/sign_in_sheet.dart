import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../profile/data/profile_repository.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_fields.dart';

/// Opens a backed-up space on this phone. Once signed in, the app gate
/// moves on to Home and the lock asks for a PIN for this phone.
abstract final class SignInSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SignInSheet(),
  );
}

class _SignInSheet extends ConsumerStatefulWidget {
  const _SignInSheet();

  @override
  ConsumerState<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<_SignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => isPlausibleEmail(_email.text) && _password.text.isNotEmpty;

  Future<void> _signIn() async {
    if (!_valid || _busy) return;
    final toast = Toast.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(_email.text.trim(), _password.text);
      TextInput.finishAutofillContext();
      HapticFeedback.mediumImpact();
      ref.invalidate(backupStatusProvider);
      ref.invalidate(profileProvider);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(authError(error, action: 'sign you in'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome back', style: text.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Sign in with the email you backed up your space with.',
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
                      isNew: false,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _signIn,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PressableButton(
                label: _busy ? 'Signing in…' : 'Sign in',
                icon: Icons.login_rounded,
                onPressed: _valid && !_busy ? _signIn : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
