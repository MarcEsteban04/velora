import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/pin_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/speech_bubble.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/backup_status.dart';
import '../../profile/data/profile_repository.dart';
import '../application/app_lock_controller.dart';
import '../data/pin_repository.dart';
import 'widgets/lock_scaffold.dart';
import 'widgets/number_pad.dart';
import 'widgets/pin_dots.dart';

/// Unlocks Velora with the user's PIN. Wrong attempts are rate-limited, and
/// a live countdown shows when the next try is allowed.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onReset});

  /// Called after the user confirms "Forgot PIN" and wants to start fresh.
  final Future<void> Function() onReset;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _digits = '';
  String? _message;
  int _errorTick = 0;
  bool _busy = false;
  bool _success = false;
  bool _confirmingReset = false;
  DateTime? _lockedUntil;
  Timer? _ticker;

  bool get _lockedOut =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    // Resume a lockout that was still running before the app was closed.
    ref.read(pinRepositoryProvider).lockedUntil().then((until) {
      if (mounted && until != null) _startCountdown(until);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown(DateTime until) {
    _ticker?.cancel();
    setState(() => _lockedUntil = until);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (!_lockedOut) {
        t.cancel();
        setState(() {
          _lockedUntil = null;
          _message = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  String _countdown() {
    final left = _lockedUntil!.difference(DateTime.now());
    final s = left.inSeconds + 1;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _onDigit(String d) {
    if (_busy || _lockedOut || _digits.length >= PinPolicy.length) return;
    setState(() {
      _digits += d;
      _message = null;
    });
    if (_digits.length == PinPolicy.length) _verify();
  }

  void _onBackspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await ref.read(pinRepositoryProvider).verify(_digits);
    if (!mounted) return;

    switch (result) {
      case PinAccepted():
        HapticFeedback.mediumImpact();
        setState(() => _success = true);
        await Future<void>.delayed(const Duration(milliseconds: 280));
        ref.read(appLockProvider.notifier).unlock();
      case PinRejected(:final attemptsLeft):
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _digits = '';
          _errorTick++;
          _message = attemptsLeft == 1
              ? 'Wrong PIN. 1 try left before a short pause.'
              : 'Wrong PIN. $attemptsLeft tries left.';
        });
      case PinLockedOut(:final until):
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _digits = '';
          _errorTick++;
        });
        _startCountdown(until);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider).value?.name;
    final text = Theme.of(context).textTheme;

    return LockScaffold(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: _confirmingReset
            ? _ResetConfirm(
                key: const ValueKey('reset'),
                onCancel: () => setState(() => _confirmingReset = false),
                onConfirm: widget.onReset,
              )
            : Column(
                key: const ValueKey('pin'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeSlideIn(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const VeloraMascot(pose: MascotPose.wave, size: 120),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 50),
                            child: SpeechBubble(
                              speaker: 'Velora',
                              message: name == null
                                  ? 'Welcome back!'
                                  : 'Welcome back, $name!',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Enter your PIN', style: text.headlineSmall),
                  const SizedBox(height: 26),
                  PinDots(
                    filled: _digits.length,
                    errorTick: _errorTick,
                    state: _success
                        ? PinDotsState.success
                        : (_message != null || _lockedOut)
                        ? PinDotsState.error
                        : PinDotsState.idle,
                  ),
                  SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        _lockedOut
                            ? 'Too many tries. Try again in ${_countdown()}'
                            : _message ?? '',
                        textAlign: TextAlign.center,
                        style: text.labelMedium?.copyWith(
                          fontSize: 13,
                          color: AppColors.ember,
                        ),
                      ),
                    ),
                  ),
                  NumberPad(
                    enabled: !_busy && !_lockedOut,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _confirmingReset = true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Forgot PIN?'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// An honest "Forgot PIN" flow. A backed-up space signs out, and signing
/// back in with the email sets a new PIN. Otherwise there's nothing to
/// verify with, so resetting means starting over, and we say so plainly.
class _ResetConfirm extends ConsumerStatefulWidget {
  const _ResetConfirm({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;

  @override
  ConsumerState<_ResetConfirm> createState() => _ResetConfirmState();
}

class _ResetConfirmState extends ConsumerState<_ResetConfirm> {
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final backup = ref.watch(backupStatusProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const VeloraMascot(pose: MascotPose.wallet, size: 150),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                backup is LinkedBackup ? 'Reset your PIN?' : 'Start over?',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                backup is LinkedBackup
                    ? 'We’ll sign you out. Sign back in with ${backup.email} '
                          'and set a new PIN. Everything in your space stays.'
                    : "Your space isn't linked to an email yet, so there's no "
                          "way to confirm it's you. Starting over signs you "
                          'out and sets up a fresh space. Your current '
                          "accounts and history can't be recovered.",
                style: text.bodyMedium,
              ),
              const SizedBox(height: 22),
              PressableButton(
                label: 'Keep trying my PIN',
                onPressed: _resetting ? null : widget.onCancel,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _resetting
                      ? null
                      : () async {
                          setState(() => _resetting = true);
                          await widget.onConfirm();
                        },
                  style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                  child: Text(
                    backup is LinkedBackup
                        ? (_resetting ? 'Signing out…' : 'Sign out')
                        : (_resetting ? 'Starting over…' : 'Start over anyway'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
