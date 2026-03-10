import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';

class FirestoreService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> addTransaction(TransactionModel trans) async {
    await db.collection('usuarios/$userId/transacoes').add(trans.toMap());
  }

  Future<void> updateTransaction(String id, TransactionModel trans) async {
    await db.collection('usuarios/$userId/transacoes').doc(id).update(trans.toMap());
  }

  Future<void> deleteTransaction(String id) async {
    await db.collection('usuarios/$userId/transacoes').doc(id).delete();
  }

  Stream<List<TransactionModel>> getTransactions() {
    return db.collection('usuarios/$userId/transacoes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<double> getTotalEntradas(DateTime mes) async {
    final snapshot = await db.collection('usuarios/$userId/transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) => t.tipo == 'entrada' && t.data.month == mes.month && t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSaidas(DateTime mes) async {
    final snapshot = await db.collection('usuarios/$userId/transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) => t.tipo == 'saida' && t.data.month == mes.month && t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<double> getTotalSuperfluos(DateTime mes) async {
    final snapshot = await db.collection('usuarios/$userId/transacoes').get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
        .where((t) => t.superfluo && t.data.month == mes.month && t.data.year == mes.year)
        .fold<double>(0.0, (acc, t) => acc + t.valor);
  }

  Future<void> addInvestment(InvestmentModel inv) async {
    await db.collection('usuarios/$userId/investimentos').add(inv.toMap());
  }


  Future<void> deleteInvestment(String id) async {
    await db.collection('usuarios/$userId/investimentos').doc(id).delete();
  }

  Stream<List<InvestmentModel>> getInvestments() {
    return db.collection('usuarios/$userId/investimentos').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => InvestmentModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addProvento(ProventoModel provento) async {
    await db.collection('usuarios/$userId/proventos').add(provento.toMap());
  }

  Future<void> deleteProvento(String id) async {
    await db.collection('usuarios/$userId/proventos').doc(id).delete();
  }

  Stream<List<ProventoModel>> getProventos() {
    return db.collection('usuarios/$userId/proventos').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ProventoModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addRentabilidade(RentabilidadeModel rentabilidade) async {
    await db.collection('usuarios/$userId/rentabilidade').add(rentabilidade.toMap());
  }

  Future<void> deleteRentabilidade(String id) async {
    await db.collection('usuarios/$userId/rentabilidade').doc(id).delete();
  }

  Stream<List<RentabilidadeModel>> getRentabilidade() {
    return db.collection('usuarios/$userId/rentabilidade').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RentabilidadeModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addShoppingItem(ShoppingItemModel item) async {
    await db.collection('usuarios/$userId/lista_compras').add(item.toMap());
  }

  Future<void> removeShoppingItem(String id) async {
    await db.collection('usuarios/$userId/lista_compras').doc(id).delete();
  }

  Stream<List<ShoppingItemModel>> getShoppingItems() {
    return db.collection('usuarios/$userId/lista_compras').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ShoppingItemModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<double> getAveragePrice(String nome, DateTime mes) async {
    final snapshot = await db.collection('usuarios/$userId/lista_compras').get();
    final items = snapshot.docs
        .map((doc) => ShoppingItemModel.fromMap(doc.data(), doc.id))
        .where((i) => i.nome == nome && i.data.month == mes.month && i.data.year == mes.year);
    if (items.isEmpty) return 0.0;
    return items.fold<double>(0.0, (acc, i) => acc + i.preco) / items.length;
  }
}
