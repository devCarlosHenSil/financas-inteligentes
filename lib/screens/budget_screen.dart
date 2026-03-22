import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/budget_model.dart';
import 'package:financas_inteligentes/providers/budget_provider.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

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
          child: _BudgetBody(
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
      ),
    );
  }
}

// ── _BudgetBody ───────────────────────────────────────────────────────────────

class _BudgetBody extends StatefulWidget {
  const _BudgetBody({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme   textTheme;

  @override
  State<_BudgetBody> createState() => _BudgetBodyState();
}

class _BudgetBodyState extends State<_BudgetBody> {
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _mesFmt   = DateFormat('MMMM yyyy', 'pt_BR');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sincroniza gastos do TransactionProvider → BudgetProvider
    final gastos = context.watch<TransactionProvider>().saidasPorCategoria;
    // usa addPostFrameCallback para evitar rebuild durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BudgetProvider>().atualizarGastos(gastos);
      }
    });
  }

  // ── Navegação de período ──────────────────────────────────────────────────

  void _anteriorMes(BudgetProvider budget) {
    final tx = context.read<TransactionProvider>();
    final ant = DateTime(
      budget.periodoSelecionado.year,
      budget.periodoSelecionado.month - 1,
    );
    budget.setPeriodo(ant);
    tx.setPeriodo(ant);
  }

  void _proximoMes(BudgetProvider budget) {
    final tx  = context.read<TransactionProvider>();
    final prx = DateTime(
      budget.periodoSelecionado.year,
      budget.periodoSelecionado.month + 1,
    );
    budget.setPeriodo(prx);
    tx.setPeriodo(prx);
  }

  bool get _temProximo {
    final now = DateTime.now();
    final p   = context.read<BudgetProvider>().periodoSelecionado;
    return p.year < now.year ||
        (p.year == now.year && p.month < now.month);
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BudgetProvider budget) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;
    final label = _mesFmt.format(budget.periodoSelecionado);
    final labelFmt = label[0].toUpperCase() + label.substring(1);
    final alertCount = budget.totalAlertas;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.surface,
                child: Icon(Icons.account_balance_outlined, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Orçamento Mensal',
                        style: tt.titleLarge?.copyWith(
                            color: cs.onPrimary, fontWeight: FontWeight.w800)),
                    Text('Defina limites por categoria e acompanhe os gastos.',
                        style: tt.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.75))),
                  ],
                ),
              ),
              if (alertCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$alertCount alerta${alertCount != 1 ? 's' : ''}',
                    style: tt.labelMedium?.copyWith(
                        color: cs.onError, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Seletor de período
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: cs.onPrimary,
                onPressed: () => _anteriorMes(budget),
              ),
              GestureDetector(
                onTap: () => _showMesPicker(budget),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: cs.onPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 16, color: cs.onPrimary),
                      const SizedBox(width: 6),
                      Text(labelFmt,
                          style: tt.labelLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down,
                          size: 18, color: cs.onPrimary),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: _temProximo
                    ? cs.onPrimary
                    : cs.onPrimary.withValues(alpha: 0.3),
                onPressed: _temProximo ? () => _proximoMes(budget) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard(BudgetProvider budget) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;
    final progresso = budget.progressoGeral;
    final corBarra  = progresso >= 1.0
        ? cs.error
        : progresso >= 0.75
            ? Colors.orange
            : cs.tertiary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Resumo do período',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${(progresso * 100).toStringAsFixed(0)}% do orçamento',
                  style: tt.labelMedium?.copyWith(
                      color: corBarra, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progresso.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 700),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(corBarra),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniCard('Limite total', _currency.format(budget.totalLimite),
                    cs.primary, tt),
                const SizedBox(width: 10),
                _miniCard('Gasto', _currency.format(budget.totalGasto),
                    progresso >= 1.0 ? cs.error : cs.onSurface, tt),
                const SizedBox(width: 10),
                _miniCard(
                  'Disponível',
                  _currency
                      .format((budget.totalLimite - budget.totalGasto)),
                  budget.totalLimite - budget.totalGasto >= 0
                      ? cs.tertiary
                      : cs.error,
                  tt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(
      String label, String value, Color color, TextTheme tt) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: tt.labelSmall
                  ?.copyWith(color: widget.colorScheme.onSurfaceVariant)),
          Text(value,
              style: tt.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(BudgetModel budget) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openForm(context, budget: budget),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: budget.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(budget.statusIcon,
                        color: budget.statusColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(budget.categoria,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(budget.statusLabel,
                            style: tt.labelSmall?.copyWith(
                                color: budget.statusColor,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currency.format(budget.gasto),
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: budget.isExceeded ? cs.error : cs.onSurface),
                      ),
                      Text(
                        'de ${_currency.format(budget.limite)}',
                        style: tt.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (action) async {
                      if (action == 'edit') {
                        _openForm(context, budget: budget);
                      } else {
                        await context
                            .read<BudgetProvider>()
                            .deleteBudget(budget.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                      begin: 0, end: budget.progresso.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        budget.statusColor),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${budget.progressoPercent.toStringAsFixed(1)}% utilizado',
                    style:
                        tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    budget.restante >= 0
                        ? 'Restam ${_currency.format(budget.restante)}'
                        : 'Excedeu ${_currency.format(budget.restante.abs())}',
                    style: tt.labelSmall?.copyWith(
                      color: budget.restante >= 0
                          ? cs.onSurfaceVariant
                          : cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriaSemOrcamento(String categoria) {
    final cs    = widget.colorScheme;
    final tt    = widget.textTheme;
    final gasto = context.read<BudgetProvider>().gastos[categoria] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surfaceContainerLow,
      child: ListTile(
        leading: Icon(Icons.remove_circle_outline,
            color: cs.onSurfaceVariant, size: 20),
        title: Text(categoria, style: tt.bodyMedium),
        subtitle: Text('Gasto: ${_currency.format(gasto)} — sem orçamento',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        trailing: TextButton(
          onPressed: () => _openForm(context, categoriaPreset: categoria),
          child: const Text('Definir'),
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showMesPicker(BudgetProvider budget) async {
    final now   = DateTime.now();
    final meses = List.generate(
      13,
      (i) => DateTime(now.year, now.month - 12 + i),
    ).reversed.toList();

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
              final mes      = meses[index];
              final label    = _mesFmt.format(mes);
              final isSelected = mes.month == budget.periodoSelecionado.month &&
                  mes.year == budget.periodoSelecionado.year;
              return ListTile(
                selected: isSelected,
                selectedColor: widget.colorScheme.primary,
                selectedTileColor: widget.colorScheme.primary
                    .withValues(alpha: 0.08),
                leading: isSelected
                    ? Icon(Icons.radio_button_checked,
                        color: widget.colorScheme.primary)
                    : const Icon(Icons.radio_button_unchecked),
                title: Text(label[0].toUpperCase() + label.substring(1),
                    style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal)),
                onTap: () {
                  budget.setPeriodo(mes);
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
              child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _openForm(BuildContext context,
      {BudgetModel? budget, String? categoriaPreset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<BudgetProvider>(),
        child: _BudgetFormSheet(
          budget:          budget,
          categoriaPreset: categoriaPreset,
          periodo:
              context.read<BudgetProvider>().periodoSelecionado,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetProvider>();
    final cs     = widget.colorScheme;
    final tt     = widget.textTheme;
    final budgets = budget.budgetsComGasto;
    final semOrc  = budget.categoriasSemOrcamento;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(budget),
          const SizedBox(height: 10),

          // Botões de ação
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo orçamento'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: budget.isSubmitting
                    ? null
                    : () async {
                        final ok =
                            await budget.copiarMesAnterior();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Orçamentos copiados do mês anterior.'
                                  : 'Sem orçamentos no mês anterior.'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar mês anterior'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: budget.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : budgets.isEmpty && semOrc.isEmpty
                    ? _emptyState(context)
                    : ListView(
                        children: [
                          if (budgets.isNotEmpty) ...[
                            _buildResumoCard(budget),
                            const SizedBox(height: 10),
                            Text(
                              'Categorias com orçamento (${budgets.length})',
                              style: tt.labelLarge?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...budgets.map(_buildBudgetCard),
                          ],
                          if (semOrc.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Categorias sem orçamento (${semOrc.length})',
                              style: tt.labelLarge?.copyWith(
                                  color: cs.onPrimary.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...semOrc.map(_buildCategoriaSemOrcamento),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_outlined,
              size: 56, color: cs.onPrimary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('Nenhum orçamento definido.',
              style: tt.titleMedium?.copyWith(
                  color: cs.onPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Defina limites por categoria para\nacompanhar seus gastos mensais.',
            textAlign: TextAlign.center,
            style:
                tt.bodySmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onPrimary,
              side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.5)),
            ),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeiro orçamento'),
          ),
        ],
      ),
    );
  }
}

// ── _BudgetFormSheet ──────────────────────────────────────────────────────────

class _BudgetFormSheet extends StatefulWidget {
  const _BudgetFormSheet({
    this.budget,
    this.categoriaPreset,
    required this.periodo,
  });

  final BudgetModel? budget;
  final String?     categoriaPreset;
  final DateTime    periodo;

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late final TextEditingController _limiteCtrl;
  late String _categoria;

  bool get _isEditing => widget.budget != null;

  static const _categorias = [
    'Amazon', 'Alimentação', 'Cartão de Crédito', 'Depósito de Construção',
    'Farmácia', 'Lazer', 'Mercado Livre', 'Magalu', 'Moradia', 'Padaria',
    'Pix para esposa', 'Papelaria', 'Shopee', 'Super Mercado',
    'Serviço de Terceiros', 'Serviços de Internet', 'Serviços de Energia',
    'Serviços de Telefonia', 'Servicos de Transporte', 'Tiktok Shop',
    'Uber', 'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _limiteCtrl = TextEditingController(
      text: widget.budget != null
          ? widget.budget!.limite.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    _categoria = widget.budget?.categoria ??
        widget.categoriaPreset ??
        _categorias.first;
  }

  @override
  void dispose() {
    _limiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final limite = double.tryParse(
          _limiteCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0;

    if (limite <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor limite válido.')),
      );
      return;
    }

    final provider = context.read<BudgetProvider>();
    final budget = BudgetModel(
      id:        _isEditing ? widget.budget!.id : '',
      categoria: _categoria,
      limite:    limite,
      mes:       widget.periodo,
    );

    final ok = _isEditing
        ? await provider.updateBudget(budget)
        : await provider.addBudget(budget);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else if (provider.appError != null) {
      ErrorHandler.instance.showSnackBar(context, provider.appError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _isEditing ? 'Editar orçamento' : 'Novo orçamento',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Categoria
            Text('Categoria',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration:
                  const InputDecoration(labelText: 'Categoria de saída'),
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v ?? _categoria),
            ),
            const SizedBox(height: 14),

            // Limite
            Text('Limite mensal (R\$)',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _limiteCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor máximo para o mês',
                prefixText: 'R\$ ',
              ),
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 24),

            Consumer<BudgetProvider>(
              builder: (context, provider, _) => SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: provider.isSubmitting ? null : _submit,
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'Salvar alterações' : 'Criar orçamento'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
