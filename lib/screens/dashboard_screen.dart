import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
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

  double totalEntradas = 0, totalSaidas = 0, totalSuperfluos = 0;
  Map<String, double> entradasPorCategoria = {};
  Map<String, double> saidasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _listenTransactions();
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

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  String getGastosAnalise() {
    if (totalSuperfluos > totalSaidas * 0.3) {
      return 'Você gastou muito em supérfluos (${_currencyFormatter.format(totalSuperfluos)}).';
    }
    return 'Bons gastos! Supérfluos baixos (${_currencyFormatter.format(totalSuperfluos)}).';
  }

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    return data.entries.map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value)).toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
  }

  Color _categoryColor(String category, {required bool isIncome}) {
    final name = category.toLowerCase().trim();

    if (name.contains('super mercado') || name.contains('supermercado') || name.contains('mercado')) return const Color(0xFF43A047);
    if (name.contains('moradia') || name.contains('aluguel') || name.contains('casa')) return const Color(0xFF757575);
    if (name.contains('uber') || name.contains('99')) return Colors.black;
    if (name.contains('lazer') || name.contains('entretenimento') || name.contains('viagem')) return const Color(0xFF1E88E5);
    if (name.contains('serviço de terceiros') || name.contains('servicos de terceiros') || name.contains('terceiros')) return const Color(0xFF00897B);
    if (name.contains('mercado livre')) return const Color(0xFFFDD835);
    if (name.contains('shopee')) return const Color(0xFFFF6D00);
    if (name.contains('amazon')) return const Color(0xFFFF9900);
    if (name.contains('magalu') || name.contains('magazine luiza')) return const Color(0xFF0086FF);
    if (name.contains('pix para esposa') || name.contains('esposa')) return const Color(0xFF8E24AA);

    if (isIncome) return const Color(0xFF66BB6A);
    if (name.contains('saúde') || name.contains('saude') || name.contains('farmácia') || name.contains('farmacia')) return const Color(0xFFEF5350);
    if (name.contains('internet') || name.contains('telefone') || name.contains('streaming')) return const Color(0xFF5C6BC0);
    if (name.contains('educação') || name.contains('educacao')) return const Color(0xFF26A69A);

    final hue = (name.codeUnits.fold<int>(0, (sum, c) => sum + c) % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.55, 0.85).toColor();
  }

  List<PieChartSectionData> _getPieSections(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    if (items.isEmpty) return [];

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return List.generate(items.length, (index) {
      final item = items[index];
      final percent = total == 0 ? 0 : (item.valor / total) * 100;
      final isTouched = index == touchedIndex;

      return PieChartSectionData(
        value: item.valor,
        color: _categoryColor(item.nome, isIncome: isIncome),
        title: '${percent.toStringAsFixed(1)}%',
        radius: isTouched ? 100 : 84,
        titleStyle: TextStyle(
          fontSize: isTouched ? 11 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildHoveredInfo(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    if (touchedIndex < 0 || touchedIndex >= items.length) {
      return Text(
        'Passe o mouse sobre as fatias para destacar categoria.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        overflow: TextOverflow.ellipsis,
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
            color: _categoryColor(item.nome, isIncome: isIncome),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${item.nome} • ${percent.toStringAsFixed(1)}% • ${_currencyFormatter.format(item.valor)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(List<_CategoryTotal> items, {required bool isIncome}) {
    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GridView.builder(
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 6.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          final percent = total == 0 ? 0 : (item.valor / total) * 100;

          return Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _categoryColor(item.nome, isIncome: isIncome),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.nome,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPieChart(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    return AspectRatio(
      aspectRatio: 1.8,
      child: PieChart(
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
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
  }) {
    final items = _prepareChartData(data);
    final touchedIndex = isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Expanded(child: Center(child: Text('Sem dados para o mês atual')))
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildPieChart(items, isIncome: isIncome, touchedIndex: touchedIndex),
                    ),
                    const SizedBox(height: 6),
                    _buildHoveredInfo(items, isIncome: isIncome, touchedIndex: touchedIndex),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 4,
                      child: _buildLegend(items, isIncome: isIncome),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, double saldo, {required bool isNarrow}) {
    return SizedBox(
      height: isNarrow ? 96 : 84,
      child: Row(
        children: [
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(getGastosAnalise(), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Com ${_currencyFormatter.format(saldo)} de saldo, invista R\$100/mês para chegar a R\$1200 em 1 ano.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Transações', overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentsScreen())),
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: const Text('Invest.', overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
                    icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                    label: const Text('Compras', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Balanço: ${_currencyFormatter.format(saldo)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
                  _buildFooterActions(context, saldo, isNarrow: isNarrow),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Balanço: ${_currencyFormatter.format(saldo)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                      const SizedBox(width: 10),
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
                const SizedBox(height: 8),
                _buildFooterActions(context, saldo, isNarrow: isNarrow),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Balanço: ${_currencyFormatter.format(saldo)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
                  _buildFooterActions(context, saldo),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Balanço: ${_currencyFormatter.format(saldo)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
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
                      const SizedBox(width: 10),
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
                const SizedBox(height: 8),
                _buildFooterActions(context, saldo),
              ],
            );
          },
        ),
      ),
    );
  }
}
