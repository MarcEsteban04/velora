import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';
import '../institutions.dart';
import 'institution_logo.dart';

/// Accounts as a deck of cards: one in front, the next two peeking out
/// behind it. Swipe down to send the front card to the back and bring the
/// next one forward; swipe up to bring the last one back. The card follows
/// the finger, the one behind rises to meet it, and it settles with a
/// click. Tap the card (or "Details") to open the account.
class AccountDeck extends StatefulWidget {
  const AccountDeck({
    super.key,
    required this.accounts,
    required this.hidden,
    required this.onOpen,
    required this.onToggleHidden,
  });

  final List<Account> accounts;
  final bool hidden;
  final ValueChanged<Account> onOpen;
  final VoidCallback onToggleHidden;

  @override
  State<AccountDeck> createState() => _AccountDeckState();
}

class _AccountDeckState extends State<AccountDeck>
    with SingleTickerProviderStateMixin {
  /// Account ids, front first.
  late List<String> _order = [for (final a in widget.accounts) a.id];

  /// How far the front card has been pulled (down is positive).
  double _drag = 0;
  bool _dragging = false;

  /// Hides the swipe hint once the user has swiped.
  bool _swiped = false;

  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(() => setState(() {}));
  Tween<double> _dyTween = Tween(begin: 0, end: 0);
  Tween<double> _fadeTween = Tween(begin: 1, end: 1);

  static const _peek = 16.0;
  static const _inset = 12.0;
  static const _threshold = 70.0;

  @override
  void didUpdateWidget(AccountDeck old) {
    super.didUpdateWidget(old);
    final ids = {for (final a in widget.accounts) a.id};
    _order = [
      ..._order.where(ids.contains),
      for (final a in widget.accounts)
        if (!_order.contains(a.id)) a.id,
    ];
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double get _dy => _dragging
      ? _drag
      : _dyTween.evaluate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
        );
  double get _fade => _dragging
      ? 1
      : _fadeTween.evaluate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        );

  Future<void> _run(
    double toDy,
    double toFade, {
    double? fromDy,
    double? fromFade,
  }) async {
    _dyTween = Tween(begin: fromDy ?? _dy, end: toDy);
    _fadeTween = Tween(begin: fromFade ?? _fade, end: toFade);
    _dragging = false;
    await _anim.forward(from: 0);
  }

  /// Sends the front card to the back.
  Future<void> _next(double cardHeight) async {
    if (_order.length < 2) return _run(0, 1);
    HapticFeedback.lightImpact();
    await _run(cardHeight * 0.75, 0);
    if (!mounted) return;
    setState(() {
      _order = [..._order.skip(1), _order.first];
      _swiped = true;
    });
    await _run(0, 1, fromDy: 0, fromFade: 1);
  }

  /// Brings the back card to the front, rising in from below.
  Future<void> _previous(double cardHeight) async {
    if (_order.length < 2) return _run(0, 1);
    HapticFeedback.lightImpact();
    setState(() {
      _order = [_order.last, ..._order.take(_order.length - 1)];
      _swiped = true;
    });
    await _run(0, 1, fromDy: cardHeight * 0.5, fromFade: 0);
  }

  Future<void> _jumpTo(String id) async {
    final i = _order.indexOf(id);
    if (i <= 0) return;
    HapticFeedback.selectionClick();
    await _run(0, 0.2);
    if (!mounted) return;
    setState(() => _order = [..._order.skip(i), ..._order.take(i)]);
    await _run(0, 1, fromDy: 24, fromFade: 0.2);
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final a in widget.accounts) a.id: a};
    final cards = [for (final id in _order) ?byId[id]];
    if (cards.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final cardHeight = width / 1.586; // A bank card's proportions.
        final behind = math.min(cards.length - 1, 2);
        final top = behind * _peek;
        // Dragging the front card lets the one behind rise toward it.
        final rise = (_dy.abs() / _threshold).clamp(0.0, 1.0);

        Widget layer(int depth, Account a) {
          final d = depth == 0 ? 0.0 : depth - rise;
          return Positioned(
            top: top - d * _peek,
            left: d * _inset,
            right: d * _inset,
            height: cardHeight,
            child: IgnorePointer(
              ignoring: depth != 0,
              child: _DeckCard(
                account: a,
                hidden: widget.hidden,
                dim: d / 2,
                onDetails: () => widget.onOpen(a),
                onToggleHidden: widget.onToggleHidden,
              ),
            ),
          );
        }

        final front = cards.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: '${front.name} card',
              value:
                  '${widget.accounts.indexWhere((a) => a.id == front.id) + 1} '
                  'of ${cards.length}',
              increasedValue: cards.length > 1 ? 'next card' : null,
              decreasedValue: cards.length > 1 ? 'previous card' : null,
              onIncrease: cards.length > 1 ? () => _next(cardHeight) : null,
              onDecrease: cards.length > 1 ? () => _previous(cardHeight) : null,
              child: SizedBox(
                height: top + cardHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var depth = behind; depth >= 1; depth--)
                      layer(depth, cards[depth]),
                    Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      height: cardHeight,
                      // Only a downward swipe belongs to the deck, so
                      // swiping up still scrolls the page.
                      child: RawGestureDetector(
                        gestures: {
                          TapGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                TapGestureRecognizer
                              >(TapGestureRecognizer.new, (t) {
                                t.onTap = () {
                                  HapticFeedback.selectionClick();
                                  widget.onOpen(front);
                                };
                              }),
                          _DownwardDragRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                _DownwardDragRecognizer
                              >(_DownwardDragRecognizer.new, (r) {
                                r
                                  ..onStart = (_) {
                                    _anim.stop();
                                    setState(() {
                                      _drag = _dy;
                                      _dragging = true;
                                    });
                                  }
                                  ..onUpdate = (d) {
                                    setState(() {
                                      _drag = math.max(0, _drag + d.delta.dy);
                                    });
                                  }
                                  ..onEnd = (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (_drag > _threshold || v > 700) {
                                      _next(cardHeight);
                                    } else {
                                      _run(0, 1);
                                    }
                                  };
                              }),
                        },
                        child: Opacity(
                          opacity: _fade.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, _dy),
                            child: Transform.rotate(
                              angle: _dy * 0.0007,
                              child: Transform.scale(
                                scale: 1 - rise * 0.03,
                                child: _DeckCard(
                                  key: ValueKey(front.id),
                                  account: front,
                                  hidden: widget.hidden,
                                  dim: 0,
                                  onDetails: () => widget.onOpen(front),
                                  onToggleHidden: widget.onToggleHidden,
                                ),
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
            if (cards.length > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final a in widget.accounts)
                    Semantics(
                      button: true,
                      label: 'Show ${a.name}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _jumpTo(a.id),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 6,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            width: a.id == front.id ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: a.id == front.id
                                  ? AppColors.leafBright
                                  : AppColors.hairline(0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _swiped ? 0 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_down_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe down for the next card',
                        style: text.labelMedium?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One card's face: brand colors and stripes, the logo, the balance with an
/// eye to hide it, and chips for the type and net worth.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    super.key,
    required this.account,
    required this.hidden,
    required this.dim,
    required this.onDetails,
    required this.onToggleHidden,
  });

  final Account account;
  final bool hidden;

  /// 0 for the front card, more for cards further back.
  final double dim;
  final VoidCallback onDetails;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = account;
    final institution = Institutions.forAccount(a);
    final colors = institution?.gradient ?? a.type.gradient;
    final currency = Currencies.byCode(a.currencyCode);
    const white = Colors.white;

    Widget chip(String label, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: text.labelMedium?.copyWith(
              fontSize: 11.5,
              color: white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label:
          '${a.name}, ${a.type.label}, balance '
          '${hidden ? 'hidden' : Money.format(a.balanceMinor, currency)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: white.withValues(alpha: 0.14)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _Stripes())),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (institution != null)
                          InstitutionLogo(institution: institution, height: 34)
                        else
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  a.type.icon,
                                  color: white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                a.name,
                                style: TextStyle(
                                  fontFamily: AppTypography.display,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  color: white,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onDetails,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Text(
                                  'Details',
                                  style: text.titleMedium?.copyWith(
                                    fontSize: 13.5,
                                    color: white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                  color: white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      institution == null ? 'Balance' : '${a.name} · balance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        fontSize: 12,
                        color: white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              hidden
                                  ? '${currency.symbol} ••••••'
                                  : Money.format(a.balanceMinor, currency),
                              style: TextStyle(
                                fontFamily: AppTypography.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 30,
                                height: 1.1,
                                color: white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          button: true,
                          label: hidden ? 'Show balances' : 'Hide balances',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onToggleHidden();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: white,
                              ),
                              child: Icon(
                                hidden
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                size: 18,
                                color: const Color(0xFF1A1A22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        chip(a.type.label, icon: a.type.icon),
                        const SizedBox(width: 8),
                        if (!a.includeInNetWorth)
                          chip('Not in net worth', icon: Icons.block_rounded),
                        const Spacer(),
                        Text(
                          currency.code,
                          style: const TextStyle(
                            fontFamily: AppTypography.display,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            fontSize: 26,
                            letterSpacing: 1,
                            color: white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Cards further back sit in the shade, instead of a shadow.
              if (dim > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28 * dim),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft vertical bands across the right of the card, like a premium card.
class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    final start = size.width * 0.44;
    final band = size.width * 0.045;
    for (var i = 0; i < 9; i++) {
      final x = start + i * band * 1.2;
      final alpha = 0.035 + (i.isEven ? 0.05 : 0.0) + i * 0.006;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, band * (i.isEven ? 0.55 : 1), size.height),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    // A gentle sheen fading toward the bottom right.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}

/// A vertical drag that only claims the gesture when it starts downward.
/// Upward movement is left to the page's scroll view.
class _DownwardDragRecognizer extends VerticalDragGestureRecognizer {
  double _moved = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _moved = 0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _moved += event.delta.dy;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) => _moved > (deviceTouchSlop ?? kTouchSlop);
}
