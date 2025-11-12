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
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.0001
        ? 0.0001
        : (maxValue - minValue);

    final points = List.generate(
      data.length,
      (i) => Offset(
        (i / (data.length - 1)) * size.width,
        size.height - ((data[i] - minValue) / range) * size.height,
      ),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 2; i++) {
      final xc = (points[i].dx + points[i + 1].dx) / 2;
      final yc = (points[i].dy + points[i + 1].dy) / 2;
      path.quadraticBezierTo(points[i].dx, points[i].dy, xc, yc);
    }
    path.lineTo(points.last.dx, points.last.dy);

    // Gradient fill
    final gradient = KGradients.sparkline(lineColor);

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}
