import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:financas_inteligentes/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Tela de transações com botão de exportação para PDF.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  final NumberFormat _currency   = NumberFormat.currency(symbol: 'R\$');
  final DateFormat   _dateFormat = DateFormat('dd/MM/yyyy');

  bool _exportando = false;

  final MoneyMaskedTextController _valorController = MoneyMaskedTextController(
    decimalSeparator: ',',
    thousandSeparator: '.',
    leftSymbol: 'R\$ ',
  );

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _addTransaction() async {
    final tx = context.read<TransactionProvider>();

    if (tx.categoria.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria.')),
      );
      return;
    }

    final ok = await tx.addTransaction(
      TransactionModel(
        id: '',
        valor: _valorController.numberValue,
        tipo: tx.tipo,
        categoria: tx.categoria,
        fixa: tx.fixa,
        data: DateTime.now(),
        superfluo: tx.superfluo,
      ),
    );

    if (ok) _valorController.updateValue(0.0);
  }

  Future<void> _exportarPdf() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final tx        = context.read<TransactionProvider>();
      final userLabel = context.read<AuthProvider>().displayLabel;
      await ReportService.instance.exportarTransacoes(
        transactions: tx.transactions,
        userLabel: userLabel,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _showEditDialog(TransactionModel trans) {
    final editValor = MoneyMaskedTextController(
      decimalSeparator: ',',
      thousandSeparator: '.',
      leftSymbol: 'R\$ ',
      initialValue: trans.valor,
    );

    String editTipo      = trans.tipo;
    String editCategoria = trans.categoria;
    bool   editFixa      = trans.fixa;
    bool   editSuperfluo = trans.superfluo;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categorias = editTipo == 'entrada'
                ? TransactionProvider.categoriasEntrada
                : TransactionProvider.categoriasSaida;

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
                        DropdownMenuItem(value: 'saida',   child: Text('Saída')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          editTipo      = v;
                          editCategoria = '';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: editCategoria.isEmpty ? null : editCategoria,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categorias
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                        const SnackBar(content: Text('Selecione uma categoria.')),
                      );
                      return;
                    }
                    await context.read<TransactionProvider>().updateTransaction(
                          trans.id,
                          TransactionModel(
                            id:         trans.id,
                            valor:      editValor.numberValue,
                            tipo:       editTipo,
                            categoria:  editCategoria,
                            fixa:       editFixa,
                            data:       trans.data,
                            superfluo:  editSuperfluo,
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

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

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
          const SizedBox(width: 12),
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
          // ── Botão exportar PDF ─────────────────────────────────────────
          Tooltip(
            message: 'Exportar extrato em PDF',
            child: _exportando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    onPressed: _exportarPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    color: colorScheme.onPrimary,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final tx          = context.watch<TransactionProvider>();

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
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Entradas', tx.totalEntradas, colorScheme.tertiary),
        const SizedBox(width: 10),
        card('Saídas',   tx.totalSaidas,   colorScheme.error),
        const SizedBox(width: 10),
        card('Saldo',    tx.saldo,          colorScheme.primary),
      ],
    );
  }

  Widget _buildForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final tx          = context.watch<TransactionProvider>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          TextField(
            controller: _valorController,
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
            selected: {tx.tipo},
            onSelectionChanged: (value) =>
                context.read<TransactionProvider>().setTipo(value.first),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('cat_${tx.tipo}'),
            initialValue: tx.categoria.isEmpty ? null : tx.categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: tx.categoriasAtuais
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) =>
                context.read<TransactionProvider>().setCategoria(v ?? ''),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Despesa fixa'),
            value: tx.fixa,
            onChanged: (v) => context.read<TransactionProvider>().setFixa(v),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Supérfluo'),
            value: tx.superfluo,
            onChanged: (v) =>
                context.read<TransactionProvider>().setSuperfluo(v),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: tx.isSubmitting ? null : _addTransaction,
              icon: tx.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Adicionar transação'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(TransactionModel t) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEntrada   = t.tipo == 'entrada';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isEntrada
              ? colorScheme.tertiaryContainer
              : colorScheme.errorContainer,
          child: Icon(
            isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
            color: isEntrada ? colorScheme.tertiary : colorScheme.error,
          ),
        ),
        title: Text(t.categoria,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${_dateFormat.format(t.data)} • ${t.fixa ? 'Fixa' : 'Variável'}'
          '${t.superfluo ? ' • Supérfluo' : ''}',
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
              onPressed: () =>
                  context.read<TransactionProvider>().deleteTransaction(t.id),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tx          = context.watch<TransactionProvider>();
    final data        = tx.transactions;

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
            child: LayoutBuilder(
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
                        itemBuilder: (_, index) => _buildTile(data[index]),
                      );

                return Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    _buildSummary(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                      child: _buildForm()),
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
            ),
          ),
        ),
      ),
    );
  }
}
