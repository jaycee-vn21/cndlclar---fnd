import 'package:flutter/material.dart';
import 'package:cndlclar/utils/constants.dart';

class SparklineWidget extends StatelessWidget {
  final List<double> data;

  const SparklineWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: KSizes.tokenSparklineHeight);
    }

    // Line color based on last two points
    final Color lineColor = data.length < 2
        ? KColors.accentPositive
        : data.last >= data[data.length - 2]
        ? KColors.accentPositive
        : KColors.accentNegative;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KSizes.tokenSparklineVerticalSpacing,
      ),
      child: SizedBox(
        height: KSizes.tokenSparklineHeight,
        child: CustomPaint(
          painter: _SparklinePainter(data: data, lineColor: lineColor),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _SparklinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
