import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';

/// Icon and color keys stored with each category. The keys live in the
/// database, and their visuals live here, so the palette can evolve freely.
abstract final class CategoryStyle {
  static const icons = <String, IconData>{
    'food': Icons.restaurant_rounded,
    'transport': Icons.directions_bus_rounded,
    'groceries': Icons.local_grocery_store_rounded,
    'bills': Icons.receipt_long_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'fun': Icons.sports_esports_rounded,
    'health': Icons.favorite_rounded,
    'phone': Icons.wifi_rounded,
    'home': Icons.home_rounded,
    'salary': Icons.work_rounded,
    'freelance': Icons.laptop_mac_rounded,
    'gift': Icons.redeem_rounded,
    'refund': Icons.replay_rounded,
    'interest': Icons.savings_rounded,
    'coffee': Icons.local_cafe_rounded,
    'travel': Icons.flight_rounded,
    'car': Icons.directions_car_rounded,
    'pets': Icons.pets_rounded,
    'education': Icons.school_rounded,
    'fitness': Icons.fitness_center_rounded,
    'beauty': Icons.spa_rounded,
    'kids': Icons.child_care_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'charity': Icons.volunteer_activism_rounded,
    'other': Icons.category_rounded,
  };

  static Map<String, Color> get colors => {
    'ember': AppColors.ember,
    'sky': AppColors.sky,
    'leaf': AppColors.leafBright,
    'amber': Color(0xFFF4C24D),
    'rose': Color(0xFFF27BA6),
    'lilac': AppColors.lilac,
    'coral': Color(0xFFF0766E),
    'teal': Color(0xFF3CC6C0),
    'rust': AppColors.rust,
    'slate': Color(0xFF8C95A8),
  };

  static IconData iconOf(String key) => icons[key] ?? Icons.category_rounded;
  static Color colorOf(String key) => colors[key] ?? const Color(0xFF8C95A8);
}

extension CategoryVisuals on Category {
  IconData get iconData => CategoryStyle.iconOf(icon);
  Color get colorValue => CategoryStyle.colorOf(color);
}

extension TransactionKindStyle on TransactionKind {
  String get label => switch (this) {
    TransactionKind.expense => 'Expense',
    TransactionKind.income => 'Income',
    TransactionKind.transfer => 'Transfer',
  };

  Color get color => switch (this) {
    TransactionKind.expense => const Color(0xFFF0766E),
    TransactionKind.income => AppColors.leafBright,
    TransactionKind.transfer => AppColors.sky,
  };

  IconData get icon => switch (this) {
    TransactionKind.expense => Icons.north_east_rounded,
    TransactionKind.income => Icons.south_west_rounded,
    TransactionKind.transfer => Icons.swap_horiz_rounded,
  };
}
