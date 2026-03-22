import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado das transações financeiras.
///
/// ## Filtro por período (P3-A)
///   - [periodoSelecionado] → mês/ano exibido na tela (padrão: mês corrente)
///   - [transactions] → lista completa, ordenada por data desc
///   - [transactionsFiltradas] → lista filtrada pelo período selecionado
///   - [totalEntradas], [totalSaidas], [saldo] → calculados sobre o período
///   - [mesesDisponiveis] → lista de meses com pelo menos 1 transação
///   - [irParaMesAnterior] / [irParaProximoMes] → navegação rápida
class TransactionProvider extends ChangeNotifier with ErrorHandlerMixin {
  final FirestoreService _service;

  TransactionProvider(this._service) {
    _periodoSelecionado = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );
    _startListening();
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  StreamSubscription<List<TransactionModel>>? _subscription;

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  // Período selecionado (apenas ano + mês)
  late DateTime _periodoSelecionado;

  // Calculados sobre o período selecionado
  double _totalEntradas = 0;
  double _totalSaidas   = 0;
  double _totalSuperfluos = 0;
  Map<String, double> _entradasPorCategoria = {};
  Map<String, double> _saidasPorCategoria   = {};

  // Estado do formulário
  String _tipo         = 'entrada';
  String _categoria    = '';
  bool   _fixa         = false;
  bool   _superfluo    = false;
  bool   _isSubmitting = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  /// Todas as transações (sem filtro de período), ordenadas por data desc.
  List<TransactionModel> get transactions => _transactions;

  /// Transações filtradas pelo [periodoSelecionado].
  List<TransactionModel> get transactionsFiltradas => _transactions
      .where((t) =>
          t.data.month == _periodoSelecionado.month &&
          t.data.year == _periodoSelecionado.year)
      .toList();

  bool get isLoading     => _isLoading;
  DateTime get periodoSelecionado => _periodoSelecionado;

  double get totalEntradas   => _totalEntradas;
  double get totalSaidas     => _totalSaidas;
  double get totalSuperfluos => _totalSuperfluos;
  double get saldo           => _totalEntradas - _totalSaidas;

  Map<String, double> get entradasPorCategoria => _entradasPorCategoria;
  Map<String, double> get saidasPorCategoria   => _saidasPorCategoria;

  String get tipo         => _tipo;
  String get categoria    => _categoria;
  bool   get fixa         => _fixa;
  bool   get superfluo    => _superfluo;
  bool   get isSubmitting => _isSubmitting;

  bool get gastosAltos => _totalSuperfluos > _totalSaidas * 0.3;

  String get analiseGastos => gastosAltos
      ? 'Você gastou muito em supérfluos. Revise gastos variáveis para equilibrar o mês.'
      : 'Bons gastos! Supérfluos sob controle.';

  /// Lista de meses distintos com pelo menos 1 transação, ordem decrescente.
  List<DateTime> get mesesDisponiveis {
    final meses = <DateTime>{};
    for (final t in _transactions) {
      meses.add(DateTime(t.data.year, t.data.month));
    }
    final lista = meses.toList()..sort((a, b) => b.compareTo(a));
    // Garante que o mês atual sempre aparece (mesmo sem transações)
    final mesAtual = DateTime(DateTime.now().year, DateTime.now().month);
    if (!lista.contains(mesAtual)) lista.insert(0, mesAtual);
    return lista;
  }

  /// True se o período selecionado é o mês corrente.
  bool get isPeriodoAtual {
    final now = DateTime.now();
    return _periodoSelecionado.year == now.year &&
        _periodoSelecionado.month == now.month;
  }

  /// True se há um mês mais recente disponível para navegar.
  bool get temProximoMes {
    final now = DateTime.now();
    return _periodoSelecionado.year < now.year ||
        (_periodoSelecionado.year == now.year &&
            _periodoSelecionado.month < now.month);
  }

  // ── Categorias ────────────────────────────────────────────────────────────

  static const List<String> categoriasEntrada = [
    'Crédito de Salário',
    'Adiantamento de Salário',
    'Pagamento de Benefícios',
  ];

  static const List<String> categoriasSaida = [
    'Amazon', 'Alimentação', 'Cartão de Crédito', 'Depósito de Construção',
    'Farmácia', 'Lazer', 'Mercado Livre', 'Magalu', 'Moradia', 'Padaria',
    'Pix para esposa', 'Papelaria', 'Shopee', 'Super Mercado',
    'Serviço de Terceiros', 'Serviços de Internet', 'Serviços de Energia',
    'Serviços de Telefonia', 'Servicos de Transporte', 'Tiktok Shop',
    'Uber', 'Outros',
  ];

  List<String> get categoriasAtuais =>
      _tipo == 'entrada' ? categoriasEntrada : categoriasSaida;

  // ── Navegação de período ──────────────────────────────────────────────────

  void setPeriodo(DateTime mes) {
    _periodoSelecionado = DateTime(mes.year, mes.month);
    _recalcular();
    notifyListeners();
  }

  void irParaMesAnterior() {
    final anterior = DateTime(
      _periodoSelecionado.year,
      _periodoSelecionado.month - 1,
    );
    setPeriodo(anterior);
  }

  void irParaProximoMes() {
    if (!temProximoMes) return;
    final proximo = DateTime(
      _periodoSelecionado.year,
      _periodoSelecionado.month + 1,
    );
    setPeriodo(proximo);
  }

  void irParaMesAtual() {
    setPeriodo(DateTime(DateTime.now().year, DateTime.now().month));
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  void _startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _subscription = _service.getTransactions().listen(
      _onTransactionsReceived,
      onError: (e, StackTrace st) {
        setAppError(ErrorHandler.instance.handle(e, st));
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void _onTransactionsReceived(List<TransactionModel> raw) {
    _transactions = List.from(raw)
      ..sort((a, b) => b.data.compareTo(a.data));
    _isLoading = false;
    setAppError(null);
    _recalcular();
    notifyListeners();
  }

  /// Recalcula totais e categorias para o [periodoSelecionado] atual.
  void _recalcular() {
    final Map<String, double> entradas = {};
    final Map<String, double> saidas   = {};
    double te = 0, ts = 0, tsp = 0;

    for (final t in transactionsFiltradas) {
      if (t.tipo == 'entrada') {
        te += t.valor;
        entradas.update(t.categoria, (v) => v + t.valor,
            ifAbsent: () => t.valor);
      } else if (t.tipo == 'saida') {
        ts += t.valor;
        saidas.update(t.categoria, (v) => v + t.valor,
            ifAbsent: () => t.valor);
      }
      if (t.superfluo) tsp += t.valor;
    }

    _totalEntradas        = te;
    _totalSaidas          = ts;
    _totalSuperfluos      = tsp;
    _entradasPorCategoria = entradas;
    _saidasPorCategoria   = saidas;
  }

  void reload() => _startListening();

  // ── Formulário ────────────────────────────────────────────────────────────

  void setTipo(String value) {
    _tipo      = value;
    _categoria = '';
    notifyListeners();
  }

  void setCategoria(String value) { _categoria = value; notifyListeners(); }
  void setFixa(bool value)        { _fixa = value;      notifyListeners(); }
  void setSuperfluo(bool value)   { _superfluo = value; notifyListeners(); }

  void resetForm() {
    _categoria = '';
    _fixa      = false;
    _superfluo = false;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> addTransaction(TransactionModel trans) async {
    _isSubmitting = true;
    notifyListeners();

    final ok = await runSafe<bool>(
      () async {
        await _service.addTransaction(trans);
        resetForm();
        return true;
      },
      fallback: false,
    );

    _isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<bool> updateTransaction(String id, TransactionModel trans) async {
    return runSafe<bool>(
      () async {
        await _service.updateTransaction(id, trans);
        return true;
      },
      fallback: false,
    );
  }

  Future<void> deleteTransaction(String id) async {
    await runSafeVoid(() => _service.deleteTransaction(id));
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
