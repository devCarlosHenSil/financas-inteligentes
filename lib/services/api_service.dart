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

class ApiService {
  Future<Map<String, double>> getRealtimeQuotes() async {
    final fxResponse = await http.get(
      Uri.parse('https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL'),
    );

    final cryptoResponse = await http.get(
      Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=brl',
      ),
    );

    if (fxResponse.statusCode != 200 || cryptoResponse.statusCode != 200) {
      throw Exception('Falha ao carregar cotações em tempo real.');
    }

    final fxData = jsonDecode(fxResponse.body) as Map<String, dynamic>;
    final cryptoData = jsonDecode(cryptoResponse.body) as Map<String, dynamic>;

    return {
      'USD': double.tryParse(fxData['USDBRL']?['bid']?.toString() ?? '0') ?? 0,
      'EUR': double.tryParse(fxData['EURBRL']?['bid']?.toString() ?? '0') ?? 0,
      'BTC': (cryptoData['bitcoin']?['brl'] as num?)?.toDouble() ?? 0,
      'ETH': (cryptoData['ethereum']?['brl'] as num?)?.toDouble() ?? 0,
    };
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
    final uri = Uri.parse(
      'https://brapi.dev/api/quote/${symbols.join(',')}?range=1d&interval=1d&fundamental=false&dividends=false',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar ranking de ativos.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
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
  }
}
