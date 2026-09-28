import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/security/pin_policy.dart';
import '../../../../core/theme/app_colors.dart';
import 'number_pad.dart';
import 'pin_dots.dart';

/// Create-then-confirm PIN entry. Too-simple PINs are refused and a mismatch
/// shakes and restarts. [onCreated] fires once the user has typed the same
/// PIN twice. Used by both onboarding and the standalone setup screen.
class PinCreator extends StatefulWidget {
  const PinCreator({super.key, required this.onCreated, this.header});

  final ValueChanged<String> onCreated;

  /// Builds the title area for the current phase (creating or confirming).
  final Widget Function(BuildContext context, bool confirming)? header;

  @override
  State<PinCreator> createState() => _PinCreatorState();
}

class _PinCreatorState extends State<PinCreator> {
  String _first = '';
  String _digits = '';
  bool _confirming = false;
  bool _done = false;
  String? _message;
  int _errorTick = 0;

  void _onDigit(String d) {
    if (_done || _digits.length >= PinPolicy.length) return;
    setState(() {
      _digits += d;
      _message = null;
    });
    if (_digits.length == PinPolicy.length) {
      Future<void>.delayed(const Duration(milliseconds: 180), _evaluate);
    }
  }

  void _onBackspace() {
    if (_done || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _fail(String message, {bool restart = false}) {
    HapticFeedback.heavyImpact();
    setState(() {
      _digits = '';
      _message = message;
      _errorTick++;
      if (restart) {
        _first = '';
        _confirming = false;
      }
    });
  }

  void _evaluate() {
    if (!mounted) return;
    if (!_confirming) {
      if (PinPolicy.isTooSimple(_digits)) {
        _fail("That one's easy to guess. Try something less obvious.");
        return;
      }
      setState(() {
        _first = _digits;
        _digits = '';
        _confirming = true;
      });
      return;
    }
    if (_digits != _first) {
      _fail("PINs didn't match. Let's start again.", restart: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _done = true);
    widget.onCreated(_digits);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.header != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey(_confirming),
              child: widget.header!(context, _confirming),
            ),
          ),
        const SizedBox(height: 28),
        PinDots(
          filled: _digits.length,
          errorTick: _errorTick,
          state: _done
              ? PinDotsState.success
              : _message != null
              ? PinDotsState.error
              : PinDotsState.idle,
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _message ?? (_done ? 'PIN set!' : ''),
                key: ValueKey(_message ?? _done),
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(
                  fontSize: 13,
                  color: _message != null
                      ? AppColors.ember
                      : AppColors.leafBright,
                ),
              ),
            ),
          ),
        ),
        NumberPad(
          enabled: !_done,
          onDigit: _onDigit,
          onBackspace: _onBackspace,
        ),
      ],
    );
  }
}
