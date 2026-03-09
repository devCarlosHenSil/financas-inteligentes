import 'package:cloud_firestore/cloud_firestore.dart';

class InvestmentModel {
  final String id;
  final String nome;
  final double valorInvestido;
  final DateTime data;

  InvestmentModel({
    required this.id,
    required this.nome,
    required this.valorInvestido,
    required this.data,
  });

  factory InvestmentModel.fromMap(Map<String, dynamic> map, String id) {
    return InvestmentModel(
      id: id,
      nome: map['nome'],
      valorInvestido: map['valorInvestido'],
      data: (map['data'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'valorInvestido': valorInvestido,
      'data': Timestamp.fromDate(data),
    };
  }
}