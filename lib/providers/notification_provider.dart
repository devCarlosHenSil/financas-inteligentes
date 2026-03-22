import 'package:flutter/foundation.dart';

import 'package:financas_inteligentes/models/goal_model.dart';
import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/services/notification_service.dart';

/// Provider responsável por:
/// - Carregar e salvar configurações de notificação
/// - Reagendar notificações sempre que proventos ou metas mudam
/// - Expor estado para a tela de configurações
class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _load();
  }

  NotificationSettings _settings = const NotificationSettings(
    enabled: true,
    dividendosEnabled: true,
    metasEnabled: true,
    resumoDiarioEnabled: false,
    horaResumo: 9,
    minutoResumo: 0,
    diasAntecedencia: 3,
  );

  bool _isLoading = false;
  bool _permissionGranted = false;

  NotificationSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get permissionGranted => _permissionGranted;

  // ---------------------------------------------------------------------------
  // Inicialização
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();

    await NotificationService.instance.init();
    _settings = await NotificationService.instance.loadSettings();

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Permissão
  // ---------------------------------------------------------------------------

  Future<bool> requestPermission() async {
    _permissionGranted =
        await NotificationService.instance.requestPermission();
    notifyListeners();
    return _permissionGranted;
  }

  // ---------------------------------------------------------------------------
  // Atualizar configurações
  // ---------------------------------------------------------------------------

  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await NotificationService.instance.saveSettings(_settings);
  }

  Future<void> toggleEnabled(bool value) async {
    await updateSettings(_settings.copyWith(enabled: value));
    if (!value) {
      await NotificationService.instance.cancelAll();
    }
  }

  Future<void> toggleDividendos(bool value) async {
    await updateSettings(_settings.copyWith(dividendosEnabled: value));
  }

  Future<void> toggleMetas(bool value) async {
    await updateSettings(_settings.copyWith(metasEnabled: value));
  }

  Future<void> toggleResumoDiario(bool value) async {
    await updateSettings(_settings.copyWith(resumoDiarioEnabled: value));
  }

  Future<void> setHoraResumo(int hora, int minuto) async {
    await updateSettings(
      _settings.copyWith(horaResumo: hora, minutoResumo: minuto),
    );
  }

  Future<void> setDiasAntecedencia(int dias) async {
    await updateSettings(_settings.copyWith(diasAntecedencia: dias));
  }

  // ---------------------------------------------------------------------------
  // Reagendamento
  // ---------------------------------------------------------------------------

  /// Chamado pelos providers de proventos e metas quando os dados mudam.
  Future<void> reschedule({
    required List<ProventoModel> proventos,
    required List<GoalModel> goals,
  }) async {
    if (kIsWeb) return;
    await NotificationService.instance.scheduleAll(
      proventos: proventos,
      goals: goals,
    );
  }

  /// Testa imediatamente um alerta de dividendo (para debug/demonstração).
  Future<void> testDividendoNotification() async {
    await NotificationService.instance.scheduleAll(
      proventos: [
        ProventoModel(
          id: 'test',
          ativo: 'PETR4',
          tipoAtivo: 'Ações',
          status: 'A Receber',
          tipoPagamento: 'Dividendo',
          dataCom: DateTime.now(),
          dataPagamento: DateTime.now(),
          quantidade: 100,
          valorDiv: 1.50,
          valorTotal: 150.00,
        ),
      ],
      goals: [],
    );
  }

  /// Testa imediatamente um alerta de meta (para debug/demonstração).
  Future<void> testMetaNotification() async {
    await NotificationService.instance.scheduleAll(
      proventos: [],
      goals: [
        GoalModel(
          id: 'test',
          title: 'Meta de Teste',
          type: GoalType.savings,
          targetValue: 1000,
          currentValue: 850,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          deadline: DateTime.now().add(const Duration(days: 3)),
          color: 0xFF1D4ED8,
          icon: 0xe570,
          status: GoalStatus.active,
        ),
      ],
    );
  }
}
