import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ShoppingListScreenState createState() => ShoppingListScreenState();
}

class ShoppingListScreenState extends State<ShoppingListScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _currency = NumberFormat.currency(symbol: 'R\$');

  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();

  final Map<String, List<String>> _catalogoPorDepartamento = const {
    'Laticínios': ['Leite', 'Queijo', 'Iogurte', 'Manteiga'],
    'Hortifruti': ['Banana', 'Maçã', 'Tomate', 'Batata', 'Alface'],
    'Mercearia': ['Arroz', 'Feijão', 'Macarrão', 'Óleo', 'Açúcar'],
    'Bebidas': ['Café', 'Suco', 'Refrigerante', 'Água'],
    'Limpeza': ['Detergente', 'Sabão em Pó', 'Água Sanitária'],
    'Higiene': ['Papel Higiênico', 'Shampoo', 'Sabonete'],
  };

  final Map<String, List<Map<String, dynamic>>> _promocoesPorCidade = const {
    'São Paulo': [
      {'item': 'Leite', 'mercado': 'Atacadão', 'preco': 4.39},
      {'item': 'Arroz', 'mercado': 'Assaí', 'preco': 24.90},
      {'item': 'Feijão', 'mercado': 'Carrefour', 'preco': 7.89},
    ],
    'Rio de Janeiro': [
      {'item': 'Leite', 'mercado': 'Guanabara', 'preco': 4.59},
      {'item': 'Tomate', 'mercado': 'Prezunic', 'preco': 5.99},
      {'item': 'Café', 'mercado': 'Mundial', 'preco': 14.99},
    ],
    'Belo Horizonte': [
      {'item': 'Leite', 'mercado': 'EPA', 'preco': 4.49},
      {'item': 'Arroz', 'mercado': 'Villefort', 'preco': 23.90},
      {'item': 'Detergente', 'mercado': 'Supernosso', 'preco': 2.19},
    ],
  };

  String _departamentoSelecionado = 'Laticínios';
  String _cidadeSelecionada = 'São Paulo';

  final Map<String, int> _carrinho = {};

  List<String> get _itensDepartamentoAtual =>
      _catalogoPorDepartamento[_departamentoSelecionado] ?? [];

  List<String> get _todosItensCatalogo =>
      _catalogoPorDepartamento.values.expand((e) => e).toSet().toList()..sort();

  @override
  void dispose() {
    _itemController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  void _adicionarAoCarrinho(String item) {
    if (item.trim().isEmpty) return;

    setState(() {
      _carrinho.update(item.trim(), (qtd) => qtd + 1, ifAbsent: () => 1);
    });
  }

  void _alterarQuantidade(String item, int delta) {
    setState(() {
      final atual = _carrinho[item] ?? 0;
      final novo = atual + delta;
      if (novo <= 0) {
        _carrinho.remove(item);
      } else {
        _carrinho[item] = novo;
      }
    });
  }

  Future<void> _salvarItemHistorico() async {
    final nome = _itemController.text.trim();
    final preco =
        double.tryParse(_precoController.text.trim().replaceAll(',', '.')) ?? 0;

    if (nome.isEmpty || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe item e preço válido.')),
      );
      return;
    }

    await _service.addShoppingItem(
      ShoppingItemModel(
        id: '',
        nome: nome,
        preco: preco,
        data: DateTime.now(),
      ),
    );

    _adicionarAoCarrinho(nome);

    _itemController.clear();
    _precoController.clear();
  }

  double _precoAtualOuPromocao(String item) {
    final promo = (_promocoesPorCidade[_cidadeSelecionada] ?? [])
        .where((p) => (p['item'] as String).toLowerCase() == item.toLowerCase())
        .toList();

    if (promo.isNotEmpty) {
      promo.sort((a, b) => (a['preco'] as double).compareTo(b['preco'] as double));
      return promo.first['preco'] as double;
    }

    return 0;
  }

  Widget _buildComparativo(String item, List<ShoppingItemModel> historico) {
    final now = DateTime.now();
    final mesAtual = historico
        .where((h) =>
            h.nome.toLowerCase() == item.toLowerCase() &&
            h.data.month == now.month &&
            h.data.year == now.year)
        .toList();

    final mesAnteriorRef = DateTime(now.year, now.month - 1, 1);
    final mesAnterior = historico
        .where((h) =>
            h.nome.toLowerCase() == item.toLowerCase() &&
            h.data.month == mesAnteriorRef.month &&
            h.data.year == mesAnteriorRef.year)
        .toList();

    if (mesAtual.isEmpty || mesAnterior.isEmpty) {
      return const Text(
        'Sem dados suficientes para comparativo mensal.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      );
    }

    final mediaAtual =
        mesAtual.fold<double>(0, (s, e) => s + e.preco) / mesAtual.length;
    final mediaAnterior =
        mesAnterior.fold<double>(0, (s, e) => s + e.preco) / mesAnterior.length;

    final diff = mediaAtual - mediaAnterior;
    final maisBarato = diff < 0;

    return Text(
      maisBarato
          ? 'Mais barato que mês anterior: ${_currency.format(diff.abs())}'
          : 'Mais caro que mês anterior: ${_currency.format(diff)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: maisBarato ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<List<ShoppingItemModel>>(
              stream: _service.getShoppingItems(),
              builder: (context, snapshot) {
                final historico = snapshot.data ?? [];

                final totalCarrinho = _carrinho.entries.fold<double>(0, (sum, e) {
                  final preco = _precoAtualOuPromocao(e.key);
                  return sum + (preco * e.value);
                });

                final promocoesCidade =
                    List<Map<String, dynamic>>.from(_promocoesPorCidade[_cidadeSelecionada] ?? [])
                      ..sort((a, b) =>
                          (a['preco'] as double).compareTo(b['preco'] as double));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lista de Compras Inteligente',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _departamentoSelecionado,
                                  decoration: const InputDecoration(
                                    labelText: 'Departamento',
                                  ),
                                  items: _catalogoPorDepartamento.keys
                                      .map(
                                        (d) => DropdownMenuItem(
                                          value: d,
                                          child: Text(d),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _departamentoSelecionado =
                                        v ?? _departamentoSelecionado,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _cidadeSelecionada,
                                  decoration: const InputDecoration(
                                    labelText: 'Região para promoções próximas',
                                  ),
                                  items: _promocoesPorCidade.keys
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(
                                    () => _cidadeSelecionada = v ?? _cidadeSelecionada,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return _todosItensCatalogo;
                                    }
                                    return _todosItensCatalogo.where(
                                      (option) => option.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                    );
                                  },
                                  onSelected: (v) => _itemController.text = v,
                                  fieldViewBuilder: (
                                    context,
                                    controller,
                                    focusNode,
                                    onEditingComplete,
                                  ) {
                                    controller.text = _itemController.text;
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Item (pré-cadastrado ou digitado manualmente)',
                                      ),
                                      onChanged: (v) => _itemController.text = v,
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _precoController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Preço pago',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _salvarItemHistorico,
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('Adicionar item e enviar ao carrinho'),
                                  ),
                                ),
                              ],
                            ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Itens do departamento: $_departamentoSelecionado',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _itensDepartamentoAtual
                                      .map(
                                        (item) => ActionChip(
                                          label: Text(item),
                                          onPressed: () => _adicionarAoCarrinho(item),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Melhores preços na região: $_cidadeSelecionada',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: promocoesCidade.length,
                                    itemBuilder: (context, index) {
                                      final promo = promocoesCidade[index];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${promo['item']} • ${promo['mercado']}',
                                        ),
                                        trailing: Text(
                                          _currency.format(promo['preco'] as double),
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Carrinho de compras',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Total estimado antes do caixa: ${_currency.format(totalCarrinho)}',
                                    style: const TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _carrinho.isEmpty
                                        ? const Center(
                                            child: Text('Carrinho vazio.'),
                                          )
                                        : ListView(
                                            children: _carrinho.entries.map((entry) {
                                              final preco = _precoAtualOuPromocao(entry.key);
                                              return ListTile(
                                                title: Text(entry.key),
                                                subtitle: Text(
                                                  'Preço ref.: ${_currency.format(preco)}',
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      onPressed: () =>
                                                          _alterarQuantidade(entry.key, -1),
                                                      icon: const Icon(Icons.remove_circle_outline),
                                                    ),
                                                    Text('${entry.value}'),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _alterarQuantidade(entry.key, 1),
                                                      icon: const Icon(Icons.add_circle_outline),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ],
                              ),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Comparativos históricos por item',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: historico.isEmpty
                                        ? const Center(
                                            child: Text('Sem compras no histórico.'),
                                          )
                                        : ListView.builder(
                                            itemCount: historico.length,
                                            itemBuilder: (context, index) {
                                              final item = historico[index];
                                              return Card(
                                                child: ListTile(
                                                  title: Text(
                                                    '${item.nome} • ${_currency.format(item.preco)}',
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(DateFormat('dd/MM/yyyy')
                                                          .format(item.data)),
                                                      _buildComparativo(
                                                        item.nome,
                                                        historico,
                                                      ),
                                                    ],
                                                  ),
                                                  trailing: IconButton(
                                                    icon: const Icon(Icons.delete_outline),
                                                    onPressed: () =>
                                                        _service.removeShoppingItem(item.id),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
