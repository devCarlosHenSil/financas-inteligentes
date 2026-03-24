import 'package:financas_inteligentes/providers/auth_provider.dart';
import 'package:financas_inteligentes/providers/goal_provider.dart';
import 'package:financas_inteligentes/providers/transaction_provider.dart';
import 'package:financas_inteligentes/screens/goals_screen.dart';
import 'package:financas_inteligentes/screens/investments_screen.dart';
import 'package:financas_inteligentes/screens/notification_settings_screen.dart';
import 'package:financas_inteligentes/screens/shopping_list_screen.dart';
import 'package:financas_inteligentes/screens/transactions_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class _CategoryTotal {
  _CategoryTotal({required this.nome, required this.valor});
  final String nome;
  final double valor;
}

class _CategorySelection {
  _CategorySelection({required this.item, required this.percent});
  final _CategoryTotal item;
  final double percent;
}

class DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: 'R\$');
  final NumberFormat _compactCurrency = NumberFormat.compactCurrency(
    symbol: 'R\$',
    decimalDigits: 1,
    locale: 'pt_BR',
  );

  int _touchedIncomeIndex  = -1;
  int _touchedExpenseIndex = -1;

  // ── Helpers de cor ────────────────────────────────────────────────────────

  Color _incomeTone(int index) {
    const tones = [
      Color(0xFF00C48C), Color(0xFF2DD4BF), Color(0xFF22D3EE),
      Color(0xFF60A5FA), Color(0xFF818CF8),
    ];
    return tones[index % tones.length];
  }

  Color _categoryColor(String category, {required bool isIncome, int index = 0}) {
    if (isIncome) return _incomeTone(index);
    final name = category.toLowerCase().trim();
    if (name.contains('uber'))          return const Color(0xFF111111);
    if (name.contains('mercado livre')) return const Color(0xFFFDD835);
    if (name.contains('shopee'))        return const Color(0xFFFF6D00);
    if (name.contains('amazon'))        return const Color(0xFFFF9900);
    if (name.contains('magalu') || name.contains('magazine luiza')) {
      return const Color(0xFF0086FF);
    }
    if (name.contains('farmácia') || name.contains('farmacia')) {
      return const Color(0xFFE91E63);
    }
    if (name.contains('lazer'))    return const Color(0xFF7C3AED);
    if (name.contains('telefone')) return const Color(0xFF84CC16);
    if (name.contains('internet')) return const Color(0xFFEF4444);
    final hue = (name.codeUnits.fold<int>(0, (sum, c) => sum + c) % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.50, 0.92).toColor();
  }

  // ── Preparação de dados ───────────────────────────────────────────────────

  List<_CategoryTotal> _prepareChartData(Map<String, double> data) {
    return data.entries
        .map((e) => _CategoryTotal(nome: e.key, valor: e.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
  }

  List<PieChartSectionData> _getPieSections(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          color: colorScheme.onSurfaceVariant,
          title: '',
          radius: 72,
        ),
      ];
    }
    final total = items.fold<double>(0.0, (sum, item) => sum + item.valor);
    return List.generate(items.length, (index) {
      final item       = items[index];
      final percent    = total == 0 ? 0.0 : (item.valor / total) * 100.0;
      final isTouched    = index == touchedIndex;
      final isLargeSlice = percent >= 20;
      final radius = isTouched
          ? (isLargeSlice ? 82.0 : 88.0)
          : (isLargeSlice ? 70.0 : 78.0);
      return PieChartSectionData(
        value: item.valor,
        color: _categoryColor(item.nome, isIncome: isIncome, index: index),
        title: isTouched
            ? '${item.nome}\n${percent.toStringAsFixed(1)}%'
            : '${percent.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 10 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  _CategorySelection? _selectedCategory(
      List<_CategoryTotal> items, int touchedIndex) {
    if (items.isEmpty || touchedIndex < 0 || touchedIndex >= items.length) {
      return null;
    }
    final total        = items.fold<double>(0.0, (sum, item) => sum + item.valor);
    final selectedItem = items[touchedIndex];
    final percent      = total == 0 ? 0.0 : (selectedItem.valor / total) * 100.0;
    return _CategorySelection(item: selectedItem, percent: percent);
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildCategoryList(List<_CategoryTotal> items,
      {required bool isIncome}) {
    final textTheme   = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Text(
        'Sem categorias no período.',
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(items.length, (index) {
        final item  = items[index];
        final color = _categoryColor(item.nome, isIncome: isIncome, index: index);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              item.nome,
              style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface, fontSize: 12),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPieChart(
    List<_CategoryTotal> items, {
    required bool isIncome,
    required int touchedIndex,
  }) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 46,
        borderData: FlBorderData(show: false),
        sections: _getPieSections(items,
            isIncome: isIncome, touchedIndex: touchedIndex),
        pieTouchData: PieTouchData(
          enabled: items.isNotEmpty,
          touchCallback: (event, response) {
            if (items.isEmpty) return;
            final hasInteraction = event.isInterestedForInteractions;
            final idx = hasInteraction
                ? (response?.touchedSection?.touchedSectionIndex ?? -1)
                : -1;
            if (!mounted) return;
            if (isIncome) {
              if (_touchedIncomeIndex == idx) return;
              setState(() => _touchedIncomeIndex = idx);
            } else {
              if (_touchedExpenseIndex == idx) return;
              setState(() => _touchedExpenseIndex = idx);
            }
          },
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Map<String, double> data,
    required bool isIncome,
  }) {
    final colorScheme  = Theme.of(context).colorScheme;
    final textTheme    = Theme.of(context).textTheme;
    final items        = _prepareChartData(data);
    final touchedIndex = isIncome ? _touchedIncomeIndex : _touchedExpenseIndex;
    final selection    = _selectedCategory(items, touchedIndex);

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildPieChart(items,
                  isIncome: isIncome, touchedIndex: touchedIndex),
            ),
            const SizedBox(height: 8),
            Text(
              selection == null
                  ? 'Passe o mouse em uma fatia para ver a categoria.'
                  : '${selection.item.nome} • ${_currencyFormatter.format(selection.item.valor)} (${selection.percent.toStringAsFixed(1)}%)',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildCategoryList(items, isIncome: isIncome),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(double saldo) {
    final auth        = context.watch<AuthProvider>();
    final userLabel   = auth.displayLabel;
    final initial     = auth.displayInitial;
    final now         = DateFormat('MMMM yyyy').format(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initial,
              style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Painel Financeiro',
                  style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Olá, $userLabel • ${now[0].toUpperCase()}${now.substring(1)}',
                  style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // ── Botão de notificações ──────────────────────────────────────
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
            icon: Icon(
              Icons.notifications_outlined,
              color: colorScheme.onSurface,
            ),
            tooltip: 'Notificações',
          ),
          Text(
            _currencyFormatter.format(saldo),
            style: textTheme.titleLarge?.copyWith(
                color: colorScheme.primary, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureLedgerStrip(TransactionProvider tx) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entradas = tx.totalEntradas;
    final saidas = tx.totalSaidas;
    final total = (entradas + saidas).abs();
    final entradaRatio = total <= 0 ? 0.5 : (entradas / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fita do mês',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (entradaRatio * 1000).round().clamp(1, 999),
                    child: Container(color: colorScheme.primary),
                  ),
                  Expanded(
                    flex: ((1 - entradaRatio) * 1000).round().clamp(1, 999),
                    child:
                        Container(color: colorScheme.error.withValues(alpha: 0.74)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Entradas ${_compactCurrency.format(entradas)}',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
                ),
              ),
              Expanded(
                child: Text(
                  'Saídas ${_compactCurrency.format(saidas)}',
                  textAlign: TextAlign.end,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 48,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  /// Mini-widget de metas exibido no Dashboard: progresso médio + botão rápido.
  Widget _buildGoalsMiniWidget() {
    final goals = context.watch<GoalProvider>();
    final cs    = Theme.of(context).colorScheme;
    final tt    = Theme.of(context).textTheme;

    if (goals.activeGoals.isEmpty) return const SizedBox.shrink();

    final progress = goals.averageProgress;
    final active   = goals.activeGoals.length;
    final overdue  = goals.overdueCount;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: overdue > 0 ? Colors.orange : cs.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Metas financeiras',
                          style: tt.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (overdue > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$overdue em atraso',
                              style: tt.labelSmall?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 700),
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: cs.primary),
                  ),
                  Text(
                    '$active ativa${active != 1 ? 's' : ''}',
                    style:
                        tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsAndActions(double saldo) {
    final colorScheme   = Theme.of(context).colorScheme;
    final textTheme     = Theme.of(context).textTheme;
    final saldoPositivo = saldo >= 0;
    final analise       = context.read<TransactionProvider>().analiseGastos;

    final sugestao = saldoPositivo
        ? 'Saldo positivo de ${_currencyFormatter.format(saldo)}. Continue investindo.'
        : 'Saldo negativo de ${_currencyFormatter.format(saldo)}. Ajuste gastos.';

    return Column(
      children: [
        // ── Mini-widget de metas ─────────────────────────────────────────
        _buildGoalsMiniWidget(),
        if (context.watch<GoalProvider>().activeGoals.isNotEmpty)
          const SizedBox(height: 8),

        // ── Cards de insight ─────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < 760;
            final insightCard = Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    analise,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ),
            );
            final suggestionCard = Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    sugestao,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ),
            );

            if (isStacked) {
              return Column(
                children: [
                  Row(children: [insightCard]),
                  const SizedBox(height: 10),
                  Row(children: [suggestionCard]),
                ],
              );
            }

            return Row(
              children: [
                insightCard,
                const SizedBox(width: 10),
                suggestionCard,
              ],
            );
          },
        ),
        const SizedBox(height: 10),

        // ── Botões de navegação 2x2 ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionsScreen()),
                ),
                icon: Icons.receipt_long,
                label: 'Transações',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const InvestmentsScreen()),
                ),
                icon: Icons.trending_up,
                label: 'Investimentos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ShoppingListScreen()),
                ),
                icon: Icons.shopping_cart,
                label: 'Lista de Compras',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                icon: Icons.flag_outlined,
                label: 'Metas',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tx          = context.watch<TransactionProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tx.isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                ),
              const SizedBox(height: 8),
              _buildPremiumHeader(tx.saldo),
              const SizedBox(height: 10),
              _buildSignatureLedgerStrip(tx),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isStacked = constraints.maxWidth < 900;
                    if (isStacked) {
                      return Column(
                        children: [
                          Expanded(
                            child: _buildChartCard(
                              title: 'Entradas por Categoria',
                              data: tx.entradasPorCategoria,
                              isIncome: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: _buildChartCard(
                              title: 'Saídas por Categoria',
                              data: tx.saidasPorCategoria,
                              isIncome: false,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _buildChartCard(
                            title: 'Entradas por Categoria',
                            data: tx.entradasPorCategoria,
                            isIncome: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChartCard(
                            title: 'Saídas por Categoria',
                            data: tx.saidasPorCategoria,
                            isIncome: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildInsightsAndActions(tx.saldo),
            ],
          ),
        ),
      ),
    );
  }
}
