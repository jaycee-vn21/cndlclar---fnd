import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/utils/constants.dart';

const int _minimumVisibleCandles = 50;

class CandlestickChartWidget extends StatefulWidget {
  final List<KlineData> candles;
  final String symbol;
  final bool showEma;
  final bool showRsi;

  const CandlestickChartWidget({
    super.key,
    required this.candles,
    this.symbol = '',
    this.showEma = true,
    this.showRsi = true,
  });

  @override
  State<CandlestickChartWidget> createState() => _CandlestickChartWidgetState();
}

class _CandlestickChartWidgetState extends State<CandlestickChartWidget> {
  late List<KlineData> _sorted;

  final double _candlesChartHeight = 170;
  final double _volumeChartHeight = 40;
  final double _rsiChartHeight = 40;
  final double _tooltipMaxWidth = 220;

  double get _contentHeight =>
      _candlesChartHeight +
      _volumeChartHeight +
      (widget.showRsi ? _rsiChartHeight : 0);

  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  Timer? _longPressTimer;
  bool _isLongPressActive = false;
  int? _activeIndex;
  Offset? _activeGlobalPos;

  Offset? _lastFocalPoint;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _sorted = List.from(widget.candles)
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  void didUpdateWidget(covariant CandlestickChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.candles != oldWidget.candles) {
      _sorted = List.from(widget.candles)
        ..sort((a, b) => a.time.compareTo(b.time));
      _clearActive();
    }
  }

  void _clearActive() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    setState(() {
      _isLongPressActive = false;
      _activeIndex = null;
      _activeGlobalPos = null;
    });
  }

  void _startLongPressTimer(Offset globalPos) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 1000), () {
      final idx = _getNearestCandle(globalPos);
      if (idx != null) {
        setState(() {
          _isLongPressActive = true;
          _activeIndex = idx;
          _activeGlobalPos = globalPos;
        });
      } else {
        _clearActive();
      }
    });
  }

  void _updatePointerMove(Offset globalPos) {
    if (!_isLongPressActive) return;
    final idx = _getNearestCandle(globalPos);
    setState(() {
      _activeIndex = idx;
      _activeGlobalPos = globalPos;
    });
  }

  int? _getNearestCandle(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || _sorted.isEmpty) return null;
    final local = box.globalToLocal(globalPos);
    final candleWidth = _candleWidth(box.size.width);
    final totalWidth = _sorted.length * candleWidth * _scale;
    final dxClamped = (local.dx - _panOffset.dx).clamp(0.0, totalWidth);
    final idx = (dxClamped / (candleWidth * _scale)).round();
    if (idx < 0 || idx >= _sorted.length) return null;
    return idx;
  }

  double _candleWidth(double chartWidth) {
    if (_sorted.isEmpty) return 0;
    return chartWidth / math.max(_sorted.length, _minimumVisibleCandles);
  }

  Widget _buildTooltip(KlineData d) {
    final change = d.close - d.open;
    final changePct = d.open == 0 ? 0.0 : (change / d.open) * 100;
    final color = change >= 0 ? KColors.accentPositive : KColors.accentNegative;
    final t = d.time;
    final date =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Container(
      constraints: BoxConstraints(maxWidth: _tooltipMaxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.symbol.isNotEmpty)
              Text(
                widget.symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              '$date $time',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text('O: ${d.open.toStringAsFixed(6)}'),
            Text('H: ${d.high.toStringAsFixed(6)}'),
            Text('L: ${d.low.toStringAsFixed(6)}'),
            Row(
              children: [
                Text('C: ${d.close.toStringAsFixed(6)}'),
                const SizedBox(width: 8),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(6)} (${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Vol: ${d.volume.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final chartWidth = constraints.maxWidth;
        final candleWidth = _candleWidth(chartWidth);

        return GestureDetector(
          onScaleStart: (details) {
            _lastFocalPoint = details.focalPoint;
            _baseScale = _scale;
          },
          onScaleUpdate: (details) {
            setState(() {
              _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
              final delta =
                  details.focalPoint - (_lastFocalPoint ?? details.focalPoint);
              _panOffset += delta;
              final totalWidth = _sorted.length * candleWidth * _scale;
              double minX = chartWidth - totalWidth;
              double maxX = 0;

              // prevent clamp crash by fixing inverted values
              if (minX > maxX) {
                final tmp = minX;
                minX = maxX;
                maxX = tmp;
              }

              _panOffset = Offset(_panOffset.dx.clamp(minX, maxX), 0);

              _lastFocalPoint = details.focalPoint;
            });
          },
          onLongPressStart: (details) =>
              _startLongPressTimer(details.globalPosition),
          onLongPressMoveUpdate: (details) =>
              _updatePointerMove(details.globalPosition),
          onLongPressEnd: (details) => _clearActive(),
          child: Stack(
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _CandlestickPainter(
                    candles: _sorted,
                    scale: _scale,
                    panOffset: _panOffset,
                    candleHeight: _candlesChartHeight,
                    volumeHeight: _volumeChartHeight,
                    rsiHeight: _rsiChartHeight,
                    activeIndex: _activeIndex,
                    showEma: widget.showEma,
                    showRsi: widget.showRsi,
                  ),
                ),
              ),
              // Tooltip
              if (_isLongPressActive &&
                  _activeIndex != null &&
                  _activeGlobalPos != null)
                Builder(
                  builder: (ctx) {
                    final local = (context.findRenderObject() as RenderBox?)
                        ?.globalToLocal(_activeGlobalPos!);
                    if (local == null) return const SizedBox.shrink();
                    final tooltip = _buildTooltip(_sorted[_activeIndex!]);
                    double left = (local.dx + 12).clamp(
                      8.0,
                      chartWidth - _tooltipMaxWidth - 8.0,
                    );
                    if (local.dx > chartWidth * 0.6) {
                      left = (local.dx - _tooltipMaxWidth - 12).clamp(
                        8.0,
                        chartWidth - _tooltipMaxWidth - 8.0,
                      );
                    }
                    double top = (local.dy - 140).clamp(
                      8.0,
                      _contentHeight - 80,
                    );
                    return Positioned(left: left, top: top, child: tooltip);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<KlineData> candles;
  final double scale;
  final Offset panOffset;
  final double candleHeight;
  final double volumeHeight;
  final double rsiHeight;
  final int? activeIndex;
  final bool showEma;
  final bool showRsi;

  _CandlestickPainter({
    required this.candles,
    required this.scale,
    required this.panOffset,
    required this.candleHeight,
    required this.volumeHeight,
    required this.rsiHeight,
    required this.activeIndex,
    required this.showEma,
    required this.showRsi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final candlePaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = Colors.white;
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    final ema9Paint = Paint()
      ..color = const Color(0xFFF6C85F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final ema21Paint = Paint()
      ..color = const Color(0xFF8D7CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rsiPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final candleWidth =
        size.width / math.max(candles.length, _minimumVisibleCandles) * scale;
    final contentHeight =
        candleHeight + volumeHeight + (showRsi ? rsiHeight : 0);
    final volumeTop = candleHeight;
    final rsiTop = candleHeight + volumeHeight;

    double low = candles.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    double high = candles.map((e) => e.high).reduce((a, b) => a > b ? a : b);

    final ema9Values = showEma ? _emaValues(9) : const <double?>[];
    final ema21Values = showEma ? _emaValues(21) : const <double?>[];
    if (showEma) {
      for (final value in [...ema9Values, ...ema21Values]) {
        if (value == null) continue;
        if (value < low) low = value;
        if (value > high) high = value;
      }
    }

    final rawRange = high - low;
    final pricePadding = rawRange == 0
        ? math.max(high.abs() * 0.01, 1e-12)
        : rawRange * 0.08;
    low -= pricePadding;
    high += pricePadding;
    final range = high - low;

    for (var i = 1; i < 4; i++) {
      final y = candleHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
      Offset(0, volumeTop),
      Offset(size.width, volumeTop),
      gridPaint,
    );

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final left = i * candleWidth + panOffset.dx;
      final right = left + candleWidth * 0.8;
      final top = candleHeight - ((c.high - low) / range * candleHeight);
      final bottom = candleHeight - ((c.low - low) / range * candleHeight);
      final openY = candleHeight - ((c.open - low) / range * candleHeight);
      final closeY = candleHeight - ((c.close - low) / range * candleHeight);

      candlePaint.color = c.close >= c.open
          ? KColors.accentPositive
          : KColors.accentNegative;
      // draw candle body
      final bodyTop = openY < closeY ? openY : closeY;
      final bodyBottom = openY > closeY ? openY : closeY;
      canvas.drawRect(
        Rect.fromLTRB(left, bodyTop, right, bodyBottom),
        candlePaint,
      );
      // draw wicks
      canvas.drawLine(
        Offset(left + (right - left) / 2, top),
        Offset(left + (right - left) / 2, bodyTop),
        candlePaint,
      );
      canvas.drawLine(
        Offset(left + (right - left) / 2, bodyBottom),
        Offset(left + (right - left) / 2, bottom),
        candlePaint,
      );
    }

    if (showEma) {
      _drawLineSeries(canvas, ema9Values, low, range, candleWidth, ema9Paint);
      _drawLineSeries(canvas, ema21Values, low, range, candleWidth, ema21Paint);
      _drawLabel(canvas, 'EMA9', const Offset(8, 6), ema9Paint.color);
      _drawLabel(canvas, 'EMA21', const Offset(58, 6), ema21Paint.color);
    }

    // volume bars
    double maxVol = candles
        .map((e) => e.volume)
        .reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final left = i * candleWidth + panOffset.dx;
      final right = left + candleWidth * 0.8;
      final volHeight = maxVol <= 0 ? 0.0 : (c.volume / maxVol) * volumeHeight;
      candlePaint.color = c.close >= c.open
          ? KColors.accentPositive
          : KColors.accentNegative;
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          volumeTop + volumeHeight - volHeight,
          right,
          volumeTop + volumeHeight,
        ),
        candlePaint,
      );
    }

    if (showRsi) {
      canvas.drawLine(Offset(0, rsiTop), Offset(size.width, rsiTop), gridPaint);
      final rsi70 = rsiTop + rsiHeight * 0.3;
      final rsi30 = rsiTop + rsiHeight * 0.7;
      canvas.drawLine(Offset(0, rsi70), Offset(size.width, rsi70), gridPaint);
      canvas.drawLine(Offset(0, rsi30), Offset(size.width, rsi30), gridPaint);
      _drawRsi(canvas, _rsiValues(), candleWidth, rsiTop, rsiHeight, rsiPaint);
      _drawLabel(canvas, 'RSI14', Offset(8, rsiTop + 6), rsiPaint.color);
    }

    // Crosshair
    if (activeIndex != null) {
      final c = candles[activeIndex!];
      final centerX =
          activeIndex! * candleWidth + candleWidth / 2 + panOffset.dx;
      final y = candleHeight - ((c.close - low) / range * candleHeight);
      // vertical
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, contentHeight),
        linePaint,
      );
      // horizontal
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      // dot
      canvas.drawCircle(Offset(centerX, y), 3, dotPaint);
    }
  }

  List<double?> _emaValues(int period) {
    final values = List<double?>.filled(candles.length, null);
    if (candles.isEmpty) return values;

    final multiplier = 2 / (period + 1);
    var ema = candles.first.close;
    for (var i = 0; i < candles.length; i++) {
      final close = candles[i].close;
      ema = i == 0 ? close : (close - ema) * multiplier + ema;
      if (i >= period - 1) {
        values[i] = ema;
      }
    }

    return values;
  }

  List<double?> _rsiValues({int period = 14}) {
    final values = List<double?>.filled(candles.length, null);
    if (candles.length <= period) return values;

    var averageGain = 0.0;
    var averageLoss = 0.0;

    for (var i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        averageGain += change;
      } else {
        averageLoss -= change;
      }
    }

    averageGain /= period;
    averageLoss /= period;
    values[period] = _rsiFromAverages(averageGain, averageLoss);

    for (var i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? -change : 0.0;
      averageGain = ((averageGain * (period - 1)) + gain) / period;
      averageLoss = ((averageLoss * (period - 1)) + loss) / period;
      values[i] = _rsiFromAverages(averageGain, averageLoss);
    }

    return values;
  }

  double _rsiFromAverages(double averageGain, double averageLoss) {
    if (averageLoss == 0) return 100;
    final relativeStrength = averageGain / averageLoss;
    return 100 - (100 / (1 + relativeStrength));
  }

  void _drawLineSeries(
    Canvas canvas,
    List<double?> values,
    double low,
    double range,
    double candleWidth,
    Paint paint,
  ) {
    final path = Path();
    var hasStarted = false;

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;

      final x = i * candleWidth + candleWidth / 2 + panOffset.dx;
      final y = candleHeight - ((value - low) / range * candleHeight);
      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (hasStarted) {
      canvas.drawPath(path, paint);
    }
  }

  void _drawRsi(
    Canvas canvas,
    List<double?> values,
    double candleWidth,
    double top,
    double height,
    Paint paint,
  ) {
    final path = Path();
    var hasStarted = false;

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;

      final x = i * candleWidth + candleWidth / 2 + panOffset.dx;
      final y = top + height - (value.clamp(0.0, 100.0) / 100 * height);
      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (hasStarted) {
      canvas.drawPath(path, paint);
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) =>
      old.candles != candles ||
      old.scale != scale ||
      old.panOffset != panOffset ||
      old.activeIndex != activeIndex ||
      old.showEma != showEma ||
      old.showRsi != showRsi;
}
