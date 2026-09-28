import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_button.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../../../core/widgets/speech_bubble.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/coach_tone_style.dart';

/// Bottom sheets for editing a single setting. Each returns the new value,
/// or null when dismissed.
abstract final class SettingsSheets {
  static Future<String?> editName(BuildContext context, String current) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _NameSheet(current: current),
      );

  static Future<CoachTone?> coachTone(
    BuildContext context, {
    required CoachTone current,
    required String name,
  }) => showModalBottomSheet<CoachTone>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CoachSheet(current: current, name: name),
  );

  static IconData appearanceIcon(Appearance a) => switch (a) {
    Appearance.night => Icons.dark_mode_rounded,
    Appearance.day => Icons.light_mode_rounded,
    Appearance.automatic => Icons.brightness_auto_rounded,
  };

  static Future<Appearance?> appearance(
    BuildContext context,
    Appearance current,
  ) => showModalBottomSheet<Appearance>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Appearance', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Visit the valley by day or by night.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final option in Appearance.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectableTile(
                    selected: option == current,
                    semanticLabel: '${option.label}: ${option.description}',
                    onTap: () => Navigator.pop(context, option),
                    child: Row(
                      children: [
                        Icon(
                          appearanceIcon(option),
                          color: option == Appearance.day
                              ? AppColors.ember
                              : AppColors.lilac,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option.label, style: text.titleMedium),
                              Text(option.description, style: text.labelMedium),
                            ],
                          ),
                        ),
                        SelectionDot(selected: option == current),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  static Future<AutoLock?> autoLock(BuildContext context, AutoLock current) =>
      showModalBottomSheet<AutoLock>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Auto-lock',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Ask for your PIN when you come back to Velora.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              RadioGroup<AutoLock>(
                groupValue: current,
                onChanged: (v) => Navigator.pop(context, v),
                child: Column(
                  children: [
                    for (final option in AutoLock.values)
                      RadioListTile<AutoLock>(
                        value: option,
                        activeColor: AppColors.leafBright,
                        title: Text(option.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.current});

  final String current;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = _controller.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your name', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Velora uses it to greet you and personalise tips.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(24)],
                style: text.titleMedium?.copyWith(fontSize: 18),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 18),
              PressableButton(
                label: 'Save',
                onPressed: _controller.text.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachSheet extends StatefulWidget {
  const _CoachSheet({required this.current, required this.name});

  final CoachTone current;
  final String name;

  @override
  State<_CoachSheet> createState() => _CoachSheetState();
}

class _CoachSheetState extends State<_CoachSheet> {
  late CoachTone _tone = widget.current;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Coaching style', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'How Velora talks to you about your money.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final option in CoachTone.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableTile(
                  selected: option == _tone,
                  semanticLabel: '${option.label}: ${option.description}',
                  onTap: () => setState(() => _tone = option),
                  child: Row(
                    children: [
                      Icon(option.icon, color: option.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.label, style: text.titleMedium),
                            Text(option.description, style: text.labelMedium),
                          ],
                        ),
                      ),
                      SelectionDot(selected: option == _tone),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: SpeechBubble(
                key: ValueKey(_tone),
                speaker: 'Velora',
                message: _tone.onTrackExample(widget.name),
              ),
            ),
            const SizedBox(height: 18),
            PressableButton(
              label: _tone == widget.current
                  ? 'Keep this style'
                  : 'Use ${_tone.label}',
              onPressed: () => Navigator.pop(context, _tone),
            ),
          ],
        ),
      ),
    );
  }
}
