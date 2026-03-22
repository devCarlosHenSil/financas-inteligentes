// test/models/models_test.dart
//
// Testa os modelos de dados sem dependência de Firebase.
// Foca em: construção, serialização toMap, computed getters.

import 'package:flutter_test/flutter_test.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/models/goal_model.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';

void main() {
  // ── TransactionModel ────────────────────────────────────────────────────────

  group('TransactionModel', () {
    final now = DateTime(2025, 6, 15);

    TransactionModel makeTransaction({
      String tipo = 'entrada',
      double valor = 1500.0,
      String categoria = 'Crédito de Salário',
      bool fixa = true,
      bool superfluo = false,
    }) {
      return TransactionModel(
        id: 'tx-001',
        valor: valor,
        tipo: tipo,
        categoria: categoria,
        fixa: fixa,
        data: now,
        superfluo: superfluo,
      );
    }

    test('cria transação de entrada com valores corretos', () {
      final t = makeTransaction();
      expect(t.id, 'tx-001');
      expect(t.valor, 1500.0);
      expect(t.tipo, 'entrada');
      expect(t.categoria, 'Crédito de Salário');
      expect(t.fixa, isTrue);
      expect(t.superfluo, isFalse);
    });

    test('cria transação de saída supérflua', () {
      final t = makeTransaction(
        tipo: 'saida',
        valor: 89.90,
        categoria: 'Uber',
        fixa: false,
        superfluo: true,
      );
      expect(t.tipo, 'saida');
      expect(t.superfluo, isTrue);
      expect(t.fixa, isFalse);
    });

    test('toMap contém todas as chaves obrigatórias', () {
      final map = makeTransaction().toMap();
      expect(map.containsKey('valor'), isTrue);
      expect(map.containsKey('tipo'), isTrue);
      expect(map.containsKey('categoria'), isTrue);
      expect(map.containsKey('fixa'), isTrue);
      expect(map.containsKey('data'), isTrue);
      expect(map.containsKey('superfluo'), isTrue);
    });

    test('toMap não inclui o id (campo Firestore)', () {
      final map = makeTransaction().toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('valor zero é aceito', () {
      final t = makeTransaction(valor: 0.0);
      expect(t.valor, 0.0);
    });

    test('superfluo default é false', () {
      final t = TransactionModel(
        id: 'x',
        valor: 100,
        tipo: 'saida',
        categoria: 'Outros',
        fixa: false,
        data: now,
      );
      expect(t.superfluo, isFalse);
    });
  });

  // ── GoalModel ────────────────────────────────────────────────────────────────

  group('GoalModel', () {
    final now = DateTime(2025, 6, 15);

    GoalModel makeGoal({
      double targetValue = 10000.0,
      double currentValue = 5000.0,
      GoalStatus status = GoalStatus.active,
      DateTime? deadline,
    }) {
      return GoalModel(
        id: 'goal-001',
        title: 'Reserva de Emergência',
        type: GoalType.savings,
        targetValue: targetValue,
        currentValue: currentValue,
        createdAt: now,
        deadline: deadline,
        color: 0xFF1D4ED8,
        icon: 0xe570,
        status: status,
      );
    }

    test('progresso é calculado corretamente (50%)', () {
      final g = makeGoal(targetValue: 10000, currentValue: 5000);
      expect(g.progress, closeTo(0.5, 0.001));
      expect(g.progressPercent, closeTo(50.0, 0.001));
    });

    test('progresso é 0 quando targetValue é 0', () {
      final g = makeGoal(targetValue: 0, currentValue: 100);
      expect(g.progress, 0.0);
    });

    test('progresso é clampado em 1.0 quando currentValue > targetValue', () {
      final g = makeGoal(targetValue: 1000, currentValue: 1500);
      expect(g.progress, 1.0);
    });

    test('remaining calcula o valor faltante corretamente', () {
      final g = makeGoal(targetValue: 10000, currentValue: 3000);
      expect(g.remaining, closeTo(7000.0, 0.001));
    });

    test('remaining é 0 quando meta concluída', () {
      final g = makeGoal(targetValue: 1000, currentValue: 1000);
      expect(g.remaining, 0.0);
    });

    test('isCompleted retorna true quando progresso >= 1.0', () {
      final g = makeGoal(targetValue: 1000, currentValue: 1000);
      expect(g.isCompleted, isTrue);
    });

    test('isCompleted retorna true quando status == completed', () {
      final g = makeGoal(status: GoalStatus.completed);
      expect(g.isCompleted, isTrue);
    });

    test('isActive retorna true apenas para status active', () {
      expect(makeGoal(status: GoalStatus.active).isActive, isTrue);
      expect(makeGoal(status: GoalStatus.completed).isActive, isFalse);
      expect(makeGoal(status: GoalStatus.archived).isActive, isFalse);
    });

    test('isOverdue retorna true quando prazo passou e não concluiu', () {
      final g = makeGoal(
        deadline: now.subtract(const Duration(days: 5)),
        currentValue: 500,
        targetValue: 10000,
      );
      expect(g.isOverdue, isTrue);
    });

    test('isOverdue retorna false quando concluída mesmo com prazo passado', () {
      final g = makeGoal(
        deadline: now.subtract(const Duration(days: 5)),
        currentValue: 10000,
        targetValue: 10000,
      );
      expect(g.isOverdue, isFalse);
    });

    test('isOverdue retorna false quando sem prazo', () {
      final g = makeGoal();
      expect(g.isOverdue, isFalse);
    });

    test('daysRemaining retorna null quando sem prazo', () {
      final g = makeGoal();
      expect(g.daysRemaining, isNull);
    });

    test('copyWith altera apenas os campos especificados', () {
      final original = makeGoal(targetValue: 10000, currentValue: 5000);
      final updated  = original.copyWith(currentValue: 8000);
      expect(updated.currentValue, 8000);
      expect(updated.targetValue, 10000);
      expect(updated.title, original.title);
      expect(updated.id, original.id);
    });

    test('toMap contém todas as chaves obrigatórias', () {
      final map = makeGoal().toMap();
      for (final key in [
        'title', 'type', 'targetValue', 'currentValue',
        'createdAt', 'color', 'icon', 'status',
      ]) {
        expect(map.containsKey(key), isTrue, reason: 'Faltou chave: $key');
      }
    });

    test('typeLabel retorna string correta para cada tipo', () {
      expect(GoalModel(id: '', title: '', type: GoalType.savings,
          targetValue: 0, currentValue: 0, createdAt: now,
          color: 0, icon: 0, status: GoalStatus.active).typeLabel,
          'Economia');
      expect(GoalModel(id: '', title: '', type: GoalType.debt,
          targetValue: 0, currentValue: 0, createdAt: now,
          color: 0, icon: 0, status: GoalStatus.active).typeLabel,
          'Dívida');
      expect(GoalModel(id: '', title: '', type: GoalType.investment,
          targetValue: 0, currentValue: 0, createdAt: now,
          color: 0, icon: 0, status: GoalStatus.active).typeLabel,
          'Investimento');
    });
  });

  // ── InvestmentModel ──────────────────────────────────────────────────────────

  group('InvestmentModel', () {
    final now = DateTime(2025, 3, 10);

    test('cria investimento com valores corretos', () {
      final inv = InvestmentModel(
        id: 'inv-001',
        nome: 'Ações • PETR4 • Compra',
        valorInvestido: 1250.0,
        data: now,
      );
      expect(inv.id, 'inv-001');
      expect(inv.nome, 'Ações • PETR4 • Compra');
      expect(inv.valorInvestido, 1250.0);
    });

    test('toMap contém nome, valorInvestido e data', () {
      final map = InvestmentModel(
        id: 'x',
        nome: 'FIIs • MXRF11 • Compra',
        valorInvestido: 500.0,
        data: now,
      ).toMap();
      expect(map['nome'], 'FIIs • MXRF11 • Compra');
      expect(map['valorInvestido'], 500.0);
      expect(map.containsKey('data'), isTrue);
    });

    test('valor negativo representa venda', () {
      final inv = InvestmentModel(
        id: 'inv-002',
        nome: 'Ações • VALE3 • Venda',
        valorInvestido: -800.0,
        data: now,
      );
      expect(inv.valorInvestido, isNegative);
    });
  });

  // ── ProventoModel ────────────────────────────────────────────────────────────

  group('ProventoModel', () {
    final now = DateTime(2025, 6, 1);

    test('cria provento com valores corretos', () {
      final p = ProventoModel(
        id: 'prov-001',
        ativo: 'MXRF11',
        tipoAtivo: 'FIIs',
        status: 'Pago',
        tipoPagamento: 'Rendimento',
        dataCom: now,
        dataPagamento: now.add(const Duration(days: 5)),
        quantidade: 100,
        valorDiv: 0.11,
        valorTotal: 11.0,
      );
      expect(p.ativo, 'MXRF11');
      expect(p.valorTotal, 11.0);
      expect(p.quantidade, 100);
    });

    test('toMap contém todas as chaves obrigatórias', () {
      final map = ProventoModel(
        id: '',
        ativo: 'HGLG11',
        tipoAtivo: 'FIIs',
        status: 'A Receber',
        tipoPagamento: 'Dividendo',
        dataCom: now,
        dataPagamento: now,
        quantidade: 50,
        valorDiv: 0.95,
        valorTotal: 47.50,
      ).toMap();

      for (final key in [
        'ativo', 'tipoAtivo', 'status', 'tipoPagamento',
        'dataCom', 'dataPagamento', 'quantidade', 'valorDiv', 'valorTotal',
      ]) {
        expect(map.containsKey(key), isTrue, reason: 'Faltou chave: $key');
      }
    });
  });

  // ── ShoppingItemModel ────────────────────────────────────────────────────────

  group('ShoppingItemModel', () {
    test('cria item de compra com valores corretos', () {
      final item = ShoppingItemModel(
        id: 'shop-001',
        nome: 'Arroz',
        preco: 24.90,
        data: DateTime(2025, 6, 1),
      );
      expect(item.nome, 'Arroz');
      expect(item.preco, 24.90);
    });

    test('toMap contém nome, preco e data', () {
      final map = ShoppingItemModel(
        id: 'x',
        nome: 'Feijão',
        preco: 8.50,
        data: DateTime(2025, 6, 1),
      ).toMap();
      expect(map['nome'], 'Feijão');
      expect(map['preco'], 8.50);
      expect(map.containsKey('data'), isTrue);
    });
  });
}
