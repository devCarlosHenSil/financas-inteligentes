import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:financas_inteligentes/models/provento_model.dart';
import 'package:financas_inteligentes/models/goal_model.dart';

// ---------------------------------------------------------------------------
// IDs de canal (Android)
// ---------------------------------------------------------------------------
const _kChannelDividendos = 'dividendos';
const _kChannelMetas = 'metas';

// ---------------------------------------------------------------------------
// IDs de notificação (ranges)
//   1000–1999 → dividendos
//   2000–2999 → metas
//   9000      → resumo diário
// ---------------------------------------------------------------------------
const _kIdResumoDiario = 9000;

// ---------------------------------------------------------------------------
// Chaves de SharedPreferences
// ---------------------------------------------------------------------------
const _kPrefEnabled = 'notif_enabled';
const _kPrefDividendos = 'notif_dividendos';
const _kPrefMetas = 'notif_metas';
const _kPrefResumoDiario = 'notif_resumo_diario';
const _kPrefHoraResumo = 'notif_hora_resumo';
const _kPrefMinutoResumo = 'notif_minuto_resumo';
const _kPrefDiasAntecedencia = 'notif_dias_antecedencia';

/// Serviço centralizado de notificações locais.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Inicialização
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    _setLocalTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _setLocalTimezone() {
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {
      // Ignora se não encontrar — usa UTC
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] tap payload: ${response.payload}');
  }

  // ---------------------------------------------------------------------------
  // Permissões
  // ---------------------------------------------------------------------------

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final darwin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await darwin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Configurações (SharedPreferences)
  // ---------------------------------------------------------------------------

  Future<NotificationSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      enabled: prefs.getBool(_kPrefEnabled) ?? true,
      dividendosEnabled: prefs.getBool(_kPrefDividendos) ?? true,
      metasEnabled: prefs.getBool(_kPrefMetas) ?? true,
      resumoDiarioEnabled: prefs.getBool(_kPrefResumoDiario) ?? false,
      horaResumo: prefs.getInt(_kPrefHoraResumo) ?? 9,
      minutoResumo: prefs.getInt(_kPrefMinutoResumo) ?? 0,
      diasAntecedencia: prefs.getInt(_kPrefDiasAntecedencia) ?? 3,
    );
  }

  Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefEnabled, settings.enabled);
    await prefs.setBool(_kPrefDividendos, settings.dividendosEnabled);
    await prefs.setBool(_kPrefMetas, settings.metasEnabled);
    await prefs.setBool(_kPrefResumoDiario, settings.resumoDiarioEnabled);
    await prefs.setInt(_kPrefHoraResumo, settings.horaResumo);
    await prefs.setInt(_kPrefMinutoResumo, settings.minutoResumo);
    await prefs.setInt(_kPrefDiasAntecedencia, settings.diasAntecedencia);
  }

  // ---------------------------------------------------------------------------
  // Agendamento principal
  // ---------------------------------------------------------------------------

  Future<void> scheduleAll({
    required List<ProventoModel> proventos,
    required List<GoalModel> goals,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final settings = await loadSettings();
    if (!settings.enabled) {
      await cancelAll();
      return;
    }

    await cancelAll();

    if (settings.dividendosEnabled) {
      await _scheduleDividendos(proventos, settings);
    }

    if (settings.metasEnabled) {
      await _scheduleMetas(goals, settings);
    }

    if (settings.resumoDiarioEnabled) {
      await _scheduleResumoDiario(proventos, goals, settings);
    }
  }

  // ---------------------------------------------------------------------------
  // Notificações de dividendos
  // ---------------------------------------------------------------------------

  Future<void> _scheduleDividendos(
    List<ProventoModel> proventos,
    NotificationSettings settings,
  ) async {
    final now = DateTime.now();
    final limite = now.add(Duration(days: settings.diasAntecedencia));

    final proximos = proventos.where((p) {
      if (p.status.toLowerCase().contains('pago')) return false;
      final data = p.dataPagamento;
      return data.isAfter(now.subtract(const Duration(days: 1))) &&
          data.isBefore(limite);
    }).toList()
      ..sort((a, b) => a.dataPagamento.compareTo(b.dataPagamento));

    for (var i = 0; i < proximos.length && i < 20; i++) {
      final p = proximos[i];
      final id = 1000 + i;

      final diasRestantes = p.dataPagamento.difference(now).inDays;

      final titulo = diasRestantes == 0
          ? '💰 Dividendo hoje: ${p.ativo}'
          : '💰 Dividendo em $diasRestantes dia${diasRestantes == 1 ? '' : 's'}: ${p.ativo}';

      final corpo = 'Pagamento de R\$ ${p.valorTotal.toStringAsFixed(2)} '
          '(${p.tipoPagamento}) em ${_formatDate(p.dataPagamento)}';

      final scheduleDate = tz.TZDateTime(
        tz.local,
        p.dataPagamento.year,
        p.dataPagamento.month,
        p.dataPagamento.day,
        8,
        0,
      );

      final notifyAt = scheduleDate.isBefore(tz.TZDateTime.now(tz.local))
          ? tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5))
          : scheduleDate;

      await _plugin.zonedSchedule(
        id,
        titulo,
        corpo,
        notifyAt,
        _notifDetails(
          channelId: _kChannelDividendos,
          channelName: 'Dividendos e Proventos',
          channelDesc: 'Alertas de pagamento de dividendos e proventos',
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ✅ CORREÇÃO P1-B: removido backslash — agora interpola p.id corretamente
        payload: 'dividendo:${p.id}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notificações de metas
  // ---------------------------------------------------------------------------

  Future<void> _scheduleMetas(
    List<GoalModel> goals,
    NotificationSettings settings,
  ) async {
    final now = DateTime.now();
    final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();

    var metaId = 2000;

    for (final goal in activeGoals) {
      // Meta concluída
      if (goal.isCompleted) {
        await _showImmediate(
          id: metaId++,
          title: '🎯 Meta concluída: ${goal.title}',
          body: 'Parabéns! Você atingiu sua meta de '
              'R\$ ${goal.targetValue.toStringAsFixed(2)}.',
          channelId: _kChannelMetas,
          channelName: 'Metas Financeiras',
          channelDesc: 'Alertas de progresso e prazo de metas',
          payload: 'meta:${goal.id}',
        );
        continue;
      }

      // Meta vencida
      if (goal.isOverdue) {
        await _showImmediate(
          id: metaId++,
          title: '⚠️ Meta vencida: ${goal.title}',
          body: 'O prazo da sua meta expirou. '
              'Progresso atual: ${(goal.progress * 100).toStringAsFixed(0)}%.',
          channelId: _kChannelMetas,
          channelName: 'Metas Financeiras',
          channelDesc: 'Alertas de progresso e prazo de metas',
          payload: 'meta:${goal.id}',
        );
        continue;
      }

      // Prazo se aproximando (próximos 7 dias)
      if (goal.deadline != null) {
        final dias = goal.deadline!.difference(now).inDays;
        if (dias >= 0 && dias <= 7) {
          final scheduleDate = tz.TZDateTime(
            tz.local,
            goal.deadline!.year,
            goal.deadline!.month,
            goal.deadline!.day,
            9,
            0,
          );

          final notifyAt =
              scheduleDate.isBefore(tz.TZDateTime.now(tz.local))
                  ? tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10))
                  : scheduleDate;

          await _plugin.zonedSchedule(
            metaId++,
            '🎯 Prazo da meta: ${goal.title}',
            'Faltam $dias dia${dias == 1 ? '' : 's'} para o prazo. '
                'Progresso: ${(goal.progress * 100).toStringAsFixed(0)}%.',
            notifyAt,
            _notifDetails(
              channelId: _kChannelMetas,
              channelName: 'Metas Financeiras',
              channelDesc: 'Alertas de progresso e prazo de metas',
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            // ✅ CORREÇÃO P1-B: removido backslash — agora interpola goal.id corretamente
            payload: 'meta:${goal.id}',
          );
        }
      }

      // Progresso >= 80% mas não concluída
      if (goal.progress >= 0.8 && !goal.isCompleted) {
        await _showImmediate(
          id: metaId++,
          title: '🚀 Quase lá: ${goal.title}',
          body: 'Você já atingiu ${(goal.progress * 100).toStringAsFixed(0)}% '
              'da sua meta. Continue assim!',
          channelId: _kChannelMetas,
          channelName: 'Metas Financeiras',
          channelDesc: 'Alertas de progresso e prazo de metas',
          payload: 'meta:${goal.id}',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Resumo diário
  // ---------------------------------------------------------------------------

  Future<void> _scheduleResumoDiario(
    List<ProventoModel> proventos,
    List<GoalModel> goals,
    NotificationSettings settings,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduleDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.horaResumo,
      settings.minutoResumo,
    );

    if (scheduleDate.isBefore(now)) {
      scheduleDate = scheduleDate.add(const Duration(days: 1));
    }

    final proventosHoje = proventos.where((p) {
      final d = p.dataPagamento;
      return d.day == scheduleDate.day &&
          d.month == scheduleDate.month &&
          d.year == scheduleDate.year;
    }).length;

    final metasAtivas = goals
        .where((g) => g.status == GoalStatus.active && !g.isCompleted)
        .length;

    final partes = <String>[];
    if (proventosHoje > 0) {
      partes.add('$proventosHoje pagamento${proventosHoje == 1 ? '' : 's'} hoje');
    }
    if (metasAtivas > 0) {
      partes.add(
          '$metasAtivas meta${metasAtivas == 1 ? '' : 's'} ativa${metasAtivas == 1 ? '' : 's'}');
    }

    final corpo = partes.isEmpty
        ? 'Tudo em dia! Sem eventos financeiros para hoje.'
        : partes.join(' • ');

    await _plugin.zonedSchedule(
      _kIdResumoDiario,
      '📊 Resumo Financeiro do Dia',
      corpo,
      scheduleDate,
      _notifDetails(
        channelId: 'resumo',
        channelName: 'Resumo Diário',
        channelDesc: 'Resumo diário das suas finanças',
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'resumo',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _showImmediate({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      _notifDetails(
        channelId: channelId,
        channelName: channelName,
        channelDesc: channelDesc,
      ),
      payload: payload,
    );
  }

  NotificationDetails _notifDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  Future<void> cancelById(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Model de configurações
// ---------------------------------------------------------------------------

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.dividendosEnabled,
    required this.metasEnabled,
    required this.resumoDiarioEnabled,
    required this.horaResumo,
    required this.minutoResumo,
    required this.diasAntecedencia,
  });

  final bool enabled;
  final bool dividendosEnabled;
  final bool metasEnabled;
  final bool resumoDiarioEnabled;
  final int horaResumo;
  final int minutoResumo;
  final int diasAntecedencia;

  NotificationSettings copyWith({
    bool? enabled,
    bool? dividendosEnabled,
    bool? metasEnabled,
    bool? resumoDiarioEnabled,
    int? horaResumo,
    int? minutoResumo,
    int? diasAntecedencia,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      dividendosEnabled: dividendosEnabled ?? this.dividendosEnabled,
      metasEnabled: metasEnabled ?? this.metasEnabled,
      resumoDiarioEnabled: resumoDiarioEnabled ?? this.resumoDiarioEnabled,
      horaResumo: horaResumo ?? this.horaResumo,
      minutoResumo: minutoResumo ?? this.minutoResumo,
      diasAntecedencia: diasAntecedencia ?? this.diasAntecedencia,
    );
  }
}
