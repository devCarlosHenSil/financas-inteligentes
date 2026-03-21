import 'dart:async';
import 'package:financas_inteligentes/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── AssetSearchField ──────────────────────────────────────────────────────────

class AssetSearchField extends StatefulWidget {
  const AssetSearchField({
    super.key,
    required this.controller,
    required this.tipoSelecionado,
    required this.api,
    required this.onSelect,
    required this.isUsd,
    required this.isFundos,
  });

  final TextEditingController controller;
  final String tipoSelecionado;
  final ApiService api;
  final ValueChanged<AssetOption> onSelect;
  final bool isUsd;
  final bool isFundos;

  @override
  State<AssetSearchField> createState() => _AssetSearchFieldState();
}

class _AssetSearchFieldState extends State<AssetSearchField> {
  List<AssetOption> _options = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant AssetSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tipoSelecionado != widget.tipoSelecionado) {
      _options = [];
      _queueSearch(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _queueSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final results = await widget.api.searchAssetsByType(
      tipo: widget.tipoSelecionado,
      query: value,
    );
    if (!mounted) return;
    setState(() {
      _options = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: 'Ativo',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _queueSearch,
        ),
        if (_options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _options.length,
              itemBuilder: (context, index) {
                final item = _options[index];
                return ListTile(
                  dense: true,
                  title: Text(item.label),
                  subtitle: Text(
                    '${item.currency == 'USD' ? 'US\$' : 'R\$'} '
                    '${item.price.toStringAsFixed(widget.isFundos || widget.tipoSelecionado == 'Criptomoedas' || widget.isUsd ? 8 : 2)}',
                  ),
                  onTap: () {
                    widget.controller.text = item.label;
                    widget.onSelect(item);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ── PtBrDecimalInputFormatter ─────────────────────────────────────────────────

class PtBrDecimalInputFormatter extends TextInputFormatter {
  PtBrDecimalInputFormatter(
      {required this.decimalDigits, this.suffix = ''});

  final int decimalDigits;
  final String suffix;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      final empty =
          decimalDigits == 0 ? '0' : '0,${'0' * decimalDigits}';
      return TextEditingValue(
        text: '$empty$suffix',
        selection: TextSelection.collapsed(offset: empty.length),
      );
    }
    final parsed = double.parse(digits) / _pow10(decimalDigits);
    final formatted = NumberFormat.decimalPatternDigits(
      locale: 'pt_BR',
      decimalDigits: decimalDigits,
    ).format(parsed);
    final text = '$formatted$suffix';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  double _pow10(int exp) {
    var value = 1.0;
    for (var i = 0; i < exp; i++) {
      value *= 10;
    }
    return value;
  }
}
