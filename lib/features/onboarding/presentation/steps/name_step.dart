import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/reveal.dart';
import '../../../../core/widgets/velora_mascot.dart';
import '../../application/onboarding_controller.dart';
import '../widgets/mascot_says.dart';
import '../widgets/step_layout.dart';

class NameStep extends ConsumerStatefulWidget {
  const NameStep({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final _controller = TextEditingController(
    text: ref.read(onboardingControllerProvider).name,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(onboardingControllerProvider).firstName;
    final text = Theme.of(context).textTheme;

    return StepLayout(
      children: [
        const SizedBox(height: 8),
        MascotSays(
          pose: MascotPose.wave,
          message: name.isEmpty
              ? 'Hi! What should I call you?'
              : 'Nice to meet you, $name!',
        ),
        const SizedBox(height: 20),
        const StepHeader(
          title: "Let's get to know each other",
          subtitle:
              "I'll use your name to make tips and summaries feel like "
              "they're written for you.",
        ),
        const FieldLabel('Your name'),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: TextField(
            controller: _controller,
            autofocus: true,
            inputFormatters: [LengthLimitingTextInputFormatter(24)],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            style: text.titleMedium?.copyWith(fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Your first name',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            onChanged: ref.read(onboardingControllerProvider.notifier).setName,
            onSubmitted: (_) {
              if (name.isNotEmpty) widget.onSubmit();
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.lock_rounded, size: 14, color: AppColors.leafBright),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Private to you, never shared',
                style: text.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
