import 'package:financas_inteligentes/providers/investment_provider.dart';
import 'package:financas_inteligentes/services/market_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Badge discreto que exibe o estado do cache de mercado.
///
/// - Oculto durante fetch de rede (spinner no botão já informa)
/// - Verde  = cache válido
/// - Laranja = menos de 2 min para expirar
/// - Vermelho = expirado / sem cache
class CacheStatusBadge extends StatelessWidget {
  const CacheStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();
    if (inv.fetchingFromNetwork) return const SizedBox.shrink();

    final info = inv.quotesInfo;
    if (info.savedAt == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: _tooltip(info),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _color(context, info).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color(context, info).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(info), size: 12, color: _color(context, info)),
              const SizedBox(width: 4),
              Text(
                info.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _color(context, info),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _color(BuildContext context, CacheInfo info) {
    final cs = Theme.of(context).colorScheme;
    if (!info.isValid) return cs.error;
    final rem = info.remaining;
    if (rem != null && rem.inMinutes < 2) return Colors.orange;
    return cs.tertiary;
  }

  IconData _icon(CacheInfo info) {
    if (!info.isValid) return Icons.cloud_off_outlined;
    final rem = info.remaining;
    if (rem != null && rem.inMinutes < 2) return Icons.sync_problem_outlined;
    return Icons.check_circle_outline;
  }

  String _tooltip(CacheInfo info) {
    if (!info.isValid || info.savedAt == null) {
      return 'Cache expirado — dados podem estar desatualizados';
    }
    final mins = info.remaining?.inMinutes ?? 0;
    return '${info.label}\nExpira em $mins min\n'
        'Cotações TTL: ${MarketCacheService.quoteTtl.inMinutes} min  '
        'Tickers TTL: ${MarketCacheService.tickerTtl.inMinutes} min';
  }
}

/// Botão de refresh com spinner integrado durante fetch de rede.
class MarketRefreshButton extends StatelessWidget {
  const MarketRefreshButton({super.key});

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InvestmentProvider>();

    if (inv.fetchingFromNetwork) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: 'Atualizar cotações',
      onPressed: () => context.read<InvestmentProvider>().refreshMarketData(),
      icon: const Icon(Icons.refresh),
    );
  }
}
