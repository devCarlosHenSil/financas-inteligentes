import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/budget_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado dos orçamentos mensais por categoria.
///
/// ## Fluxo
///   1. Escuta orçamentos do Firestore para o [periodoSelecionado].
///   2. Recebe [gastosExternos] do TransactionProvider via [atualizarGastos].
///   3. Mescla os dois para calcular [budgetsComGasto] (progresso real).
///   4. Expõe [alertas] — categorias com status warning ou exceeded.
///
/// ## Uso
/// ```dart
/// // No widget que observa os dois providers:
/// final gastos = context.watch<TransactionProvider>().saidasPorCategoria;
/// context.read<BudgetProvider>().atualizarGastos(gastos);
/// ```
class BudgetProvider extends ChangeNotifier with ErrorHandlerMixin {
  final FirestoreService _service;

  BudgetProvider(this._service) {
    _periodoSelecionado = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    );
    _startListening();
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  StreamSubscription<List<BudgetModel>>? _subscription;
  List<BudgetModel> _budgets        = [];
  Map<String, double> _gastos       = {};
  bool   _isLoading                 = true;
  bool   _isSubmitting              = false;
  late DateTime _periodoSelecionado;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool      get isLoading      => _isLoading;
  bool      get isSubmitting   => _isSubmitting;
  DateTime  get periodoSelecionado => _periodoSelecionado;

  /// Gastos externos por categoria (para uso na tela).
  Map<String, double> get gastos => Map.unmodifiable(_gastos);

  /// Orçamentos com o gasto real preenchido a partir de [_gastos].
  List<BudgetModel> get budgetsComGasto => _budgets
      .map((b) => b.withGasto(_gastos[b.categoria] ?? 0))
      .toList()
    ..sort((a, b) => b.progresso.compareTo(a.progresso));

  /// Categorias sem orçamento cadastrado mas com gasto no período.
  List<String> get categoriasSemOrcamento {
    final comOrcamento = _budgets.map((b) => b.categoria).toSet();
    return _gastos.keys
        .where((cat) => !comOrcamento.contains(cat) && _gastos[cat]! > 0)
        .toList()
      ..sort();
  }

  /// Orçamentos em alerta (warning ou exceeded), ordenados por severidade.
  List<BudgetModel> get alertas => budgetsComGasto
      .where((b) => b.status != BudgetStatus.ok)
      .toList()
    ..sort((a, b) {
      // exceeded antes de warning
      final ord = {BudgetStatus.exceeded: 0, BudgetStatus.warning: 1};
      return (ord[a.status] ?? 2).compareTo(ord[b.status] ?? 2);
    });

  /// Soma dos limites cadastrados no período.
  double get totalLimite =>
      _budgets.fold(0.0, (s, b) => s + b.limite);

  /// Soma dos gastos nas categorias com orçamento.
  double get totalGasto => budgetsComGasto.fold(0.0, (s, b) => s + b.gasto);

  /// Progresso geral: gastos / limite total.
  double get progressoGeral =>
      totalLimite > 0 ? (totalGasto / totalLimite).clamp(0.0, 2.0) : 0;

  int get totalAlertas => alertas.length;

  // ── Período ───────────────────────────────────────────────────────────────

  void setPeriodo(DateTime mes) {
    _periodoSelecionado = DateTime(mes.year, mes.month);
    _startListening();
  }

  // ── Gastos externos (do TransactionProvider) ──────────────────────────────

  /// Chamado sempre que os gastos do período mudam no TransactionProvider.
  void atualizarGastos(Map<String, double> saidasPorCategoria) {
    _gastos = Map.from(saidasPorCategoria);
    notifyListeners();
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  void _startListening() {
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _service.getBudgets(_periodoSelecionado).listen(
      (data) {
        _budgets   = data;
        _isLoading = false;
        setAppError(null);
        notifyListeners();
      },
      onError: (e, StackTrace st) {
        setAppError(ErrorHandler.instance.handle(e, st));
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> addBudget(BudgetModel budget) async {
    _isSubmitting = true;
    notifyListeners();
    final ok = await runSafe<bool>(
      () async {
        await _service.addBudget(budget);
        return true;
      },
      fallback: false,
    );
    _isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<bool> updateBudget(BudgetModel budget) async {
    return runSafe<bool>(
      () async {
        await _service.updateBudget(budget.id, budget);
        return true;
      },
      fallback: false,
    );
  }

  Future<void> deleteBudget(String id) async {
    await runSafeVoid(() => _service.deleteBudget(id));
  }

  /// Copia os orçamentos do mês anterior para o mês atual.
  Future<bool> copiarMesAnterior() async {
    final anterior = DateTime(
      _periodoSelecionado.year,
      _periodoSelecionado.month - 1,
    );
    return runSafe<bool>(
      () async {
        await _service.copiarOrcamentos(anterior, _periodoSelecionado);
        return true;
      },
      fallback: false,
    );
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
