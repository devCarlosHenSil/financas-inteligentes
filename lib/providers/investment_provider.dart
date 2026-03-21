import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/market_cache_service.dart';

/// Estado centralizado da tela de Investimentos.
///
/// ## Estratégia de cache
///   1. Carrega cache local imediatamente (UI exibe dados offline).
///   2. Se TTL expirado → atualiza em background.
///   3. Timer 60 s verifica TTL antes de chamar a API.
///
/// ## Tratamento de erros
///   Usa [ErrorHandlerMixin]: `appError` tipado, `runSafe`/`runSafeVoid`.
class InvestmentProvider extends ChangeNotifier with ErrorHandlerMixin {
  final FirestoreService   _firestoreService;
  final ApiService         _apiService;
  final MarketCacheService _cache;

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
        setAppError(null);
        notifyListeners();
      },
      onError: (e, StackTrace st) {
        setAppError(ErrorHandler.instance.handle(e, st));
        _isLoadingInvestments = false;
        notifyListeners();
      },
    );
  }

  void reload() => _startListening();

  // ── Cache-first init ──────────────────────────────────────────────────────

  Future<void> _initMarketData() async {
    await _loadFromCache();
    _quotesInfo  = await _cache.quotesInfo();
    _tickersInfo = await _cache.etfsInfo();
    if (!_quotesInfo.isValid || !_tickersInfo.isValid) {
      await _fetchFromNetwork();
    }
  }

  Future<void> _loadFromCache() async {
    final q = await _cache.loadQuotes();
    final e = await _cache.loadEtfs();
    final f = await _cache.loadFiis();
    final s = await _cache.loadStocks();

    if (q != null) _quotes    = q;
    if (e != null) _topEtfs   = e;
    if (f != null) _topFiis   = f;
    if (s != null) _topStocks = s;

    if (q != null || e != null || f != null || s != null) {
      _loadingMarket = false;
      notifyListeners();
    }
  }

  Future<void> _autoRefresh() async {
    final qExp = !(await _cache.quotesInfo()).isValid;
    final tExp = !(await _cache.etfsInfo()).isValid;
    if (qExp || tExp) await _fetchFromNetwork();
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
      setAppError(null);
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
    } catch (e, st) {
      // Erro de rede ao buscar mercado: mantém dados do cache
      setAppError(ErrorHandler.instance.handle(e, st));
    } finally {
      _loadingMarket       = false;
      _fetchingFromNetwork = false;
      notifyListeners();
    }
  }

  // ── CRUD investimentos ────────────────────────────────────────────────────

  Future<void> addInvestment(InvestmentModel inv) async {
    await runSafeVoid(() => _firestoreService.addInvestment(inv));
  }

  Future<void> deleteInvestment(String id) async {
    await runSafeVoid(() => _firestoreService.deleteInvestment(id));
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
