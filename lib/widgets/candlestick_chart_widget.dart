import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/providers/chart_indicator_visibility_provider.dart';
import 'package:cndlclar/utils/constants.dart';

const int _minimumVisibleCandles = 50;
const Color _ema3Color = Color(0xFFFFB020);
const Color _ema7Color = Color(0xFFFF6B35);
const Color _ema9Color = Color(0xFFE879F9);
const Color _ema21Color = Color(0xFF7C8CFF);
const Color _bollOuterColor = Color(0xBB38BDF8);
const Color _bollMiddleColor = Color(0x6638BDF8);
const Color _rsi3Color = Color(0xFFFFD166);
const Color _rsi14Color = Color(0xFF4FC3F7);
const Color _rsi50Color = Color(0xFFA78BFA);
const Color _sarUpColor = Color(0xCC2DD4BF);
const Color _sarDownColor = Color(0xCCFB7185);

List<double?> _calculateRsiValues(List<KlineData> candles, {int period = 14}) {
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
  values[period] = _rsiFromAverageChanges(averageGain, averageLoss);

  for (var i = period + 1; i < candles.length; i++) {
    final change = candles[i].close - candles[i - 1].close;
    final gain = change > 0 ? change : 0.0;
    final loss = change < 0 ? -change : 0.0;
    averageGain = ((averageGain * (period - 1)) + gain) / period;
    averageLoss = ((averageLoss * (period - 1)) + loss) / period;
    values[i] = _rsiFromAverageChanges(averageGain, averageLoss);
  }

  return values;
}

double _rsiFromAverageChanges(double averageGain, double averageLoss) {
  if (averageLoss == 0) return 100;
  final relativeStrength = averageGain / averageLoss;
  return 100 - (100 / (1 + relativeStrength));
}

class CandlestickChartWidget extends StatefulWidget {
  final List<KlineData> candles;
  final String symbol;
  final bool showEma;
  final bool showRsi;
  final bool showSar;
  final bool showBoll;
  final int bollPeriod;
  final double bollDeviations;
  final bool isInteractive;
  final bool allowPanAndZoom;

  const CandlestickChartWidget({
    super.key,
    required this.candles,
    this.symbol = '',
    this.showEma = true,
    this.showRsi = true,
    this.showSar = true,
    this.showBoll = true,
    this.bollPeriod = 7,
    this.bollDeviations = 2,
    this.isInteractive = true,
    this.allowPanAndZoom = true,
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

  double _contentHeight(bool showRsi) =>
      _candlesChartHeight +
      _volumeChartHeight +
      (showRsi ? _rsiChartHeight : 0);

  Offset _panOffset = Offset.zero;
  bool _hasCustomPanOffset = false;

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
    if (!widget.isInteractive && oldWidget.isInteractive) {
      _isLongPressActive = false;
      _activeIndex = null;
      _activeGlobalPos = null;
    }

    if (!widget.allowPanAndZoom && oldWidget.allowPanAndZoom) {
      _lastFocalPoint = null;
      _hasCustomPanOffset = false;
      _panOffset = Offset.zero;
    }

    if (widget.candles != oldWidget.candles) {
      final wasInspecting = _isLongPressActive && _activeGlobalPos != null;
      final previousIndex = _activeIndex;

      _sorted = List.from(widget.candles)
        ..sort((a, b) => a.time.compareTo(b.time));

      if (_sorted.isEmpty) {
        _isLongPressActive = false;
        _activeIndex = null;
        _activeGlobalPos = null;
      } else if (wasInspecting) {
        _activeIndex =
            _getNearestCandle(_activeGlobalPos!) ??
            previousIndex?.clamp(0, _sorted.length - 1).toInt() ??
            0;
      }
    }
  }

  void _clearActive() {
    if (!_isLongPressActive &&
        _activeIndex == null &&
        _activeGlobalPos == null) {
      return;
    }

    setState(() {
      _isLongPressActive = false;
      _activeIndex = null;
      _activeGlobalPos = null;
    });
  }

  void _activateCrosshair(Offset globalPos) {
    final idx = _getNearestCandle(globalPos);
    if (idx == null) {
      _clearActive();
      return;
    }

    setState(() {
      _isLongPressActive = true;
      _activeIndex = idx;
      _activeGlobalPos = globalPos;
    });
  }

  void _updatePointerMove(Offset globalPos) {
    if (!_isLongPressActive) return;
    final idx = _getNearestCandle(globalPos);
    if (idx == null) return;

    setState(() {
      _activeIndex = idx;
      _activeGlobalPos = globalPos;
    });
  }

  int? _getNearestCandle(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || _sorted.isEmpty) return null;
    final local = box.globalToLocal(globalPos);
    final chartScale = context
        .read<ChartIndicatorVisibilityProvider>()
        .chartScale;
    final candleWidth = _candleWidth(box.size.width);
    final panOffset = _effectivePanOffset(
      chartWidth: box.size.width,
      candleWidth: candleWidth,
      scale: chartScale,
    );
    final candleStep = candleWidth * chartScale;
    if (candleStep <= 0) return null;

    final dx = local.dx - panOffset.dx;
    final idx = (dx / candleStep).round().clamp(0, _sorted.length - 1).toInt();
    return idx;
  }

  double _candleWidth(double chartWidth) {
    if (_sorted.isEmpty) return 0;
    return chartWidth / math.max(_sorted.length, _minimumVisibleCandles);
  }

  Offset _effectivePanOffset({
    required double chartWidth,
    required double candleWidth,
    required double scale,
  }) {
    final totalWidth = _sorted.length * candleWidth * scale;
    if (totalWidth <= chartWidth) return Offset.zero;

    final minX = chartWidth - totalWidth;
    if (!_hasCustomPanOffset) return Offset(minX, 0);

    return Offset(_panOffset.dx.clamp(minX, 0.0), 0);
  }

  _RsiSnapshot _rsiSnapshotFor(int? index) {
    if (index == null || index < 0 || index >= _sorted.length) {
      return const _RsiSnapshot();
    }

    return _RsiSnapshot(
      rsi3: _calculateRsiValues(_sorted, period: 3)[index],
      rsi14: _calculateRsiValues(_sorted, period: 14)[index],
      rsi50: _calculateRsiValues(_sorted, period: 50)[index],
    );
  }

  Widget _buildTooltip(int index) {
    final d = _sorted[index];
    final rsi = _rsiSnapshotFor(index);
    final change = d.close - d.open;
    final changePct = d.open == 0 ? 0.0 : (change / d.open) * 100;
    final range = d.high - d.low;
    final rangePct = d.low == 0 ? 0.0 : (range / d.low) * 100;
    final color = change >= 0 ? KColors.accentPositive : KColors.accentNegative;
    final netVolumeColor = d.netVolumeUsdt > 0
        ? KColors.accentPositive
        : d.netVolumeUsdt < 0
        ? KColors.accentNegative
        : Colors.white70;
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
            Row(
              children: [
                if (widget.symbol.isNotEmpty)
                  Expanded(
                    child: Text(
                      widget.symbol,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (d.isClosed ? Colors.white24 : KColors.accentPositive)
                            .withValues(alpha: d.isClosed ? 0.24 : 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    d.isClosed ? 'Closed' : 'Live',
                    style: TextStyle(
                      color: d.isClosed
                          ? Colors.white70
                          : KColors.accentPositive,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$date $time',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 6),
            _tooltipLine('Open', _formatPrice(d.open)),
            _tooltipLine('High', _formatPrice(d.high)),
            _tooltipLine('Low', _formatPrice(d.low)),
            _tooltipLine('Close', _formatPrice(d.close)),
            _tooltipLine(
              'RSI(3)',
              _formatIndicatorValue(rsi.rsi3),
              valueColor: _rsi3Color,
            ),
            _tooltipLine(
              'RSI(14)',
              _formatIndicatorValue(rsi.rsi14),
              valueColor: _rsi14Color,
            ),
            _tooltipLine(
              'RSI(50)',
              _formatIndicatorValue(rsi.rsi50),
              valueColor: _rsi50Color,
            ),
            _tooltipLine(
              'Change',
              '${_formatSignedPrice(change)} (${_formatSignedPercent(changePct)})',
              valueColor: color,
              strong: true,
            ),
            _tooltipLine(
              'Range',
              '${_formatPrice(range)} (${_formatPercent(rangePct)})',
            ),
            _tooltipLine('Vol USDT', _formatUsdt(d.volumeUsdt)),
            _tooltipLine(
              'Net Vol',
              _formatSignedUsdt(d.netVolumeUsdt),
              valueColor: netVolumeColor,
              strong: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tooltipLine(
    String label,
    String value, {
    Color? valueColor,
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? Colors.white70,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) {
    final abs = value.abs();
    if (abs >= 1000) return value.toStringAsFixed(2);
    if (abs >= 1) return value.toStringAsFixed(4);
    if (abs >= 0.01) return value.toStringAsFixed(6);
    return value.toStringAsFixed(8);
  }

  String _formatSignedPrice(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatPercent(double value) => '${value.toStringAsFixed(2)}%';

  String _formatIndicatorValue(double? value) {
    if (value == null) return 'n/a';
    return value.toStringAsFixed(1);
  }

  String _formatSignedPercent(double value) {
    final prefix = value >= 0 ? '+' : '';
    return '$prefix${_formatPercent(value)}';
  }

  String _formatVolume(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
    if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (abs >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
    return value.toStringAsFixed(2);
  }

  String _formatUsdt(double value) {
    final prefix = value < 0 ? '-' : '';
    return '$prefix\$${_formatVolume(value.abs())}';
  }

  String _formatSignedUsdt(double value) {
    final prefix = value >= 0 ? '+' : '-';
    return '$prefix\$${_formatVolume(value.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartIndicatorVisibilityProvider>(
      builder: (context, visibility, child) {
        final showEma3 = widget.showEma && visibility.showEma3;
        final showEma7 = widget.showEma && visibility.showEma7;
        final showEma9 = widget.showEma && visibility.showEma9;
        final showEma21 = widget.showEma && visibility.showEma21;
        final showBoll = widget.showBoll && visibility.showBoll;
        final showSar = widget.showSar && visibility.showSar;
        final showRsi = widget.showRsi && visibility.showRsi;
        final chartScale = visibility.chartScale;
        final rsiSnapshot = _rsiSnapshotFor(
          _activeIndex ?? (_sorted.isEmpty ? null : _sorted.length - 1),
        );

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final chartWidth = constraints.maxWidth;
            final candleWidth = _candleWidth(chartWidth);

            return Listener(
              onPointerMove: widget.isInteractive
                  ? (event) => _updatePointerMove(event.position)
                  : null,
              onPointerUp: widget.isInteractive ? (_) => _clearActive() : null,
              onPointerCancel: widget.isInteractive
                  ? (_) => _clearActive()
                  : null,
              child: Stack(
                children: [
                  GestureDetector(
                    onScaleStart: widget.allowPanAndZoom
                        ? (details) {
                            _lastFocalPoint = details.focalPoint;
                            _baseScale = chartScale;
                          }
                        : null,
                    onScaleUpdate: widget.allowPanAndZoom
                        ? (details) {
                            final nextScale = (_baseScale * details.scale)
                                .clamp(
                                  ChartIndicatorVisibilityProvider
                                      .minChartScale,
                                  ChartIndicatorVisibilityProvider
                                      .maxChartScale,
                                );
                            visibility.setChartScale(nextScale.toDouble());

                            setState(() {
                              final delta =
                                  details.focalPoint -
                                  (_lastFocalPoint ?? details.focalPoint);
                              _hasCustomPanOffset = true;
                              _panOffset += delta;
                              final totalWidth =
                                  _sorted.length * candleWidth * nextScale;
                              double minX = chartWidth - totalWidth;
                              double maxX = 0;

                              // prevent clamp crash by fixing inverted values
                              if (minX > maxX) {
                                final tmp = minX;
                                minX = maxX;
                                maxX = tmp;
                              }

                              _panOffset = Offset(
                                _panOffset.dx.clamp(minX, maxX),
                                0,
                              );

                              _lastFocalPoint = details.focalPoint;
                            });
                          }
                        : null,
                    onLongPressStart: widget.isInteractive
                        ? (details) =>
                              _activateCrosshair(details.globalPosition)
                        : null,
                    onLongPressEnd: widget.isInteractive
                        ? (details) => _clearActive()
                        : null,
                    onLongPressCancel: widget.isInteractive
                        ? _clearActive
                        : null,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _CandlestickPainter(
                          candles: _sorted,
                          scale: chartScale,
                          panOffset: _effectivePanOffset(
                            chartWidth: chartWidth,
                            candleWidth: candleWidth,
                            scale: chartScale,
                          ),
                          candleHeight: _candlesChartHeight,
                          volumeHeight: _volumeChartHeight,
                          rsiHeight: _rsiChartHeight,
                          activeIndex: _activeIndex,
                          showEma3: showEma3,
                          showEma7: showEma7,
                          showEma9: showEma9,
                          showEma21: showEma21,
                          showRsi: showRsi,
                          showSar: showSar,
                          showBoll: showBoll,
                          bollPeriod: widget.bollPeriod,
                          bollDeviations: widget.bollDeviations,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 4,
                    right: 6,
                    child: _IndicatorLegend(
                      items: [
                        _IndicatorLegendItem(
                          label: 'EMA3',
                          color: _ema3Color,
                          isActive: showEma3,
                          onTap: widget.isInteractive
                              ? visibility.toggleEma3
                              : null,
                        ),
                        _IndicatorLegendItem(
                          label: 'EMA7',
                          color: _ema7Color,
                          isActive: showEma7,
                          onTap: widget.isInteractive
                              ? visibility.toggleEma7
                              : null,
                        ),
                        _IndicatorLegendItem(
                          label: 'EMA9',
                          color: _ema9Color,
                          isActive: showEma9,
                          onTap: widget.isInteractive
                              ? visibility.toggleEma9
                              : null,
                        ),
                        _IndicatorLegendItem(
                          label: 'EMA21',
                          color: _ema21Color,
                          isActive: showEma21,
                          onTap: widget.isInteractive
                              ? visibility.toggleEma21
                              : null,
                        ),
                        _IndicatorLegendItem(
                          label: 'BOLL',
                          color: _bollOuterColor,
                          isActive: showBoll,
                          onTap: widget.isInteractive
                              ? visibility.toggleBoll
                              : null,
                        ),
                        _IndicatorLegendItem(
                          label: 'SAR',
                          color: KColors.textSecondary,
                          isActive: showSar,
                          onTap: widget.isInteractive
                              ? visibility.toggleSar
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (widget.showRsi)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 4,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _RsiLegend(
                          isActive: showRsi,
                          snapshot: rsiSnapshot,
                          onTap: widget.isInteractive
                              ? visibility.toggleRsi
                              : null,
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
                        final tooltip = _buildTooltip(_activeIndex!);
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
                          _contentHeight(showRsi) - 80,
                        );
                        return Positioned(left: left, top: top, child: tooltip);
                      },
                    ),
                ],
              ),
            );
          },
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
  final bool showEma3;
  final bool showEma7;
  final bool showEma9;
  final bool showEma21;
  final bool showRsi;
  final bool showSar;
  final bool showBoll;
  final int bollPeriod;
  final double bollDeviations;

  _CandlestickPainter({
    required this.candles,
    required this.scale,
    required this.panOffset,
    required this.candleHeight,
    required this.volumeHeight,
    required this.rsiHeight,
    required this.activeIndex,
    required this.showEma3,
    required this.showEma7,
    required this.showEma9,
    required this.showEma21,
    required this.showRsi,
    required this.showSar,
    required this.showBoll,
    required this.bollPeriod,
    required this.bollDeviations,
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
    final ema3Paint = Paint()
      ..color = _ema3Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    final ema7Paint = Paint()
      ..color = _ema7Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final ema9Paint = Paint()
      ..color = _ema9Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final ema21Paint = Paint()
      ..color = _ema21Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final bollUpperPaint = Paint()
      ..color = _bollOuterColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;
    final bollMiddlePaint = Paint()
      ..color = _bollMiddleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final bollLowerPaint = Paint()
      ..color = _bollOuterColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95;
    final rsiPaint = Paint()
      ..color = _rsi14Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rsi3Paint = Paint()
      ..color = _rsi3Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final rsi50Paint = Paint()
      ..color = _rsi50Color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final sarUpPaint = Paint()
      ..color = _sarUpColor
      ..style = PaintingStyle.fill;
    final sarDownPaint = Paint()
      ..color = _sarDownColor
      ..style = PaintingStyle.fill;

    final candleWidth =
        size.width / math.max(candles.length, _minimumVisibleCandles) * scale;
    final contentHeight =
        candleHeight + volumeHeight + (showRsi ? rsiHeight : 0);
    final volumeTop = candleHeight;
    final rsiTop = candleHeight + volumeHeight;

    double low = candles.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    double high = candles.map((e) => e.high).reduce((a, b) => a > b ? a : b);

    final ema3Values = showEma3 ? _emaValues(3) : const <double?>[];
    final ema7Values = showEma7 ? _emaValues(7) : const <double?>[];
    final ema9Values = showEma9 ? _emaValues(9) : const <double?>[];
    final ema21Values = showEma21 ? _emaValues(21) : const <double?>[];
    final sarValues = showSar ? _sarValues() : const <_SarPoint?>[];
    final bollValues = showBoll
        ? _bollValues(period: bollPeriod, deviations: bollDeviations)
        : _BollSeries.empty(candles.length);
    if (showEma3 || showEma7 || showEma9 || showEma21) {
      for (final value in [
        ...ema3Values,
        ...ema7Values,
        ...ema9Values,
        ...ema21Values,
      ]) {
        if (value == null) continue;
        if (value < low) low = value;
        if (value > high) high = value;
      }
    }
    if (showSar) {
      for (final point in sarValues) {
        if (point == null) continue;
        if (point.value < low) low = point.value;
        if (point.value > high) high = point.value;
      }
    }
    if (showBoll) {
      for (final value in [...bollValues.upper, ...bollValues.lower]) {
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

    if (showEma3) {
      _drawLineSeries(canvas, ema3Values, low, range, candleWidth, ema3Paint);
    }
    if (showEma7) {
      _drawLineSeries(canvas, ema7Values, low, range, candleWidth, ema7Paint);
    }
    if (showEma9) {
      _drawLineSeries(canvas, ema9Values, low, range, candleWidth, ema9Paint);
    }
    if (showEma21) {
      _drawLineSeries(canvas, ema21Values, low, range, candleWidth, ema21Paint);
    }

    if (showBoll) {
      _drawLineSeries(
        canvas,
        bollValues.upper,
        low,
        range,
        candleWidth,
        bollUpperPaint,
      );
      _drawLineSeries(
        canvas,
        bollValues.middle,
        low,
        range,
        candleWidth,
        bollMiddlePaint,
      );
      _drawLineSeries(
        canvas,
        bollValues.lower,
        low,
        range,
        candleWidth,
        bollLowerPaint,
      );
    }

    if (showSar) {
      _drawSar(
        canvas,
        sarValues,
        low,
        range,
        candleWidth,
        sarUpPaint,
        sarDownPaint,
      );
    }

    // volume bars
    double maxVol = candles
        .map((e) => e.volumeUsdt)
        .reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final left = i * candleWidth + panOffset.dx;
      final right = left + candleWidth * 0.8;
      final volHeight = maxVol <= 0
          ? 0.0
          : (c.volumeUsdt / maxVol) * volumeHeight;
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
      _drawRsi(
        canvas,
        _rsiValues(period: 3),
        candleWidth,
        rsiTop,
        rsiHeight,
        rsi3Paint,
      );
      _drawRsi(
        canvas,
        _rsiValues(period: 14),
        candleWidth,
        rsiTop,
        rsiHeight,
        rsiPaint,
      );
      _drawRsi(
        canvas,
        _rsiValues(period: 50),
        candleWidth,
        rsiTop,
        rsiHeight,
        rsi50Paint,
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
    return _calculateRsiValues(candles, period: period);
  }

  List<_SarPoint?> _sarValues({double step = 0.02, double maxStep = 0.2}) {
    final values = List<_SarPoint?>.filled(candles.length, null);
    if (candles.length < 2) return values;

    var isUpTrend = candles[1].close >= candles[0].close;
    var sar = isUpTrend ? candles[0].low : candles[0].high;
    var extremePoint = isUpTrend ? candles[0].high : candles[0].low;
    var accelerationFactor = step;

    for (var i = 1; i < candles.length; i++) {
      final candle = candles[i];
      final previous = candles[i - 1];
      final twoBack = i > 1 ? candles[i - 2] : previous;

      sar = sar + accelerationFactor * (extremePoint - sar);

      if (isUpTrend) {
        sar = math.min(sar, math.min(previous.low, twoBack.low));

        if (candle.low < sar) {
          isUpTrend = false;
          sar = extremePoint;
          extremePoint = candle.low;
          accelerationFactor = step;
        } else if (candle.high > extremePoint) {
          extremePoint = candle.high;
          accelerationFactor = math.min(accelerationFactor + step, maxStep);
        }
      } else {
        sar = math.max(sar, math.max(previous.high, twoBack.high));

        if (candle.high > sar) {
          isUpTrend = true;
          sar = extremePoint;
          extremePoint = candle.high;
          accelerationFactor = step;
        } else if (candle.low < extremePoint) {
          extremePoint = candle.low;
          accelerationFactor = math.min(accelerationFactor + step, maxStep);
        }
      }

      values[i] = _SarPoint(value: sar, isUpTrend: isUpTrend);
    }

    return values;
  }

  _BollSeries _bollValues({required int period, required double deviations}) {
    final upper = List<double?>.filled(candles.length, null);
    final middle = List<double?>.filled(candles.length, null);
    final lower = List<double?>.filled(candles.length, null);
    if (period <= 0 || candles.length < period) {
      return _BollSeries(upper: upper, middle: middle, lower: lower);
    }

    for (var i = period - 1; i < candles.length; i++) {
      final closes = candles
          .sublist(i - period + 1, i + 1)
          .map((candle) => candle.close)
          .toList(growable: false);
      final average =
          closes.reduce((sum, close) => sum + close) / closes.length;
      final variance =
          closes
              .map((close) => math.pow(close - average, 2))
              .reduce((sum, value) => sum + value)
              .toDouble() /
          closes.length;
      final standardDeviation = math.sqrt(variance);

      middle[i] = average;
      upper[i] = average + deviations * standardDeviation;
      lower[i] = average - deviations * standardDeviation;
    }

    return _BollSeries(upper: upper, middle: middle, lower: lower);
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

  void _drawSar(
    Canvas canvas,
    List<_SarPoint?> values,
    double low,
    double range,
    double candleWidth,
    Paint upPaint,
    Paint downPaint,
  ) {
    if (range == 0) return;

    final radius = math.max(1.4, math.min(3.0, candleWidth * 0.18));
    for (var i = 0; i < values.length; i++) {
      final point = values[i];
      if (point == null) continue;

      final x = i * candleWidth + candleWidth / 2 + panOffset.dx;
      final y = candleHeight - ((point.value - low) / range * candleHeight);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        point.isUpTrend ? upPaint : downPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter old) =>
      old.candles != candles ||
      old.scale != scale ||
      old.panOffset != panOffset ||
      old.activeIndex != activeIndex ||
      old.showEma3 != showEma3 ||
      old.showEma7 != showEma7 ||
      old.showEma9 != showEma9 ||
      old.showEma21 != showEma21 ||
      old.showRsi != showRsi ||
      old.showSar != showSar ||
      old.showBoll != showBoll ||
      old.bollPeriod != bollPeriod ||
      old.bollDeviations != bollDeviations;
}

class _IndicatorLegend extends StatelessWidget {
  const _IndicatorLegend({required this.items});

  final List<_IndicatorLegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items
          .map(
            (item) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: item.onTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: item.isActive ? 0.42 : 0.2,
                  ),
                  border: Border.all(
                    color: item.color.withValues(
                      alpha: item.isActive ? 0.8 : 0.18,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 2,
                        decoration: BoxDecoration(
                          color: item.color.withValues(
                            alpha: item.isActive ? 1 : 0.28,
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: item.isActive
                              ? KColors.textPrimary
                              : KColors.textSecondary.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _IndicatorLegendItem {
  const _IndicatorLegendItem({
    required this.label,
    required this.color,
    required this.isActive,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;
}

class _RsiLegend extends StatelessWidget {
  const _RsiLegend({
    required this.isActive,
    required this.snapshot,
    this.onTap,
  });

  final bool isActive;
  final _RsiSnapshot snapshot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: isActive ? 0.42 : 0.2),
          border: Border.all(
            color: _rsi14Color.withValues(alpha: isActive ? 0.55 : 0.18),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!isActive)
                Text(
                  'RSI off',
                  style: TextStyle(
                    color: KColors.textSecondary.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (isActive) ...[
                _RsiLegendValue(
                  label: '3',
                  value: snapshot.rsi3,
                  color: _rsi3Color,
                ),
                _RsiLegendValue(
                  label: '14',
                  value: snapshot.rsi14,
                  color: _rsi14Color,
                ),
                _RsiLegendValue(
                  label: '50',
                  value: snapshot.rsi50,
                  color: _rsi50Color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RsiLegendValue extends StatelessWidget {
  const _RsiLegendValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'RSI($label) - ${value == null ? 'n/a' : value!.toStringAsFixed(1)}',
          style: TextStyle(
            color: KColors.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RsiSnapshot {
  const _RsiSnapshot({this.rsi3, this.rsi14, this.rsi50});

  final double? rsi3;
  final double? rsi14;
  final double? rsi50;
}

class _BollSeries {
  const _BollSeries({
    required this.upper,
    required this.middle,
    required this.lower,
  });

  factory _BollSeries.empty(int length) {
    return _BollSeries(
      upper: List<double?>.filled(length, null),
      middle: List<double?>.filled(length, null),
      lower: List<double?>.filled(length, null),
    );
  }

  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;
}

class _SarPoint {
  const _SarPoint({required this.value, required this.isUpTrend});

  final double value;
  final bool isUpTrend;
}
