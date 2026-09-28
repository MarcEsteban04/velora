import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The picture being read, with a scan line sweeping over it and the steps
/// cycling underneath.
class ScanningPreview extends StatefulWidget {
  const ScanningPreview({super.key, required this.bytes, required this.steps});

  final Uint8List bytes;

  /// What's happening, shown one after another.
  final List<String> steps;

  @override
  State<ScanningPreview> createState() => _ScanningPreviewState();
}

class _ScanningPreviewState extends State<ScanningPreview>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Timer _ticker;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 1400),
      (_) => setState(() => _step = (_step + 1) % widget.steps.length),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Stack(
              children: [
                Image.memory(
                  widget.bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  gaplessPlayback: true,
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.night.withValues(alpha: 0.35),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) => Align(
                      alignment: Alignment(0, _sweep.value * 2 - 1),
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.leafBright,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              widget.steps[_step],
              key: ValueKey(_step),
              style: text.titleMedium,
            ),
          ),
        ),
      ],
    );
  }
}
