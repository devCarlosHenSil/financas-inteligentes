import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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
  final MoneyMaskedTextController _precoController = MoneyMaskedTextController(
    decimalSeparator: ',',
    thousandSeparator: '.',
    leftSymbol: 'R\$ ',
  );
//departamento
  final Map<String, List<String>> _catalogoPorDepartamento = const {
    'Mercearia': [
      'Arroz',
      'Feijão',
      'Açúcar',
      'Sal',
      'Óleo de Soja',
      'Macarrão',
      'Farinha de Trigo',
      'Farinha de Mandioca',
      'Molho de Tomate',
      'Café',
    ],
    'Hortifruti': [
      'Batata',
      'Cebola',
      'Tomate',
      'Alface',
      'Cenoura',
      'Banana',
      'Maçã',
      'Laranja',
      'Limão',
      'Mamão',
    ],
    'Açougue': [
      'Carne Bovina',
      'Frango',
      'Peito de Frango',
      'Coxa e Sobrecoxa',
      'Carne Suína',
      'Linguiça Fresca',
      'Peixe',
      'Ovos',
    ],
    'Embutidos': [
      'Presunto',
      'Mortadela',
      'Salame',
      'Salsicha',
      'Bacon',
      'Peito de Peru',
      'Calabresa',
    ],
    'Laticínios': [
      'Leite',
      'Queijo Mussarela',
      'Requeijão',
      'Manteiga',
      'Iogurte',
      'Creme de Leite',
      'Leite Condensado',
    ],
    'Padaria': [
      'Pão Francês',
      'Pão de Forma',
      'Bolo Simples',
      'Biscoito',
      'Torrada',
    ],
    'Bebidas': [
      'Água Mineral',
      'Suco',
      'Refrigerante',
      'Chá',
      'Achocolatado',
    ],
    'Limpeza': [
      'Detergente',
      'Sabão em Pó',
      'Amaciante',
      'Água Sanitária',
      'Desinfetante',
      'Esponja',
      'Saco de Lixo',
    ],
    'Higiene': [
      'Papel Higiênico',
      'Sabonete',
      'Shampoo',
      'Condicionador',
      'Creme Dental',
      'Escova de Dentes',
      'Desodorante',
    ],
    'Congelados': [
      'Hambúrguer',
      'Nuggets',
      'Lasanha',
      'Pizza Congelada',
      'Batata Congelada',
    ],
  };

  final Map<String, List<Map<String, dynamic>>> _promocoesPorCidade = const {
    'São Paulo': [
      {'item': 'Leite', 'mercado': 'Atacadão', 'preco': 4.39},
      {'item': 'Arroz', 'mercado': 'Assaí', 'preco': 24.90},
      {'item': 'Feijão', 'mercado': 'Carrefour', 'preco': 7.89},
      {'item': 'Óleo de Soja', 'mercado': 'Extra', 'preco': 6.49},
      {'item': 'Açúcar', 'mercado': 'Sonda', 'preco': 4.29},
      {'item': 'Carne Bovina', 'mercado': 'Roldão', 'preco': 32.90},
    ],
    'Itu': [
      {'item': 'Leite', 'mercado': 'Pague Menos', 'preco': 4.29},
      {'item': 'Arroz', 'mercado': 'Assaí Itu', 'preco': 23.90},
      {'item': 'Feijão', 'mercado': 'Roldão Itu', 'preco': 7.49},
      {'item': 'Óleo de Soja', 'mercado': 'GoodBom', 'preco': 6.19},
      {'item': 'Açúcar', 'mercado': 'São Vicente', 'preco': 4.09},
      {'item': 'Carne Bovina', 'mercado': 'Tenda Itu', 'preco': 31.90},
    ],
    'Campinas': [
      {'item': 'Leite', 'mercado': 'Enxuto', 'preco': 4.45},
      {'item': 'Arroz', 'mercado': 'Savegnago', 'preco': 24.40},
      {'item': 'Feijão', 'mercado': 'Dalben', 'preco': 7.79},
      {'item': 'Óleo de Soja', 'mercado': 'Atacadão', 'preco': 6.39},
      {'item': 'Açúcar', 'mercado': 'Assaí', 'preco': 4.19},
      {'item': 'Carne Bovina', 'mercado': 'Atacadista', 'preco': 32.50},
    ],
    'Rio de Janeiro': [
      {'item': 'Leite', 'mercado': 'Guanabara', 'preco': 4.59},
      {'item': 'Tomate', 'mercado': 'Prezunic', 'preco': 5.99},
      {'item': 'Café', 'mercado': 'Mundial', 'preco': 14.99},
      {'item': 'Arroz', 'mercado': 'Assaí', 'preco': 25.10},
      {'item': 'Feijão', 'mercado': 'Inter', 'preco': 8.29},
    ],
    'Belo Horizonte': [
      {'item': 'Leite', 'mercado': 'EPA', 'preco': 4.49},
      {'item': 'Arroz', 'mercado': 'Villefort', 'preco': 23.90},
      {'item': 'Detergente', 'mercado': 'Supernosso', 'preco': 2.19},
      {'item': 'Feijão', 'mercado': 'BH', 'preco': 7.69},
      {'item': 'Carne Bovina', 'mercado': 'ABC', 'preco': 32.90},
    ],
  };

  String _departamentoSelecionado = 'Mercearia';
  String _cidadeSelecionada = 'São Paulo';
  bool _localizando = false;

  final Map<String, int> _carrinho = {};

  List<String> get _itensDepartamentoAtual =>
      _catalogoPorDepartamento[_departamentoSelecionado] ?? [];

  @override
  void initState() {
    super.initState();
    _detectarCidadePorGeolocalizacao();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  String _normalizar(String text) {
    const map = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c'
    };
    var out = text.toLowerCase();
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  Future<void> _detectarCidadePorGeolocalizacao() async {
    setState(() => _localizando = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _localizando = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _localizando = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        setState(() => _localizando = false);
        return;
      }

      final cidadeDetectada =
          (placemarks.first.subAdministrativeArea ?? placemarks.first.locality ?? '')
              .trim();

      final cidadeMatch = _promocoesPorCidade.keys.firstWhere(
        (c) => _normalizar(c) == _normalizar(cidadeDetectada),
        orElse: () => _promocoesPorCidade.keys.firstWhere(
          (c) => _normalizar(cidadeDetectada).contains(_normalizar(c)),
          orElse: () => _cidadeSelecionada,
        ),
      );

      if (!mounted) return;
      setState(() {
        _cidadeSelecionada = cidadeMatch;
        _localizando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _localizando = false);
    }
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
    final preco = _precoController.numberValue;

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
    _precoController.updateValue(0);
  }

  double _precoAtualOuPromocao(String item, List<ShoppingItemModel> historico) {
    final promo = (_promocoesPorCidade[_cidadeSelecionada] ?? [])
        .where((p) => (p['item'] as String).toLowerCase() == item.toLowerCase())
        .toList();

    if (promo.isNotEmpty) {
      promo.sort((a, b) => (a['preco'] as double).compareTo(b['preco'] as double));
      return promo.first['preco'] as double;
    }

    final historicoItem = historico
        .where((h) => h.nome.toLowerCase() == item.toLowerCase())
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));

    return historicoItem.isNotEmpty ? historicoItem.first.preco : 0;
  }

  Widget _buildComparativo(String item, List<ShoppingItemModel> historico) {
    final colorScheme = Theme.of(context).colorScheme;
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
      return Text(
        'Sem dados suficientes para comparativo mensal.',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
        color: maisBarato ? colorScheme.tertiary : colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primaryContainer],
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
                  final preco = _precoAtualOuPromocao(e.key, historico);
                  return sum + (preco * e.value);
                });

                final promocoesCidade = List<Map<String, dynamic>>.from(
                  _promocoesPorCidade[_cidadeSelecionada] ?? [],
                )..sort(
                    (a, b) =>
                        (a['preco'] as double).compareTo(b['preco'] as double),
                  );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lista de Compras Inteligente',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_localizando)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          tooltip: 'Atualizar localização',
                          onPressed: _detectarCidadePorGeolocalizacao,
                          icon: Icon(Icons.my_location, color: colorScheme.onPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localizando
                          ? 'Detectando sua cidade...'
                          : 'Cidade atual para promoções: $_cidadeSelecionada',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 340,
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
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
                                    onChanged: (v) => setState(() {
                                      _departamentoSelecionado =
                                          v ?? _departamentoSelecionado;
                                      _itemController.clear();
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('cidade-$_cidadeSelecionada'),
                                    initialValue: _cidadeSelecionada,
                                    decoration: const InputDecoration(
                                      labelText: 'Cidade para promoções próximas',
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
                                    key: ValueKey('autocomplete-$_departamentoSelecionado'),
                                    optionsBuilder: (textEditingValue) {
                                      final itensDepartamento =
                                          List<String>.from(_itensDepartamentoAtual);
                                      if (textEditingValue.text.isEmpty) {
                                        return itensDepartamento;
                                      }
                                      return itensDepartamento.where(
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
                                      labelText: 'Preço pago (R\$)',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _salvarItemHistorico,
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text(
                                        'Adicionar item e enviar ao carrinho',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Itens do departamento: $_departamentoSelecionado',
                                      style: textTheme.titleMedium?.copyWith(
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
                                      'Melhores preços em $_cidadeSelecionada',
                                      style: textTheme.titleMedium?.copyWith(
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
                                              style: TextStyle(
                                                color: colorScheme.tertiary,
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
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Carrinho de compras',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Total estimado antes do caixa: ${_currency.format(totalCarrinho)}',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
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
                                                final preco =
                                                    _precoAtualOuPromocao(entry.key, historico);
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
                                                        icon: const Icon(
                                                          Icons.remove_circle_outline,
                                                        ),
                                                      ),
                                                      Text('${entry.value}'),
                                                      IconButton(
                                                        onPressed: () =>
                                                            _alterarQuantidade(entry.key, 1),
                                                        icon: const Icon(
                                                          Icons.add_circle_outline,
                                                        ),
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Comparativos históricos por item',
                                      style: textTheme.titleMedium?.copyWith(
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
                                                        Text(
                                                          DateFormat('dd/MM/yyyy')
                                                              .format(item.data),
                                                        ),
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
