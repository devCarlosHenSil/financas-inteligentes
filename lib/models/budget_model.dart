import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Status de consumo do orçamento.
enum BudgetStatus {
  /// Consumo abaixo de 75% — dentro do esperado.
  ok,

  /// Consumo entre 75% e 99% — atenção.
  warning,

  /// Consumo ≥ 100% — limite atingido ou ultrapassado.
  exceeded,
}

/// Representa um orçamento mensal para uma categoria de saída.
///
/// ## Campos
/// - [categoria]   → ex.: "Alimentação", "Lazer"
/// - [limite]      → valor máximo permitido no mês (R$)
/// - [gasto]       → valor já gasto no período (calculado externamente)
/// - [mes]         → mês/ano de referência (dia sempre = 1)
///
/// ## Computed
/// - [progresso]   → 0.0 – N (pode ultrapassar 1.0)
/// - [status]      → ok / warning / exceeded
/// - [restante]    → quanto ainda pode gastar (pode ser negativo)
class BudgetModel {
  const BudgetModel({
    required this.id,
    required this.categoria,
    required this.limite,
    required this.mes,
    this.gasto = 0,
  });

  final String   id;
  final String   categoria;
  final double   limite;
  final DateTime mes;

  /// Valor gasto no período — preenchido pelo provider, não persistido.
  final double gasto;

  // ── Computed ───────────────────────────────────────────────────────────────

  double get progresso => limite > 0 ? gasto / limite : 0;
  double get progressoPercent => progresso * 100;
  double get restante => limite - gasto;

  BudgetStatus get status {
    if (progresso >= 1.0) return BudgetStatus.exceeded;
    if (progresso >= 0.75) return BudgetStatus.warning;
    return BudgetStatus.ok;
  }

  bool get isExceeded => status == BudgetStatus.exceeded;
  bool get isWarning  => status == BudgetStatus.warning;
  bool get isOk       => status == BudgetStatus.ok;

  Color get statusColor {
    switch (status) {
      case BudgetStatus.exceeded: return const Color(0xFFDC2626); // red
      case BudgetStatus.warning:  return const Color(0xFFD97706); // amber
      case BudgetStatus.ok:       return const Color(0xFF059669); // green
    }
  }

  IconData get statusIcon {
    switch (status) {
      case BudgetStatus.exceeded: return Icons.error_outline;
      case BudgetStatus.warning:  return Icons.warning_amber_outlined;
      case BudgetStatus.ok:       return Icons.check_circle_outline;
    }
  }

  String get statusLabel {
    switch (status) {
      case BudgetStatus.exceeded: return 'Limite ultrapassado';
      case BudgetStatus.warning:  return 'Atenção — próximo do limite';
      case BudgetStatus.ok:       return 'Dentro do orçamento';
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  factory BudgetModel.fromMap(Map<String, dynamic> map, String id) {
    return BudgetModel(
      id:        id,
      categoria: (map['categoria'] as String? ?? '').trim(),
      limite:    (map['limite'] as num?)?.toDouble() ?? 0,
      mes:       (map['mes'] as Timestamp?)?.toDate() ??
                 DateTime(DateTime.now().year, DateTime.now().month),
    );
  }

  Map<String, dynamic> toMap() => {
        'categoria': categoria,
        'limite':    limite,
        'mes':       Timestamp.fromDate(DateTime(mes.year, mes.month)),
      };

  BudgetModel copyWith({
    String?   categoria,
    double?   limite,
    DateTime? mes,
    double?   gasto,
  }) =>
      BudgetModel(
        id:        id,
        categoria: categoria ?? this.categoria,
        limite:    limite    ?? this.limite,
        mes:       mes       ?? this.mes,
        gasto:     gasto     ?? this.gasto,
      );

  BudgetModel withGasto(double gasto) => copyWith(gasto: gasto);
}
