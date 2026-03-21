import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/market_cache_service.dart';

/// Estado centralizado da tela de Investimentos.
///
/// ## Estratégia de cache
///
/// Na inicialização:
///   1. Carrega dados do cache local (SharedPreferences) imediatamente →
///      UI exibe dados offline sem esperar rede.
///   2. Verifica TTL: cotações 5 min / tickers 10 min.
///   3. Se expirado → atualiza em background sem bloquear a UI.
///
/// No refresh manual ([refreshMarketData]):
///   1. Invalida todo o cache.
///   2. Busca dados frescos na API.
///   3. Grava no cache e notifica listeners.
///
/// Timer 60 s verifica TTL antes de chamar a API — evita requisições desnecessárias.
class InvestmentProvider extends ChangeNotifier {
  final FirestoreService    _firestoreService;
  final ApiService          _apiService;
  final MarketCacheService  _cache;

  InvestmentProvider(
    this._firestoreService,
    this._apiService, {
    MarketCacheService? cache,
  }) : _cache = cache ?? MarketCacheService() {
    _startListening();
    _initMarketData();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoRefresh(),
    );
  }

  // ── Estado Firestore ──────────────────────────────────────────────────────

  StreamSubscription<List<InvestmentModel>>? _subscription;
  List<InvestmentModel> _investments       = [];
  bool                  _isLoadingInvestments = true;
  String?               _error;

  // ── Estado mercado ────────────────────────────────────────────────────────

  Map<String, double> _quotes    = {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
  List<MarketTicker>  _topEtfs   = [];
  List<MarketTicker>  _topFiis   = [];
  List<MarketTicker>  _topStocks = [];
  bool                _loadingMarket       = true;
  bool                _fetchingFromNetwork = false;
  CacheInfo           _quotesInfo  = CacheInfo.empty();
  CacheInfo           _tickersInfo = CacheInfo.empty();
  Timer?              _refreshTimer;

  // ── Filtros de UI ─────────────────────────────────────────────────────────

  String _proventosPeriodo       = 'Mensal';
  String _patrimonioConsolidacao = 'Tipo de ativos';
  String _patrimonioAcoes        = 'Consolidado';
  String _patrimonioFiis         = 'Consolidado';
  bool   _showIdealConsolidacao  = false;
  bool   _showIdealAcoes         = false;
  bool   _showIdealFiis          = false;
  bool   _showIdealRendaFixa     = false;
  bool   _importingProventos     = false;
  bool   _importingRentabilidade = false;

  // ── Getters — investimentos ───────────────────────────────────────────────

  List<InvestmentModel> get investments          => _investments;
  bool                  get isLoadingInvestments => _isLoadingInvestments;
  String?               get error                => _error;

  double get patrimonio => _investments.fold(0.0, (s, inv) => s + inv.valorInvestido);
  double get totalInvestido => _investments
      .where((inv) => inv.valorInvestido > 0)
      .fold(0.0, (s, inv) => s + inv.valorInvestido);

  // ── Getters — mercado ─────────────────────────────────────────────────────

  Map<String, double> get quotes              => _quotes;
  List<MarketTicker>  get topEtfs             => _topEtfs;
  List<MarketTicker>  get topFiis             => _topFiis;
  List<MarketTicker>  get topStocks           => _topStocks;
  bool                get loadingMarket       => _loadingMarket;
  bool                get fetchingFromNetwork => _fetchingFromNetwork;
  CacheInfo           get quotesInfo          => _quotesInfo;
  CacheInfo           get tickersInfo         => _tickersInfo;

  // ── Getters — filtros UI ──────────────────────────────────────────────────

  String get proventosPeriodo       => _proventosPeriodo;
  String get patrimonioConsolidacao => _patrimonioConsolidacao;
  String get patrimonioAcoes        => _patrimonioAcoes;
  String get patrimonioFiis         => _patrimonioFiis;
  bool   get showIdealConsolidacao  => _showIdealConsolidacao;
  bool   get showIdealAcoes         => _showIdealAcoes;
  bool   get showIdealFiis          => _showIdealFiis;
  bool   get showIdealRendaFixa     => _showIdealRendaFixa;
  bool   get importingProventos     => _importingProventos;
  bool   get importingRentabilidade => _importingRentabilidade;

  // ── Stream Firestore ──────────────────────────────────────────────────────

  void _startListening() {
    _subscription?.cancel();
    _isLoadingInvestments = true;
    _subscription = _firestoreService.getInvestments().listen(
      (data) {
        _investments          = data;
        _isLoadingInvestments = false;
        _error                = null;
        notifyListeners();
      },
      onError: (e) {
        _error                = e.toString();
        _isLoadingInvestments = false;
        notifyListeners();
      },
    );
  }

  void reload() => _startListening();

  // ── Cache-first init ──────────────────────────────────────────────────────

  Future<void> _initMarketData() async {
    await _loadFromCache();

    final qInfo = await _cache.quotesInfo();
    final tInfo = await _cache.etfsInfo();
    _quotesInfo  = qInfo;
    _tickersInfo = tInfo;

    if (!qInfo.isValid || !tInfo.isValid) {
      await _fetchFromNetwork();
    }
  }

  Future<void> _loadFromCache() async {
    final q  = await _cache.loadQuotes();
    final e  = await _cache.loadEtfs();
    final f  = await _cache.loadFiis();
    final s  = await _cache.loadStocks();

    if (q != null) _quotes    = q;
    if (e != null) _topEtfs   = e;
    if (f != null) _topFiis   = f;
    if (s != null) _topStocks = s;

    final hasCache = q != null || e != null || f != null || s != null;
    if (hasCache) {
      _loadingMarket = false;
      notifyListeners();
    }
  }

  // ── Auto-refresh (Timer 60 s) ─────────────────────────────────────────────

  Future<void> _autoRefresh() async {
    final quotesExpired  = !(await _cache.quotesInfo()).isValid;
    final tickersExpired = !(await _cache.etfsInfo()).isValid;
    if (quotesExpired || tickersExpired) await _fetchFromNetwork();
  }

  // ── Refresh público ───────────────────────────────────────────────────────

  Future<void> refreshMarketData() async {
    await _cache.invalidateAll();
    await _fetchFromNetwork();
  }

  // ── Busca na rede ─────────────────────────────────────────────────────────

  Future<void> _fetchFromNetwork() async {
    if (_fetchingFromNetwork) return;

    _fetchingFromNetwork = true;
    _loadingMarket       = _quotes.values.every((v) => v == 0);
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getRealtimeQuotes(),
        _apiService.getTopEtfs(),
        _apiService.getTopFiis(),
        _apiService.getTopStocks(),
      ]);

      final quotes  = results[0] as Map<String, double>;
      final etfs    = results[1] as List<MarketTicker>;
      final fiis    = results[2] as List<MarketTicker>;
      final stocks  = results[3] as List<MarketTicker>;

      if (quotes.values.any((v) => v > 0)) {
        _quotes = quotes;
        await _cache.saveQuotes(quotes);
      }
      if (etfs.isNotEmpty)   { _topEtfs   = etfs;   await _cache.saveEtfs(etfs);     }
      if (fiis.isNotEmpty)   { _topFiis   = fiis;   await _cache.saveFiis(fiis);     }
      if (stocks.isNotEmpty) { _topStocks = stocks; await _cache.saveStocks(stocks); }

      _quotesInfo  = await _cache.quotesInfo();
      _tickersInfo = await _cache.etfsInfo();
    } catch (e) {
      _error = 'Falha ao atualizar mercado: $e';
    } finally {
      _loadingMarket       = false;
      _fetchingFromNetwork = false;
      notifyListeners();
    }
  }

  // ── CRUD investimentos ────────────────────────────────────────────────────

  Future<void> addInvestment(InvestmentModel inv) async {
    try {
      await _firestoreService.addInvestment(inv);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteInvestment(String id) async {
    try {
      await _firestoreService.deleteInvestment(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Setters filtros ───────────────────────────────────────────────────────

  void setProventosPeriodo(String v)       { _proventosPeriodo = v;       notifyListeners(); }
  void setPatrimonioConsolidacao(String v) { _patrimonioConsolidacao = v; notifyListeners(); }
  void setPatrimonioAcoes(String v)        { _patrimonioAcoes = v;        notifyListeners(); }
  void setPatrimonioFiis(String v)         { _patrimonioFiis = v;         notifyListeners(); }
  void setShowIdealConsolidacao(bool v)    { _showIdealConsolidacao = v;  notifyListeners(); }
  void setShowIdealAcoes(bool v)           { _showIdealAcoes = v;         notifyListeners(); }
  void setShowIdealFiis(bool v)            { _showIdealFiis = v;          notifyListeners(); }
  void setShowIdealRendaFixa(bool v)       { _showIdealRendaFixa = v;     notifyListeners(); }
  void setImportingProventos(bool v)       { _importingProventos = v;     notifyListeners(); }
  void setImportingRentabilidade(bool v)   { _importingRentabilidade = v; notifyListeners(); }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
