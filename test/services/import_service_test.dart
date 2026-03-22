// test/services/import_service_test.dart
//
// Testa o ImportService: parsing de CSV/JSON de proventos e rentabilidade.
// Sem dependência de Firebase ou rede.

import 'package:flutter_test/flutter_test.dart';
import 'package:financas_inteligentes/services/import_service.dart';

void main() {
  late ImportService service;

  setUp(() => service = ImportService());

  // ── parseProventosCsv ────────────────────────────────────────────────────────

  group('ImportService.parseProventosCsv', () {
    test('CSV vazio retorna lista vazia', () {
      expect(service.parseProventosCsv(''), isEmpty);
    });

    test('CSV só com cabeçalho retorna lista vazia', () {
      const csv = 'ativo;tipo de ativo;status;tipo de pagamento;'
          'data com;data pagamento;quantidade;valor do div;valor total';
      expect(service.parseProventosCsv(csv), isEmpty);
    });

    test('parseia linha única com separador ponto-e-vírgula', () {
      const csv =
          'ativo;tipo de ativo;status;tipo de pagamento;data com;data pagamento;quantidade;valor do div;valor total\n'
          'MXRF11;FIIs;Pago;Rendimento;01/06/2025;05/06/2025;100;0,11;11,00';
      final result = service.parseProventosCsv(csv);
      expect(result, hasLength(1));
      expect(result.first.ativo, 'MXRF11');
      expect(result.first.tipoAtivo, 'FIIs');
      expect(result.first.status, 'Pago');
      expect(result.first.tipoPagamento, 'Rendimento');
      expect(result.first.quantidade, closeTo(100, 0.001));
      expect(result.first.valorDiv, closeTo(0.11, 0.001));
      expect(result.first.valorTotal, closeTo(11.0, 0.001));
    });

    test('parseia linha com separador vírgula', () {
      const csv =
          'ativo,tipo de ativo,status,tipo de pagamento,data com,data pagamento,quantidade,valor do div,valor total\n'
          'HGLG11,FIIs,Pago,Dividendo,15/06/2025,20/06/2025,50,0.95,47.50';
      final result = service.parseProventosCsv(csv);
      expect(result, hasLength(1));
      expect(result.first.ativo, 'HGLG11');
      expect(result.first.valorTotal, closeTo(47.5, 0.001));
    });

    test('calcula valorTotal = quantidade * valorDiv quando coluna total ausente', () {
      const csv =
          'ativo;quantidade;valor do div\n'
          'KNRI11;200;0,50';
      final result = service.parseProventosCsv(csv);
      expect(result, hasLength(1));
      expect(result.first.valorTotal, closeTo(100.0, 0.001));
    });

    test('ignora linhas com ativo vazio', () {
      const csv =
          'ativo;quantidade;valor do div\n'
          'VISC11;100;0,20\n'
          ';50;0,10\n'
          'XPLG11;80;0,15';
      final result = service.parseProventosCsv(csv);
      expect(result, hasLength(2));
      expect(result.map((p) => p.ativo), containsAll(['VISC11', 'XPLG11']));
    });

    test('usa "Outros" como tipoAtivo padrão quando coluna ausente', () {
      const csv =
          'ativo;quantidade;valor do div\n'
          'BTC;0,001;50';
      final result = service.parseProventosCsv(csv);
      expect(result.first.tipoAtivo, 'Outros');
    });

    test('infere status "Pago" para data de pagamento passada', () {
      const csv =
          'ativo;data pagamento;quantidade;valor do div\n'
          'PETR4;01/01/2020;100;1,00';
      final result = service.parseProventosCsv(csv);
      expect(result.first.status, 'Pago');
    });

    test('infere status "A Receber" para data de pagamento futura', () {
      // Data no futuro distante
      const csv =
          'ativo;data pagamento;quantidade;valor do div\n'
          'VALE3;01/12/2099;100;1,00';
      final result = service.parseProventosCsv(csv);
      expect(result.first.status, 'A Receber');
    });

    test('parseia multiplas linhas corretamente', () {
      const csv =
          'ativo;quantidade;valor do div;valor total\n'
          'MXRF11;100;0,11;11,00\n'
          'HGLG11;50;0,95;47,50\n'
          'KNRI11;200;0,50;100,00';
      final result = service.parseProventosCsv(csv);
      expect(result, hasLength(3));
    });

    test('parseia data no formato yyyyMMdd', () {
      const csv =
          'ativo;data pagamento;quantidade;valor do div\n'
          'BBAS3;20250601;100;0,50';
      final result = service.parseProventosCsv(csv);
      expect(result.first.dataPagamento.year, 2025);
      expect(result.first.dataPagamento.month, 6);
      expect(result.first.dataPagamento.day, 1);
    });

    test('parseia data no formato yyyy-MM-dd', () {
      const csv =
          'ativo;data pagamento;quantidade;valor do div\n'
          'ITUB4;2025-06-15;100;0,50';
      final result = service.parseProventosCsv(csv);
      expect(result.first.dataPagamento.year, 2025);
      expect(result.first.dataPagamento.month, 6);
    });
  });

  // ── parseRentabilidadeCsv ────────────────────────────────────────────────────

  group('ImportService.parseRentabilidadeCsv', () {
    test('CSV vazio retorna lista vazia', () {
      expect(service.parseRentabilidadeCsv(''), isEmpty);
    });

    test('parseia linha única de rentabilidade', () {
      const csv =
          'data;rentabilidade;cdi\n'
          '01/2025;1,5;1,2';
      final result = service.parseRentabilidadeCsv(csv);
      expect(result, hasLength(1));
      expect(result.first.rentabilidade, closeTo(1.5, 0.001));
      expect(result.first.cdi, closeTo(1.2, 0.001));
    });

    test('data é normalizada para o primeiro dia do mês', () {
      const csv =
          'data;rentabilidade;cdi\n'
          '15/03/2025;2,0;1,1';
      final result = service.parseRentabilidadeCsv(csv);
      expect(result.first.data.day, 1);
      expect(result.first.data.month, 3);
      expect(result.first.data.year, 2025);
    });

    test('parseia formato MM/yyyy', () {
      const csv =
          'mes;rentabilidade;cdi\n'
          '06/2025;1,8;1,05';
      final result = service.parseRentabilidadeCsv(csv);
      expect(result.first.data.month, 6);
      expect(result.first.data.year, 2025);
    });

    test('ignora linhas sem data válida', () {
      const csv =
          'data;rentabilidade;cdi\n'
          ';1,5;1,2\n'
          '01/2025;2,0;1,1';
      final result = service.parseRentabilidadeCsv(csv);
      expect(result, hasLength(1));
    });

    test('parseia múltiplas linhas', () {
      const csv =
          'data;rentabilidade;cdi\n'
          '01/2025;1,5;1,2\n'
          '02/2025;2,1;1,1\n'
          '03/2025;-0,3;1,0';
      final result = service.parseRentabilidadeCsv(csv);
      expect(result, hasLength(3));
      expect(result[2].rentabilidade, closeTo(-0.3, 0.001));
    });
  });

  // ── parseProventosJson ───────────────────────────────────────────────────────

  group('ImportService.parseProventosJson', () {
    test('lista vazia retorna vazia', () {
      expect(service.parseProventosJson([]), isEmpty);
    });

    test('parseia item JSON com chaves snake_case', () {
      final items = [
        {
          'ativo': 'MXRF11',
          'tipoAtivo': 'FIIs',
          'status': 'Pago',
          'tipoPagamento': 'Rendimento',
          'dataCom': '2025-06-01',
          'dataPagamento': '2025-06-05',
          'quantidade': 100.0,
          'valorDiv': 0.11,
          'valorTotal': 11.0,
        }
      ];
      final result = service.parseProventosJson(items);
      expect(result, hasLength(1));
      expect(result.first.ativo, 'MXRF11');
      expect(result.first.valorTotal, closeTo(11.0, 0.001));
    });

    test('ignora itens sem ativo', () {
      final items = [
        {'ativo': '', 'quantidade': 100.0, 'valorDiv': 0.5},
        {'ativo': 'HGLG11', 'quantidade': 50.0, 'valorDiv': 0.95},
      ];
      final result = service.parseProventosJson(items);
      expect(result, hasLength(1));
    });
  });

  // ── parseRentabilidadeJson ───────────────────────────────────────────────────

  group('ImportService.parseRentabilidadeJson', () {
    test('parseia item JSON corretamente', () {
      final items = [
        {'data': '2025-06-01', 'rentabilidade': 1.5, 'cdi': 1.2},
      ];
      final result = service.parseRentabilidadeJson(items);
      expect(result, hasLength(1));
      expect(result.first.rentabilidade, closeTo(1.5, 0.001));
    });

    test('ignora itens sem data válida', () {
      final items = [
        {'data': null, 'rentabilidade': 1.5, 'cdi': 1.2},
        {'data': '2025-06-01', 'rentabilidade': 2.0, 'cdi': 1.1},
      ];
      final result = service.parseRentabilidadeJson(items);
      expect(result, hasLength(1));
    });
  });
}
