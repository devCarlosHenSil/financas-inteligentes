import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';

class FirestoreService {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  // ── getter dinâmico — avaliado a cada chamada ─────────────────────────────
  // BUG CORRIGIDO: antes era `final String? userId = ...` (capturado uma única
  // vez no construtor). Após logout/login, o campo ficava com o UID antigo,
  // apontando para a coleção do usuário anterior.
  // Agora lança StateError claro se chamado sem sessão ativa.
  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Nenhum usuário autenticado.');
    return uid;
  }

  // Atalho para a coleção raiz do usuário corrente
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
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSaidas(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) =>
            t.tipo == 'saida' &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSuperfluos(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) =>
            t.superfluo &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
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
}
