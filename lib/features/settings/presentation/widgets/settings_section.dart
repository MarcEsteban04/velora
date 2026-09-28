import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

/// A titled group of settings rows on a frosted card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 26, 6, 10),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontSize: 12, letterSpacing: 1.6),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          radius: 24,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 66,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings row: a tinted icon, a title with an optional subtitle, and
/// a trailing value, switch or chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.color = AppColors.leafBright,
    this.destructive = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Short current value shown on the right, for example "PHP".
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;
  final bool destructive;

  /// A small pill after the title, for example "SOON".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = destructive ? AppColors.rust : color;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              fontSize: 15,
                              color: destructive
                                  ? AppColors.rust
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ember.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: text.labelMedium?.copyWith(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: AppColors.ember,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: text.labelMedium),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value!,
                  style: text.labelMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
