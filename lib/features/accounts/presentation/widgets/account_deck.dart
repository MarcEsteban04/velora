import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';
import '../institutions.dart';
import 'institution_logo.dart';

/// Accounts as a deck of cards: one in front, the next two peeking out
/// behind it. Swipe left to send the front card away and bring the next
/// one forward; swipe right to bring the last one back. Sideways, so the
/// page still scrolls up and down over the deck. The card follows the
/// finger, the one behind rises to meet it, and it settles with a click.
/// Tap the card (or "Details") to open the account.
class AccountDeck extends StatefulWidget {
  const AccountDeck({
    super.key,
    required this.accounts,
    required this.hidden,
    required this.onOpen,
    required this.onToggleHidden,
    required this.holder,
  });

  final List<Account> accounts;

  /// The user's name, printed as the cardholder.
  final String holder;
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

  /// How far the front card has been pulled (right is positive).
  double _drag = 0;
  bool _dragging = false;

  /// Hides the swipe hint once the user has swiped.
  bool _swiped = false;

  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..addListener(() => setState(() {}));
  Tween<double> _dxTween = Tween(begin: 0, end: 0);
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

  double get _dx => _dragging
      ? _drag
      : _dxTween.evaluate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
        );
  double get _fade => _dragging
      ? 1
      : _fadeTween.evaluate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        );

  Future<void> _run(
    double toDx,
    double toFade, {
    double? fromDx,
    double? fromFade,
  }) async {
    _dxTween = Tween(begin: fromDx ?? _dx, end: toDx);
    _fadeTween = Tween(begin: fromFade ?? _fade, end: toFade);
    _dragging = false;
    await _anim.forward(from: 0);
  }

  /// Sends the front card off to the left and to the back of the deck.
  Future<void> _next(double width) async {
    if (_order.length < 2) return _run(0, 1);
    HapticFeedback.lightImpact();
    await _run(-width * 0.9, 0);
    if (!mounted) return;
    setState(() {
      _order = [..._order.skip(1), _order.first];
      _swiped = true;
    });
    await _run(0, 1, fromDx: 0, fromFade: 1);
  }

  /// Brings the back card to the front, sliding in from the left.
  Future<void> _previous(double width) async {
    if (_order.length < 2) return _run(0, 1);
    HapticFeedback.lightImpact();
    setState(() {
      _order = [_order.last, ..._order.take(_order.length - 1)];
      _swiped = true;
    });
    await _run(0, 1, fromDx: -width * 0.6, fromFade: 0);
  }

  Future<void> _jumpTo(String id) async {
    final i = _order.indexOf(id);
    if (i <= 0) return;
    HapticFeedback.selectionClick();
    await _run(0, 0.2);
    if (!mounted) return;
    setState(() => _order = [..._order.skip(i), ..._order.take(i)]);
    await _run(0, 1, fromDx: 24, fromFade: 0.2);
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
        final rise = (_dx.abs() / _threshold).clamp(0.0, 1.0);

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
                holder: widget.holder,
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
              onIncrease: cards.length > 1 ? () => _next(width) : null,
              onDecrease: cards.length > 1 ? () => _previous(width) : null,
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
                      // Sideways swipes belong to the deck; up and down
                      // still scroll the page.
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
                          HorizontalDragGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                HorizontalDragGestureRecognizer
                              >(HorizontalDragGestureRecognizer.new, (r) {
                                r
                                  ..onStart = (_) {
                                    _anim.stop();
                                    setState(() {
                                      _drag = _dx;
                                      _dragging = true;
                                    });
                                  }
                                  ..onUpdate = (d) {
                                    setState(() => _drag += d.delta.dx);
                                  }
                                  ..onEnd = (d) {
                                    final v = d.primaryVelocity ?? 0;
                                    if (_drag < -_threshold || v < -700) {
                                      _next(width);
                                    } else if (_drag > _threshold || v > 700) {
                                      _previous(width);
                                    } else {
                                      _run(0, 1);
                                    }
                                  };
                              }),
                        },
                        child: Opacity(
                          opacity: _fade.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(_dx, 0),
                            child: Transform.rotate(
                              angle: _dx * 0.0006,
                              child: Transform.scale(
                                scale: 1 - rise * 0.03,
                                child: _DeckCard(
                                  key: ValueKey(front.id),
                                  account: front,
                                  holder: widget.holder,
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
                        Icons.swipe_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Swipe sideways for your other cards',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(fontSize: 11),
                        ),
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

/// One card's face, laid out like a debit card: logo and "Details", the
/// chip and contactless mark, the balance on the number line (with an eye
/// to hide it), the cardholder and member-since date, and the currency as
/// the network mark. A fine wave pattern stands in for security print.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    super.key,
    required this.account,
    required this.holder,
    required this.hidden,
    required this.dim,
    required this.onDetails,
    required this.onToggleHidden,
  });

  final Account account;

  /// Printed as the cardholder.
  final String holder;
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

    TextStyle small(double opacity) => TextStyle(
      fontFamily: AppTypography.body,
      fontWeight: FontWeight.w700,
      fontSize: 8.5,
      letterSpacing: 1.4,
      color: white.withValues(alpha: opacity),
    );
    // Wide, heavy capitals, like the name pressed into a card.
    final embossed = TextStyle(
      fontFamily: AppTypography.body,
      fontWeight: FontWeight.w800,
      fontSize: 14,
      letterSpacing: 2,
      color: white,
    );

    final since =
        '${a.createdAt.month.toString().padLeft(2, '0')}/'
        '${(a.createdAt.year % 100).toString().padLeft(2, '0')}';

    return Semantics(
      label:
          '${a.name}, ${a.type.label}, '
          '${hidden ? 'balance hidden' : balanceText(a.type, a.balanceMinor, currency)}'
          '${a.includeInNetWorth ? '' : ', not in net worth'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: white.withValues(alpha: 0.16)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _SecurityPrint()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (institution != null)
                          InstitutionLogo(institution: institution, height: 30)
                        else
                          Row(
                            children: [
                              Icon(a.type.icon, color: white, size: 22),
                              const SizedBox(width: 8),
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
                                    fontSize: 13,
                                    color: white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const _EmvChip(),
                        const SizedBox(width: 10),
                        Transform.rotate(
                          angle: math.pi / 2,
                          child: Icon(
                            Icons.wifi_rounded,
                            size: 22,
                            color: white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        if (!a.includeInNetWorth)
                          Text('NOT IN NET WORTH', style: small(0.8)),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      cardCaption(a.type, a.balanceMinor),
                      style: small(0.7),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              hidden
                                  ? '${currency.symbol} ••••  ••••'
                                  : cardAmount(
                                      a.type,
                                      a.balanceMinor,
                                      currency,
                                    ),
                              style: TextStyle(
                                fontFamily: AppTypography.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 27,
                                height: 1.15,
                                letterSpacing: 0.6,
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
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: white.withValues(alpha: 0.22),
                                border: Border.all(
                                  color: white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                hidden
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                size: 16,
                                color: white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CARDHOLDER', style: small(0.65)),
                              Text(
                                holder.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: embossed,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MEMBER\nSINCE', style: small(0.65)),
                            Text(since, style: embossed),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Text(
                          currency.code,
                          style: TextStyle(
                            fontFamily: AppTypography.display,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            fontSize: 24,
                            height: 1,
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

/// A gold EMV chip with its contact pads.
class _EmvChip extends StatelessWidget {
  const _EmvChip();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 40,
    height: 30,
    child: CustomPaint(painter: _ChipPainter()),
  );
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3DC8E), Color(0xFFD4A94A), Color(0xFFF0D27F)],
        ).createShader(Offset.zero & size),
    );
    final line = Paint()
      ..color = const Color(0xFF9C7627).withValues(alpha: 0.7)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    // The pads: a middle column and three rows either side.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.18, w * 0.28, h * 0.64),
        const Radius.circular(3),
      ),
      line,
    );
    for (final y in [h / 3, h * 2 / 3]) {
      canvas.drawLine(Offset(0, y), Offset(w * 0.36, y), line);
      canvas.drawLine(Offset(w * 0.64, y), Offset(w, y), line);
    }
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.18), line);
    canvas.drawLine(Offset(w / 2, h * 0.82), Offset(w / 2, h), line);
    canvas.drawRRect(
      r,
      line..color = const Color(0xFF9C7627).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => false;
}

/// Fine flowing lines, like the security print on a real card, and a soft
/// sheen toward the corner.
class _SecurityPrint extends CustomPainter {
  const _SecurityPrint();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 14; i++) {
      final path = Path();
      final base = size.height * (0.15 + i * 0.07);
      for (var x = 0.0; x <= size.width; x += 6) {
        final y =
            base +
            math.sin((x / size.width) * math.pi * 2 + i * 0.45) *
                size.height *
                0.08;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      paint.color = Colors.white.withValues(alpha: 0.045 + (i % 3) * 0.01);
      canvas.drawPath(path, paint);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, -0.9),
          radius: 1.3,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SecurityPrint old) => false;
}
