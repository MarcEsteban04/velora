import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/velora_mascot.dart';

/// What the user said, on the right in brand green.
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        margin: const EdgeInsets.only(bottom: 10, left: 40),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.onBrand, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Velora's reply, on the left, with her face on the first of a run.
class VeloraBubble extends StatelessWidget {
  const VeloraBubble({
    super.key,
    required this.text,
    this.fromAi = false,
    this.showAvatar = true,
  });

  final String text;
  final bool fromAi;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 34, child: showAvatar ? const _Avatar() : null),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised.withValues(alpha: 0.92),
                border: Border.all(color: AppColors.hairline(0.08)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (fromAi)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: AppColors.ember,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'AI',
                            style: t.labelMedium?.copyWith(
                              fontSize: 10,
                              color: AppColors.ember,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.ember.withValues(alpha: 0.16),
    ),
    child: ClipOval(
      child: Transform.scale(
        scale: 1.5,
        alignment: const Alignment(0, -0.7),
        child: Image(
          image: MascotPose.wave.image(context, 52),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

/// Three dots bouncing while Velora thinks.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Velora is typing',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const SizedBox(width: 34, child: _Avatar()),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -3 *
                                (1 -
                                    ((_c.value * 3 - i).abs() % 3).clamp(0, 1)),
                          ),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Velora can see, said plainly.
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 2),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'I see account names, balances and totals, never your notes. '
              'Nothing is saved until you tap Log it.',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
