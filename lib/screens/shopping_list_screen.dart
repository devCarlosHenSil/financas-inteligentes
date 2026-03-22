import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/providers/shopping_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ── Dados estáticos ────────────────────────────────────────────────────────────
// Movidos para constantes de arquivo — não precisam ser recriados a cada build.

const _catalogoPorDepartamento = <String, List<String>>{
  'Mercearia': [
    'Arroz', 'Feijão', 'Açúcar', 'Sal', 'Óleo de Soja',
    'Macarrão', 'Farinha de Trigo', 'Farinha de Mandioca',
    'Molho de Tomate', 'Café',
  ],
  'Hortifruti': [
    'Batata', 'Cebola', 'Tomate', 'Alface', 'Cenoura',
    'Banana', 'Maçã', 'Laranja', 'Limão', 'Mamão',
  ],
  'Açougue': [
    'Carne Bovina', 'Frango', 'Peito de Frango', 'Coxa e Sobrecoxa',
    'Carne Suína', 'Linguiça Fresca', 'Peixe', 'Ovos',
  ],
  'Embutidos': [
    'Presunto', 'Mortadela', 'Salame', 'Salsicha',
    'Bacon', 'Peito de Peru', 'Calabresa',
  ],
  'Laticínios': [
    'Leite', 'Queijo Mussarela', 'Requeijão', 'Manteiga',
    'Iogurte', 'Creme de Leite', 'Leite Condensado',
  ],
  'Padaria': [
    'Pão Francês', 'Pão de Forma', 'Bolo Simples', 'Biscoito', 'Torrada',
  ],
  'Bebidas': [
    'Água Mineral', 'Suco', 'Refrigerante', 'Chá', 'Achocolatado',
  ],
  'Limpeza': [
    'Detergente', 'Sabão em Pó', 'Amaciante', 'Água Sanitária',
    'Desinfetante', 'Esponja', 'Saco de Lixo',
  ],
  'Higiene': [
    'Papel Higiênico', 'Sabonete', 'Shampoo', 'Condicionador',
    'Creme Dental', 'Escova de Dentes', 'Desodorante',
  ],
  'Congelados': [
    'Hambúrguer', 'Nuggets', 'Lasanha', 'Pizza Congelada', 'Batata Congelada',
  ],
};

const _promocoesPorCidade = <String, List<Map<String, dynamic>>>{
  'São Paulo': [
    {'item': 'Leite',        'mercado': 'Atacadão',  'preco': 4.39},
    {'item': 'Arroz',        'mercado': 'Assaí',     'preco': 24.90},
    {'item': 'Feijão',       'mercado': 'Carrefour', 'preco': 7.89},
    {'item': 'Óleo de Soja', 'mercado': 'Extra',     'preco': 6.49},
    {'item': 'Açúcar',       'mercado': 'Sonda',     'preco': 4.29},
    {'item': 'Carne Bovina', 'mercado': 'Roldão',    'preco': 32.90},
  ],
  'Itu': [
    {'item': 'Leite',        'mercado': 'Pague Menos', 'preco': 4.29},
    {'item': 'Arroz',        'mercado': 'Assaí Itu',   'preco': 23.90},
    {'item': 'Feijão',       'mercado': 'Roldão Itu',  'preco': 7.49},
    {'item': 'Óleo de Soja', 'mercado': 'GoodBom',     'preco': 6.19},
    {'item': 'Açúcar',       'mercado': 'São Vicente',  'preco': 4.09},
    {'item': 'Carne Bovina', 'mercado': 'Tenda Itu',   'preco': 31.90},
  ],
  'Campinas': [
    {'item': 'Leite',        'mercado': 'Enxuto',     'preco': 4.45},
    {'item': 'Arroz',        'mercado': 'Savegnago',  'preco': 24.40},
    {'item': 'Feijão',       'mercado': 'Dalben',     'preco': 7.79},
    {'item': 'Óleo de Soja', 'mercado': 'Atacadão',   'preco': 6.39},
    {'item': 'Açúcar',       'mercado': 'Assaí',      'preco': 4.19},
    {'item': 'Carne Bovina', 'mercado': 'Atacadista', 'preco': 32.50},
  ],
  'Rio de Janeiro': [
    {'item': 'Leite',  'mercado': 'Guanabara', 'preco': 4.59},
    {'item': 'Tomate', 'mercado': 'Prezunic',  'preco': 5.99},
    {'item': 'Café',   'mercado': 'Mundial',   'preco': 14.99},
    {'item': 'Arroz',  'mercado': 'Assaí',     'preco': 25.10},
    {'item': 'Feijão', 'mercado': 'Inter',     'preco': 8.29},
  ],
  'Belo Horizonte': [
    {'item': 'Leite',        'mercado': 'EPA',        'preco': 4.49},
    {'item': 'Arroz',        'mercado': 'Villefort',  'preco': 23.90},
    {'item': 'Detergente',   'mercado': 'Supernosso', 'preco': 2.19},
    {'item': 'Feijão',       'mercado': 'BH',         'preco': 7.69},
    {'item': 'Carne Bovina', 'mercado': 'ABC',        'preco': 32.90},
  ],
};

// ── ShoppingListScreen ─────────────────────────────────────────────────────────
//
// Migração P2-A:
//   REMOVIDO  — FirestoreService instanciado diretamente
//   REMOVIDO  — setState para carrinho, departamento, cidade, localizando
//   ADICIONADO — context.watch<ShoppingProvider> para todo estado de negócio
//
// Estado local mantido (puro de UI):
//   _itemController, _precoController — campos do formulário
//
// Geolocalização permanece no State: usa verificação de `mounted` e
// precisa de permissões que dependem do contexto de plataforma.

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ShoppingListScreenState createState() => ShoppingListScreenState();
}

class ShoppingListScreenState extends State<ShoppingListScreen> {
  final NumberFormat _currency = NumberFormat.currency(symbol: 'R\$');

  // Controllers de formulário — único estado local desta tela
  final TextEditingController _itemController = TextEditingController();
  final MoneyMaskedTextController _precoController = MoneyMaskedTextController(
    decimalSeparator: ',',
    thousandSeparator: '.',
    leftSymbol: 'R\$ ',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectarCidadePorGeolocalizacao();
    });
  }

  @override
  void dispose() {
    _itemController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  // ── Geolocalização ────────────────────────────────────────────────────────

  String _normalizar(String text) {
    const map = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'ê': 'e', 'í': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ç': 'c',
    };
    var out = text.toLowerCase();
    map.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
  }

  Future<void> _detectarCidadePorGeolocalizacao() async {
    if (!mounted) return;
    final shopping = context.read<ShoppingProvider>();
    shopping.setLocalizando(true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) shopping.setLocalizando(false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) shopping.setLocalizando(false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        shopping.setLocalizando(false);
        return;
      }

      final cidadeDetectada =
          (placemarks.first.subAdministrativeArea ??
                  placemarks.first.locality ??
                  '')
              .trim();

      final cidadeMatch = _promocoesPorCidade.keys.firstWhere(
        (c) => _normalizar(c) == _normalizar(cidadeDetectada),
        orElse: () => _promocoesPorCidade.keys.firstWhere(
          (c) => _normalizar(cidadeDetectada).contains(_normalizar(c)),
          orElse: () => shopping.cidadeSelecionada,
        ),
      );

      shopping
        ..setCidade(cidadeMatch)
        ..setLocalizando(false);
    } catch (_) {
      if (mounted) context.read<ShoppingProvider>().setLocalizando(false);
    }
  }

  // ── Ações do formulário ───────────────────────────────────────────────────

  Future<void> _salvarItemHistorico() async {
    final nome = _itemController.text.trim();
    final preco = _precoController.numberValue;

    if (nome.isEmpty || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe item e preço válido.')),
      );
      return;
    }

    await context.read<ShoppingProvider>().salvarItem(
          ShoppingItemModel(
            id: '',
            nome: nome,
            preco: preco,
            data: DateTime.now(),
          ),
        );

    _itemController.clear();
    _precoController.updateValue(0);
  }

  // ── Preço de referência unitário para exibição no carrinho ────────────────

  double _precoUnitario(String item, List<ShoppingItemModel> historico) {
    final cidade = context.read<ShoppingProvider>().cidadeSelecionada;
    final promos = (_promocoesPorCidade[cidade] ?? [])
        .where((p) => (p['item'] as String).toLowerCase() == item.toLowerCase())
        .toList();

    if (promos.isNotEmpty) {
      promos.sort(
          (a, b) => (a['preco'] as double).compareTo(b['preco'] as double));
      return promos.first['preco'] as double;
    }

    final hist = historico
        .where((h) => h.nome.toLowerCase() == item.toLowerCase())
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));

    return hist.isNotEmpty ? hist.first.preco : 0;
  }

  // ── Widget: comparativo mensal de preço ───────────────────────────────────

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
        'Sem dados suficientes para comparativo.',
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // context.watch → rebuild ao notifyListeners() do provider
    final shopping = context.watch<ShoppingProvider>();
    final departamentoAtual =
        _catalogoPorDepartamento[shopping.departamentoSelecionado] ?? [];

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
              stream: shopping.shoppingItemsStream,
              builder: (context, snapshot) {
                final historico = snapshot.data ?? [];

                final totalCarrinho = shopping.calcularTotalCarrinho(
                  historico,
                  _promocoesPorCidade,
                );

                final promocoesCidade = List<Map<String, dynamic>>.from(
                  _promocoesPorCidade[shopping.cidadeSelecionada] ?? [],
                )..sort((a, b) =>
                    (a['preco'] as double).compareTo(b['preco'] as double));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────
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
                        if (shopping.localizando)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton(
                          tooltip: 'Atualizar localização',
                          onPressed: _detectarCidadePorGeolocalizacao,
                          icon: Icon(Icons.my_location,
                              color: colorScheme.onPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shopping.localizando
                          ? 'Detectando sua cidade...'
                          : 'Cidade: ${shopping.cidadeSelecionada}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Painel superior: formulário + promoções ─────────
                    SizedBox(
                      height: 340,
                      child: Row(
                        children: [
                          // Formulário
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: shopping.departamentoSelecionado,
                                      decoration: const InputDecoration(
                                          labelText: 'Departamento'),
                                      items: _catalogoPorDepartamento.keys
                                          .map((d) => DropdownMenuItem(
                                              value: d, child: Text(d)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        context
                                            .read<ShoppingProvider>()
                                            .setDepartamento(v);
                                        _itemController.clear();
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(
                                          'cidade-${shopping.cidadeSelecionada}'),
                                      initialValue: shopping.cidadeSelecionada,
                                      decoration: const InputDecoration(
                                          labelText:
                                              'Cidade para promoções próximas'),
                                      items: _promocoesPorCidade.keys
                                          .map((c) => DropdownMenuItem(
                                              value: c, child: Text(c)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          context
                                              .read<ShoppingProvider>()
                                              .setCidade(v);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Autocomplete<String>(
                                      key: ValueKey(
                                          'ac-${shopping.departamentoSelecionado}'),
                                      optionsBuilder: (textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return departamentoAtual;
                                        }
                                        return departamentoAtual.where((o) =>
                                            o.toLowerCase().contains(
                                                textEditingValue.text
                                                    .toLowerCase()));
                                      },
                                      onSelected: (v) =>
                                          _itemController.text = v,
                                      fieldViewBuilder: (ctx, ctrl, fn, _) {
                                        ctrl.text = _itemController.text;
                                        return TextField(
                                          controller: ctrl,
                                          focusNode: fn,
                                          decoration: const InputDecoration(
                                              labelText:
                                                  'Item (pré-cadastrado ou manual)'),
                                          onChanged: (v) =>
                                              _itemController.text = v,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _precoController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Preço pago (R\$)'),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _salvarItemHistorico,
                                        icon: const Icon(
                                            Icons.add_shopping_cart),
                                        label: const Text(
                                            'Adicionar item ao carrinho'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Chips + promoções
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Itens: ${shopping.departamentoSelecionado}',
                                      style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: departamentoAtual
                                          .map((item) => ActionChip(
                                                label: Text(item),
                                                onPressed: () => context
                                                    .read<ShoppingProvider>()
                                                    .adicionarAoCarrinho(item),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Melhores preços em ${shopping.cidadeSelecionada}',
                                      style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: promocoesCidade.length,
                                        itemBuilder: (context, i) {
                                          final p = promocoesCidade[i];
                                          return ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                                '${p['item']} • ${p['mercado']}'),
                                            trailing: Text(
                                              _currency.format(
                                                  p['preco'] as double),
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

                    // ── Painel inferior: carrinho + histórico ───────────
                    Expanded(
                      child: Row(
                        children: [
                          // Carrinho
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
                                          fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      'Total estimado: ${_currency.format(totalCarrinho)}',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: shopping.carrinho.isEmpty
                                          ? const Center(
                                              child: Text('Carrinho vazio.'))
                                          : ListView(
                                              children: shopping.carrinho.entries
                                                  .map((entry) {
                                                final precoRef =
                                                    _precoUnitario(
                                                        entry.key, historico);
                                                return ListTile(
                                                  title: Text(entry.key),
                                                  subtitle: Text(
                                                      'Ref.: ${_currency.format(precoRef)}'),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        onPressed: () => context
                                                            .read<ShoppingProvider>()
                                                            .alterarQuantidade(
                                                                entry.key, -1),
                                                        icon: const Icon(Icons
                                                            .remove_circle_outline),
                                                      ),
                                                      Text('${entry.value}'),
                                                      IconButton(
                                                        onPressed: () => context
                                                            .read<ShoppingProvider>()
                                                            .alterarQuantidade(
                                                                entry.key, 1),
                                                        icon: const Icon(Icons
                                                            .add_circle_outline),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                    ),
                                    if (shopping.carrinho.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () => context
                                              .read<ShoppingProvider>()
                                              .limparCarrinho(),
                                          icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16),
                                          label:
                                              const Text('Limpar carrinho'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Histórico
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Comparativos históricos',
                                      style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: historico.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  'Sem compras no histórico.'))
                                          : ListView.builder(
                                              itemCount: historico.length,
                                              itemBuilder: (context, i) {
                                                final item = historico[i];
                                                return Card(
                                                  child: ListTile(
                                                    title: Text(
                                                        '${item.nome} • ${_currency.format(item.preco)}'),
                                                    subtitle: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(DateFormat(
                                                                'dd/MM/yyyy')
                                                            .format(
                                                                item.data)),
                                                        _buildComparativo(
                                                            item.nome,
                                                            historico),
                                                      ],
                                                    ),
                                                    trailing: IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline),
                                                      onPressed: () => context
                                                          .read<
                                                              ShoppingProvider>()
                                                          .removerItem(
                                                              item.id),
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
