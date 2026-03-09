import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingItemModel {
  final String id;
  final String nome;
  final double preco;
  final DateTime data;

  ShoppingItemModel({
    required this.id,
    required this.nome,
    required this.preco,
    required this.data,
  });

  factory ShoppingItemModel.fromMap(Map<String, dynamic> map, String id) {
    return ShoppingItemModel(
      id: id,
      nome: map['nome'],
      preco: map['preco'],
      data: (map['data'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'preco': preco,
      'data': Timestamp.fromDate(data),
    };
  }
}