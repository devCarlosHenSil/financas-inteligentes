import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financas_inteligentes/models/budget_model.dart';
import 'package:financas_inteligentes/models/goal_model.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ── getter dinâmico — avaliado a cada chamada ─────────────────────────────
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Nenhum usuário autenticado.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _col(String path) =>
      db.collection('usuarios/$_uid/$path');

  // ── Transações ────────────────────────────────────────────────────────────

  Future<void> addTransaction(TransactionModel trans) async {
    await _col('transacoes').add(trans.toMap());
  }

  Future<void> updateTransaction(String id, TransactionModel trans) async {
    await _col('transacoes').doc(id).update(trans.toMap());
  }

  Future<void> deleteTransaction(String id) async {
    await _col('transacoes').doc(id).delete();
  }

  Stream<List<TransactionModel>> getTransactions() {
    return _col('transacoes').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<double> getTotalEntradas(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) =>
            t.tipo == 'entrada' &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (double acc, t) => acc + t.valor);
  }

  Future<double> getTotalSaidas(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) =>
            t.tipo == 'saida' &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (double acc, t) => acc + t.valor);
  }

  Future<double> getTotalSuperfluos(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) =>
            t.superfluo &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (double acc, t) => acc + t.valor);
  }

  // ── Investimentos ─────────────────────────────────────────────────────────

  Future<void> addInvestment(InvestmentModel inv) async {
    await _col('investimentos').add(inv.toMap());
  }

  Future<void> deleteInvestment(String id) async {
    await _col('investimentos').doc(id).delete();
  }

  Stream<List<InvestmentModel>> getInvestments() {
    return _col('investimentos').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => InvestmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ── Proventos ─────────────────────────────────────────────────────────────

  Future<void> addProvento(ProventoModel provento) async {
    await _col('proventos').add(provento.toMap());
  }

  Future<void> deleteProvento(String id) async {
    await _col('proventos').doc(id).delete();
  }

  Stream<List<ProventoModel>> getProventos() {
    return _col('proventos').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => ProventoModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<ProventoModel>> getProventosOnce() async {
    final snapshot = await _col('proventos').get();
    return snapshot.docs
        .map((doc) => ProventoModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addProventosBatch(List<ProventoModel> items) async {
    if (items.isEmpty) return;
    final batch = db.batch();
    final col = _col('proventos');
    for (final item in items) {
      batch.set(col.doc(), item.toMap());
    }
    await batch.commit();
  }

  // ── Rentabilidade ─────────────────────────────────────────────────────────

  Future<void> addRentabilidade(RentabilidadeModel rentabilidade) async {
    await _col('rentabilidade').add(rentabilidade.toMap());
  }

  Future<void> deleteRentabilidade(String id) async {
    await _col('rentabilidade').doc(id).delete();
  }

  Stream<List<RentabilidadeModel>> getRentabilidade() {
    return _col('rentabilidade').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => RentabilidadeModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<List<RentabilidadeModel>> getRentabilidadeOnce() async {
    final snapshot = await _col('rentabilidade').get();
    return snapshot.docs
        .map((doc) => RentabilidadeModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> addRentabilidadeBatch(List<RentabilidadeModel> items) async {
    if (items.isEmpty) return;
    final batch = db.batch();
    final col = _col('rentabilidade');
    for (final item in items) {
      batch.set(col.doc(), item.toMap());
    }
    await batch.commit();
  }

  // ── Lista de Compras ──────────────────────────────────────────────────────

  Future<void> addShoppingItem(ShoppingItemModel item) async {
    await _col('lista_compras').add(item.toMap());
  }

  Future<void> removeShoppingItem(String id) async {
    await _col('lista_compras').doc(id).delete();
  }

  Stream<List<ShoppingItemModel>> getShoppingItems() {
    return _col('lista_compras').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => ShoppingItemModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<double> getAveragePrice(String nome, DateTime mes) async {
    final snapshot = await _col('lista_compras').get();
    final items = snapshot.docs
        .map((doc) => ShoppingItemModel.fromMap(doc.data(), doc.id))
        .where((i) =>
            i.nome == nome &&
            i.data.month == mes.month &&
            i.data.year == mes.year);
    if (items.isEmpty) return 0.0;
    return items.fold<double>(0.0, (acc, i) => acc + i.preco) / items.length;
  }

  // ── Metas Financeiras ─────────────────────────────────────────────────────

  Future<void> addGoal(GoalModel goal) async {
    await _col('metas').add(goal.toMap());
  }

  Future<void> updateGoal(String id, GoalModel goal) async {
    await _col('metas').doc(id).update(goal.toMap());
  }

  Future<void> deleteGoal(String id) async {
    await _col('metas').doc(id).delete();
  }

  Stream<List<GoalModel>> getGoals() {
    return _col('metas')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs
                .map((doc) => GoalModel.fromMap(doc.data(), doc.id))
                .toList());
  }

  // ── Orçamentos por Categoria ──────────────────────────────────────────────

  Future<void> addBudget(BudgetModel budget) async {
    await _col('orcamentos').add(budget.toMap());
  }

  Future<void> updateBudget(String id, BudgetModel budget) async {
    await _col('orcamentos').doc(id).update(budget.toMap());
  }

  Future<void> deleteBudget(String id) async {
    await _col('orcamentos').doc(id).delete();
  }

  /// Retorna todos os orçamentos de um mês/ano específico.
  Stream<List<BudgetModel>> getBudgets(DateTime mes) {
    final inicio = Timestamp.fromDate(DateTime(mes.year, mes.month));
    final fim    = Timestamp.fromDate(DateTime(mes.year, mes.month + 1));
    return _col('orcamentos')
        .where('mes', isGreaterThanOrEqualTo: inicio)
        .where('mes', isLessThan: fim)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BudgetModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Copia orçamentos de um mês para outro (útil para replicar configuração).
  Future<void> copiarOrcamentos(DateTime deMes, DateTime paraMes) async {
    final snap = await _col('orcamentos')
        .where('mes',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(DateTime(deMes.year, deMes.month)))
        .where('mes',
            isLessThan:
                Timestamp.fromDate(DateTime(deMes.year, deMes.month + 1)))
        .get();

    if (snap.docs.isEmpty) return;
    final batch = db.batch();
    final col   = _col('orcamentos');
    for (final doc in snap.docs) {
      final original = BudgetModel.fromMap(doc.data(), doc.id);
      batch.set(
        col.doc(),
        original.copyWith(mes: DateTime(paraMes.year, paraMes.month)).toMap(),
      );
    }
    await batch.commit();
  }
}
