import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado das transações financeiras.
///
/// Usa [ErrorHandlerMixin] para padronizar o tratamento de erros:
/// - `appError` → [AppError] tipado (substitui `String? _error`)
/// - `runSafe` / `runSafeVoid` → try/catch padronizado
class TransactionProvider extends ChangeNotifier with ErrorHandlerMixin {
  final FirestoreService _service;

  TransactionProvider(this._service) {
    _startListening();
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  StreamSubscription<List<TransactionModel>>? _subscription;

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  // Calculados do mês corrente
  double _totalEntradas = 0;
  double _totalSaidas   = 0;
  double _totalSuperfluos = 0;
  Map<String, double> _entradasPorCategoria = {};
  Map<String, double> _saidasPorCategoria   = {};

  // Estado do formulário
  String _tipo      = 'entrada';
  String _categoria = '';
  bool   _fixa      = false;
  bool   _superfluo = false;
  bool   _isSubmitting = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading     => _isLoading;

  double get totalEntradas   => _totalEntradas;
  double get totalSaidas     => _totalSaidas;
  double get totalSuperfluos => _totalSuperfluos;
  double get saldo           => _totalEntradas - _totalSaidas;

  Map<String, double> get entradasPorCategoria => _entradasPorCategoria;
  Map<String, double> get saidasPorCategoria   => _saidasPorCategoria;

  String get tipo      => _tipo;
  String get categoria => _categoria;
  bool   get fixa      => _fixa;
  bool   get superfluo => _superfluo;
  bool   get isSubmitting => _isSubmitting;

  bool   get gastosAltos => _totalSuperfluos > _totalSaidas * 0.3;

  String get analiseGastos {
    if (gastosAltos) {
      return 'Você gastou muito em supérfluos. Revise gastos variáveis para equilibrar o mês.';
    }
    return 'Bons gastos! Supérfluos sob controle.';
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

    final now = DateTime.now();
    final mesAtual = _transactions.where(
      (t) => t.data.month == now.month && t.data.year == now.year,
    );

    final Map<String, double> entradas = {};
    final Map<String, double> saidas   = {};
    double te = 0, ts = 0, tsp = 0;

    for (final t in mesAtual) {
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

    _totalEntradas          = te;
    _totalSaidas            = ts;
    _totalSuperfluos        = tsp;
    _entradasPorCategoria   = entradas;
    _saidasPorCategoria     = saidas;
    _isLoading              = false;
    setAppError(null);
    notifyListeners();
  }

  void reload() => _startListening();

  // ── Formulário ────────────────────────────────────────────────────────────

  void setTipo(String value) {
    _tipo = value;
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
