import 'package:flutter/material.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  final FirestoreService _service = FirestoreService();
  final MoneyMaskedTextController valorController = MoneyMaskedTextController(decimalSeparator: ',', thousandSeparator: '.', leftSymbol: 'R\$ ');
  String tipo = 'entrada', categoria = '';
  bool fixa = false, superfluo = false;

  List<String> categoriasEntrada = ['Crédito de Salário', 'Adiantamento de Salário', 'Pagamento de Benefícios'];
  List<String> categoriasSaida = [
    'Amazon',
    'Alimentação',
    'Cartão de Crédito',
    'Depósito de Construção',
    'Farmácia',
    'Lazer',
    'Mercado Livre',
    'Magalu',
    'Moradia',
    'Padaria',
    'Pix para esposa',
    'Papelaria',
    'Shopee',
    'Super Mercado',
    'Serviço de Terceiros',
    'Serviços de Internet',
    'Serviços de Energia',
    'Serviços de Telefonia',
    'Servicos de Transporte',
    'Tiktok Shop',   
    'Uber',
    'Outros'
  ];

  void _showEditDialog(TransactionModel trans) {
    valorController.updateValue(trans.valor);
    tipo = trans.tipo;
    categoria = trans.categoria;
    fixa = trans.fixa;
    superfluo = trans.superfluo;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Transação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valorController,
                  decoration: const InputDecoration(labelText: 'Valor'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButton<String>(
                  value: tipo,
                  items: ['entrada', 'saida'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    setState(() {
                      tipo = v!;
                      categoria = '';
                    });
                  },
                ),
                DropdownButton<String>(
                  value: categoria.isEmpty ? null : categoria,
                  hint: const Text('Selecione a Categoria'),
                  items: (tipo == 'entrada' ? categoriasEntrada : categoriasSaida).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => categoria = v!),
                ),
                CheckboxListTile(title: const Text('Fixa'), value: fixa, onChanged: (v) => setState(() => fixa = v!)),
                CheckboxListTile(title: const Text('Supérfluo'), value: superfluo, onChanged: (v) => setState(() => superfluo = v!)),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (categoria.isNotEmpty) {
                  _service.updateTransaction(trans.id, TransactionModel(
                    id: trans.id,
                    valor: valorController.numberValue,
                    tipo: tipo,
                    categoria: categoria,
                    fixa: fixa,
                    data: trans.data,
                    superfluo: superfluo,
                  ));
                  Navigator.pop(context);
                  setState(() {});  // Força atualização da lista após edição
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma categoria')));
                }
              },
              child: const Text('Salvar'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transações')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: valorController,
              decoration: const InputDecoration(labelText: 'Valor'),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: tipo,
              items: ['entrada', 'saida'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) {
                setState(() {
                  tipo = v!;
                  categoria = ''; // Reset categoria ao mudar tipo
                });
              },
            ),
            DropdownButton<String>(
              value: categoria.isEmpty ? null : categoria,
              hint: const Text('Selecione a Categoria'),
              items: (tipo == 'entrada' ? categoriasEntrada : categoriasSaida).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => categoria = v!),
            ),
            CheckboxListTile(title: const Text('Fixa'), value: fixa, onChanged: (v) => setState(() => fixa = v!)),
            CheckboxListTile(title: const Text('Supérfluo'), value: superfluo, onChanged: (v) => setState(() => superfluo = v!)),
            ElevatedButton(
              onPressed: () {
                if (categoria.isNotEmpty) {
                  _service.addTransaction(TransactionModel(
                    id: '', // Gerado pelo Firestore
                    valor: valorController.numberValue,
                    tipo: tipo,
                    categoria: categoria,
                    fixa: fixa,
                    data: DateTime.now(),
                    superfluo: superfluo,
                  ));
                  setState(() {});  // Força atualização da lista após adição
                  valorController.updateValue(0.0); // Reset campo valor
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma categoria')));
                }
              },
              child: const Text('Adicionar'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<TransactionModel>>(
                stream: _service.getTransactions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final t = snapshot.data![index];
                      return Card(
                        color: t.tipo == 'entrada' ? Colors.green[100] : Colors.red[100],
                        child: ListTile(
                          title: Text('${t.categoria}: R\$${t.valor} (${t.tipo})'),
                          subtitle: Text(t.fixa ? 'Fixa' : 'Variável'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _service.deleteTransaction(t.id);
                                  setState(() {});  // Força atualização após deleção
                                },
                              ),
                            ],
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