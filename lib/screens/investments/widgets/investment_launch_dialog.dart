import 'package:financas_inteligentes/models/investment_model.dart';
import 'package:financas_inteligentes/screens/investments/widgets/asset_search_field.dart';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Lista de tipos de carteira — exportada para o shell também usar
const kTiposCarteira = [
  'Ações',
  'Fundos de Investimentos',
  'FIIs',
  'Criptomoedas',
  'Stock',
  'Reit',
  'BDRs',
  'ETF',
  'ETFs Internacionais',
  'Tesouro Direto',
  'Renda Fixa (CDB,LCI,LCA,LC,LF,RDB)',
  'Outros',
];

bool isUsdType(String tipo) =>
    tipo == 'Stock' || tipo == 'Reit' || tipo == 'ETFs Internacionais';
bool isFundosInvestimentos(String tipo) => tipo == 'Fundos de Investimentos';
bool isRendaFixa(String tipo) =>
    tipo == 'Renda Fixa (CDB,LCI,LCA,LC,LF,RDB)';
bool isOutros(String tipo) => tipo == 'Outros';

Future<void> showLaunchDialog({
  required BuildContext context,
  required ApiService api,
  required FirestoreService service,
}) async {
  final ativoCtrl = TextEditingController();
  final quantidadeCtrl = TextEditingController(text: '1');
  final precoCtrl = TextEditingController(text: '0,00');
  final custosCtrl = TextEditingController(text: '0,00');
  final valorInvestidoCtrl = TextEditingController(text: '0,01');
  final precoCotaCtrl = TextEditingController(text: '0,00000000');
  final emissorCtrl = TextEditingController();
  final taxaCtrl = TextEditingController(text: '0,00');
  final valorRendaFixaCtrl = TextEditingController(text: '0,00');
  final nomeOutroCtrl = TextEditingController();
  final jurosAnualCtrl = TextEditingController(text: '0,00');

  String tipoSelecionado = kTiposCarteira.first;
  DateTime dataSelecionada = DateTime.now();
  DateTime dataVencimento = DateTime.now().add(const Duration(days: 1));
  bool isCompra = true;
  bool liquidezDiaria = false;
  String tipoTitulo = 'CDB';
  String indexador = 'CDI';
  String formaRendaFixa = 'Pós-fixado';

  double parsePt(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  String fmtCurrency(double v, {String symbol = 'R\$'}) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: symbol, decimalDigits: 2)
          .format(v);

  String fmtDecInput(double v, int dec) =>
      NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: dec)
          .format(v <= 0 ? 0 : v);

  String fmtDecValue(double v, int dec) =>
      NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: dec)
          .format(v);

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isFundos = isFundosInvestimentos(tipoSelecionado);
          final isUsd = isUsdType(tipoSelecionado);
          final isRF = isRendaFixa(tipoSelecionado);
          final isOt = isOutros(tipoSelecionado);
          final isCrypto = tipoSelecionado == 'Criptomoedas';
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          final qtd = parsePt(quantidadeCtrl.text);
          final preco = parsePt(precoCtrl.text);
          final custos = parsePt(custosCtrl.text);
          final valorInv = parsePt(valorInvestidoCtrl.text);
          final precoCota = parsePt(precoCotaCtrl.text);
          final valorRF = parsePt(valorRendaFixaCtrl.text);
          final juros = parsePt(jurosAnualCtrl.text);

          final total = isFundos
              ? valorInv + custos
              : isRF
                  ? valorRF + custos
                  : isOt
                      ? preco + custos + juros
                      : qtd * preco + custos;

          final totalCotas =
              precoCota > 0 ? valorInv / precoCota : 0.0;

          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Adicionar Lançamento',
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Compra / Venda ─────────────────────────────────────
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: true,
                          label: Text('Compra'),
                          icon: Icon(Icons.add_shopping_cart)),
                      ButtonSegment(
                          value: false,
                          label: Text('Venda'),
                          icon: Icon(Icons.sell_outlined)),
                    ],
                    selected: {isCompra},
                    onSelectionChanged: (v) =>
                        setDialogState(() => isCompra = v.first),
                  ),
                  const SizedBox(height: 16),

                  // ── Tipo de ativo ──────────────────────────────────────
                  DropdownButtonFormField<String>(
                    initialValue: tipoSelecionado,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de ativo'),
                    items: kTiposCarteira
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      tipoSelecionado = v ?? kTiposCarteira.first;
                      ativoCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 10),

                  // ── Campo de busca de ativo ────────────────────────────
                  if (!isRF && !isOt)
                    AssetSearchField(
                      controller: ativoCtrl,
                      tipoSelecionado: tipoSelecionado,
                      isUsd: isUsd,
                      isFundos: isFundos,
                      onSelect: (asset) {
                        if (isFundos) {
                          precoCotaCtrl.text = fmtDecInput(asset.price, 8);
                        } else {
                          final dec = isCrypto || isUsd ? 8 : 2;
                          precoCtrl.text = fmtDecInput(asset.price, dec);
                        }
                        setDialogState(() {});
                      },
                      api: api,
                    ),

                  if (isOt)
                    TextField(
                      controller: nomeOutroCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Nome do ativo'),
                    ),

                  // ── Campos Renda Fixa ──────────────────────────────────
                  if (isRF) ...[
                    TextField(
                      controller: emissorCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Emissor'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: tipoTitulo,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de título'),
                      items: const [
                        'CDB','LCI','LCA','LC','LF','RDB',
                        'Debênture','CRI','CRA','CCB'
                      ]
                          .map((i) =>
                              DropdownMenuItem(value: i, child: Text(i)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => tipoTitulo = v ?? 'CDB'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: indexador,
                      decoration:
                          const InputDecoration(labelText: 'Indexador'),
                      items: const ['CDI', 'CDI+', 'IPCA+']
                          .map((i) =>
                              DropdownMenuItem(value: i, child: Text(i)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => indexador = v ?? 'CDI'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: taxaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        PtBrDecimalInputFormatter(
                            decimalDigits: 2, suffix: ' %')
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Taxa do CDI'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: formaRendaFixa,
                      decoration: const InputDecoration(
                          labelText: 'Forma (Opcional)'),
                      items: const ['Pós-fixado', 'Pré-fixado']
                          .map((i) =>
                              DropdownMenuItem(value: i, child: Text(i)))
                          .toList(),
                      onChanged: (v) => setDialogState(
                          () => formaRendaFixa = v ?? 'Pós-fixado'),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // ── Data + Quantidade ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dataSelecionada,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setDialogState(
                                  () => dataSelecionada = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: isCompra
                                  ? 'Data da compra'
                                  : 'Data da venda',
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy')
                                .format(dataSelecionada)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isFundos && !isRF)
                        Expanded(
                          child: TextField(
                            controller: quantidadeCtrl,
                            keyboardType: isCrypto
                                ? const TextInputType.numberWithOptions(
                                    decimal: true)
                                : TextInputType.number,
                            inputFormatters: isCrypto
                                ? [
                                    PtBrDecimalInputFormatter(
                                        decimalDigits: 8)
                                  ]
                                : [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: isCrypto
                                  ? 'Quantidade (fração)'
                                  : 'Quantidade',
                            ),
                          ),
                        ),
                      if (isRF)
                        Expanded(
                          child: TextField(
                            controller: valorRendaFixaCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              PtBrDecimalInputFormatter(decimalDigits: 2)
                            ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'Valor em R\$ (Opcional)'),
                          ),
                        ),
                    ],
                  ),

                  // ── Fundos: Valor + Preço da cota ─────────────────────
                  if (isFundos) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: valorInvestidoCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              PtBrDecimalInputFormatter(decimalDigits: 2)
                            ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'Valor investido'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: precoCotaCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              PtBrDecimalInputFormatter(decimalDigits: 8)
                            ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                                labelText: 'Preço da cota em R\$'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!isRF) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        PtBrDecimalInputFormatter(
                            decimalDigits: isCrypto || isUsd ? 8 : 2)
                      ],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                          labelText: isUsd
                              ? 'Preço em US\$'
                              : 'Preço em R\$'),
                    ),
                  ],

                  const SizedBox(height: 10),
                  if (!isRF)
                    TextField(
                      controller: custosCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        PtBrDecimalInputFormatter(decimalDigits: 2)
                      ],
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Outros custos (Opcional)'),
                    ),

                  // ── Renda Fixa: liquidez + vencimento ─────────────────
                  if (isRF) ...[
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Liquidez diária'),
                      value: liquidezDiaria,
                      onChanged: (v) =>
                          setDialogState(() => liquidezDiaria = v),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dataVencimento,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 36500)),
                        );
                        if (picked != null) {
                          setDialogState(() => dataVencimento = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data de vencimento',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy')
                            .format(dataVencimento)),
                      ),
                    ),
                  ],

                  // ── Outros: juros anual ────────────────────────────────
                  if (isOt) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: jurosAnualCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        PtBrDecimalInputFormatter(decimalDigits: 2)
                      ],
                      onChanged: (_) => setDialogState(() {}),
                      decoration:
                          const InputDecoration(labelText: 'Juros anual'),
                    ),
                  ],

                  // ── Total cotas (Fundos) ───────────────────────────────
                  if (isFundos) ...[
                    const SizedBox(height: 12),
                    _TotalRow(
                      label: 'Total de cotas',
                      value: fmtDecValue(totalCotas, 8),
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],

                  // ── Total geral ───────────────────────────────────────
                  const SizedBox(height: 12),
                  _TotalRow(
                    label: 'Valor total',
                    value: fmtCurrency(total, symbol: isUsd ? 'US\$' : 'R\$'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 16),

                  // ── Ações ─────────────────────────────────────────────
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () async {
                          final ativo = isRF
                              ? '${emissorCtrl.text.trim()} • $tipoTitulo • $indexador'
                              : isOt
                                  ? nomeOutroCtrl.text.trim()
                                  : ativoCtrl.text.trim();
                          if (ativo.isEmpty || total <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Preencha ativo e valores válidos.')),
                            );
                            return;
                          }
                          final valorLancamento =
                              isCompra ? total : -total;
                          final operacao = isCompra ? 'Compra' : 'Venda';
                          await service.addInvestment(
                            InvestmentModel(
                              id: '',
                              nome:
                                  '$tipoSelecionado • $ativo • $operacao',
                              valorInvestido: valorLancamento,
                              data: dataSelecionada,
                            ),
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Lançamento'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  for (final c in [
    ativoCtrl, quantidadeCtrl, precoCtrl, custosCtrl,
    valorInvestidoCtrl, precoCotaCtrl, emissorCtrl, taxaCtrl,
    valorRendaFixaCtrl, nomeOutroCtrl, jurosAnualCtrl,
  ]) {
    c.dispose();
  }
}

// ── Widget auxiliar interno ───────────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label,
              style: textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value,
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
