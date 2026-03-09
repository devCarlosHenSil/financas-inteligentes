import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final double valor;
  final String tipo;
  final String categoria;
  final bool fixa;
  final DateTime data;
  final bool superfluo;

  TransactionModel({
    required this.id,
    required this.valor,
    required this.tipo,
    required this.categoria,
    required this.fixa,
    required this.data,
    this.superfluo = false,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      valor: map['valor'],
      tipo: map['tipo'],
      categoria: map['categoria'],
      fixa: map['fixa'],
      data: (map['data'] as Timestamp).toDate(),
      superfluo: map['superfluo'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'valor': valor,
      'tipo': tipo,
      'categoria': categoria,
      'fixa': fixa,
      'data': Timestamp.fromDate(data),
      'superfluo': superfluo,
    };
  }
}