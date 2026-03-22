import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:financas_inteligentes/providers/notification_provider.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        centerTitle: false,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _NotificationSettingsBody(provider: provider);
        },
      ),
    );
  }
}

class _NotificationSettingsBody extends StatelessWidget {
  const _NotificationSettingsBody({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = provider.settings;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Banner de permissão ─────────────────────────────────────────────
        _PermissionBanner(provider: provider),
        const SizedBox(height: 8),

        // ── Notificações habilitadas ────────────────────────────────────────
        _SectionCard(
          children: [
            SwitchListTile.adaptive(
              title: const Text(
                'Notificações habilitadas',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Ativa ou desativa todos os alertas do app',
              ),
              secondary: Icon(
                Icons.notifications_outlined,
                color: colorScheme.primary,
              ),
              value: settings.enabled,
              onChanged: provider.toggleEnabled,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Dividendos ──────────────────────────────────────────────────────
        _SectionCard(
          header: 'Dividendos e Proventos',
          enabled: settings.enabled,
          children: [
            SwitchListTile.adaptive(
              title: const Text('Alertas de dividendos'),
              subtitle: const Text(
                'Notifica quando um pagamento está próximo',
              ),
              secondary: const Icon(Icons.payments_outlined),
              value: settings.enabled && settings.dividendosEnabled,
              onChanged: settings.enabled
                  ? provider.toggleDividendos
                  : null,
            ),
            if (settings.dividendosEnabled && settings.enabled) ...[
              const Divider(indent: 16, endIndent: 16),
              _DaysSliderTile(
                value: settings.diasAntecedencia,
                onChanged: provider.setDiasAntecedencia,
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // ── Metas ───────────────────────────────────────────────────────────
        _SectionCard(
          header: 'Metas Financeiras',
          enabled: settings.enabled,
          children: [
            SwitchListTile.adaptive(
              title: const Text('Alertas de metas'),
              subtitle: const Text(
                'Notifica prazo próximo, progresso 80% e conclusão',
              ),
              secondary: const Icon(Icons.flag_outlined),
              value: settings.enabled && settings.metasEnabled,
              onChanged: settings.enabled ? provider.toggleMetas : null,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Resumo diário ───────────────────────────────────────────────────
        _SectionCard(
          header: 'Resumo Diário',
          enabled: settings.enabled,
          children: [
            SwitchListTile.adaptive(
              title: const Text('Resumo diário'),
              subtitle: const Text(
                'Receba um resumo das suas finanças todo dia',
              ),
              secondary: const Icon(Icons.summarize_outlined),
              value: settings.enabled && settings.resumoDiarioEnabled,
              onChanged:
                  settings.enabled ? provider.toggleResumoDiario : null,
            ),
            if (settings.resumoDiarioEnabled && settings.enabled) ...[
              const Divider(indent: 16, endIndent: 16),
              _TimeTile(
                hora: settings.horaResumo,
                minuto: settings.minutoResumo,
                onChanged: provider.setHoraResumo,
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),

        // ── Botões de teste ──────────────────────────────────────────────────
        if (settings.enabled) ...[
          Text(
            'Testar notificações',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await provider.testDividendoNotification();
                    if (context.mounted) {
                      _showSnack(context, 'Notificação de dividendo enviada');
                    }
                  },
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Dividendo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await provider.testMetaNotification();
                    if (context.mounted) {
                      _showSnack(context, 'Notificação de meta enviada');
                    }
                  },
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Meta'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider.updateSettings(settings);
                if (context.mounted) {
                  _showSnack(context, 'Notificações reagendadas');
                }
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reagendar todas as notificações'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner de permissão
// ---------------------------------------------------------------------------

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<bool>(
      future: _checkPermission(),
      builder: (context, snapshot) {
        final granted = snapshot.data ?? true;
        if (granted) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: colorScheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Permissão de notificações não concedida.',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: () => provider.requestPermission(),
                child: const Text('Permitir'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkPermission() async {
    return provider.requestPermission();
  }
}

// ---------------------------------------------------------------------------
// Slider de dias de antecedência
// ---------------------------------------------------------------------------

class _DaysSliderTile extends StatelessWidget {
  const _DaysSliderTile({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 16),
              const SizedBox(width: 8),
              Text(
                'Antecipar alerta em $value dia${value == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          Slider.adaptive(
            value: value.toDouble(),
            min: 1,
            max: 14,
            divisions: 13,
            label: '$value dia${value == 1 ? '' : 's'}',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de horário do resumo diário
// ---------------------------------------------------------------------------

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.hora,
    required this.minuto,
    required this.onChanged,
  });

  final int hora;
  final int minuto;
  final Future<void> Function(int hora, int minuto) onChanged;

  String get _label =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.access_time_outlined),
      title: const Text('Horário do resumo'),
      trailing: Text(
        _label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hora, minute: minuto),
        );
        if (picked != null) {
          await onChanged(picked.hour, picked.minute);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card de seção
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.children,
    this.header,
    this.enabled = true,
  });

  final List<Widget> children;
  final String? header;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  header!,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}
