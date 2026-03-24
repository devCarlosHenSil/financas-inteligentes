import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:financas_inteligentes/models/transaction_model.dart';

/// Serviço de geração e exportação de relatórios em PDF.
///
/// ## Uso
/// ```dart
/// await ReportService.exportarTransacoes(
///   periodo: DateTime(2026, 3),
///   transacoes: tx.transactionsFiltradas,
///   totalEntradas: tx.totalEntradas,
///   totalSaidas: tx.totalSaidas,
///   saldo: tx.saldo,
/// );
/// ```
///
/// ## Comportamento por plataforma
///   - Web    → abre preview com download automático
///   - Mobile → abre share/print nativo do SO
///   - Desktop→ abre visualizador PDF nativo
class ReportService {
  ReportService._();

  static final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt  = DateFormat('dd/MM/yyyy');
  static final _mesFmt   = DateFormat('MMMM yyyy', 'pt_BR');

  // ── Cores do relatório ────────────────────────────────────────────────────

  static const _primary    = PdfColor.fromInt(0xFF1D4ED8);
  static const _success    = PdfColor.fromInt(0xFF059669);
  static const _error      = PdfColor.fromInt(0xFFDC2626);
  static const _surface    = PdfColor.fromInt(0xFFF8FAFC);
  static const _border     = PdfColor.fromInt(0xFFE2E8F0);
  static const _textDark   = PdfColor.fromInt(0xFF0F172A);
  static const _textMuted  = PdfColor.fromInt(0xFF64748B);
  static const _rowAlt     = PdfColor.fromInt(0xFFF1F5F9);

  // ── Exportação principal ─────────────────────────────────────────────────

  /// Gera e exibe o PDF de transações do período.
  static Future<void> exportarTransacoes({
    required DateTime periodo,
    required List<TransactionModel> transacoes,
    required double totalEntradas,
    required double totalSaidas,
    required double saldo,
    Map<String, double>? entradasPorCategoria,
    Map<String, double>? saidasPorCategoria,
  }) async {
    final doc = pw.Document(
      title: 'Relatório de Transações',
      author: 'Finanças Inteligentes',
    );

    final mesLabel = _capitalize(_mesFmt.format(periodo));
    final geradoEm = DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(mesLabel, geradoEm),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 16),
          _buildSummaryCards(totalEntradas, totalSaidas, saldo),
          pw.SizedBox(height: 20),
          if (saidasPorCategoria != null && saidasPorCategoria.isNotEmpty) ...[
            _buildSectionTitle('Saídas por categoria'),
            pw.SizedBox(height: 8),
            _buildCategoryTable(saidasPorCategoria, totalSaidas),
            pw.SizedBox(height: 20),
          ],
          if (entradasPorCategoria != null && entradasPorCategoria.isNotEmpty) ...[
            _buildSectionTitle('Entradas por categoria'),
            pw.SizedBox(height: 8),
            _buildCategoryTable(entradasPorCategoria, totalEntradas),
            pw.SizedBox(height: 20),
          ],
          _buildSectionTitle('Lançamentos do período (${transacoes.length})'),
          pw.SizedBox(height: 8),
          if (transacoes.isEmpty)
            pw.Center(
              child: pw.Text(
                'Nenhuma transação no período.',
                style: pw.TextStyle(color: _textMuted),
              ),
            )
          else
            _buildTransacoesTable(transacoes),
        ],
      ),
    );

    final pdfBytes = await doc.save();

    // Nome do arquivo — ex.: transacoes_marco_2026.pdf
    final nomeArquivo =
        'transacoes_${_mesFmt.format(periodo).toLowerCase().replaceAll(' ', '_').replaceAll('/', '_')}.pdf';

    if (kIsWeb) {
      // No Web: Printing.layoutPdf abre o preview com opção de download
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: nomeArquivo,
      );
    } else {
      // Mobile/Desktop: share sheet nativo
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: nomeArquivo,
      );
    }
  }

  // ── Seções do PDF ─────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(String mesLabel, String geradoEm) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Finanças Inteligentes',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Relatorio de Transacoes - $mesLabel',
                  style: pw.TextStyle(fontSize: 11, color: _textMuted),
                ),
              ],
            ),
            pw.Text(
              'Gerado em $geradoEm',
              style: pw.TextStyle(fontSize: 9, color: _textMuted),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _border, thickness: 1),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: _border, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Financas Inteligentes - Relatorio confidencial',
              style: pw.TextStyle(fontSize: 8, color: _textMuted),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _textMuted),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCards(
    double entradas,
    double saidas,
    double saldo,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(child: _summaryCard('Entradas', entradas, _success)),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _summaryCard('Saídas', saidas, _error)),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _summaryCard(
            'Saldo',
            saldo,
            saldo >= 0 ? _success : _error,
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, color: _textMuted),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _currency.format(value),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _textDark,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: _primary, thickness: 1.5),
      ],
    );
  }

  static pw.Widget _buildCategoryTable(
    Map<String, double> data,
    double total,
  ) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rows = sorted.asMap().entries.map((entry) {
      final i     = entry.key;
      final cat   = entry.value.key;
      final valor = entry.value.value;
      final pct   = total > 0 ? (valor / total * 100) : 0.0;
      final bg    = i.isEven ? PdfColors.white : _rowAlt;

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _cell(cat, align: pw.TextAlign.left),
          _cell(_currency.format(valor)),
          _cell('${pct.toStringAsFixed(1)}%'),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        // Cabeçalho
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primary),
          children: [
            _headerCell('Categoria'),
            _headerCell('Valor'),
            _headerCell('%'),
          ],
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _buildTransacoesTable(List<TransactionModel> transacoes) {
    final rows = transacoes.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      final isEntrada = t.tipo == 'entrada';
      final bg = i.isEven ? PdfColors.white : _rowAlt;
      final valorColor = isEntrada ? _success : _error;

      return pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          _cell(_dateFmt.format(t.data), align: pw.TextAlign.center),
          _cell(isEntrada ? 'Entrada' : 'Saída',
              color: valorColor, align: pw.TextAlign.center),
          _cell(t.categoria, align: pw.TextAlign.left),
          _cell(
            _currency.format(t.valor),
            color: valorColor,
            bold: true,
          ),
          _cell(t.fixa ? 'Fixa' : 'Variável', align: pw.TextAlign.center),
          _cell(t.superfluo ? 'Sim' : '', align: pw.TextAlign.center),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4), // data
        1: const pw.FlexColumnWidth(1.0), // tipo
        2: const pw.FlexColumnWidth(2.5), // categoria
        3: const pw.FlexColumnWidth(1.6), // valor
        4: const pw.FlexColumnWidth(1.0), // fixa
        5: const pw.FlexColumnWidth(0.9), // supérfluo
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primary),
          children: [
            _headerCell('Data'),
            _headerCell('Tipo'),
            _headerCell('Categoria'),
            _headerCell('Valor'),
            _headerCell('Fixa'),
            _headerCell('Supérf.'),
          ],
        ),
        ...rows,
      ],
    );
  }

  // ── Helpers de célula ─────────────────────────────────────────────────────

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          color: color ?? _textDark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
