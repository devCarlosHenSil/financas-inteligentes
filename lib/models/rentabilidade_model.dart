import 'package:cloud_firestore/cloud_firestore.dart';

class RentabilidadeModel {
  RentabilidadeModel({
    required this.id,
    required this.data,
    required this.rentabilidade,
    required this.cdi,
  });

  final String id;
  final DateTime data;
  final double rentabilidade;
  final double cdi;

  factory RentabilidadeModel.fromMap(Map<String, dynamic> map, String id) {
    return RentabilidadeModel(
      id: id,
      data: (map['data'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rentabilidade: (map['rentabilidade'] as num?)?.toDouble() ?? 0,
      cdi: (map['cdi'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'data': Timestamp.fromDate(data),
      'rentabilidade': rentabilidade,
      'cdi': cdi,
    };
  }
}
