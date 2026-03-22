import 'package:financas_inteligentes/models/transaction_model.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Tela de transações com filtro por período (P3-A).
///
/// Novidades:
///   - [_buildPeriodoSelector] → navegação ← mês/ano → com seta e picker
///   - Lista exibe apenas [tx.transactionsFiltradas] (período selecionado)
///   - Totais (entradas/saídas/saldo) refletem o período selecionado
///   - Botão "Hoje" volta para o mês corrente quando em mês diferente
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  TransactionsScreenState createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  final NumberFormat _currency = NumberFormat.currency(symbol: 'R\$');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _mesFormat  = DateFormat('MMMM yyyy', 'pt_BR');

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
                      onChanged: (v) =>
                          setDialogState(() => editSuperfluo = v),
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
                            content: Text('Selecione uma categoria.')),
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

  // ── Seletor de período ────────────────────────────────────────────────────

  /// Abre um diálogo com lista dos meses disponíveis para selecionar.
  Future<void> _showMesPicker(TransactionProvider tx) async {
    final meses = tx.mesesDisponiveis;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar período'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 280,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: meses.length,
            itemBuilder: (context, index) {
              final mes = meses[index];
              final isSelected =
                  mes.month == tx.periodoSelecionado.month &&
                  mes.year  == tx.periodoSelecionado.year;
              final label = DateFormat('MMMM yyyy', 'pt_BR').format(mes);
              final count = tx.transactions
                  .where((t) =>
                      t.data.month == mes.month && t.data.year == mes.year)
                  .length;

              return ListTile(
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primary,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                leading: isSelected
                    ? Icon(Icons.radio_button_checked,
                        color: Theme.of(context).colorScheme.primary)
                    : const Icon(Icons.radio_button_unchecked),
                title: Text(
                  label[0].toUpperCase() + label.substring(1),
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                trailing: count > 0
                    ? Text(
                        '$count',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      )
                    : null,
                onTap: () {
                  context.read<TransactionProvider>().setPeriodo(mes);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodoSelector(TransactionProvider tx) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final label       = _mesFormat.format(tx.periodoSelecionado);
    final labelFmt    = label[0].toUpperCase() + label.substring(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ← mês anterior
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          color: colorScheme.onPrimary,
          onPressed: tx.irParaMesAnterior,
        ),

        // Label clicável — abre picker
        GestureDetector(
          onTap: () => _showMesPicker(tx),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: colorScheme.onPrimary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 16, color: colorScheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  labelFmt,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: colorScheme.onPrimary),
              ],
            ),
          ),
        ),

        // → mês seguinte (oculto quando já está no mês atual)
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          color: tx.temProximoMes
              ? colorScheme.onPrimary
              : colorScheme.onPrimary.withValues(alpha: 0.3),
          onPressed: tx.temProximoMes ? tx.irParaProximoMes : null,
        ),

        // Botão "Hoje" — só aparece quando não está no mês atual
        if (!tx.isPeriodoAtual)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: tx.irParaMesAtual,
            child: const Text('Hoje'),
          ),
      ],
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader(TransactionProvider tx) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            ],
          ),
          const SizedBox(height: 12),
          // Seletor de período centralizado abaixo do título
          Center(child: _buildPeriodoSelector(tx)),
        ],
      ),
    );
  }

  Widget _buildSummary(TransactionProvider tx) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;
    final count       = tx.transactionsFiltradas.length;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            card('Entradas', tx.totalEntradas, colorScheme.tertiary),
            const SizedBox(width: 10),
            card('Saídas', tx.totalSaidas, colorScheme.error),
            const SizedBox(width: 10),
            card('Saldo', tx.saldo, colorScheme.primary),
          ],
        ),
        if (count > 0) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$count transaç${count == 1 ? 'ão' : 'ões'} no período',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForm(TransactionProvider tx) {
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
            onChanged: (v) =>
                context.read<TransactionProvider>().setFixa(v),
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
              onPressed: () => context
                  .read<TransactionProvider>()
                  .deleteTransaction(t.id),
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

    // Lista filtrada pelo período selecionado
    final data = tx.transactionsFiltradas;

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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 48,
                              color: colorScheme.onPrimary
                                  .withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sem transações em ${DateFormat('MMMM yyyy', 'pt_BR').format(tx.periodoSelecionado)}.',
                              style: TextStyle(
                                  color: colorScheme.onPrimary
                                      .withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) =>
                            _buildTile(data[index]),
                      );

                return Column(
                  children: [
                    _buildHeader(tx),
                    const SizedBox(height: 10),
                    _buildSummary(tx),
                    const SizedBox(height: 10),
                    Expanded(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                      child: _buildForm(tx)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: listWidget),
                              ],
                            )
                          : Column(
                              children: [
                                _buildForm(tx),
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
