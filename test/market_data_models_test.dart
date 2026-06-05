import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/models/token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Token parses live OHLCV candle data from the backend payload', () {
    final token = Token.fromMap({
      'tokenName': 'BTCUSDT',
      'openPrice5m': 100.0,
      'highPrice5m': 110.0,
      'lowPrice5m': 95.0,
      'closePrice5m': 105.0,
      'volumeInMoney5m': 1234.0,
      'intervalStartTime5m': '2026-06-01T10:00:00.000Z',
      'isIntervalClosed5m': false,
    });

    expect(token.name, 'BTCUSDT');
    expect(token.openPrice('5m'), 100);
    expect(token.highPrice('5m'), 110);
    expect(token.lowPrice('5m'), 95);
    expect(token.closePrice('5m'), 105);
    expect(token.volume('5m'), 1234);
    expect(token.startTime('5m'), DateTime.utc(2026, 6, 1, 10));
    expect(token.isIntervalClosed('5m'), isFalse);
  });

  test('KlineData treats REST history as closed candles', () {
    final candle = KlineData.fromJson({
      'time': DateTime.utc(2026, 6, 1, 10).millisecondsSinceEpoch,
      'open': 100.0,
      'high': 110.0,
      'low': 95.0,
      'close': 105.0,
      'volume': 1234.0,
      'isClosed': true,
    });

    expect(candle.isClosed, isTrue);
  });
}
