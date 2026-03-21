import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:financas_inteligentes/services/api_service.dart';

/// Serviço de cache local para dados de mercado.
///
/// Persiste cotações e rankings em [SharedPreferences] com TTL configurável.
/// Permite exibir dados offline imediatamente enquanto atualiza em background.
///
/// ## Chaves de cache
/// | Chave                        | Dado                         | TTL padrão |
/// |------------------------------|------------------------------|------------|
/// | `cache_quotes`               | USD, EUR, BTC, ETH           | 5 min      |
/// | `cache_quotes_ts`            | timestamp de gravação        | —          |
/// | `cache_tickers_etfs`         | Top ETFs do dia              | 10 min     |
/// | `cache_tickers_etfs_ts`      | timestamp de gravação        | —          |
/// | `cache_tickers_fiis`         | Top FIIs do dia              | 10 min     |
/// | `cache_tickers_fiis_ts`      | timestamp de gravação        | —          |
/// | `cache_tickers_stocks`       | Top Ações do dia             | 10 min     |
/// | `cache_tickers_stocks_ts`    | timestamp de gravação        | —          |
class MarketCacheService {
  static const _kQuotes      = 'cache_quotes';
  static const _kQuotesTs    = 'cache_quotes_ts';
  static const _kEtfs        = 'cache_tickers_etfs';
  static const _kEtfsTs      = 'cache_tickers_etfs_ts';
  static const _kFiis        = 'cache_tickers_fiis';
  static const _kFiisTs      = 'cache_tickers_fiis_ts';
  static const _kStocks      = 'cache_tickers_stocks';
  static const _kStocksTs    = 'cache_tickers_stocks_ts';

  /// TTL para cotações de moedas/cripto (mais volátil).
  static const quoteTtl  = Duration(minutes: 5);

  /// TTL para rankings de tickers de mercado.
  static const tickerTtl = Duration(minutes: 10);

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<bool> _isValid(String tsKey, Duration ttl) async {
    final prefs = await _sharedPrefs;
    final ts = prefs.getInt(tsKey);
    if (ts == null) return false;
    final saved = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateTime.now().difference(saved) < ttl;
  }

  Future<void> _saveTimestamp(String tsKey) async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ── Cotações ──────────────────────────────────────────────────────────────

  Future<Map<String, double>?> loadQuotes() async {
    if (!await _isValid(_kQuotesTs, quoteTtl)) return null;
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(_kQuotes);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveQuotes(Map<String, double> quotes) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_kQuotes, jsonEncode(quotes));
    await _saveTimestamp(_kQuotesTs);
  }

  Future<CacheInfo> quotesInfo() => _infoFor(_kQuotesTs, quoteTtl);

  // ── Tickers genérico ──────────────────────────────────────────────────────

  Future<List<MarketTicker>?> _loadTickers(String dataKey, String tsKey) async {
    if (!await _isValid(tsKey, tickerTtl)) return null;
    final prefs = await _sharedPrefs;
    final raw = prefs.getString(dataKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _tickerFromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTickers(
    String dataKey,
    String tsKey,
    List<MarketTicker> tickers,
  ) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(dataKey, jsonEncode(tickers.map(_tickerToMap).toList()));
    await _saveTimestamp(tsKey);
  }

  // ── ETFs ──────────────────────────────────────────────────────────────────

  Future<List<MarketTicker>?> loadEtfs()                      => _loadTickers(_kEtfs, _kEtfsTs);
  Future<void>                saveEtfs(List<MarketTicker> t)  => _saveTickers(_kEtfs, _kEtfsTs, t);
  Future<CacheInfo>           etfsInfo()                      => _infoFor(_kEtfsTs, tickerTtl);

  // ── FIIs ──────────────────────────────────────────────────────────────────

  Future<List<MarketTicker>?> loadFiis()                      => _loadTickers(_kFiis, _kFiisTs);
  Future<void>                saveFiis(List<MarketTicker> t)  => _saveTickers(_kFiis, _kFiisTs, t);
  Future<CacheInfo>           fiisInfo()                      => _infoFor(_kFiisTs, tickerTtl);

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<List<MarketTicker>?> loadStocks()                      => _loadTickers(_kStocks, _kStocksTs);
  Future<void>                saveStocks(List<MarketTicker> t)  => _saveTickers(_kStocks, _kStocksTs, t);
  Future<CacheInfo>           stocksInfo()                      => _infoFor(_kStocksTs, tickerTtl);

  // ── Invalidação ───────────────────────────────────────────────────────────

  Future<void> invalidateAll() async {
    final prefs = await _sharedPrefs;
    await Future.wait([
      prefs.remove(_kQuotes),   prefs.remove(_kQuotesTs),
      prefs.remove(_kEtfs),     prefs.remove(_kEtfsTs),
      prefs.remove(_kFiis),     prefs.remove(_kFiisTs),
      prefs.remove(_kStocks),   prefs.remove(_kStocksTs),
    ]);
  }

  Future<void> invalidateQuotes() async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_kQuotesTs);
  }

  // ── CacheInfo ─────────────────────────────────────────────────────────────

  Future<CacheInfo> _infoFor(String tsKey, Duration ttl) async {
    final prefs = await _sharedPrefs;
    final ts = prefs.getInt(tsKey);
    if (ts == null) return CacheInfo.empty();
    final savedAt = DateTime.fromMillisecondsSinceEpoch(ts);
    final age = DateTime.now().difference(savedAt);
    return CacheInfo(savedAt: savedAt, age: age, ttl: ttl, isValid: age < ttl);
  }

  // ── Serialização ──────────────────────────────────────────────────────────

  Map<String, dynamic> _tickerToMap(MarketTicker t) => {
    'symbol': t.symbol,
    'price': t.price,
    'changePercent': t.changePercent,
    if (t.name != null) 'name': t.name,
  };

  MarketTicker _tickerFromMap(Map<String, dynamic> m) => MarketTicker(
    symbol: m['symbol'] as String,
    price: (m['price'] as num).toDouble(),
    changePercent: (m['changePercent'] as num).toDouble(),
    name: m['name'] as String?,
  );
}

// ── CacheInfo ─────────────────────────────────────────────────────────────────

/// Metadados de uma entrada de cache — útil para exibir "Atualizado há X min".
class CacheInfo {
  const CacheInfo({
    required this.savedAt,
    required this.age,
    required this.ttl,
    required this.isValid,
  });

  factory CacheInfo.empty() => const CacheInfo(
    savedAt: null, age: null, ttl: Duration.zero, isValid: false,
  );

  final DateTime? savedAt;
  final Duration? age;
  final Duration  ttl;
  final bool      isValid;

  Duration? get remaining => age == null ? null : ttl - age!;

  String get label {
    if (savedAt == null) return 'Sem dados em cache';
    final mins = (age!.inSeconds / 60).floor();
    if (mins == 0) return 'Atualizado agora';
    if (mins == 1) return 'Atualizado há 1 min';
    return 'Atualizado há $mins min';
  }
}
