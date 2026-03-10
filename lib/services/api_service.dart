import 'dart:convert';

import 'package:http/http.dart' as http;

class MarketTicker {
  MarketTicker({
    required this.symbol,
    required this.price,
    required this.changePercent,
    this.name,
  });

  final String symbol;
  final double price;
  final double changePercent;
  final String? name;
}

class AssetOption {
  AssetOption({
    required this.symbol,
    required this.name,
    required this.price,
    required this.currency,
  });

  final String symbol;
  final String name;
  final double price;
  final String currency;

  String get label => (name.trim().isEmpty || name == symbol) ? symbol : '$symbol - $name';
}

class ApiService {
  static const String _brapiProxyBaseUrl = String.fromEnvironment(
    'BRAPI_PROXY_BASE_URL',
    defaultValue: 'https://brapi-proxy.financasinteligentes.workers.dev',
  );

  Uri _brapiProxyUri(String path, Map<String, String?> params) {
    final filtered = <String, String>{};
    params.forEach((key, value) {
      final cleaned = value?.trim() ?? '';
      if (cleaned.isNotEmpty) {
        filtered[key] = cleaned;
      }
    });
    return Uri.parse('$_brapiProxyBaseUrl/$path')
        .replace(queryParameters: filtered);
  }

  static const Map<String, String> _fallbackNames = {
    'ITSA3': 'Itausa',
    'PETR4': 'Petrobras',
    'VALE3': 'Vale',
    'WEGE3': 'WEG',
    'BBAS3': 'Banco do Brasil',
    'ABEV3': 'Ambev',
    'ALZR11': 'Alianza Trust Renda Imobiliaria',
    'CPTS11': 'Capitania Securities II',
    'RBRF11': 'RBR Alpha Multiestrategia',
    'MXRF11': 'Maxi Renda',
    'HGLG11': 'CSHG Logistica',
    'KNRI11': 'Kinea Renda Imobiliaria',
    'VISC11': 'Vinci Shopping Centers',
    'XPLG11': 'XP Log',
    'BTC': 'Bitcoin',
    'ETH': 'Ethereum',
    'SOL': 'Solana',
    'XRP': 'XRP',
    'AAPL': 'Apple',
    'MSFT': 'Microsoft',
    'GOOGL': 'Alphabet',
    'AMZN': 'Amazon',
    'O': 'Realty Income',
    'PLD': 'Prologis',
    'SPG': 'Simon Property Group',
    'DLR': 'Digital Realty',
    'AAPL34': 'Apple',
    'MSFT34': 'Microsoft',
    'GOGL34': 'Alphabet',
    'AMZO34': 'Amazon',
    'BOVA11': 'iShares Ibovespa',
    'SMAL11': 'iShares Small Cap',
    'IVVB11': 'iShares S&P 500',
    'HASH11': 'Hashdex Nasdaq Crypto Index',
    'VOO': 'Vanguard S&P 500 ETF',
    'QQQ': 'Invesco QQQ Trust',
    'VTI': 'Vanguard Total Stock Market ETF',
    'SPY': 'SPDR S&P 500 ETF Trust',
  };

  static const Set<String> _knownBrEtfs = {
    'BOVA11',
    'SMAL11',
    'IVVB11',
    'HASH11',
    'DIVO11',
    'ECOO11',
    'XFIX11',
    'XBOV11',
    'PIBB11',
    'GOVE11',
    'BOVV11',
    'SPXI11',
  };

  static const List<String> _defaultBrStocks = [
    'ITSA3',
    'PETR4',
    'VALE3',
    'WEGE3',
    'BBAS3',
    'ABEV3',
  ];

  static const List<String> _defaultBrFiis = [
    'ALZR11',
    'CPTS11',
    'RBRF11',
    'MXRF11',
    'HGLG11',
    'KNRI11',
    'VISC11',
    'XPLG11',
  ];

  static const List<String> _defaultBrBdrs = [
    'AAPL34',
    'MSFT34',
    'GOGL34',
    'AMZO34',
  ];

  static const List<String> _defaultUsStocks = [
    'AAPL',
    'MSFT',
    'GOOGL',
    'AMZN',
  ];

  static const List<String> _defaultUsReits = [
    'O',
    'PLD',
    'SPG',
    'DLR',
  ];

  static const List<String> _defaultUsEtfs = [
    'VOO',
    'QQQ',
    'VTI',
    'SPY',
  ];

  Future<dynamic> _getJson(
    String url, {
    Map<String, String>? headers,
    bool allowProxy = true,
  }) async {
    final direct = await http.get(Uri.parse(url), headers: headers);
    if (direct.statusCode == 200) {
      return jsonDecode(direct.body);
    }

    if (!allowProxy) {
      throw Exception('Falha ao buscar dados de $url');
    }

    final proxyUrl =
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    final proxy = await http.get(Uri.parse(proxyUrl));
    if (proxy.statusCode == 200) {
      return jsonDecode(proxy.body);
    }

    throw Exception('Falha ao buscar dados de $url');
  }

  Future<Map<String, dynamic>> _getJsonMap(
    String url, {
    Map<String, String>? headers,
    bool allowProxy = true,
  }) async {
    final data = await _getJson(url, headers: headers, allowProxy: allowProxy);
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList(
    String url, {
    Map<String, String>? headers,
    bool allowProxy = true,
  }) async {
    final data = await _getJson(url, headers: headers, allowProxy: allowProxy);
    return data as List<dynamic>;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double _pickCurrencyBid(
    Map<String, dynamic> data, {
    required String from,
    required String to,
  }) {
    final list = data['currency'];
    if (list is! List) return 0;
    for (final entry in list) {
      if (entry is! Map) continue;
      final fromCurrency = (entry['fromCurrency'] ?? entry['from'] ?? '').toString().toUpperCase();
      final toCurrency = (entry['toCurrency'] ?? entry['to'] ?? '').toString().toUpperCase();
      if (fromCurrency == from && toCurrency == to) {
        return _toDouble(entry['bidPrice'] ?? entry['bid'] ?? entry['bidPriceRaw']);
      }
    }
    return 0;
  }

  double _pickCryptoPrice(Map<String, dynamic> data, String coin) {
    final list = data['coins'];
    if (list is! List) return 0;
    for (final entry in list) {
      if (entry is! Map) continue;
      final code = (entry['coin'] ?? entry['symbol'] ?? '').toString().toUpperCase();
      if (code == coin) {
        return _toDouble(entry['regularMarketPrice'] ?? entry['price']);
      }
    }
    return 0;
  }

  Future<Map<String, double>> getRealtimeQuotes() async {
    try {
      final fxData = await _getJsonMap(
        _brapiProxyUri(
          'brapiCurrency',
          {'currency': 'USD-BRL,EUR-BRL'},
        ).toString(),
        allowProxy: false,
      );

      final cryptoData = await _getJsonMap(
        _brapiProxyUri(
          'brapiCrypto',
          {'coin': 'BTC,ETH', 'currency': 'BRL'},
        ).toString(),
        allowProxy: false,
      );

      return {
        'USD': _pickCurrencyBid(fxData, from: 'USD', to: 'BRL'),
        'EUR': _pickCurrencyBid(fxData, from: 'EUR', to: 'BRL'),
        'BTC': _pickCryptoPrice(cryptoData, 'BTC'),
        'ETH': _pickCryptoPrice(cryptoData, 'ETH'),
      };
    } catch (_) {
      return {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
    }
  }

  Future<List<AssetOption>> searchAssetsByType({
    required String tipo,
    String query = '',
  }) async {
    final cleanedQuery = query.trim();
    if (tipo == 'Criptomoedas') {
      return _searchCryptoAssets(query: cleanedQuery);
    }

    if (tipo == 'Stock' || tipo == 'Reit' || tipo == 'ETFs Internacionais') {
      if (cleanedQuery.isEmpty) {
        final symbols = tipo == 'Stock'
            ? _defaultUsStocks
            : tipo == 'Reit'
                ? _defaultUsReits
                : _defaultUsEtfs;
        return _searchYahooDefaults(
          symbols: symbols,
          region: 'US',
          lang: 'en-US',
          tipo: tipo,
        );
      }
      return _searchYahooAssets(
        query: cleanedQuery,
        region: 'US',
        lang: 'en-US',
        tipo: tipo,
      );
    }

    if (tipo == 'Tesouro Direto') {
      return _searchTesouroAssets(query: cleanedQuery);
    }

    return _searchBrapiAssets(tipo: tipo, query: cleanedQuery);
  }

  Future<List<AssetOption>> _searchCryptoAssets({String query = ''}) async {
    try {
      final q = query.trim().toLowerCase();
      final list = await _getJsonList(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=brl&order=market_cap_desc&per_page=150&page=1&sparkline=false',
      );

      return list
          .map((item) => item as Map<String, dynamic>)
          .where((item) {
            if (q.isEmpty) return true;
            final symbol = (item['symbol'] ?? '').toString().toLowerCase();
            final name = (item['name'] ?? '').toString().toLowerCase();
            return symbol.contains(q) || name.contains(q);
          })
          .take(30)
          .map(
            (item) => AssetOption(
              symbol: (item['symbol'] ?? '').toString().toUpperCase(),
              name: (item['name'] ?? '').toString(),
              price: (item['current_price'] as num?)?.toDouble() ?? 0,
              currency: 'BRL',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AssetOption>> _searchYahooAssets({
    required String query,
    required String region,
    required String lang,
    required String tipo,
  }) async {
    try {
      final q = query.trim().isEmpty
          ? (tipo == 'Tesouro Direto' ? 'tesouro' : tipo.toLowerCase())
          : query.trim();
      final data = await _getJsonMap(
        'https://query1.finance.yahoo.com/v1/finance/search?q=${Uri.encodeComponent(q)}&lang=$lang&region=$region&quotesCount=40&newsCount=0',
      );

      final quotes = (data['quotes'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .where((item) => _matchesType(item, tipo))
          .take(30)
          .map((item) {
            final symbol = (item['symbol'] ?? '-').toString();
            final rawName =
                (item['longname'] ?? item['shortname'] ?? symbol).toString();
            final name = _normalizeName(symbol, rawName);
            final price = (item['regularMarketPrice'] as num?)?.toDouble() ?? 0;
            final currency = (item['currency'] ?? (region == 'US' ? 'USD' : 'BRL'))
                .toString();
            return AssetOption(
              symbol: symbol,
              name: name,
              price: price,
              currency: currency,
            );
          })
          .toList();

      return quotes;
    } catch (_) {
      return [];
    }
  }

  bool _matchesType(Map<String, dynamic> item, String tipo) {
    final quoteType = (item['quoteType'] ?? '').toString().toUpperCase();
    final symbol = (item['symbol'] ?? '').toString().toUpperCase();
    final name = (item['longname'] ?? item['shortname'] ?? '').toString().toUpperCase();
    final isDefaultReit = _defaultUsReits.contains(symbol);

    switch (tipo) {
      case 'Criptomoedas':
        return quoteType == 'CRYPTOCURRENCY';
      case 'ETF':
      case 'ETFs Internacionais':
        return quoteType == 'ETF';
      case 'Stock':
        return quoteType == 'EQUITY' && !name.contains('REIT');
      case 'Reit':
        return quoteType == 'EQUITY' &&
            (isDefaultReit ||
                name.contains('REIT') ||
                name.contains('REALTY') ||
                name.contains('TRUST') ||
                name.contains('PROPERTIES'));
      case 'FIIs':
      case 'Fundos de Investimentos':
        return quoteType == 'EQUITY' && symbol.endsWith('11');
      case 'BDRs':
        return quoteType == 'EQUITY' && symbol.endsWith('34');
      case 'Ações':
        return quoteType == 'EQUITY' &&
            !symbol.endsWith('11') &&
            !symbol.endsWith('34');
      case 'Tesouro Direto':
        return name.contains('TESOURO');
      default:
        return true;
    }
  }

  Future<List<AssetOption>> _searchYahooDefaults({
    required List<String> symbols,
    required String region,
    required String lang,
    required String tipo,
  }) async {
    final futures = symbols
        .map((symbol) => _searchYahooAssets(
              query: symbol,
              region: region,
              lang: lang,
              tipo: tipo,
            ))
        .toList();

    final lists = await Future.wait(futures);
    final options = <AssetOption>[];

    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i].toUpperCase();
      final list = lists[i];
      AssetOption? match;
      for (final item in list) {
        if (item.symbol.toUpperCase() == symbol) {
          match = item;
          break;
        }
      }
      match ??= list.isNotEmpty ? list.first : null;
      if (match != null) {
        options.add(match);
      }
    }

    if (options.isEmpty) {
      return _defaultAssetsForTipo(tipo);
    }

    return options;
  }

  Future<List<AssetOption>> _searchBrapiAssets({
    required String tipo,
    String query = '',
  }) async {
    try {
      final brapiType = _brapiTypeForTipo(tipo);
      if (brapiType == null) {
        return [];
      }

      final trimmed = query.trim();
      final params = <String, String>{
        'type': brapiType,
        'limit': '40',
      };
      if (trimmed.isNotEmpty) {
        params['search'] = trimmed;
        params['sortBy'] = 'name';
        params['sortOrder'] = 'asc';
      } else {
        params['sortBy'] = 'volume';
        params['sortOrder'] = 'desc';
      }
      final data = await _getJsonMap(
        _brapiProxyUri('brapiQuoteList', params).toString(),
        allowProxy: false,
      );

      final stocks = (data['stocks'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .where((item) => _matchesBrapiTipo(tipo, item))
          .map((item) {
            final symbol = (item['stock'] ?? '').toString().toUpperCase();
            final rawName = (item['name'] ?? '').toString();
            final name = _normalizeName(symbol, rawName);
            final price = (item['close'] as num?)?.toDouble() ?? 0;
            return AssetOption(
              symbol: symbol,
              name: name,
              price: price,
              currency: 'BRL',
            );
          })
          .take(30)
          .toList();

      if (stocks.isNotEmpty || trimmed.isNotEmpty) {
        return stocks;
      }

      return _defaultAssetsForTipo(tipo);
    } catch (_) {
      return _defaultAssetsForTipo(tipo);
    }
  }

  Future<List<AssetOption>> _searchTesouroAssets({String query = ''}) async {
    final items = const [
      'Tesouro Selic 2029',
      'Tesouro IPCA+ 2035',
      'Tesouro Prefixado 2029',
      'Tesouro IPCA+ com Juros Semestrais 2045',
    ];

    final q = query.trim().toLowerCase();
    final filtered = items.where((item) => q.isEmpty || item.toLowerCase().contains(q));

    return filtered
        .map(
          (name) => AssetOption(
            symbol: name,
            name: name,
            price: 0,
            currency: 'BRL',
          ),
        )
        .toList();
  }

  List<AssetOption> _defaultAssetsForTipo(String tipo) {
    List<String> symbols;
    String currency = 'BRL';

    switch (tipo) {
      case 'Ações':
        symbols = _defaultBrStocks;
        break;
      case 'FIIs':
      case 'Fundos de Investimentos':
        symbols = _defaultBrFiis;
        break;
      case 'ETF':
        symbols = _knownBrEtfs.toList();
        break;
      case 'BDRs':
        symbols = _defaultBrBdrs;
        break;
      case 'Stock':
        symbols = _defaultUsStocks;
        currency = 'USD';
        break;
      case 'Reit':
        symbols = _defaultUsReits;
        currency = 'USD';
        break;
      case 'ETFs Internacionais':
        symbols = _defaultUsEtfs;
        currency = 'USD';
        break;
      default:
        symbols = [];
        break;
    }

    return symbols
        .map(
          (symbol) => AssetOption(
            symbol: symbol,
            name: _normalizeName(symbol, symbol),
            price: 0,
            currency: currency,
          ),
        )
        .toList();
  }

  String? _brapiTypeForTipo(String tipo) {
    switch (tipo) {
      case 'Ações':
        return 'stock';
      case 'FIIs':
      case 'Fundos de Investimentos':
      case 'ETF':
        return 'fund';
      case 'BDRs':
        return 'bdr';
      default:
        return 'stock';
    }
  }

  bool _matchesBrapiTipo(String tipo, Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString().toLowerCase();
    final symbol = (item['stock'] ?? '').toString().toUpperCase();
    final name = (item['name'] ?? '').toString().toUpperCase();

    switch (tipo) {
      case 'Ações':
        return type == 'stock' && !symbol.endsWith('F');
      case 'FIIs':
      case 'Fundos de Investimentos':
        return type == 'fund' && _isLikelyFii(symbol, name);
      case 'ETF':
        return type == 'fund' && _isLikelyEtf(symbol, name);
      case 'BDRs':
        return type == 'bdr' || symbol.endsWith('34');
      default:
        return true;
    }
  }

  bool _isLikelyEtf(String symbol, String name) {
    if (_knownBrEtfs.contains(symbol)) return true;
    return name.contains('ETF') || name.contains('INDEX');
  }

  bool _isLikelyFii(String symbol, String name) {
    if (!symbol.endsWith('11')) return false;
    if (_isLikelyEtf(symbol, name)) return false;
    return true;
  }

  String _normalizeName(String symbol, String rawName) {
    final cleaned = rawName.trim();
    if (cleaned.isEmpty || cleaned.toUpperCase() == symbol.toUpperCase()) {
      return _fallbackNames[symbol.toUpperCase()] ?? symbol;
    }
    return cleaned;
  }

  Future<List<MarketTicker>> getTopEtfs() {
    return _getTopBySymbols([
      'BOVA11',
      'SMAL11',
      'IVVB11',
      'HASH11',
      'DIVO11',
      'ECOO11',
      'XFIX11',
      'XBOV11',
      'PIBB11',
      'GOVE11',
      'BOVV11',
      'SPXI11',
    ]);
  }

  Future<List<MarketTicker>> getTopFiis() {
    return _getTopBySymbols([
      'HGLG11',
      'MXRF11',
      'KNRI11',
      'XPLG11',
      'VISC11',
      'BTLG11',
      'HSML11',
      'RBRF11',
      'XPML11',
      'CPTS11',
      'IRDM11',
      'ALZR11',
    ]);
  }

  Future<List<MarketTicker>> getTopStocks() {
    return _getTopBySymbols([
      'PETR4',
      'VALE3',
      'ITUB4',
      'BBAS3',
      'WEGE3',
      'BBDC4',
      'ABEV3',
      'PRIO3',
      'B3SA3',
      'SUZB3',
      'RENT3',
      'BPAC11',
    ]);
  }

  Future<List<MarketTicker>> _getTopBySymbols(List<String> symbols) async {
    try {
      final data = await _getJsonMap(
        _brapiProxyUri('brapiQuote', {
          'symbols': symbols.join(','),
          'range': '1d',
          'interval': '1d',
          'fundamental': 'false',
          'dividends': 'false',
        }).toString(),
        allowProxy: false,
      );

      final results = (data['results'] as List<dynamic>? ?? []);

      final items = results.map((item) {
        final map = item as Map<String, dynamic>;
        return MarketTicker(
          symbol: map['symbol']?.toString() ?? '-',
          name: map['shortName']?.toString() ?? map['longName']?.toString(),
          price: (map['regularMarketPrice'] as num?)?.toDouble() ?? 0,
          changePercent:
              (map['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      items.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      return items.take(10).toList();
    } catch (_) {
      return _getTopBySymbolsFallback(symbols);
    }
  }

  Future<List<MarketTicker>> _getTopBySymbolsFallback(List<String> symbols) async {
    final futures = symbols.map(_getBrapiListQuote).toList();
    final results = await Future.wait(futures);
    final items = results.whereType<MarketTicker>().toList();
    items.sort((a, b) => b.changePercent.compareTo(a.changePercent));
    return items.take(10).toList();
  }

  Future<MarketTicker?> _getBrapiListQuote(String symbol) async {
    try {
      final data = await _getJsonMap(
        _brapiProxyUri('brapiQuoteList', {
          'search': symbol,
          'limit': '5',
        }).toString(),
        allowProxy: false,
      );
      final stocks = (data['stocks'] as List<dynamic>? ?? [])
          .map((item) => item as Map<String, dynamic>)
          .toList();
      final match = stocks.firstWhere(
        (item) => (item['stock'] ?? '').toString().toUpperCase() == symbol.toUpperCase(),
        orElse: () => {},
      );
      if (match.isEmpty) return null;

      final close = (match['close'] as num?)?.toDouble() ?? 0;
      final change = (match['change'] as num?)?.toDouble() ?? 0;
      final previous = close - change;
      final changePercent =
          previous != 0 ? (change / previous) * 100 : 0.0;
      final rawName = (match['name'] ?? '').toString();
      final normalizedName = _normalizeName(symbol, rawName);

      return MarketTicker(
        symbol: symbol.toUpperCase(),
        name: normalizedName,
        price: close,
        changePercent: changePercent,
      );
    } catch (_) {
      return null;
    }
  }
}
