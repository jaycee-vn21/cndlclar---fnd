import 'package:cndlclar/models/kline_data.dart';
import 'package:cndlclar/models/short_term_buy_candidate.dart';
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
      'volumeUsdt': 1234.0,
      'netVolumeUsdt': -234.0,
      'isClosed': true,
    });

    expect(candle.isClosed, isTrue);
    expect(candle.volume, 1234);
    expect(candle.volumeUsdt, 1234);
    expect(candle.netVolumeUsdt, -234);
  });

  test('ShortTermBuyCandidate parses backend signal payload', () {
    final candidate = ShortTermBuyCandidate.fromMap({
      'rank': 1,
      'tokenName': 'BTCUSDT',
      'score': 57,
      'reasons': ['+8 5m volume >= 100k', '-6 spread too wide'],
      'metrics': {
        'priceChange5m': 1.25,
        'relativeVolume5m': '3.4',
        'rsi14in5m': null,
      },
    });

    expect(candidate.rank, 1);
    expect(candidate.tokenName, 'BTCUSDT');
    expect(candidate.score, 57);
    expect(candidate.reasons, hasLength(2));
    expect(candidate.metric('priceChange5m'), 1.25);
    expect(candidate.metric('relativeVolume5m'), 3.4);
    expect(candidate.metric('rsi14in5m'), isNull);
  });
}
