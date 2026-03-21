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

// ── GoalModel ──────────────────────────────────────────────────────────────────

/// Representa uma meta financeira do usuário.
///
/// ## Campos
/// - [title]       — nome da meta (ex.: "Reserva de emergência")
/// - [type]        — categoria: savings / debt / investment / spending
/// - [targetValue] — valor alvo (quanto quer juntar/pagar/não ultrapassar)
/// - [currentValue]— valor atual já acumulado/pago/gasto
/// - [deadline]    — prazo opcional para conclusão
/// - [color]       — cor de destaque na UI (int ARGB)
/// - [icon]        — código do ícone Material (codePoint)
/// - [status]      — active / completed / archived
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

  final String     id;
  final String     title;
  final GoalType   type;
  final double     targetValue;
  final double     currentValue;
  final DateTime   createdAt;
  final DateTime?  deadline;
  final String?    description;
  final int        color;   // Color.value (ARGB int)
  final int        icon;    // IconData.codePoint
  final GoalStatus status;

  // ── Computed ───────────────────────────────────────────────────────────────

  /// Progresso de 0.0 a 1.0 (pode ultrapassar 1.0 em metas de gastos).
  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  double get progressPercent => progress * 100;

  double get remaining =>
      (targetValue - currentValue).clamp(0.0, double.infinity);

  bool get isCompleted => progress >= 1.0 || status == GoalStatus.completed;
  bool get isActive    => status == GoalStatus.active;
  bool get isArchived  => status == GoalStatus.archived;

  /// Dias restantes até o prazo (null se sem prazo).
  int? get daysRemaining {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// `true` se a meta está atrasada (prazo passou e não concluiu).
  bool get isOverdue =>
      deadline != null &&
      DateTime.now().isAfter(deadline!) &&
      !isCompleted;

  Color get goalColor => Color(color);
  IconData get goalIcon => IconData(icon, fontFamily: 'MaterialIcons');

  /// Rótulo do tipo de meta.
  String get typeLabel {
    switch (type) {
      case GoalType.savings:    return 'Economia';
      case GoalType.debt:       return 'Dívida';
      case GoalType.investment: return 'Investimento';
      case GoalType.spending:   return 'Controle de gastos';
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory GoalModel.fromMap(Map<String, dynamic> map, String id) {
    return GoalModel(
      id:           id,
      title:        (map['title'] as String? ?? '').trim(),
      type:         _parseType(map['type'] as String? ?? 'savings'),
      targetValue:  (map['targetValue'] as num?)?.toDouble() ?? 0,
      currentValue: (map['currentValue'] as num?)?.toDouble() ?? 0,
      createdAt:    (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deadline:     (map['deadline'] as Timestamp?)?.toDate(),
      description:  map['description'] as String?,
      color:        (map['color'] as int?) ?? const Color(0xFF1D4ED8).toARGB32(),
      icon:         (map['icon'] as int?) ?? Icons.flag_outlined.codePoint,
      status:       _parseStatus(map['status'] as String? ?? 'active'),
    );
  }

  Map<String, dynamic> toMap() => {
        'title':        title,
        'type':         type.name,
        'targetValue':  targetValue,
        'currentValue': currentValue,
        'createdAt':    Timestamp.fromDate(createdAt),
        'deadline':     deadline != null ? Timestamp.fromDate(deadline!) : null,
        'description':  description,
        'color':        color,
        'icon':         icon,
        'status':       status.name,
      };

  // ── copyWith ───────────────────────────────────────────────────────────────

  GoalModel copyWith({
    String?     title,
    GoalType?   type,
    double?     targetValue,
    double?     currentValue,
    DateTime?   deadline,
    String?     description,
    int?        color,
    int?        icon,
    GoalStatus? status,
  }) =>
      GoalModel(
        id:           id,
        title:        title ?? this.title,
        type:         type ?? this.type,
        targetValue:  targetValue ?? this.targetValue,
        currentValue: currentValue ?? this.currentValue,
        createdAt:    createdAt,
        deadline:     deadline ?? this.deadline,
        description:  description ?? this.description,
        color:        color ?? this.color,
        icon:         icon ?? this.icon,
        status:       status ?? this.status,
      );

  // ── Helpers privados ───────────────────────────────────────────────────────

  static GoalType _parseType(String value) {
    switch (value) {
      case 'debt':       return GoalType.debt;
      case 'investment': return GoalType.investment;
      case 'spending':   return GoalType.spending;
      default:           return GoalType.savings;
    }
  }

  static GoalStatus _parseStatus(String value) {
    switch (value) {
      case 'completed': return GoalStatus.completed;
      case 'archived':  return GoalStatus.archived;
      default:          return GoalStatus.active;
    }
  }
}
