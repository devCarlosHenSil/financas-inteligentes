import 'dart:async';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/goal_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado das metas financeiras.
///
/// Responsabilidades:
///   - Stream de [GoalModel] do Firestore (em tempo real)
///   - Filtro de status (ativas / concluídas / arquivadas)
///   - CRUD de metas e atualização de progresso
///   - Computed: totais, progresso médio, metas em atraso
class GoalProvider extends ChangeNotifier with ErrorHandlerMixin {
  final FirestoreService _service;

  GoalProvider(this._service) {
    _startListening();
  }

  // ── Estado ────────────────────────────────────────────────────────────────

  StreamSubscription<List<GoalModel>>? _subscription;
  List<GoalModel> _goals   = [];
  bool _isLoading          = true;
  GoalStatus _filterStatus = GoalStatus.active;
  bool _isSubmitting       = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  bool           get isLoading    => _isLoading;
  bool           get isSubmitting => _isSubmitting;
  GoalStatus     get filterStatus => _filterStatus;

  /// Todas as metas sem filtro.
  List<GoalModel> get goals => _goals;

  /// Metas filtradas pelo [filterStatus].
  List<GoalModel> get filteredGoals =>
      _goals.where((g) => g.status == _filterStatus).toList()
        ..sort((a, b) {
          // Concluídas por último, depois por prazo mais próximo
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          if (a.deadline != null && b.deadline != null) {
            return a.deadline!.compareTo(b.deadline!);
          }
          return 0;
        });

  List<GoalModel> get activeGoals    => _goals.where((g) => g.isActive).toList();
  List<GoalModel> get completedGoals => _goals.where((g) => g.status == GoalStatus.completed).toList();
  List<GoalModel> get overdueGoals   => _goals.where((g) => g.isOverdue).toList();

  /// Progresso médio das metas ativas (0.0 – 1.0).
  double get averageProgress {
    final active = activeGoals;
    if (active.isEmpty) return 0;
    return active.fold(0.0, (sum, g) => sum + g.progress) / active.length;
  }

  /// Valor total alvo de todas as metas ativas.
  double get totalTarget =>
      activeGoals.fold(0.0, (sum, g) => sum + g.targetValue);

  /// Valor total já acumulado nas metas ativas.
  double get totalCurrent =>
      activeGoals.fold(0.0, (sum, g) => sum + g.currentValue);

  /// Quantidade de metas concluídas.
  int get completedCount => completedGoals.length;

  /// Quantidade de metas em atraso.
  int get overdueCount => overdueGoals.length;

  // ── Stream ────────────────────────────────────────────────────────────────

  void _startListening() {
    _subscription?.cancel();
    _isLoading = true;
    _subscription = _service.getGoals().listen(
      (data) {
        _goals     = data;
        _isLoading = false;
        setAppError(null);
        // Auto-concluir metas que atingiram 100 %
        _autoComplete();
        notifyListeners();
      },
      onError: (e, StackTrace st) {
        setAppError(ErrorHandler.instance.handle(e, st));
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void reload() => _startListening();

  /// Marca automaticamente como concluída qualquer meta ativa com progress ≥ 1.
  Future<void> _autoComplete() async {
    for (final goal in _goals) {
      if (goal.isActive && goal.progress >= 1.0) {
        await _service.updateGoal(
          goal.id,
          goal.copyWith(status: GoalStatus.completed),
        );
      }
    }
  }

  // ── Filtro de UI ──────────────────────────────────────────────────────────

  void setFilter(GoalStatus status) {
    _filterStatus = status;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> addGoal(GoalModel goal) async {
    _isSubmitting = true;
    notifyListeners();

    final ok = await runSafe<bool>(
      () async {
        await _service.addGoal(goal);
        return true;
      },
      fallback: false,
    );

    _isSubmitting = false;
    notifyListeners();
    return ok;
  }

  Future<bool> updateGoal(GoalModel goal) async {
    return runSafe<bool>(
      () async {
        await _service.updateGoal(goal.id, goal);
        return true;
      },
      fallback: false,
    );
  }

  Future<void> deleteGoal(String id) async {
    await runSafeVoid(() => _service.deleteGoal(id));
  }

  Future<void> archiveGoal(String id) async {
    final goal = _goals.firstWhere((g) => g.id == id, orElse: () => throw StateError('Meta não encontrada'));
    await runSafeVoid(
      () => _service.updateGoal(id, goal.copyWith(status: GoalStatus.archived)),
    );
  }

  /// Adiciona [amount] ao progresso de uma meta e retorna true se bem-sucedido.
  Future<bool> addProgress(String id, double amount) async {
    final goal = _goals.firstWhere(
      (g) => g.id == id,
      orElse: () => throw StateError('Meta não encontrada'),
    );

    final newValue = (goal.currentValue + amount).clamp(0.0, goal.targetValue);
    return runSafe<bool>(
      () async {
        await _service.updateGoal(
          id,
          goal.copyWith(currentValue: newValue),
        );
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
