import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── CORREÇÃO DO BUG: userId como getter dinâmico ─────────────────────────
  // Antes: `final String? userId = FirebaseAuth.instance.currentUser?.uid`
  // Problema: capturado uma única vez no construtor → após logout/login o
  // ID ficava stale (apontando para o usuário anterior ou null).
  // Agora: avaliado a cada chamada, sempre refletindo o usuário corrente.
  String get _userId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Nenhum usuário autenticado.');
    return uid;
  }

  // ── Helpers internos ─────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String path) =>
      _db.collection('usuarios/$_userId/$path');

  // ── Transações ───────────────────────────────────────────────────────────

  Future<void> addTransaction(TransactionModel trans) async =>
      _col('transacoes').add(trans.toMap());

  Future<void> updateTransaction(String id, TransactionModel trans) async =>
      _col('transacoes').doc(id).update(trans.toMap());

  Future<void> deleteTransaction(String id) async =>
      _col('transacoes').doc(id).delete();

  Stream<List<TransactionModel>> getTransactions() =>
      _col('transacoes').snapshots().map((s) =>
          s.docs.map((d) => TransactionModel.fromMap(d.data(), d.id)).toList());

  Future<double> getTotalEntradas(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((d) => TransactionModel.fromMap(d.data(), d.id))
        .where((t) =>
            t.tipo == 'entrada' &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSaidas(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((d) => TransactionModel.fromMap(d.data(), d.id))
        .where((t) =>
            t.tipo == 'saida' &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSuperfluos(DateTime mes) async {
    final snapshot = await _col('transacoes').get();
    return snapshot.docs
        .map((d) => TransactionModel.fromMap(d.data(), d.id))
        .where((t) =>
            t.superfluo &&
            t.data.month == mes.month &&
            t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  // ── Investimentos ─────────────────────────────────────────────────────────

  Future<void> addInvestment(InvestmentModel inv) async =>
      _col('investimentos').add(inv.toMap());

  Future<void> deleteInvestment(String id) async =>
      _col('investimentos').doc(id).delete();

  Stream<List<InvestmentModel>> getInvestments() =>
      _col('investimentos').snapshots().map((s) =>
          s.docs.map((d) => InvestmentModel.fromMap(d.data(), d.id)).toList());

  // ── Proventos ─────────────────────────────────────────────────────────────

  Future<void> addProvento(ProventoModel provento) async =>
      _col('proventos').add(provento.toMap());

  Future<void> deleteProvento(String id) async =>
      _col('proventos').doc(id).delete();

  Stream<List<ProventoModel>> getProventos() =>
      _col('proventos').snapshots().map((s) =>
          s.docs.map((d) => ProventoModel.fromMap(d.data(), d.id)).toList());

  Future<List<ProventoModel>> getProventosOnce() async {
    final s = await _col('proventos').get();
    return s.docs.map((d) => ProventoModel.fromMap(d.data(), d.id)).toList();
  }

  Future<void> addProventosBatch(List<ProventoModel> items) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    final col = _col('proventos');
    for (final item in items) {
      batch.set(col.doc(), item.toMap());
    }
    await batch.commit();
  }

  // ── Rentabilidade ─────────────────────────────────────────────────────────

  Future<void> addRentabilidade(RentabilidadeModel r) async =>
      _col('rentabilidade').add(r.toMap());

  Future<void> deleteRentabilidade(String id) async =>
      _col('rentabilidade').doc(id).delete();

  Stream<List<RentabilidadeModel>> getRentabilidade() =>
      _col('rentabilidade').snapshots().map((s) =>
          s.docs
              .map((d) => RentabilidadeModel.fromMap(d.data(), d.id))
              .toList());

  Future<List<RentabilidadeModel>> getRentabilidadeOnce() async {
    final s = await _col('rentabilidade').get();
    return s.docs
        .map((d) => RentabilidadeModel.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> addRentabilidadeBatch(List<RentabilidadeModel> items) async {
    if (items.isEmpty) return;
    final batch = _db.batch();
    final col = _col('rentabilidade');
    for (final item in items) {
      batch.set(col.doc(), item.toMap());
    }
    await batch.commit();
  }

  // ── Lista de Compras ──────────────────────────────────────────────────────

  Future<void> addShoppingItem(ShoppingItemModel item) async =>
      _col('lista_compras').add(item.toMap());

  Future<void> removeShoppingItem(String id) async =>
      _col('lista_compras').doc(id).delete();

  Stream<List<ShoppingItemModel>> getShoppingItems() =>
      _col('lista_compras').snapshots().map((s) =>
          s.docs
              .map((d) => ShoppingItemModel.fromMap(d.data(), d.id))
              .toList());

  Future<double> getAveragePrice(String nome, DateTime mes) async {
    final s = await _col('lista_compras').get();
    final items = s.docs
        .map((d) => ShoppingItemModel.fromMap(d.data(), d.id))
        .where((i) =>
            i.nome == nome &&
            i.data.month == mes.month &&
            i.data.year == mes.year)
        .toList();
    if (items.isEmpty) return 0.0;
    return items.fold<double>(0.0, (acc, i) => acc + i.preco) / items.length;
  }
}
