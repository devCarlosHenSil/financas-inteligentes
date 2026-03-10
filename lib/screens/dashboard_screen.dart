import 'dart:async';

import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class _CategoryTotal {
  _CategoryTotal({required this.nome, required this.valor});

  final String nome;
  final double valor;
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: 'R\$');

  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;
  bool _isLoading = true;
  int _touchedIncomeIndex = -1;
  int _touchedExpenseIndex = -1;

  double totalEntradas = 0;
  double totalSaidas = 0;
  double totalSuperfluos = 0;
  Map<String, double> entradasPorCategoria = {};
  Map<String, double> saidasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _listenTransactions();
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _listenTransactions() {
    _transactionsSubscription = _service.getTransactions().listen((transactions) {
      final now = DateTime.now();
      final txMesAtual = transactions.where((t) => t.data.month == now.month && t.data.year == now.year);

      final Map<String, double> novasEntradasPorCategoria = {};
      final Map<String, double> novasSaidasPorCategoria = {};
      double novasEntradas = 0;
      double novasSaidas = 0;
      double novosSuperfluos = 0;

      for (final t in txMesAtual) {
        if (t.tipo == 'entrada') {
          novasEntradas += t.valor;
          novasEntradasPorCategoria.update(t.categoria, (value) => value + t.valor, ifAbsent: () => t.valor);
        } else if (t.tipo == 'saida') {
          novasSaidas += t.valor;
          novasSaidasPorCategoria.update(t.categoria, (value) => value + t.valor, ifAbsent: () => t.valor);
        }

        if (t.superfluo) {
          novosSuperfluos += t.valor;
        }
      }

      if (!mounted) return;
      setState(() {
        totalEntradas = novasEntradas;
        totalSaidas = novasSaidas;
        totalSuperfluos = novosSuperfluos;
        entradasPorCategoria = novasEntradasPorCategoria;
        saidasPorCategoria = novasSaidasPorCategoria;
        _isLoading = false;
      });
    });
  }

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    return data.entries.map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value)).toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
  }

  Color _incomeTone(int index) {
    const tones = [
      Color(0xFF2E7D32),
      Color(0xFF43A047),
      Color(0xFF66BB6A),
      Color(0xFF81C784),
    ];
    return tones[index % tones.length];
  }

  Color _categoryColor(String category, {required bool isIncome, int index = 0}) {
    if (isIncome) {
      return _incomeTone(index);
    }

    final name = category.toLowerCase().trim();

    if (name.contains('mercado livre')) return const Color(0xFFFDD835);
    if (name.contains('shopee')) return const Color(0xFFFF6D00);
    if (name.contains('amazon')) return const Color(0xFFFF9900);
    if (name.contains('magalu') || name.contains('magazine luiza')) return const Color(0xFF0086FF);
    if (name.contains('uber') || name.contains('99')) return Colors.black;
    if (name.contains('pix para esposa') || name.contains('esposa')) return const Color(0xFF820AD1);
    if (name.contains('moradia') || name.contains('aluguel') || name.contains('casa')) return const Color(0xFF6D6D6D);
    if (name.contains('mercado') || name.contains('aliment')) return const Color(0xFF43A047);
    if (name.contains('lazer') || name.contains('entretenimento') || name.contains('viagem')) return const Color(0xFF1E88E5);
    if (name.contains('serviço de terceiros') || name.contains('servicos de terceiros') || name.contains('terceiros')) return const Color(0xFF00897B);
    if (name.contains('farmácia') || name.contains('farmacia') || name.contains('saúde') || name.contains('saude')) return const Color(0xFFE53935);
    if (name.contains('internet') || name.contains('telefone') || name.contains('streaming')) return const Color(0xFF5C6BC0);
    if (name.contains('padaria')) return const Color(0xFF8D6E63);

    final hue = (name.codeUnits.fold<int>(0, (sum, c) => sum + c) % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.55, 0.82).toColor();
  }

  List<PieChartSectionData> _getPieSections(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    if (items.isEmpty) return [];

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return List.generate(items.length, (index) {
      final item = items[index];
      final percent = total == 0 ? 0 : (item.valor / total) * 100;
      final isTouched = index == touchedIndex;

      return PieChartSectionData(
        value: item.valor,
        color: _categoryColor(item.nome, isIncome: isIncome, index: index),
        title: '${percent.toStringAsFixed(1)}%',
        radius: isTouched ? 98 : 84,
        titleStyle: TextStyle(
          fontSize: isTouched ? 11 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildHoveredInfo(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    if (touchedIndex < 0 || touchedIndex >= items.length) {
      return Text(
        'Passe o mouse sobre as fatias para destacar a categoria.',
        style: TextStyle(color: Colors.white.withAlpha((0.78 * 255).round()), fontSize: 12),
      );
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);
    final item = items[touchedIndex];
    final percent = total == 0 ? 0 : (item.valor / total) * 100;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _categoryColor(item.nome, isIncome: isIncome, index: touchedIndex),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${item.nome} • ${percent.toStringAsFixed(1)}% • ${_currencyFormatter.format(item.valor)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(List<_CategoryTotal> items, {required bool isIncome}) {
    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = items[index];
        final percent = total == 0 ? 0 : (item.valor / total) * 100;

        return Tooltip(
          message: '${item.nome}: ${percent.toStringAsFixed(1)}% (${_currencyFormatter.format(item.valor)})',
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _categoryColor(item.nome, isIncome: isIncome, index: index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.nome,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.white.withAlpha((0.85 * 255).round()), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        sections: _getPieSections(items, isIncome: isIncome, touchedIndex: touchedIndex),
        borderData: FlBorderData(show: false),
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (event, response) {
            final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
            if (!mounted) return;
            setState(() {
              if (isIncome) {
                _touchedIncomeIndex = idx;
              } else {
                _touchedExpenseIndex = idx;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Map<String, double> data, required bool isIncome}) {
    final items = _prepareChartData(data);
    final touchedIndex = isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha((0.18 * 255).round())),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Expanded(child: Center(child: Text('Sem dados para o mês atual', style: TextStyle(color: Colors.white))))
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(flex: 6, child: _buildPieChart(items, isIncome: isIncome, touchedIndex: touchedIndex)),
                    const SizedBox(height: 8),
                    _buildHoveredInfo(items, isIncome: isIncome, touchedIndex: touchedIndex),
                    const SizedBox(height: 8),
                    Expanded(flex: 5, child: _buildLegend(items, isIncome: isIncome)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsAndActions(BuildContext context, double saldo) {
    final saldoPositivo = saldo >= 0;
    final sugestao = saldoPositivo
        ? 'Saldo positivo de ${_currencyFormatter.format(saldo)}. Continue investindo mensalmente para acelerar seu patrimônio.'
        : 'Saldo negativo de ${_currencyFormatter.format(saldo)}. Ajuste gastos variáveis para recuperar seu caixa no próximo mês.';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Text(getGastosAnalise(), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
            ),
            child: Text(sugestao, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: 'Abrir gerenciamento de transações',
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Transações', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Abrir carteira de investimentos',
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentsScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: const Text('Invest.', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Abrir lista de compras',
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                    label: const Text('Compras', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 1000;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Balanço: ${_currencyFormatter.format(saldo)}',
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildChartCard(
                            title: 'Entradas por Categoria',
                            data: entradasPorCategoria,
                            isIncome: true,
                          ),
                        ),
                        SizedBox(width: isNarrow ? 8 : 10),
                        Expanded(
                          child: _buildChartCard(
                            title: 'Saídas por Categoria',
                            data: saidasPorCategoria,
                            isIncome: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInsightsAndActions(context, saldo),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
