import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado da tela de Investimentos.
///
/// Gerencia:
///   - Stream de [InvestmentModel] do Firestore
///   - Cotações em tempo real (USD, EUR, BTC, ETH)
///   - Rankings de mercado (Top ETFs, FIIs, Ações)
///   - Filtros de UI (período de proventos, consolidações, etc.)
///   - Timer de auto-refresh a cada 60 segundos
class InvestmentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final ApiService _apiService;

  InvestmentProvider(this._firestoreService, this._apiService) {
    _startListening();
    _refreshMarketData();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshMarketData(),
    );
  }

  // ── Estado do Firestore ───────────────────────────────────────────────────

  StreamSubscription<List<InvestmentModel>>? _subscription;
  List<InvestmentModel> _investments = [];
  bool _isLoadingInvestments = true;
  String? _error;

  // ── Estado do mercado ─────────────────────────────────────────────────────

  Map<String, double> _quotes = {'USD': 0, 'EUR': 0, 'BTC': 0, 'ETH': 0};
  List<MarketTicker> _topEtfs = [];
  List<MarketTicker> _topFiis = [];
  List<MarketTicker> _topStocks = [];
  bool _loadingMarket = true;
  Timer? _refreshTimer;

  // ── Estado dos filtros de UI ──────────────────────────────────────────────

  String _proventosPeriodo = 'Mensal';
  String _patrimonioConsolidacao = 'Tipo de ativos';
  String _patrimonioAcoes = 'Consolidado';
  String _patrimonioFiis = 'Consolidado';
  bool _showIdealConsolidacao = false;
  bool _showIdealAcoes = false;
  bool _showIdealFiis = false;
  bool _showIdealRendaFixa = false;
  bool _importingProventos = false;
  bool _importingRentabilidade = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<InvestmentModel> get investments => _investments;
  bool get isLoadingInvestments => _isLoadingInvestments;
  String? get error => _error;

  Map<String, double> get quotes => _quotes;
  List<MarketTicker> get topEtfs => _topEtfs;
  List<MarketTicker> get topFiis => _topFiis;
  List<MarketTicker> get topStocks => _topStocks;
  bool get loadingMarket => _loadingMarket;

  String get proventosPeriodo => _proventosPeriodo;
  String get patrimonioConsolidacao => _patrimonioConsolidacao;
  String get patrimonioAcoes => _patrimonioAcoes;
  String get patrimonioFiis => _patrimonioFiis;
  bool get showIdealConsolidacao => _showIdealConsolidacao;
  bool get showIdealAcoes => _showIdealAcoes;
  bool get showIdealFiis => _showIdealFiis;
  bool get showIdealRendaFixa => _showIdealRendaFixa;
  bool get importingProventos => _importingProventos;
  bool get importingRentabilidade => _importingRentabilidade;

  /// Patrimônio total (soma de todos os valorInvestido, incluindo vendas negativas).
  double get patrimonio =>
      _investments.fold(0.0, (sum, inv) => sum + inv.valorInvestido);

  /// Total aplicado (somente compras / valores positivos).
  double get totalInvestido => _investments
      .where((inv) => inv.valorInvestido > 0)
      .fold(0.0, (sum, inv) => sum + inv.valorInvestido);

  // ── Stream de investimentos ───────────────────────────────────────────────

  void _startListening() {
    _subscription?.cancel();
    _isLoadingInvestments = true;
    _subscription = _firestoreService.getInvestments().listen(
      (data) {
        _investments = data;
        _isLoadingInvestments = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoadingInvestments = false;
        notifyListeners();
      },
    );
  }

  void reload() => _startListening();

  // ── Cotações e mercado ────────────────────────────────────────────────────

  Future<void> refreshMarketData() => _refreshMarketData();

  Future<void> _refreshMarketData() async {
    _loadingMarket = true;
    notifyListeners();

    final results = await Future.wait([
      _apiService.getRealtimeQuotes(),
      _apiService.getTopEtfs(),
      _apiService.getTopFiis(),
      _apiService.getTopStocks(),
    ]);

    final quotes = results[0] as Map<String, double>;
    final etfs = results[1] as List<MarketTicker>;
    final fiis = results[2] as List<MarketTicker>;
    final stocks = results[3] as List<MarketTicker>;

    if (quotes.values.any((v) => v > 0)) _quotes = quotes;
    if (etfs.isNotEmpty) _topEtfs = etfs;
    if (fiis.isNotEmpty) _topFiis = fiis;
    if (stocks.isNotEmpty) _topStocks = stocks;

    _loadingMarket = false;
    notifyListeners();
  }

  // ── CRUD de investimentos ─────────────────────────────────────────────────

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

  // ── Setters de filtros ────────────────────────────────────────────────────

  void setProventosPeriodo(String v) {
    _proventosPeriodo = v;
    notifyListeners();
  }

  void setPatrimonioConsolidacao(String v) {
    _patrimonioConsolidacao = v;
    notifyListeners();
  }

  void setPatrimonioAcoes(String v) {
    _patrimonioAcoes = v;
    notifyListeners();
  }

  void setPatrimonioFiis(String v) {
    _patrimonioFiis = v;
    notifyListeners();
  }

  void setShowIdealConsolidacao(bool v) {
    _showIdealConsolidacao = v;
    notifyListeners();
  }

  void setShowIdealAcoes(bool v) {
    _showIdealAcoes = v;
    notifyListeners();
  }

  void setShowIdealFiis(bool v) {
    _showIdealFiis = v;
    notifyListeners();
  }

  void setShowIdealRendaFixa(bool v) {
    _showIdealRendaFixa = v;
    notifyListeners();
  }

  void setImportingProventos(bool v) {
    _importingProventos = v;
    notifyListeners();
  }

  void setImportingRentabilidade(bool v) {
    _importingRentabilidade = v;
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
