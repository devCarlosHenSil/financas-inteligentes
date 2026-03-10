import 'package:cloud_firestore/cloud_firestore.dart';

class ProventoModel {
  ProventoModel({
    required this.id,
    required this.ativo,
    required this.tipoAtivo,
    required this.status,
    required this.tipoPagamento,
    required this.dataCom,
    required this.dataPagamento,
    required this.quantidade,
    required this.valorDiv,
    required this.valorTotal,
  });

  final String id;
  final String ativo;
  final String tipoAtivo;
  final String status;
  final String tipoPagamento;
  final DateTime dataCom;
  final DateTime dataPagamento;
  final double quantidade;
  final double valorDiv;
  final double valorTotal;

  factory ProventoModel.fromMap(Map<String, dynamic> map, String id) {
    final quantidade = (map['quantidade'] as num?)?.toDouble() ?? 0;
    final valorDiv = (map['valorDiv'] as num?)?.toDouble() ?? 0;
    final valorTotal = (map['valorTotal'] as num?)?.toDouble() ?? (quantidade * valorDiv);
    return ProventoModel(
      id: id,
      ativo: (map['ativo'] ?? '').toString(),
      tipoAtivo: (map['tipoAtivo'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      tipoPagamento: (map['tipoPagamento'] ?? '').toString(),
      dataCom: (map['dataCom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataPagamento: (map['dataPagamento'] as Timestamp?)?.toDate() ?? DateTime.now(),
      quantidade: quantidade,
      valorDiv: valorDiv,
      valorTotal: valorTotal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ativo': ativo,
      'tipoAtivo': tipoAtivo,
      'status': status,
      'tipoPagamento': tipoPagamento,
      'dataCom': Timestamp.fromDate(dataCom),
      'dataPagamento': Timestamp.fromDate(dataPagamento),
      'quantidade': quantidade,
      'valorDiv': valorDiv,
      'valorTotal': valorTotal,
    };
  }
}
