import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/app_preferences.dart';
import 'currency.dart';

/// The market (mid) rate between two currencies on a day: 1 [from] buys
/// [rate] [to]. Only ever used for estimates; what a bank or Payoneer
/// actually paid is always entered by the user.
class ExchangeRate {
  const ExchangeRate({
    required this.from,
    required this.to,
    required this.rate,
    required this.asOf,
    required this.source,
  });

  final String from;
  final String to;
  final double rate;

  /// The day the rate was published.
  final DateTime asOf;

  /// Who published it, for the fine print.
  final String source;

  /// [minor] of [from] in [to], at this rate.
  int convert(int minor, {double spread = 0}) {
    final a = Currencies.byCode(from), b = Currencies.byCode(to);
    final major = minor / math.pow(10, a.decimalDigits);
    return (major * rate * (1 - spread) * math.pow(10, b.decimalDigits))
        .round();
  }

  Map<String, Object> toJson() => {
    'from': from,
    'to': to,
    'rate': rate,
    'asOf': asOf.toIso8601String(),
    'source': source,
  };

  static ExchangeRate? fromJson(Object? json) {
    if (json is! Map) return null;
    final asOf = DateTime.tryParse('${json['asOf']}');
    final rate = json['rate'];
    if (asOf == null || rate is! num) return null;
    return ExchangeRate(
      from: '${json['from']}',
      to: '${json['to']}',
      rate: rate.toDouble(),
      asOf: asOf,
      source: '${json['source']}',
    );
  }
}

/// Where live rates come from.
abstract interface class ExchangeRateSource {
  Future<ExchangeRate> fetch(String from, String to);
}

/// Free, keyless public rates: the European Central Bank's daily reference
/// rates via Frankfurter, and ExchangeRate-API as a fallback.
class PublicExchangeRateSource implements ExchangeRateSource {
  PublicExchangeRateSource([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);

  @override
  Future<ExchangeRate> fetch(String from, String to) async {
    try {
      return await _frankfurter(from, to);
    } on Object {
      return _erApi(from, to);
    }
  }

  Future<ExchangeRate> _frankfurter(String from, String to) async {
    final res = await _client
        .get(
          Uri.https('api.frankfurter.dev', '/v1/latest', {
            'base': from,
            'symbols': to,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException('${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ExchangeRate(
      from: from,
      to: to,
      rate: ((json['rates'] as Map)[to] as num).toDouble(),
      asOf: DateTime.parse(json['date'] as String),
      source: 'European Central Bank',
    );
  }

  Future<ExchangeRate> _erApi(String from, String to) async {
    final res = await _client
        .get(Uri.https('open.er-api.com', '/v6/latest/$from'))
        .timeout(_timeout);
    if (res.statusCode != 200) throw http.ClientException('${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final seconds = (json['time_last_update_unix'] as num).toInt();
    return ExchangeRate(
      from: from,
      to: to,
      rate: ((json['rates'] as Map)[to] as num).toDouble(),
      asOf: DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      source: 'ExchangeRate-API',
    );
  }
}

final exchangeRateSourceProvider = Provider<ExchangeRateSource>(
  (ref) => PublicExchangeRateSource(),
);

/// The latest known rate for a pair, or null if there has never been one.
///
/// A rate fetched in the last few hours is reused as is (they're published
/// once a day). Offline, the last one fetched is used, so estimates keep
/// working; its [ExchangeRate.asOf] says how old it is.
final exchangeRateProvider =
    FutureProvider.family<ExchangeRate?, (String, String)>((ref, pair) async {
      final (from, to) = pair;
      final prefs = ref.watch(sharedPreferencesProvider);
      final key = 'fx.$from.$to';
      final cached = _read(prefs, key);
      final fetchedAt = DateTime.tryParse(prefs.getString('$key.at') ?? '');
      final fresh =
          fetchedAt != null &&
          DateTime.now().difference(fetchedAt) < const Duration(hours: 3);
      if (cached != null && fresh) return cached;
      try {
        final rate = await ref.read(exchangeRateSourceProvider).fetch(from, to);
        await prefs.setString(key, jsonEncode(rate.toJson()));
        await prefs.setString('$key.at', DateTime.now().toIso8601String());
        return rate;
      } on Object {
        return cached;
      }
    });

/// Forgets how recently a pair was fetched, so the next read goes online.
Future<void> expireExchangeRate(
  SharedPreferences prefs,
  String from,
  String to,
) => prefs.remove('fx.$from.$to.at');

ExchangeRate? _read(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return null;
  try {
    return ExchangeRate.fromJson(jsonDecode(raw));
  } on FormatException {
    return null;
  }
}
