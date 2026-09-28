import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/friendly_error.dart';

/// Passwords are at least this long.
const minPasswordLength = 8;

bool isPlausibleEmail(String v) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

/// Auth failures in words a person can act on.
String authError(Object error, {required String action}) {
  if (error is AuthException) {
    final message = switch (error.code) {
      'invalid_credentials' => 'That email and password don’t match.',
      'email_exists' || 'user_already_exists' =>
        'That email already has a Velora space. Try another one.',
      'weak_password' =>
        'Pick a stronger password, at least $minPasswordLength characters.',
      'email_address_invalid' => 'That email doesn’t look right.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Too many tries. Wait a few minutes, then try again.',
      'email_not_confirmed' =>
        'Open the link we emailed you first, then try again.',
      _ => null,
    };
    if (message != null) return message;
  }
  return friendlyError(error, action: action);
}

class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autocorrect: false,
    autofillHints: const [AutofillHints.email],
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
    decoration: const InputDecoration(
      hintText: 'Email',
      prefixIcon: Icon(Icons.alternate_email_rounded),
    ),
    onChanged: onChanged,
  );
}

/// A password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.isNew,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// A new password (backing up) or an existing one (signing in), so
  /// password managers offer the right thing.
  final bool isNew;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autofocus: widget.autofocus,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: TextInputAction.done,
    autofillHints: [
      widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
    ],
    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16),
    decoration: InputDecoration(
      hintText: widget.isNew
          ? 'Password (at least $minPasswordLength characters)'
          : 'Password',
      prefixIcon: const Icon(Icons.key_rounded),
      suffixIcon: IconButton(
        tooltip: _visible ? 'Hide password' : 'Show password',
        onPressed: () => setState(() => _visible = !_visible),
        icon: Icon(
          _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        ),
      ),
    ),
    onChanged: widget.onChanged,
    onSubmitted: (_) => widget.onSubmitted?.call(),
  );
}
