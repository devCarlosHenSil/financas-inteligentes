import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Tipo de meta ───────────────────────────────────────────────────────────────

enum GoalType {
  /// Juntar um valor total (ex.: reserva de emergência, viagem).
  savings,

  /// Quitar uma dívida ou reduzir um gasto.
  debt,

  /// Meta de investimento (aporte mensal ou patrimônio alvo).
  investment,

  /// Controle de gastos — não ultrapassar um limite mensal.
  spending,
}

// ── Status da meta ─────────────────────────────────────────────────────────────

enum GoalStatus {
  /// Em andamento.
  active,

  /// Concluída (progresso ≥ 100 %).
  completed,

  /// Arquivada manualmente.
  archived,
}

// ── Sentinel para distinguir "não informado" de "null explícito" ──────────────
//
// O padrão `deadline ?? this.deadline` em copyWith impede limpar o prazo,
// porque null é interpretado como "não informado". O sentinel resolve isso:
//
//   goal.copyWith(deadline: null)         → mantém o prazo atual
//   goal.copyWith(clearDeadline: true)    → seta deadline = null
//
// Alternativa: usar Object? com valor sentinel privado, que é
// a abordagem mais segura sem precisar de parâmetro extra.

const _deadlineSentinel = Object();

// ── GoalModel ──────────────────────────────────────────────────────────────────

class GoalModel {
  GoalModel({
    required this.id,
    required this.title,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.createdAt,
    this.deadline,
    this.description,
    required this.color,
    required this.icon,
    required this.status,
  });

  final String id;
  final String title;
  final GoalType type;
  final double targetValue;
  final double currentValue;
  final DateTime createdAt;
  final DateTime? deadline;
  final String? description;
  final int color;
  final int icon;
  final GoalStatus status;

  // ── Computed ───────────────────────────────────────────────────────────────

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  double get progressPercent => progress * 100;

  double get remaining =>
      (targetValue - currentValue).clamp(0.0, double.infinity);

  bool get isCompleted =>
      progress >= 1.0 || status == GoalStatus.completed;
  bool get isActive => status == GoalStatus.active;
  bool get isArchived => status == GoalStatus.archived;

  int? get daysRemaining {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue =>
      deadline != null &&
      DateTime.now().isAfter(deadline!) &&
      !isCompleted;

  Color get goalColor => Color(color);
  IconData get goalIcon => IconData(icon, fontFamily: 'MaterialIcons');

  String get typeLabel {
    switch (type) {
      case GoalType.savings:
        return 'Economia';
      case GoalType.debt:
        return 'Dívida';
      case GoalType.investment:
        return 'Investimento';
      case GoalType.spending:
        return 'Controle de gastos';
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory GoalModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalModel(
      id: id,
      title: (map['title'] as String? ?? '').trim(),
      type: _parseType(map['type'] as String? ?? 'savings'),
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      currentValue: (map['currentValue'] as num?)?.toDouble() ?? 0,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      description: map['description'] as String?,
      color: (map['color'] as int?) ??
          const Color(0xFF1D4ED8).toARGB32(),
      icon: (map['icon'] as int?) ?? Icons.flag_outlined.codePoint,
      status: _parseStatus(map['status'] as String? ?? 'active'),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.name,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'createdAt': Timestamp.fromDate(createdAt),
        'deadline':
            deadline != null ? Timestamp.fromDate(deadline!) : null,
        'description': description,
        'color': color,
        'icon': icon,
        'status': status.name,
      };

  // ── copyWith ───────────────────────────────────────────────────────────────
  //
  // CORREÇÃO P2-C: deadline usa Object? com sentinel para distinguir
  // "não informado" (mantém o atual) de "explicitamente null" (limpa o prazo).
  //
  // Uso:
  //   goal.copyWith()                          → mantém deadline
  //   goal.copyWith(deadline: novaData)        → atualiza deadline
  //   goal.copyWith(deadline: _deadlineSentinel as dynamic)
  //                                            → não é necessário — veja clearDeadline
  //
  // Para limpar o prazo, use o parâmetro booleano clearDeadline:
  //   goal.copyWith(clearDeadline: true)       → seta deadline = null
  //   goal.copyWith(deadline: outraData, clearDeadline: true)
  //                                            → clearDeadline tem precedência

  GoalModel copyWith({
    String? title,
    GoalType? type,
    double? targetValue,
    double? currentValue,
    // ignore: avoid_annotating_with_dynamic
    Object? deadline = _deadlineSentinel,
    bool clearDeadline = false,
    String? description,
    int? color,
    int? icon,
    GoalStatus? status,
  }) {
    // Resolve o novo valor de deadline:
    //   clearDeadline=true       → null (remove o prazo)
    //   deadline == sentinel     → mantém o prazo atual (parâmetro não informado)
    //   deadline != sentinel     → usa o novo valor (pode ser null para remover)
    final DateTime? resolvedDeadline;
    if (clearDeadline) {
      resolvedDeadline = null;
    } else if (identical(deadline, _deadlineSentinel)) {
      resolvedDeadline = this.deadline;
    } else {
      resolvedDeadline = deadline as DateTime?;
    }

    return GoalModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      createdAt: createdAt,
      deadline: resolvedDeadline,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      status: status ?? this.status,
    );
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  static GoalType _parseType(String value) {
    switch (value) {
      case 'debt':
        return GoalType.debt;
      case 'investment':
        return GoalType.investment;
      case 'spending':
        return GoalType.spending;
      default:
        return GoalType.savings;
    }
  }

  static GoalStatus _parseStatus(String value) {
    switch (value) {
      case 'completed':
        return GoalStatus.completed;
      case 'archived':
        return GoalStatus.archived;
      default:
        return GoalStatus.active;
    }
  }
}
