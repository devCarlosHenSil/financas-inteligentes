import 'package:flutter/material.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:intl/intl.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ShoppingListScreenState createState() => ShoppingListScreenState();
}

class ShoppingListScreenState extends State<ShoppingListScreen> {
  final FirestoreService _service = FirestoreService();
  String nome = '';
  double preco = 0;
  double avgLastMonth = 0;

  void _calculateAvg() async {
    final lastMonth = DateTime.now().subtract(const Duration(days: 30));
    avgLastMonth = await _service.getAveragePrice(nome, lastMonth);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Compras')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: 'Nome Item')),
            TextField(
              onChanged: (v) => preco = double.tryParse(v) ?? 0,
              decoration: const InputDecoration(labelText: 'Preço'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: () {
                _service.addShoppingItem(ShoppingItemModel(id: '', nome: nome, preco: preco, data: DateTime.now()));
                _calculateAvg();
              },
              child: const Text('Adicionar'),
            ),
            Text('Média Mês Passado: R\$${NumberFormat.currency(symbol: '').format(avgLastMonth)}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<ShoppingItemModel>>(
                stream: _service.getShoppingItems(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final item = snapshot.data![index];
                      return Card(
                        color: Colors.yellow[100],
                        child: ListTile(
                          title: Text('${item.nome}: R\$${item.preco}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _service.removeShoppingItem(item.id),
                          ),
                        ),
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