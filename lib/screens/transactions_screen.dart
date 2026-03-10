import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  final FirestoreService _service = FirestoreService();
  final NumberFormat _currency = NumberFormat.currency(symbol: 'R\$');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final MoneyMaskedTextController valorController = MoneyMaskedTextController(
    decimalSeparator: ',',
    thousandSeparator: '.',
    leftSymbol: 'R\$ ',
  );

  String tipo = 'entrada';
  String categoria = '';
  bool fixa = false;
  bool superfluo = false;

  final List<String> categoriasEntrada = [
    'Crédito de Salário',
    'Adiantamento de Salário',
    'Pagamento de Benefícios',
  ];

  final List<String> categoriasSaida = [
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
    'Outros',
  ];

  @override
  void dispose() {
    valorController.dispose();
    super.dispose();
  }

  List<String> get _categoriasAtuais =>
      tipo == 'entrada' ? categoriasEntrada : categoriasSaida;

  void _resetForm() {
    setState(() {
      valorController.updateValue(0.0);
      categoria = '';
      fixa = false;
      superfluo = false;
    });
  }

  Future<void> _addTransaction() async {
    if (categoria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria.')),
      );
      return;
    }

    await _service.addTransaction(
      TransactionModel(
        id: '',
        valor: valorController.numberValue,
        tipo: tipo,
        categoria: categoria,
        fixa: fixa,
        data: DateTime.now(),
        superfluo: superfluo,
      ),
    );

    _resetForm();
  }

  void _showEditDialog(TransactionModel trans) {
    final editValor = MoneyMaskedTextController(
      decimalSeparator: ',',
      thousandSeparator: '.',
      leftSymbol: 'R\$ ',
      initialValue: trans.valor,
    );

    String editTipo = trans.tipo;
    String editCategoria = trans.categoria;
    bool editFixa = trans.fixa;
    bool editSuperfluo = trans.superfluo;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categorias =
                editTipo == 'entrada' ? categoriasEntrada : categoriasSaida;

            return AlertDialog(
              title: const Text('Editar transação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editValor,
                      decoration: const InputDecoration(labelText: 'Valor'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editTipo,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                        DropdownMenuItem(value: 'saida', child: Text('Saída')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          editTipo = v;
                          editCategoria = '';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editCategoria.isEmpty ? null : editCategoria,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categorias
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => editCategoria = v ?? ''),
                    ),
                    SwitchListTile(
                      title: const Text('Despesa fixa'),
                      value: editFixa,
                      onChanged: (v) => setDialogState(() => editFixa = v),
                    ),
                    SwitchListTile(
                      title: const Text('Supérfluo'),
                      value: editSuperfluo,
                      onChanged: (v) => setDialogState(() => editSuperfluo = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (editCategoria.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione uma categoria.'),
                        ),
                      );
                      return;
                    }

                    await _service.updateTransaction(
                      trans.id,
                      TransactionModel(
                        id: trans.id,
                        valor: editValor.numberValue,
                        tipo: editTipo,
                        categoria: editCategoria,
                        fixa: editFixa,
                        data: trans.data,
                        superfluo: editSuperfluo,
                      ),
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => editValor.dispose());
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.surface,
            child: Icon(Icons.receipt_long, color: colorScheme.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transações',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Gerencie entradas e saídas com visão premium.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<TransactionModel> data) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entradas = data
        .where((t) => t.tipo == 'entrada')
        .fold<double>(0.0, (sum, t) => sum + t.valor);
    final saidas = data
        .where((t) => t.tipo == 'saida')
        .fold<double>(0.0, (sum, t) => sum + t.valor);

    Widget card(String label, double value, Color color) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(value),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Entradas', entradas, colorScheme.tertiary),
        const SizedBox(width: 10),
        card('Saídas', saidas, colorScheme.error),
        const SizedBox(width: 10),
        card('Saldo', entradas - saidas, colorScheme.primary),
      ],
    );
  }

  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: valorController,
            decoration: const InputDecoration(labelText: 'Valor'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'entrada',
                label: Text('Entrada'),
                icon: Icon(Icons.arrow_downward),
              ),
              ButtonSegment(
                value: 'saida',
                label: Text('Saída'),
                icon: Icon(Icons.arrow_upward),
              ),
            ],
            selected: {tipo},
            onSelectionChanged: (value) => setState(() {
              tipo = value.first;
              categoria = '';
            }),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: categoria.isEmpty ? null : categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: _categoriasAtuais
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => categoria = v ?? ''),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Despesa fixa'),
            value: fixa,
            onChanged: (v) => setState(() => fixa = v),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Supérfluo'),
            value: superfluo,
            onChanged: (v) => setState(() => superfluo = v),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addTransaction,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar transação'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(TransactionModel t) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEntrada = t.tipo == 'entrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isEntrada ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
          child: Icon(
            isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
            color: isEntrada ? colorScheme.tertiary : colorScheme.error,
          ),
        ),
        title: Text(t.categoria, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${_dateFormat.format(t.data)} • ${t.fixa ? 'Fixa' : 'Variável'}${t.superfluo ? ' • Supérfluo' : ''}',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            Text(
              _currency.format(t.valor),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isEntrada ? colorScheme.tertiary : colorScheme.error,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(t),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _service.deleteTransaction(t.id),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            child: StreamBuilder<List<TransactionModel>>(
              stream: _service.getTransactions(),
              builder: (context, snapshot) {
                final data = List<TransactionModel>.from(snapshot.data ?? [])
                  ..sort((a, b) => b.data.compareTo(a.data));

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 1100;

                    final Widget listWidget = data.isEmpty
                        ? Center(
                            child: Text(
                              'Sem transações ainda.',
                              style: TextStyle(color: colorScheme.onPrimary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: data.length,
                            itemBuilder: (context, index) => _buildTile(data[index]),
                          );

                    return Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildSummary(data),
                        const SizedBox(height: 10),
                        Expanded(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: _buildForm(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: listWidget),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildForm(),
                                    const SizedBox(height: 10),
                                    Expanded(child: listWidget),
                                  ],
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
