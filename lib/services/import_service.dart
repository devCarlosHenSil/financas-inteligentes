import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/rentabilidade_model.dart';
import 'package:http/http.dart' as http;

class ImportService {
  List<ProventoModel> parseProventosCsv(String content) {
    final rows = _parseCsv(content);
    if (rows.isEmpty) return [];

    final header = rows.first.map((e) => e.toString()).toList();
    final index = _buildHeaderIndex(header);

    final ativoIdx = _findIndex(index, ['ativo', 'ticker', 'codigo', 'código', 'papel', 'stock']);
    final tipoIdx = _findIndex(index, ['tipo de ativo', 'tipo ativo', 'categoria', 'classe']);
    final statusIdx = _findIndex(index, ['status', 'situacao', 'situação']);
    final tipoPagamentoIdx = _findIndex(index, ['tipo de pagamento', 'tipo pagamento', 'evento', 'tipo evento']);
    final dataComIdx = _findIndex(index, ['data com', 'data base', 'data corte', 'data de corte', 'data com data']);
    final dataPagamentoIdx = _findIndex(index, ['data pagamento', 'data de pagamento', 'pagamento']);
    final quantidadeIdx = _findIndex(index, ['quantidade', 'qtd', 'qtde']);
    final valorDivIdx = _findIndex(index, ['valor do div', 'valor do div.', 'valor unitario', 'valor unitário', 'valor por cota', 'valor provento']);
    final valorTotalIdx = _findIndex(index, ['valor total', 'total', 'total liquido', 'total líquido', 'valor liquido', 'valor líquido']);

    final results = <ProventoModel>[];
    for (final row in rows.skip(1)) {
      final ativo = _cell(row, ativoIdx);
      if (ativo.trim().isEmpty) continue;

      final tipoAtivo = _cell(row, tipoIdx);
      final status = _cell(row, statusIdx);
      final tipoPagamento = _cell(row, tipoPagamentoIdx);
      final dataCom = _parseDate(_cell(row, dataComIdx));
      final dataPagamento = _parseDate(_cell(row, dataPagamentoIdx));
      final quantidade = _parseNumber(_cell(row, quantidadeIdx));
      final valorDiv = _parseNumber(_cell(row, valorDivIdx));
      final valorTotalCell = _parseNumber(_cell(row, valorTotalIdx));
      final total = valorTotalCell > 0 ? valorTotalCell : quantidade * valorDiv;

      results.add(
        ProventoModel(
          id: '',
          ativo: ativo.trim(),
          tipoAtivo: tipoAtivo.trim().isEmpty ? 'Outros' : tipoAtivo.trim(),
          status: status.trim().isEmpty ? _inferStatus(dataPagamento) : status.trim(),
          tipoPagamento: tipoPagamento.trim().isEmpty ? 'Provento' : tipoPagamento.trim(),
          dataCom: dataCom ?? dataPagamento ?? DateTime.now(),
          dataPagamento: dataPagamento ?? dataCom ?? DateTime.now(),
          quantidade: quantidade,
          valorDiv: valorDiv,
          valorTotal: total,
        ),
      );
    }
    return results;
  }

  List<RentabilidadeModel> parseRentabilidadeCsv(String content) {
    final rows = _parseCsv(content);
    if (rows.isEmpty) return [];

    final header = rows.first.map((e) => e.toString()).toList();
    final index = _buildHeaderIndex(header);

    final dataIdx = _findIndex(index, ['data', 'mes', 'mês', 'competencia', 'competência']);
    final rentIdx = _findIndex(index, ['rentabilidade', 'retorno', 'carteira']);
    final cdiIdx = _findIndex(index, ['cdi']);

    final results = <RentabilidadeModel>[];
    for (final row in rows.skip(1)) {
      final date = _parseDate(_cell(row, dataIdx));
      if (date == null) continue;
      final rent = _parseNumber(_cell(row, rentIdx));
      final cdi = _parseNumber(_cell(row, cdiIdx));
      results.add(
        RentabilidadeModel(
          id: '',
          data: DateTime(date.year, date.month, 1),
          rentabilidade: rent,
          cdi: cdi,
        ),
      );
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> fetchJsonList(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar dados da API.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    throw Exception('Formato de API inválido. Use uma lista JSON.');
  }

  List<ProventoModel> parseProventosJson(List<Map<String, dynamic>> items) {
    return items.map((item) => _parseProventoMap(item)).whereType<ProventoModel>().toList();
  }

  List<RentabilidadeModel> parseRentabilidadeJson(List<Map<String, dynamic>> items) {
    return items.map((item) => _parseRentabilidadeMap(item)).whereType<RentabilidadeModel>().toList();
  }

  ProventoModel? _parseProventoMap(Map<String, dynamic> item) {
    final ativo = (item['ativo'] ?? item['ticker'] ?? item['codigo'] ?? '').toString();
    if (ativo.trim().isEmpty) return null;
    final tipoAtivo = (item['tipoAtivo'] ?? item['tipo_ativo'] ?? item['categoria'] ?? 'Outros').toString();
    final status = (item['status'] ?? '').toString();
    final tipoPagamento = (item['tipoPagamento'] ?? item['tipo_pagamento'] ?? item['evento'] ?? 'Provento').toString();
    final dataCom = _parseDate(item['dataCom'] ?? item['data_com'] ?? item['dataBase'] ?? item['data_base']);
    final dataPagamento = _parseDate(item['dataPagamento'] ?? item['data_pagamento'] ?? item['data']);
    final quantidade = _parseNumber(item['quantidade'] ?? item['qtd']);
    final valorDiv = _parseNumber(item['valorDiv'] ?? item['valor_div'] ?? item['valorUnitario'] ?? item['valor_unitario']);
    final valorTotal = _parseNumber(item['valorTotal'] ?? item['valor_total'] ?? item['total']);
    final total = valorTotal > 0 ? valorTotal : quantidade * valorDiv;

    return ProventoModel(
      id: '',
      ativo: ativo.trim(),
      tipoAtivo: tipoAtivo.trim(),
      status: status.trim().isEmpty ? _inferStatus(dataPagamento) : status.trim(),
      tipoPagamento: tipoPagamento.trim(),
      dataCom: dataCom ?? dataPagamento ?? DateTime.now(),
      dataPagamento: dataPagamento ?? dataCom ?? DateTime.now(),
      quantidade: quantidade,
      valorDiv: valorDiv,
      valorTotal: total,
    );
  }

  RentabilidadeModel? _parseRentabilidadeMap(Map<String, dynamic> item) {
    final date = _parseDate(item['data'] ?? item['mes'] ?? item['competencia'] ?? item['competência']);
    if (date == null) return null;
    final rent = _parseNumber(item['rentabilidade'] ?? item['retorno'] ?? item['carteira']);
    final cdi = _parseNumber(item['cdi']);
    return RentabilidadeModel(
      id: '',
      data: DateTime(date.year, date.month, 1),
      rentabilidade: rent,
      cdi: cdi,
    );
  }

  List<List<dynamic>> _parseCsv(String content) {
    final delimiter = _detectDelimiter(content);
    final converter = CsvToListConverter(fieldDelimiter: delimiter, eol: '\n');
    return converter.convert(content);
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split('\n').first;
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    return semicolons >= commas ? ';' : ',';
  }

  Map<String, int> _buildHeaderIndex(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      map[_cleanHeader(header[i])] = i;
    }
    return map;
  }

  int _findIndex(Map<String, int> header, List<String> candidates) {
    for (final candidate in candidates) {
      final key = _cleanHeader(candidate);
      if (header.containsKey(key)) return header[key]!;
    }
    for (final entry in header.entries) {
      for (final candidate in candidates) {
        if (entry.key.contains(_cleanHeader(candidate))) {
          return entry.value;
        }
      }
    }
    return -1;
  }

  String _cleanHeader(String value) => value.trim().toLowerCase();

  String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final numeric = RegExp(r'^\d+$');
    if (numeric.hasMatch(raw) && raw.length == 8) {
      final year = int.tryParse(raw.substring(0, 4));
      final month = int.tryParse(raw.substring(4, 6));
      final day = int.tryParse(raw.substring(6, 8));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }

    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(raw)) {
      final parts = raw.split('/');
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
    if (RegExp(r'^\d{2}/\d{4}$').hasMatch(raw)) {
      final parts = raw.split('/');
      return DateTime(int.parse(parts[1]), int.parse(parts[0]), 1);
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return DateTime.parse(raw);
    }
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) {
      final parts = raw.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    }
    return null;
  }

  double _parseNumber(dynamic value) {
    if (value == null) return 0;
    var raw = value.toString().trim();
    if (raw.isEmpty) return 0;
    raw = raw.replaceAll('%', '');
    raw = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (raw.contains(',') && raw.contains('.')) {
      if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }
    return double.tryParse(raw) ?? 0;
  }

  String _inferStatus(DateTime? dataPagamento) {
    if (dataPagamento == null) return 'A Receber';
    return dataPagamento.isBefore(DateTime.now()) ? 'Pago' : 'A Receber';
  }
}
