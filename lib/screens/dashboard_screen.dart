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
      final txMesAtual = transactions.where(
        (t) => t.data.month == now.month && t.data.year == now.year,
      );

      final Map<String, double> novasEntradasPorCategoria = {};
      final Map<String, double> novasSaidasPorCategoria = {};
      double novasEntradas = 0;
      double novasSaidas = 0;
      double novosSuperfluos = 0;

      for (final t in txMesAtual) {
        if (t.tipo == 'entrada') {
          novasEntradas += t.valor;
          novasEntradasPorCategoria.update(
            t.categoria,
            (value) => value + t.valor,
            ifAbsent: () => t.valor,
          );
        } else if (t.tipo == 'saida') {
          novasSaidas += t.valor;
          novasSaidasPorCategoria.update(
            t.categoria,
            (value) => value + t.valor,
            ifAbsent: () => t.valor,
          );
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
      return 'Você gastou muito em itens supérfluos (${_currencyFormatter.format(totalSuperfluos)}) – considere poupar mais!';
    }

    return 'Bons gastos! Supérfluos estão baixos (${_currencyFormatter.format(totalSuperfluos)}). Continue assim!';
  }

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    final items = data.entries
        .map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return items;
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
        radius: isTouched ? 108 : 92,
        titleStyle: TextStyle(
          fontSize: isTouched ? 12 : 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      );
    });
  }

  Widget _buildLegend(List<_CategoryTotal> items, {required bool isIncome}) {
    final total = items.fold<double>(0, (sum, item) => sum + item.valor);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 5.8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final percent = total == 0 ? 0 : (item.valor / total) * 100;

        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _categoryColor(item.nome, isIncome: isIncome),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.nome,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHoveredInfo(List<_CategoryTotal> items, {required bool isIncome, required int touchedIndex}) {
    if (touchedIndex < 0 || touchedIndex >= items.length) {
      return Text(
        'Passe o mouse sobre uma fatia para destacar categoria',
        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      );
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.valor);
    final touched = items[touchedIndex];
    final percent = total == 0 ? 0 : (touched.valor / total) * 100;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _categoryColor(touched.nome, isIncome: isIncome),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${touched.nome} • ${percent.toStringAsFixed(1)}% • ${_currencyFormatter.format(touched.valor)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    return SizedBox(
      height: 320,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 46,
          sections: _getPieSections(items, isIncome: isIncome, touchedIndex: touchedIndex),
          borderData: FlBorderData(show: false),
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (!mounted) return;
              final idx = response?.touchedSection?.touchedSectionIndex ?? -1;
              if (isIncome) {
                setState(() => _touchedIncomeIndex = idx);
              } else {
                setState(() => _touchedExpenseIndex = idx);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartCard({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
  }) {
    final items = _prepareChartData(data);
    final touchedIndex = isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(child: Text('Sem dados para o mês atual')),
              )
            else ...[
              _buildPieChart(items, isIncome: isIncome, touchedIndex: touchedIndex),
              const SizedBox(height: 8),
              _buildHoveredInfo(items, isIncome: isIncome, touchedIndex: touchedIndex),
              const SizedBox(height: 12),
              _buildLegend(items, isIncome: isIncome),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Transações'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentsScreen())),
            icon: const Icon(Icons.trending_up),
            label: const Text('Investimentos'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
            icon: const Icon(Icons.shopping_cart_checkout),
            label: const Text('Lista de Compras'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading) const LinearProgressIndicator(),
              if (_isLoading) const SizedBox(height: 16),
              Text(
                'Balanço: ${_currencyFormatter.format(saldo)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildPieChartCard(
                title: 'Entradas por Categoria',
                data: entradasPorCategoria,
                isIncome: true,
              ),
              const SizedBox(height: 16),
              _buildPieChartCard(
                title: 'Saídas por Categoria',
                data: saidasPorCategoria,
                isIncome: false,
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(getGastosAnalise(), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Dica para poupança: Com ${_currencyFormatter.format(saldo)} sobrando, invista R\$100/mês para acumular R\$1200 em 1 ano!',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildNavigationActions(context),
            ],
          ),
        ),
      ),
    );
  }
}
