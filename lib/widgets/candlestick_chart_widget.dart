import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/utils/constants.dart';

class CandlestickChartWidget extends StatefulWidget {
  final List<KlineData> candles;
  final String symbol;

  const CandlestickChartWidget({
    super.key,
    required this.candles,
    this.symbol = '',
  });

  @override
  State<CandlestickChartWidget> createState() => _CandlestickChartWidgetState();
}

class _CandlestickChartWidgetState extends State<CandlestickChartWidget> {
  late List<KlineData> _sorted;

  final double _candlesChartHeight = 200;
  final double _volumeChartHeight = 50;
  final double _tooltipMaxWidth = 220;

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
    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
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
    return chartWidth / _sorted.length;
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
                    activeIndex: _activeIndex,
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
                      _candlesChartHeight + _volumeChartHeight - 80,
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
  final int? activeIndex;

  _CandlestickPainter({
    required this.candles,
    required this.scale,
    required this.panOffset,
    required this.candleHeight,
    required this.volumeHeight,
    required this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final candlePaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = Colors.white;

    final candleWidth = size.width / candles.length * scale;

    double low = candles.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    double high = candles.map((e) => e.high).reduce((a, b) => a > b ? a : b);
    double range = (high - low) == 0 ? 1 : (high - low);

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
      // optional: EMA lines could be drawn here
    }

    // volume bars
    double maxVol = candles
        .map((e) => e.volume)
        .reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final left = i * candleWidth + panOffset.dx;
      final right = left + candleWidth * 0.8;
      final volHeight = (c.volume / maxVol) * volumeHeight;
      candlePaint.color = c.close >= c.open
          ? KColors.accentPositive
          : KColors.accentNegative;
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          candleHeight + volumeHeight - volHeight,
          right,
          candleHeight + volumeHeight,
        ),
        candlePaint,
      );
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
        Offset(centerX, candleHeight + volumeHeight),
        linePaint,
      );
      // horizontal
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      // dot
      canvas.drawCircle(Offset(centerX, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) =>
      old.candles != candles ||
      old.scale != scale ||
      old.panOffset != panOffset ||
      old.activeIndex != activeIndex;
}
