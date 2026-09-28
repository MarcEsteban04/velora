import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A cream speech bubble with a speaker tag and a tail pointing down-left
/// toward the speaker.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.speaker, required this.message});

  final String speaker;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return CustomPaint(
      painter: const _BubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              speaker.toUpperCase(),
              style: text.labelMedium?.copyWith(
                color: AppColors.leafShadow,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: text.bodyMedium?.copyWith(
                color: AppColors.textOnLight,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  static const _radius = 18.0;
  static const _tail = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - _tail),
      const Radius.circular(_radius),
    );
    final tail = Path()
      ..moveTo(26, size.height - _tail - 1)
      ..quadraticBezierTo(22, size.height, 12, size.height)
      ..quadraticBezierTo(30, size.height - 2, 44, size.height - _tail - 1)
      ..close();
    final shape = Path()
      ..addRRect(body)
      ..addPath(tail, Offset.zero);

    canvas.drawShadow(shape, Colors.black, 10, false);
    canvas.drawPath(shape, Paint()..color = AppColors.cream);
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}
