import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _service = FirestoreService();
  double totalEntradas = 0, totalSaidas = 0, totalSuperfluos = 0;
  Map<String, double> entradasPorCategoria = {};
  Map<String, double> saidasPorCategoria = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    DateTime now = DateTime.now();
    totalEntradas = await _service.getTotalEntradas(now);
    totalSaidas = await _service.getTotalSaidas(now);
    totalSuperfluos = await _service.getTotalSuperfluos(now);

    // Calcular por categoria
    final snapshot = await _service.db.collection('usuarios/${_service.userId}/transacoes').get();
    entradasPorCategoria = {};
    saidasPorCategoria = {};
    for (var doc in snapshot.docs) {
      final t = TransactionModel.fromMap(doc.data(), doc.id);
      if (t.data.month == now.month && t.data.year == now.year) {
        if (t.tipo == 'entrada') {
          entradasPorCategoria.update(t.categoria, (value) => value + t.valor, ifAbsent: () => t.valor);
        } else {
          saidasPorCategoria.update(t.categoria, (value) => value + t.valor, ifAbsent: () => t.valor);
        }
      }
    }

    setState(() {});
    _service.getTransactions().listen((list) {
      setState(() {});
    });
  }

  String getGastosAnalise() {
    if (totalSuperfluos > totalSaidas * 0.3) {
      return 'Você gastou muito em itens supérfluos (R\$$totalSuperfluos) – considere poupar mais!';
    } else {
      return 'Bons gastos! Supérfluos estão baixos (R\$$totalSuperfluos). Continue assim!';
    }
  }

  List<PieChartSectionData> _getPieSections(Map<String, double> data, Color baseColor) {
    Map<String, Color> categoryColors = {
      'Uber': Colors.black,
      'Mercado Livre': Colors.yellow,
      'Shopee': Colors.orange,
      'Pix para esposa': Colors.purple,
      'Padaria': Colors.brown[200]!,
      'Super Mercado': Colors.blue[200]!,
      // Adicione mais categorias se necessário
    };

    List<PieChartSectionData> sections = [];
    List<Color> defaultColors = [
      baseColor,
      baseColor.withAlpha((0.8 * 255).round()),
      baseColor.withAlpha((0.6 * 255).round()),
      baseColor.withAlpha((0.4 * 255).round()),
      baseColor.withAlpha((0.2 * 255).round())
    ];
    int colorIndex = 0;
    data.forEach((key, value) {
      Color color = categoryColors[key] ?? defaultColors[colorIndex % defaultColors.length];
      sections.add(PieChartSectionData(
        value: value,
        color: color,
        title: '$key\nR\$${value.toStringAsFixed(2)}',
        radius: 120,  // Aumentado para mais espaço
        titlePositionPercentageOffset: 1.5,  // Move o título mais para fora
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
      ));
      colorIndex++;
    });
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balanço: ${NumberFormat.currency(symbol: 'R\$').format(totalEntradas - totalSaidas)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Entradas por Categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 300,  // Aumenta a altura para mais espaço
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: _getPieSections(entradasPorCategoria, Colors.green),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Saídas por Categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 300,  // Aumenta a altura para mais espaço
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: _getPieSections(saidasPorCategoria, Colors.red),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(getGastosAnalise(), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Dica para poupança: Com R\$${totalEntradas - totalSaidas} sobrando, invista R\$100/mês para acumular R\$1200 em 1 ano!', style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())), child: const Text('Transações')),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvestmentsScreen())), child: const Text('Investimentos')),
              ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())), child: const Text('Lista de Compras')),
            ],
          ),
        ),
      ),
    );
  }
}