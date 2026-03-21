import 'package:financas_inteligentes/errors/error_handler.dart';
import 'package:financas_inteligentes/models/goal_model.dart';
import 'package:financas_inteligentes/providers/goal_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// ── GoalsScreen ────────────────────────────────────────────────────────────────

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  static const _tabs = ['Ativas', 'Concluídas', 'Arquivadas'];
  static const _statuses = [
    GoalStatus.active,
    GoalStatus.completed,
    GoalStatus.archived,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme   = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Metas Financeiras',
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const _GoalsSummaryLine(),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onPrimary,
                          foregroundColor: colorScheme.primary,
                        ),
                        onPressed: () => _openForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova meta'),
                      ),
                    ],
                  ),
                ),

                // ── Resumo cards ──────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _SummaryCards(),
                ),

                const SizedBox(height: 16),

                // ── TabBar ────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    onTap: (i) => context
                        .read<GoalProvider>()
                        .setFilter(_statuses[i]),
                    indicator: BoxDecoration(
                      color: colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor:
                        colorScheme.onPrimary.withValues(alpha: 0.75),
                    labelStyle: textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    tabs: _tabs
                        .map((t) => Tab(text: t, height: 40))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Lista de metas ────────────────────────────────────────
                Expanded(
                  child: Consumer<GoalProvider>(
                    builder: (context, provider, _) {
                      if (provider.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      // Exibe erro se houver
                      if (provider.appError != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            ErrorHandler.instance.showSnackBar(
                              context, provider.appError!,
                              onRetry: provider.reload,
                            );
                          }
                        });
                      }

                      final goals = provider.filteredGoals;

                      if (goals.isEmpty) {
                        return _EmptyState(
                          status: provider.filterStatus,
                          onAdd: () => _openForm(context),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: goals.length,
                        itemBuilder: (context, index) => _GoalCard(
                          goal: goals[index],
                          onTap: () => _openForm(context, goal: goals[index]),
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
    );
  }

  void _openForm(BuildContext context, {GoalModel? goal}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<GoalProvider>(),
        child: GoalFormSheet(goal: goal),
      ),
    );
  }
}

// ── _GoalsSummaryLine ──────────────────────────────────────────────────────────

class _GoalsSummaryLine extends StatelessWidget {
  const _GoalsSummaryLine();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GoalProvider>();
    final active   = p.activeGoals.length;
    final overdue  = p.overdueCount;
    final cs       = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          '$active ativa${active != 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.85),
              ),
        ),
        if (overdue > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$overdue em atraso',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

// ── _SummaryCards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context) {
    final p          = context.watch<GoalProvider>();
    final cs         = Theme.of(context).colorScheme;
    final fmt        = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Row(
      children: [
        _card(
          context,
          icon:  Icons.savings_outlined,
          label: 'Total acumulado',
          value: fmt.format(p.totalCurrent),
          sub:   'de ${fmt.format(p.totalTarget)}',
          color: cs.onPrimary,
        ),
        const SizedBox(width: 10),
        _card(
          context,
          icon:  Icons.trending_up,
          label: 'Progresso médio',
          value: '${(p.averageProgress * 100).toStringAsFixed(0)}%',
          sub:   '${p.completedCount} concluída${p.completedCount != 1 ? 's' : ''}',
          color: cs.onPrimary,
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tt.labelSmall
                          ?.copyWith(color: color.withValues(alpha: 0.8))),
                  Text(value,
                      style: tt.titleSmall?.copyWith(
                          color: color, fontWeight: FontWeight.w800)),
                  Text(sub,
                      style: tt.labelSmall
                          ?.copyWith(color: color.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GoalCard ─────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final GoalModel goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header do card ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: goal.goalColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(goal.goalIcon,
                        color: goal.goalColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.title,
                            style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            _TypeChip(type: goal.type),
                            if (goal.isOverdue) ...[
                              const SizedBox(width: 6),
                              _OverdueChip(days: goal.daysRemaining!.abs()),
                            ] else if (goal.daysRemaining != null) ...[
                              const SizedBox(width: 6),
                              _DeadlineChip(days: goal.daysRemaining!),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Ações rápidas
                  _CardMenu(goal: goal),
                ],
              ),

              const SizedBox(height: 14),

              // ── Progresso ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt.format(goal.currentValue),
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${goal.progressPercent.toStringAsFixed(0)}%',
                    style: tt.labelLarge?.copyWith(
                        color: goal.goalColor,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'de ${fmt.format(goal.targetValue)}',
                style:
                    tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),

              // ── Barra de progresso animada ───────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: goal.progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(goal.goalColor),
                  ),
                ),
              ),

              // ── Falta / concluída ────────────────────────────────────
              const SizedBox(height: 6),
              if (goal.isCompleted)
                Row(children: [
                  Icon(Icons.check_circle,
                      color: Colors.green.shade600, size: 14),
                  const SizedBox(width: 4),
                  Text('Meta concluída! 🎉',
                      style: tt.labelSmall?.copyWith(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w700)),
                ])
              else
                Text(
                  'Faltam ${fmt.format(goal.remaining)}',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _CardMenu ─────────────────────────────────────────────────────────────────

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.goal});
  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GoalProvider>();
    final fmt      = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        if (goal.isActive) ...[
          const PopupMenuItem(value: 'progress', child: Text('Registrar progresso')),
          const PopupMenuItem(value: 'archive',  child: Text('Arquivar')),
        ],
        const PopupMenuItem(
          value: 'delete',
          child: Text('Excluir', style: TextStyle(color: Colors.red)),
        ),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'progress':
            _showProgressDialog(context, provider, fmt);
            break;
          case 'archive':
            await provider.archiveGoal(goal.id);
            break;
          case 'delete':
            final confirm = await showAdaptiveDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                title: const Text('Excluir meta'),
                content: Text('Deseja excluir "${goal.title}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Excluir',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) await provider.deleteGoal(goal.id);
            break;
        }
      },
    );
  }

  void _showProgressDialog(
    BuildContext context,
    GoalProvider provider,
    NumberFormat fmt,
  ) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar progresso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meta: ${goal.title}'),
            const SizedBox(height: 4),
            Text(
              'Acumulado: ${fmt.format(goal.currentValue)} de ${fmt.format(goal.targetValue)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor a adicionar (R\$)',
                prefixText: 'R\$ ',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (val == null || val <= 0) return;
              Navigator.pop(ctx);
              final ok = await provider.addProgress(goal.id, val);
              if (!ok && context.mounted && provider.appError != null) {
                ErrorHandler.instance.showSnackBar(context, provider.appError!);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ── Chips auxiliares ───────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final GoalType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label(type),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  String _label(GoalType t) {
    switch (t) {
      case GoalType.savings:    return 'Economia';
      case GoalType.debt:       return 'Dívida';
      case GoalType.investment: return 'Investimento';
      case GoalType.spending:   return 'Gastos';
    }
  }
}

class _OverdueChip extends StatelessWidget {
  const _OverdueChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Atrasada $days d',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 7;
    final color  = urgent ? Colors.orange.shade700 : Colors.blueGrey.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        days == 0 ? 'Prazo hoje' : '$days d restantes',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── _EmptyState ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status, required this.onAdd});
  final GoalStatus status;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (icon, title, sub) = switch (status) {
      GoalStatus.active   => (Icons.flag_outlined,     'Nenhuma meta ativa',    'Crie sua primeira meta financeira!'),
      GoalStatus.completed=> (Icons.check_circle_outline, 'Nenhuma meta concluída', 'Continue evoluindo!'),
      GoalStatus.archived => (Icons.archive_outlined,  'Nenhuma meta arquivada', ''),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onPrimary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title,
                style: tt.titleMedium?.copyWith(
                    color: cs.onPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(sub,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.75)),
                  textAlign: TextAlign.center),
            ],
            if (status == GoalStatus.active) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.onPrimary,
                  side: BorderSide(color: cs.onPrimary.withValues(alpha: 0.5)),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Nova meta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── GoalFormSheet ─────────────────────────────────────────────────────────────

/// BottomSheet para criar ou editar uma meta.
class GoalFormSheet extends StatefulWidget {
  const GoalFormSheet({super.key, this.goal});
  final GoalModel? goal;

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {

  late final TextEditingController _titleCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _currentCtrl;
  late final TextEditingController _descCtrl;

  GoalType   _type    = GoalType.savings;
  DateTime?  _deadline;
  Color      _color   = const Color(0xFF1D4ED8);
  IconData   _icon    = Icons.savings_outlined;

  bool get _isEditing => widget.goal != null;

  static const _typeOptions = [
    (GoalType.savings,    'Economia',     Icons.savings_outlined),
    (GoalType.investment, 'Investimento', Icons.trending_up),
    (GoalType.debt,       'Dívida',       Icons.credit_card_off_outlined),
    (GoalType.spending,   'Gastos',       Icons.remove_shopping_cart_outlined),
  ];

  static const _colorOptions = [
    Color(0xFF1D4ED8), Color(0xFF059669), Color(0xFFDC2626),
    Color(0xFFD97706), Color(0xFF7C3AED), Color(0xFF0891B2),
    Color(0xFFDB2777), Color(0xFF65A30D),
  ];

  static const _iconOptions = [
    Icons.savings_outlined,   Icons.home_outlined,
    Icons.directions_car_outlined, Icons.flight_outlined,
    Icons.school_outlined,    Icons.favorite_outline,
    Icons.trending_up,        Icons.credit_card_off_outlined,
    Icons.beach_access_outlined, Icons.laptop_mac_outlined,
  ];

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _titleCtrl   = TextEditingController(text: g?.title ?? '');
    _targetCtrl  = TextEditingController(
        text: g != null ? g.targetValue.toStringAsFixed(2) : '');
    _currentCtrl = TextEditingController(
        text: g != null ? g.currentValue.toStringAsFixed(2) : '0,00');
    _descCtrl    = TextEditingController(text: g?.description ?? '');
    if (g != null) {
      _type     = g.type;
      _deadline = g.deadline;
      _color    = g.goalColor;
      _icon     = g.goalIcon;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
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
            // Handle
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
                  _isEditing ? 'Editar meta' : 'Nova meta',
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

            // ── Tipo ─────────────────────────────────────────────────
            Text('Tipo de meta', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeOptions.map((opt) {
                final (type, label, icon) = opt;
                final selected = _type == type;
                return FilterChip(
                  selected: selected,
                  label: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 16,
                        color: selected ? cs.onPrimary : cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(label),
                  ]),
                  onSelected: (_) => setState(() {
                    _type = type;
                    _icon = icon;
                  }),
                  selectedColor: cs.primary,
                  labelStyle: TextStyle(
                      color: selected ? cs.onPrimary : cs.onSurface),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Título ───────────────────────────────────────────────
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da meta *',
                hintText: 'Ex.: Reserva de emergência',
              ),
            ),
            const SizedBox(height: 12),

            // ── Valores ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor alvo (R\$) *',
                      prefixText: 'R\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _currentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Já acumulado (R\$)',
                      prefixText: 'R\$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Prazo ────────────────────────────────────────────────
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Prazo (opcional)',
                  suffixIcon: _deadline != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _deadline = null),
                        )
                      : const Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _deadline != null
                      ? DateFormat('dd/MM/yyyy').format(_deadline!)
                      : 'Sem prazo definido',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _deadline != null
                            ? null
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Descrição ────────────────────────────────────────────
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Motivo ou detalhe da meta',
              ),
            ),
            const SizedBox(height: 16),

            // ── Cor ──────────────────────────────────────────────────
            Text('Cor', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colorOptions.map((c) {
                final selected = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: cs.onSurface, width: 3)
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Ícone ────────────────────────────────────────────────
            Text('Ícone', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _iconOptions.map((ic) {
                final selected = _icon.codePoint == ic.codePoint;
                return GestureDetector(
                  onTap: () => setState(() => _icon = ic),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? _color.withValues(alpha: 0.15)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: _color, width: 2)
                          : null,
                    ),
                    child: Icon(ic,
                        color: selected ? _color : cs.onSurfaceVariant,
                        size: 22),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Botão salvar ─────────────────────────────────────────
            Consumer<GoalProvider>(
              builder: (context, provider, _) => SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: provider.isSubmitting ? null : _submit,
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'Salvar alterações' : 'Criar meta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title  = _titleCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final current= double.tryParse(_currentCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (title.isEmpty) {
      ErrorHandler.instance.showSnackBar(
        context,
        ErrorHandler.instance.validation('Informe o nome da meta.'),
      );
      return;
    }
    if (target <= 0) {
      ErrorHandler.instance.showSnackBar(
        context,
        ErrorHandler.instance.validation('Informe um valor alvo válido.'),
      );
      return;
    }

    final provider = context.read<GoalProvider>();
    final goal = GoalModel(
      id:           _isEditing ? widget.goal!.id : '',
      title:        title,
      type:         _type,
      targetValue:  target,
      currentValue: current.clamp(0, target),
      createdAt:    _isEditing ? widget.goal!.createdAt : DateTime.now(),
      deadline:     _deadline,
      description:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      color:        _color.toARGB32(),
      icon:         _icon.codePoint,
      status:       GoalStatus.active,
    );

    final ok = _isEditing
        ? await provider.updateGoal(goal)
        : await provider.addGoal(goal);

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else if (provider.appError != null) {
      ErrorHandler.instance.showSnackBar(context, provider.appError!);
    }
  }
}
