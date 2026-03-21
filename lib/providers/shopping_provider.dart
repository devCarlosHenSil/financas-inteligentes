import 'package:flutter/material.dart';
import 'package:financas_inteligentes/models/shopping_item_model.dart';
import 'package:financas_inteligentes/services/firestore_service.dart';

/// Estado centralizado da lista de compras inteligente.
///
/// Gerencia:
///   - Carrinho em memória (item → quantidade)
///   - Histórico de preços do Firestore
///   - Cidade selecionada para exibição de promoções
///   - Departamento ativo
class ShoppingProvider extends ChangeNotifier {
  final FirestoreService _service;

  ShoppingProvider(this._service);

  // ── Estado ────────────────────────────────────────────────────────────────

  final Map<String, int> _carrinho = {};
  String _departamentoSelecionado = 'Mercearia';
  String _cidadeSelecionada = 'São Paulo';
  bool _localizando = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  Map<String, int> get carrinho => Map.unmodifiable(_carrinho);
  String get departamentoSelecionado => _departamentoSelecionado;
  String get cidadeSelecionada => _cidadeSelecionada;
  bool get localizando => _localizando;

  Stream<List<ShoppingItemModel>> get shoppingItemsStream =>
      _service.getShoppingItems();

  // ── Carrinho ──────────────────────────────────────────────────────────────

  void adicionarAoCarrinho(String item) {
    if (item.trim().isEmpty) return;
    _carrinho.update(item.trim(), (qtd) => qtd + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void alterarQuantidade(String item, int delta) {
    final atual = _carrinho[item] ?? 0;
    final novo = atual + delta;
    if (novo <= 0) {
      _carrinho.remove(item);
    } else {
      _carrinho[item] = novo;
    }
    notifyListeners();
  }

  void limparCarrinho() {
    _carrinho.clear();
    notifyListeners();
  }

  double calcularTotalCarrinho(
      List<ShoppingItemModel> historico,
      Map<String, List<Map<String, dynamic>>> promocoesPorCidade) {
    return _carrinho.entries.fold(0.0, (sum, e) {
      final preco = _precoAtualOuPromocao(e.key, historico, promocoesPorCidade);
      return sum + (preco * e.value);
    });
  }

  double _precoAtualOuPromocao(
      String item,
      List<ShoppingItemModel> historico,
      Map<String, List<Map<String, dynamic>>> promocoesPorCidade) {
    final promo = (promocoesPorCidade[_cidadeSelecionada] ?? [])
        .where((p) => (p['item'] as String).toLowerCase() == item.toLowerCase())
        .toList();

    if (promo.isNotEmpty) {
      promo.sort(
          (a, b) => (a['preco'] as double).compareTo(b['preco'] as double));
      return promo.first['preco'] as double;
    }

    final historicoItem = historico
        .where((h) => h.nome.toLowerCase() == item.toLowerCase())
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));

    return historicoItem.isNotEmpty ? historicoItem.first.preco : 0;
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  void setDepartamento(String value) {
    _departamentoSelecionado = value;
    notifyListeners();
  }

  void setCidade(String value) {
    _cidadeSelecionada = value;
    notifyListeners();
  }

  void setLocalizando(bool value) {
    _localizando = value;
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> salvarItem(ShoppingItemModel item) async {
    await _service.addShoppingItem(item);
    adicionarAoCarrinho(item.nome);
  }

  Future<void> removerItem(String id) async {
    await _service.removeShoppingItem(id);
  }
}
