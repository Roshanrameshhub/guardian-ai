import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 180,
    this.strokeWidth = 10,
    this.child,
    this.gradient = AppColors.primaryGradient,
    this.trackColor,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;
  final Gradient gradient;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          gradient: gradient,
          trackColor: trackColor ?? AppColors.surfaceContainerHighest,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Gradient gradient;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.strokeWidth != strokeWidth;
}

class SafetyScoreRing extends StatelessWidget {
  const SafetyScoreRing({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.size = 200,
    this.label = 'SAFETY SCORE',
  });

  final int score;
  final int maxScore;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ProgressRing(
      progress: score / maxScore,
      size: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: AppTextStyles.displayLgMobile.copyWith(color: AppColors.white),
          ),
          Text(
            label,
            style: AppTextStyles.labelUpper.copyWith(color: AppColors.primaryPulse),
          ),
        ],
      ),
    );
  }
}
