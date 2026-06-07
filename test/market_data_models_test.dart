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
      'rollingPriceChange5m': 0.7,
      'rollingPriceChangeReady5m': true,
      'rollingPriceChange15m': 1.4,
      'rollingPriceChangeReady15m': true,
      'rollingPriceChange30m': -0.2,
      'rollingPriceChangeReady30m': true,
      'rollingPriceChange1h': 3.5,
      'rollingPriceChangeReady1h': true,
      'intervalStartTime5m': '2026-06-01T10:00:00.000Z',
      'isIntervalClosed5m': false,
    });

    expect(token.name, 'BTCUSDT');
    expect(token.openPrice('5m'), 100);
    expect(token.highPrice('5m'), 110);
    expect(token.lowPrice('5m'), 95);
    expect(token.closePrice('5m'), 105);
    expect(token.volume('5m'), 1234);
    expect(token.rollingPriceChange('5m'), 0.7);
    expect(token.rollingPriceChange('15m'), 1.4);
    expect(token.rollingPriceChange('30m'), -0.2);
    expect(token.rollingPriceChange('1h'), 3.5);
    expect(token.hasRollingPriceChange('5m'), isTrue);
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
      'score': 68,
      'primarySignalType': 'elastic',
      'signalTypes': ['setup', 'elastic'],
      'setupScore': 57,
      'setupActive': true,
      'setupRank': 4,
      'setupReasons': ['+8 5m volume >= 100k', '-6 spread too wide'],
      'elasticScore': 68,
      'elasticActive': true,
      'elasticRank': 1,
      'elasticReasons': [
        '+18 elastic rolling 5m expansion',
        '+12 positive 5m net buy volume',
      ],
      'reasons': [
        '+18 elastic rolling 5m expansion',
        '+12 positive 5m net buy volume',
      ],
      'signals': {
        'setup': {
          'type': 'setup',
          'score': 57,
          'isActive': true,
          'rank': 4,
          'reasons': ['+8 5m volume >= 100k', '-6 spread too wide'],
        },
        'elastic': {
          'type': 'elastic',
          'score': 68,
          'isActive': true,
          'rank': 1,
          'reasons': [
            '+18 elastic rolling 5m expansion',
            '+12 positive 5m net buy volume',
          ],
        },
      },
      'metrics': {
        'priceChange5m': 1.25,
        'rollingPriceChange5m': 0.9,
        'rollingPriceChange15m': 2.1,
        'rollingPriceChange30m': 3.2,
        'relativeVolume5m': '3.4',
        'rsi14in5m': null,
      },
    });

    expect(candidate.rank, 1);
    expect(candidate.tokenName, 'BTCUSDT');
    expect(candidate.score, 68);
    expect(candidate.primarySignalType, 'elastic');
    expect(candidate.setupScore, 57);
    expect(candidate.elasticScore, 68);
    expect(candidate.setupRank, 4);
    expect(candidate.elasticRank, 1);
    expect(candidate.hasSetupSignal, isTrue);
    expect(candidate.hasElasticSignal, isTrue);
    expect(candidate.primarySignal.type, 'elastic');
    expect(candidate.activeSignals.map((signal) => signal.type), [
      'elastic',
      'setup',
    ]);
    expect(candidate.reasons, hasLength(2));
    expect(candidate.metric('priceChange5m'), 1.25);
    expect(candidate.metric('rollingPriceChange5m'), 0.9);
    expect(candidate.metric('rollingPriceChange15m'), 2.1);
    expect(candidate.metric('rollingPriceChange30m'), 3.2);
    expect(candidate.metric('relativeVolume5m'), 3.4);
    expect(candidate.metric('rsi14in5m'), isNull);
  });
}
