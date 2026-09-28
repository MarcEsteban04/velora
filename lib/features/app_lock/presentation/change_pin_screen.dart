import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/security/pin_policy.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../data/pin_repository.dart';
import 'widgets/lock_scaffold.dart';
import 'widgets/number_pad.dart';
import 'widgets/pin_creator.dart';
import 'widgets/pin_dots.dart';

/// Change PIN: prove you know the current one (with the same attempt limits
/// as the lock screen), then create and confirm a new one.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ChangePinScreen());

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  bool _verified = false;
  String _digits = '';
  String? _message;
  int _errorTick = 0;
  bool _busy = false;
  DateTime? _lockedUntil;
  Timer? _ticker;

  bool get _lockedOut =>
      _lockedUntil != null && _lockedUntil!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
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
        setState(() => _lockedUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await ref.read(pinRepositoryProvider).verify(_digits);
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        HapticFeedback.mediumImpact();
        setState(() {
          _verified = true;
          _busy = false;
        });
      case PinRejected(:final attemptsLeft):
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _digits = '';
          _errorTick++;
          _message =
              'Wrong PIN. $attemptsLeft '
              '${attemptsLeft == 1 ? 'try' : 'tries'} left.';
        });
      case PinLockedOut(:final until):
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _digits = '';
          _errorTick++;
          _message = null;
        });
        _startCountdown(until);
    }
  }

  Future<void> _save(String pin) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(pinRepositoryProvider).setPin(pin);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('PIN changed')));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(friendlyError(error, action: 'change your PIN')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final countdown = _lockedUntil == null
        ? ''
        : () {
            final s = _lockedUntil!.difference(DateTime.now()).inSeconds + 1;
            return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
          }();

    return LockScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const VeloraMascot(pose: MascotPose.thumbsUp, size: 120),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: _verified
                ? PinCreator(
                    key: const ValueKey('new'),
                    header: (context, confirming) => Column(
                      children: [
                        Text(
                          confirming ? 'Confirm new PIN' : 'Choose a new PIN',
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          confirming
                              ? 'Enter it once more.'
                              : 'Pick something only you would know.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                    onCreated: _save,
                  )
                : Column(
                    key: const ValueKey('current'),
                    children: [
                      Text('Enter your current PIN', style: text.headlineSmall),
                      const SizedBox(height: 26),
                      PinDots(
                        filled: _digits.length,
                        errorTick: _errorTick,
                        state: (_message != null || _lockedOut)
                            ? PinDotsState.error
                            : PinDotsState.idle,
                      ),
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            _lockedOut
                                ? 'Too many tries. Try again in $countdown'
                                : _message ?? '',
                            style: text.labelMedium?.copyWith(
                              fontSize: 14,
                              color: AppColors.ember,
                            ),
                          ),
                        ),
                      ),
                      NumberPad(
                        enabled: !_busy && !_lockedOut,
                        onDigit: (d) {
                          if (_digits.length >= PinPolicy.length) return;
                          setState(() {
                            _digits += d;
                            _message = null;
                          });
                          if (_digits.length == PinPolicy.length) _verify();
                        },
                        onBackspace: () {
                          if (_digits.isEmpty) return;
                          setState(
                            () => _digits = _digits.substring(
                              0,
                              _digits.length - 1,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
