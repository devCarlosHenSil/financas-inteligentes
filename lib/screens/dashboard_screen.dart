import 'dart:async';

import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class _CategorySelection {
  _CategorySelection({
    required this.item,
    required this.percent,
  });

  final _CategoryTotal item;
  final double percent;
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
    _transactionsSubscription =
        _service.getTransactions().listen((transactions) {
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

  String getGastosAnalise() {
    if (totalSuperfluos > totalSaidas * 0.3) {
      return 'Você gastou muito em supérfluos (${_currencyFormatter.format(totalSuperfluos)}). Revise gastos variáveis para equilibrar o mês.';
    }

    return 'Bons gastos! Supérfluos sob controle (${_currencyFormatter.format(totalSuperfluos)}).';
  }

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    return data.entries
        .map((entry) => _CategoryTotal(nome: entry.key, valor: entry.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
  }

  Color _incomeTone(int index) {
    const tones = [
      Color(0xFF00C48C),
      Color(0xFF2DD4BF),
      Color(0xFF22D3EE),
      Color(0xFF60A5FA),
      Color(0xFF818CF8),
    ];

    return tones[index % tones.length];
  }

  Color _categoryColor(String category,
      {required bool isIncome, int index = 0}) {
    if (isIncome) {
      return _incomeTone(index);
    }

    final name = category.toLowerCase().trim();

    if (name.contains('uber')) return const Color(0xFF111111);
    if (name.contains('mercado livre')) return const Color(0xFFFDD835);
    if (name.contains('shopee')) return const Color(0xFFFF6D00);
    if (name.contains('amazon')) return const Color(0xFFFF9900);
    if (name.contains('magalu') || name.contains('magazine luiza')) {
      return const Color(0xFF0086FF);
    }
    if (name.contains('farmácia') || name.contains('farmacia')) {
      return const Color(0xFFE91E63);
    }
    if (name.contains('lazer')) return const Color(0xFF7C3AED);
    if (name.contains('telefone')) return const Color(0xFF84CC16);
    if (name.contains('internet')) return const Color(0xFFEF4444);

    final hue =
        (name.codeUnits.fold<int>(0, (sum, c) => sum + c) % 360).toDouble();

    return HSVColor.fromAHSV(1, hue, 0.50, 0.92).toColor();
  }

  List<PieChartSectionData> _getPieSections(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    if (items.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          color: const Color(0xFF64748B),
          title: '',
          radius: 72,
        ),
      ];
    }

    final total = items.fold<double>(0.0, (sum, item) => sum + item.valor);

    return List.generate(items.length, (index) {
      final item = items[index];

      final double percent =
          total == 0 ? 0.0 : (item.valor / total) * 100.0;

      final isTouched = index == touchedIndex;
      final bool isLargeSlice = percent >= 20;
      final double radius = isTouched
          ? (isLargeSlice ? 82 : 88)
          : (isLargeSlice ? 70 : 78);

      return PieChartSectionData(
        value: item.valor,
        color: _categoryColor(item.nome, isIncome: isIncome, index: index),
        title: isTouched
            ? '${item.nome}\n${percent.toStringAsFixed(1)}%'
            : '${percent.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  _CategorySelection? _selectedCategory(
    List<_CategoryTotal> items,
    int touchedIndex,
  ) {
    if (items.isEmpty || touchedIndex < 0 || touchedIndex >= items.length) {
      return null;
    }

    final total = items.fold<double>(0.0, (sum, item) => sum + item.valor);
    final selectedItem = items[touchedIndex];
    final double percent =
        total == 0 ? 0.0 : (selectedItem.valor / total) * 100.0;

    return _CategorySelection(item: selectedItem, percent: percent);
  }

  Widget _buildCategoryList(List<_CategoryTotal> items, {required bool isIncome}) {
    if (items.isEmpty) {
      return const Text(
        'Sem categorias no período.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final color = _categoryColor(item.nome, isIncome: isIncome, index: index);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.nome,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPieChart(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 46,
        borderData: FlBorderData(show: false),
        sections: _getPieSections(
          items,
          isIncome: isIncome,
          touchedIndex: touchedIndex,
        ),
        pieTouchData: PieTouchData(
          enabled: items.isNotEmpty,
          touchCallback: (event, response) {
            if (items.isEmpty) return;

            final bool hasInteraction = event.isInterestedForInteractions;
            final int idx = hasInteraction
                ? (response?.touchedSection?.touchedSectionIndex ?? -1)
                : -1;

            if (!mounted) return;

            if (isIncome) {
              if (_touchedIncomeIndex == idx) return;
              setState(() => _touchedIncomeIndex = idx);
            } else {
              if (_touchedExpenseIndex == idx) return;
              setState(() => _touchedExpenseIndex = idx);
            }
          },
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

    final touchedIndex =
        isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;
    final selection = _selectedCategory(items, touchedIndex);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildPieChart(
                items,
                isIncome: isIncome,
                touchedIndex: touchedIndex,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selection == null
                  ? 'Passe o mouse em uma fatia para ver a categoria.'
                  : '${selection.item.nome} • ${_currencyFormatter.format(selection.item.valor)} (${selection.percent.toStringAsFixed(1)}%)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildCategoryList(items, isIncome: isIncome),
          ],
        ),
      ),
    );
  }


  String _loggedUserLabel() {
    final user = _auth.currentUser;
    if (user == null) return 'Convidado';
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return user.email ?? 'Usuário';
  }

  Widget _buildPremiumHeader(double saldo) {
    final userLabel = _loggedUserLabel();
    final now = DateFormat('MMMM yyyy').format(DateTime.now());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.10 * 255).round()),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              userLabel.isNotEmpty ? userLabel[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Financeiro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Olá, $userLabel • ${now[0].toUpperCase()}${now.substring(1)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormatter.format(saldo),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _actionButtonStyle() {
    return ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.transparent,
      disabledForegroundColor: Colors.white70,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required List<Color> colors,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: _actionButtonStyle(),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsAndActions(BuildContext context, double saldo) {
    final saldoPositivo = saldo >= 0;

    final sugestao = saldoPositivo
        ? 'Saldo positivo de ${_currencyFormatter.format(saldo)}. Continue investindo.'
        : 'Saldo negativo de ${_currencyFormatter.format(saldo)}. Ajuste gastos.';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(getGastosAnalise()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(sugestao),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
                icon: Icons.receipt_long,
                label: 'Transações',
                colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvestmentsScreen(),
                    ),
                  );
                },
                icon: Icons.trending_up,
                label: 'Investimentos',
                colors: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen(),
                    ),
                  );
                },
                icon: Icons.shopping_cart,
                label: 'Lista de Compras',
                colors: const [Color(0xFFEA580C), Color(0xFFC2410C)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saldo = totalEntradas - totalSaidas;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1D4ED8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                _buildPremiumHeader(saldo),
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
                const SizedBox(height: 10),
                _buildInsightsAndActions(context, saldo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
