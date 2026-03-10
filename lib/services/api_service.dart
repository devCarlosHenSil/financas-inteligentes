import 'dart:convert';

import 'package:http/http.dart' as http;

class MarketTicker {
  MarketTicker({
    required this.symbol,
    required this.price,
    required this.changePercent,
  });

  final String symbol;
  final double price;
  final double changePercent;
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

  String get label => '$symbol - $name';
}

class ApiService {
  Future<dynamic> _getJson(String url) async {
    final direct = await http.get(Uri.parse(url));
    if (direct.statusCode == 200) {
      return jsonDecode(direct.body);
    }

    final proxyUrl =
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    final proxy = await http.get(Uri.parse(proxyUrl));
    if (proxy.statusCode == 200) {
      return jsonDecode(proxy.body);
    }

    throw Exception('Falha ao buscar dados de $url');
  }

  Future<Map<String, dynamic>> _getJsonMap(String url) async {
    final data = await _getJson(url);
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getJsonList(String url) async {
    final data = await _getJson(url);
    return data as List<dynamic>;
  }

  Future<Map<String, double>> getRealtimeQuotes() async {
    try {
      final fxData = await _getJsonMap(
        'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL',
      );

      final cryptoData = await _getJsonMap(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=brl',
      );

      return {
        'USD':
            double.tryParse(fxData['USDBRL']?['bid']?.toString() ?? '0') ?? 0,
        'EUR':
            double.tryParse(fxData['EURBRL']?['bid']?.toString() ?? '0') ?? 0,
        'BTC': (cryptoData['bitcoin']?['brl'] as num?)?.toDouble() ?? 0,
        'ETH': (cryptoData['ethereum']?['brl'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      return {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
    }
  }

  Future<List<AssetOption>> searchAssetsByType({
    required String tipo,
    String query = '',
  }) async {
    if (tipo == 'Criptomoedas') {
      return _searchCryptoAssets(query: query);
    }

    if (tipo == 'Stock' || tipo == 'Reit' || tipo == 'ETFs Internacionais') {
      return _searchYahooAssets(
        query: query,
        region: 'US',
        lang: 'en-US',
        tipo: tipo,
      );
    }

    return _searchYahooAssets(
      query: query,
      region: 'BR',
      lang: 'pt-BR',
      tipo: tipo,
    );
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
            final name = (item['longname'] ?? item['shortname'] ?? symbol)
                .toString();
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

    switch (tipo) {
      case 'Criptomoedas':
        return quoteType == 'CRYPTOCURRENCY';
      case 'ETF':
      case 'ETFs Internacionais':
        return quoteType == 'ETF';
      case 'Stock':
        return quoteType == 'EQUITY' && !name.contains('REIT');
      case 'Reit':
        return quoteType == 'EQUITY' && name.contains('REIT');
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
        'https://brapi.dev/api/quote/${symbols.join(',')}?range=1d&interval=1d&fundamental=false&dividends=false',
      );

      final results = (data['results'] as List<dynamic>? ?? []);

      final items = results.map((item) {
        final map = item as Map<String, dynamic>;
        return MarketTicker(
          symbol: map['symbol']?.toString() ?? '-',
          price: (map['regularMarketPrice'] as num?)?.toDouble() ?? 0,
          changePercent:
              (map['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      items.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      return items.take(10).toList();
    } catch (_) {
      return [];
    }
  }
}
