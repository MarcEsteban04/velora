import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/widgets/account_card.dart';

/// Swipeable account cards. The next card peeks in at the edge so it's
/// obvious there's more, and dots appear once there are two or more.
class AccountsCarousel extends StatefulWidget {
  const AccountsCarousel({
    super.key,
    required this.accounts,
    required this.hidden,
  });

  final List<Account> accounts;
  final bool hidden;

  @override
  State<AccountsCarousel> createState() => _AccountsCarouselState();
}

class _AccountsCarouselState extends State<AccountsCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.accounts;
    final single = accounts.length == 1;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: single
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _card(accounts.first),
                )
              : PageView.builder(
                  controller: _controller,
                  padEnds: false,
                  itemCount: accounts.length,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 24),
                    child: _card(accounts[i]),
                  ),
                ),
        ),
        if (!single)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < accounts.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _page
                        ? AppColors.leafBright
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _card(Account a) => AccountCard(
    name: a.name,
    type: a.type,
    currency: Currencies.byCode(a.currencyCode),
    balanceMinor: a.openingBalanceMinor,
    obscured: widget.hidden,
  );
}
