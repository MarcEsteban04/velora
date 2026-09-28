import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

enum ToastTone { success, info, error }

/// Something to do from the toast, such as Undo.
class ToastAction {
  const ToastAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

/// Shows short messages as an island at the top of the screen, like the
/// iPhone's Dynamic Island: a black capsule that stretches open, says its
/// piece, and tucks itself away. Swipe it up or tap it to dismiss early.
///
/// Grab a [Toaster] before an `await` (like `ScaffoldMessenger.of`), since
/// the calling screen may be gone by the time there's something to say:
///
/// ```dart
/// final toast = Toast.of(context);
/// await save();
/// toast.show('Saved');
/// ```
abstract final class Toast {
  static Toaster of(BuildContext context) => Toaster._(
    context.findAncestorStateOfType<_IslandToastHostState>(),
    ScaffoldMessenger.maybeOf(context),
  );
}

class Toaster {
  const Toaster._(this._host, this._fallback);

  final _IslandToastHostState? _host;
  final ScaffoldMessengerState? _fallback;

  void show(
    String message, {
    ToastTone tone = ToastTone.success,
    IconData? icon,
    ToastAction? action,
    Duration? duration,
  }) {
    final data = _ToastData(
      message: message,
      tone: tone,
      icon: icon,
      action: action,
      duration:
          duration ??
          (action != null
              ? const Duration(milliseconds: 4500)
              : tone == ToastTone.error
              ? const Duration(milliseconds: 4000)
              : const Duration(milliseconds: 2800)),
    );
    final host = _host;
    if (host != null && host.mounted) {
      host._show(data);
      return;
    }
    // Outside the app shell (a bare test widget, say): a plain snackbar.
    _fallback?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows [message] in the error style.
  void error(String message) => show(message, tone: ToastTone.error);
}

class _ToastData {
  const _ToastData({
    required this.message,
    required this.tone,
    required this.icon,
    required this.action,
    required this.duration,
  });

  final String message;
  final ToastTone tone;
  final IconData? icon;
  final ToastAction? action;
  final Duration duration;
}

/// Hosts the island above every screen. It sits in `MaterialApp.builder`,
/// so a toast outlives the screen or sheet that showed it.
class IslandToastHost extends StatefulWidget {
  const IslandToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<IslandToastHost> createState() => _IslandToastHostState();
}

class _IslandToastHostState extends State<IslandToastHost>
    with TickerProviderStateMixin {
  _ToastData? _data;

  /// Bumped for every toast, so a new message replaces the old one in place.
  int _serial = 0;

  /// 0 = tucked away as a dot, 1 = fully open.
  late final _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    reverseDuration: const Duration(milliseconds: 300),
  );

  /// Counts down how long the toast stays; drawn as a thin line.
  late final _life = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _hide();
    });

  double _dragUp = 0;

  void _show(_ToastData data) {
    setState(() {
      _data = data;
      _serial++;
      _dragUp = 0;
    });
    if (data.tone == ToastTone.error) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      data.message,
      Directionality.of(context),
    );
    _presence.forward();
    _life
      ..duration = data.duration
      ..forward(from: 0);
  }

  Future<void> _hide() async {
    _life.stop();
    await _presence.reverse();
    if (mounted && _presence.isDismissed) setState(() => _data = null);
  }

  @override
  void dispose() {
    _presence.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Stack(
      children: [
        widget.child,
        if (data != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 12,
            right: 12,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hide,
                onVerticalDragUpdate: (d) => setState(
                  () => _dragUp = (_dragUp - d.delta.dy).clamp(0, 80),
                ),
                onVerticalDragEnd: (d) {
                  if (_dragUp > 24 || (d.primaryVelocity ?? 0) < -300) {
                    _hide();
                  } else {
                    setState(() => _dragUp = 0);
                  }
                },
                child: Transform.translate(
                  offset: Offset(0, -_dragUp),
                  child: _Island(
                    key: ValueKey(_serial),
                    data: data,
                    presence: _presence,
                    life: _life,
                    onAction: () {
                      data.action?.onPressed();
                      _hide();
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({
    super.key,
    required this.data,
    required this.presence,
    required this.life,
    required this.onAction,
  });

  final _ToastData data;
  final Animation<double> presence;
  final Animation<double> life;
  final VoidCallback onAction;

  /// The island stays black in Day and Night, like the hardware it echoes.
  static const _ink = Color(0xFF0A0A0D);
  static const _green = Color(0xFF7CD992);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Fixed colors: the island is black in every scene, so the Day
    // palette's deeper greens would read poorly on it.
    final (tint, fallbackIcon) = switch (data.tone) {
      ToastTone.success => (_green, Icons.check_rounded),
      ToastTone.info => (const Color(0xFF8AB8FF), Icons.info_rounded),
      ToastTone.error => (const Color(0xFFFF6B5E), Icons.error_rounded),
    };

    // Opening: drops in and stretches sideways from a small capsule, then
    // the content fades in once it's wide enough.
    final open = CurvedAnimation(
      parent: presence,
      curve: reduceMotion ? Curves.easeOut : Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final content = CurvedAnimation(
      parent: presence,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.5, curve: Curves.easeIn),
    );

    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380, minHeight: 50),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              FadeTransition(
                opacity: content,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    8,
                    data.action == null ? 18 : 6,
                    8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tint.withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          data.icon ?? fallbackIcon,
                          size: 19,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          data.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontSize: 13.5,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (data.action case final a?) ...[
                        const SizedBox(width: 8),
                        _ActionPill(
                          label: a.label,
                          color: _green,
                          onTap: onAction,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Time left, as a line that drains along the bottom.
              Positioned(
                left: 22,
                right: 22,
                bottom: 3,
                child: AnimatedBuilder(
                  animation: life,
                  builder: (context, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 1 - life.value,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: data.message,
      child: AnimatedBuilder(
        animation: open,
        builder: (context, child) {
          final t = open.value;
          return Opacity(
            opacity: presence.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * -26),
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.diagonal3Values(
                  0.32 + 0.68 * t,
                  0.72 + 0.28 * t,
                  1,
                ),
                child: child,
              ),
            ),
          );
        },
        child: body,
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 13.5, color: color),
          ),
        ),
      ),
    );
  }
}
