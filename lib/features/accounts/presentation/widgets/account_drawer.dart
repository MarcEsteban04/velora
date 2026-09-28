import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/account.dart';
import '../institutions.dart';
import 'account_card.dart';

/// Accounts as a drawer of cards, like a wallet: each one peeks out above
/// the next, showing its logo and name. Tap a card to slide it out in full
/// (the ones below make room); tap it again to open the account.
class AccountDrawer extends StatefulWidget {
  const AccountDrawer({
    super.key,
    required this.accounts,
    required this.hidden,
    required this.onOpen,
  });

  final List<Account> accounts;
  final bool hidden;
  final ValueChanged<Account> onOpen;

  /// How much of each card shows when it's tucked in.
  static const peek = 64.0;
  static const cardHeight = 176.0;
  static const _gap = 10.0;

  @override
  State<AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends State<AccountDrawer> {
  /// The card slid out, if any. The last card is always fully visible.
  int? _open;

  static const _duration = Duration(milliseconds: 420);
  static const _curve = Curves.easeOutCubic;

  void _tap(int i, Account a) {
    final last = i == widget.accounts.length - 1;
    // A card already showing in full opens; any other slides out first.
    if (_open == i || (last && _open == null)) {
      HapticFeedback.selectionClick();
      widget.onOpen(a);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _open = last ? null : i);
  }

  @override
  void didUpdateWidget(AccountDrawer old) {
    super.didUpdateWidget(old);
    if (_open != null && _open! >= widget.accounts.length) _open = null;
  }

  @override
  Widget build(BuildContext context) {
    const peek = AccountDrawer.peek;
    const card = AccountDrawer.cardHeight;
    const gap = AccountDrawer._gap;
    final n = widget.accounts.length;
    if (n == 0) return const SizedBox.shrink();

    // Cards below the open one move down by what it needs to show in full.
    final push = _open == null ? 0.0 : card - peek + gap;
    double top(int i) => i * peek + (_open != null && i > _open! ? push : 0);
    final height = (n - 1) * peek + card + (_open == null ? 0 : push);

    return Semantics(
      label: 'Accounts drawer, ${widget.accounts.length} cards',
      child: AnimatedContainer(
        duration: _duration,
        curve: _curve,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, a) in widget.accounts.indexed)
              AnimatedPositioned(
                key: ValueKey(a.id),
                duration: _duration,
                curve: _curve,
                top: top(i),
                left: 0,
                right: 0,
                height: card,
                child: Semantics(
                  button: true,
                  hint: _open == i || (i == n - 1 && _open == null)
                      ? 'Opens account details'
                      : 'Slides the card out',
                  child: GestureDetector(
                    onTap: () => _tap(i, a),
                    child: Opacity(
                      opacity: a.includeInNetWorth ? 1 : 0.7,
                      child: Stack(
                        children: [
                          AccountCard(
                            name: a.name,
                            type: a.type,
                            currency: Currencies.byCode(a.currencyCode),
                            balanceMinor: a.balanceMinor,
                            obscured: widget.hidden,
                            institution: Institutions.forAccount(a),
                          ),
                          // A light top edge tells stacked cards apart
                          // without shadows.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: AppColors.onBrand.withValues(
                                      alpha: 0.22,
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
