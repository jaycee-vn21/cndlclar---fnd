import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/models/token.dart';
import 'package:cndlclar/providers/chart_indicator_visibility_provider.dart';
import 'package:cndlclar/providers/interval_provider.dart';
import 'package:cndlclar/widgets/candlestick_chart_widget.dart';
import 'package:cndlclar/widgets/token_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cndlclar/main.dart';

void main() {
  testWidgets('CndlClar opens and navigates without backend connection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CndlClarApp(connectToBackend: false));

    expect(find.text('CndlClar'), findsOneWidget);
    expect(find.bySemanticsLabel('Market'), findsOneWidget);
    expect(find.bySemanticsLabel('Charts'), findsOneWidget);
    expect(find.bySemanticsLabel('Demo'), findsOneWidget);
    expect(find.bySemanticsLabel('Alerts'), findsOneWidget);

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.bySemanticsLabel('Alerts'));
    await tester.pump();

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);
  });

  testWidgets('token card replaces a cached candle with live websocket OHLCV', (
    WidgetTester tester,
  ) async {
    final interval = IntervalProvider();
    final visibility = ChartIndicatorVisibilityProvider()..setChartScale(1);
    final token = Token.fromMap({
      'tokenName': 'LIVEUSDT',
      'openPrice5m': 100.0,
      'highPrice5m': 108.0,
      'lowPrice5m': 99.0,
      'closePrice5m': 105.0,
      'volumeInMoney5m': 15000.0,
      'netVolumeInMoney5m': 2500.0,
      'priceChangePercent5m': 5.0,
      'tickerPriceChange1h': 3.0,
      'intervalStartTime5m': '2026-06-01T10:00:00.000Z',
      'isIntervalClosed5m': false,
    });

    void noop() {}

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<IntervalProvider>.value(value: interval),
          ChangeNotifierProvider<ChartIndicatorVisibilityProvider>.value(
            value: visibility,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 380,
              child: TokenCardWidget(
                liveToken: token,
                tokenName: token.name,
                currentPrice: token.closePrice('5m'),
                selectedIntervalChange: token.priceChange('5m'),
                tickerPriceChange1h: token.tickerPriceChange1h,
                dailyChange: 0,
                historicalKlines: {
                  'LIVEUSDT': {
                    '5m': [
                      KlineData(
                        time: DateTime.utc(2026, 6, 1, 10),
                        open: 90,
                        high: 95,
                        low: 89,
                        close: 91,
                        volume: 1000,
                        isClosed: false,
                      ),
                    ],
                  },
                },
                showTradeButtons: false,
                onEma7LimitOcoPressed: noop,
                onMarketAutoClosePressed: noop,
                onBuyPressed: noop,
                onQuickBuyPressed: noop,
                onSellPressed: noop,
              ),
            ),
          ),
        ),
      ),
    );

    final chart = find.byType(CandlestickChartWidget);
    expect(chart, findsOneWidget);

    final topLeft = tester.getTopLeft(chart);
    final gesture = await tester.startGesture(topLeft + const Offset(190, 125));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('100.0000'), findsOneWidget);
    expect(find.text('105.0000'), findsOneWidget);
    expect(find.text('90.0000'), findsNothing);

    await gesture.up();
  });

  testWidgets('candlestick chart shows candle data while long-press dragging', (
    WidgetTester tester,
  ) async {
    final visibility = ChartIndicatorVisibilityProvider()..setChartScale(1);
    final candles = List.generate(60, (index) {
      final open = 100.0 + index;
      return KlineData(
        time: DateTime.utc(2026, 6, 1, 10).add(Duration(minutes: index)),
        open: open,
        high: open + 2,
        low: open - 1,
        close: open + 0.5,
        volume: 1000.0 + index,
        volumeUsdt: 1000.0 + index,
        netVolumeUsdt: index.isEven ? 100.0 + index : -100.0 - index,
        isClosed: true,
      );
    });

    Widget chartHost(List<KlineData> chartCandles) {
      return ChangeNotifierProvider.value(
        value: visibility,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 250,
              child: CandlestickChartWidget(
                candles: chartCandles,
                symbol: 'TESTUSDT',
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(chartHost(candles));

    final chart = find.byType(CandlestickChartWidget);
    final topLeft = tester.getTopLeft(chart);
    final gesture = await tester.startGesture(topLeft + const Offset(150, 125));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('TESTUSDT'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('RSI(3)'), findsOneWidget);
    expect(find.text('RSI(14)'), findsOneWidget);
    expect(find.text('RSI(50)'), findsOneWidget);
    expect(find.text('Vol USDT'), findsOneWidget);
    expect(find.text('Net Vol'), findsOneWidget);
    expect(find.text('130.5000'), findsOneWidget);

    final refreshedCandles = candles
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final candle = entry.value;
          if (index != 30) return candle;

          return KlineData(
            time: candle.time,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: 130.75,
            volume: candle.volume + 10,
            volumeUsdt: candle.volumeUsdt + 10,
            netVolumeUsdt: candle.netVolumeUsdt + 5,
            isClosed: candle.isClosed,
          );
        })
        .toList(growable: false);

    await tester.pumpWidget(chartHost(refreshedCandles));
    await tester.pump();

    expect(find.text('TESTUSDT'), findsOneWidget);
    expect(find.text('130.7500'), findsOneWidget);

    await gesture.moveTo(topLeft + const Offset(270, 125));
    await tester.pump();

    expect(find.text('154.5000'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.text('TESTUSDT'), findsNothing);
  });

  testWidgets('locked candlestick chart keeps inspection gestures', (
    WidgetTester tester,
  ) async {
    final visibility = ChartIndicatorVisibilityProvider()..setChartScale(2);
    final candles = List.generate(60, (index) {
      final open = 100.0 + index;
      return KlineData(
        time: DateTime.utc(2026, 6, 1, 10).add(Duration(minutes: index)),
        open: open,
        high: open + 2,
        low: open - 1,
        close: open + 0.5,
        volume: 1000.0 + index,
        volumeUsdt: 1000.0 + index,
        netVolumeUsdt: index.isEven ? 100.0 + index : -100.0 - index,
        isClosed: true,
      );
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: visibility,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 250,
              child: CandlestickChartWidget(
                candles: candles,
                symbol: 'TESTUSDT',
                allowPanAndZoom: false,
              ),
            ),
          ),
        ),
      ),
    );

    final chart = find.byType(CandlestickChartWidget);
    final topLeft = tester.getTopLeft(chart);
    final gesture = await tester.startGesture(topLeft + const Offset(150, 125));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('TESTUSDT'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.text('TESTUSDT'), findsNothing);

    await tester.tap(find.text('EMA3'));
    await tester.pump();

    expect(visibility.showEma3, false);

    final firstFinger = await tester.createGesture(pointer: 1);
    final secondFinger = await tester.createGesture(pointer: 2);
    await firstFinger.down(topLeft + const Offset(120, 125));
    await secondFinger.down(topLeft + const Offset(180, 125));
    await tester.pump();
    await firstFinger.moveTo(topLeft + const Offset(90, 125));
    await secondFinger.moveTo(topLeft + const Offset(210, 125));
    await tester.pump();
    await firstFinger.up();
    await secondFinger.up();

    expect(visibility.chartScale, 2);
  });
}
