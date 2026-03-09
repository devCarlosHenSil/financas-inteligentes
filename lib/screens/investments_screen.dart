import 'package:flutter/material.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:logger/logger.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  InvestmentsScreenState createState() => InvestmentsScreenState();
}

class InvestmentsScreenState extends State<InvestmentsScreen> {
  final FirestoreService _service = FirestoreService();
  final ApiService _api = ApiService();
  final logger = Logger();
  String nome = '';
  double valorInvestido = 0;
  double btcPrice = 0;

  @override
  void initState() {
    super.initState();
    _loadBtcPrice();
  }

  void _loadBtcPrice() async {
    try {
      btcPrice = await _api.getBitcoinPrice();
      setState(() {});
    } catch (e) {
      logger.e('Erro ao carregar preço do Bitcoin: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Investimentos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Preço Bitcoin: R\$$btcPrice', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome (ex: Bitcoin)')),
            TextField(
              onChanged: (v) => valorInvestido = double.tryParse(v) ?? 0,
              decoration: const InputDecoration(labelText: 'Valor Investido'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: () {
                _service.addInvestment(InvestmentModel(
                  id: '',
                  nome: nome,
                  valorInvestido: valorInvestido,
                  data: DateTime.now(),
                ));
              },
              child: const Text('Adicionar Investimento'),
            ),
            const Text('Dica: Poupe R\$100/mês para crescer seu patrimônio!', style: TextStyle(fontSize: 16)),
            const Text('Sugestão: Poupe 10% das suas entradas para investimentos – isso ajuda a crescer seu patrimônio!', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<InvestmentModel>>(
                stream: _service.getInvestments(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final inv = snapshot.data![index];
                      return Card(
                        color: Colors.blue[100],
                        child: ListTile(title: Text('${inv.nome}: R\$${inv.valorInvestido}')),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}