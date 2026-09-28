import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/reveal.dart';

/// The shared frame for every onboarding step: scrollable (so the keyboard
/// never hides a field), padded, and at most 480 wide on tablets.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.center = false,
  });

  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final align = center ? TextAlign.center : TextAlign.start;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: align,
              style: text.displaySmall?.copyWith(fontSize: 30),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle!, textAlign: align, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Small uppercase label above a field or group.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 22),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          letterSpacing: 1.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
