import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_record.dart';

/// Lembretes locais da agenda: um pouco antes do horário marcado, e outro
/// depois, para lembrar de lançar os dados da avaliação no aluno.
///
/// São notificações locais (agendadas no próprio aparelho), não push do
/// servidor — funcionam mesmo sem internet no momento do disparo, mas só
/// no aparelho onde foram agendadas.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _exactAlarmsAllowed = false;

  static const AndroidNotificationChannel _beforeChannel = AndroidNotificationChannel(
    'appointment_reminders',
    'Lembretes de avaliação',
    description: 'Aviso antes do horário de uma avaliação agendada',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _afterChannel = AndroidNotificationChannel(
    'appointment_followups',
    'Lançar avaliação',
    description: 'Lembrete para registrar os dados de uma avaliação após o horário marcado',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _testChannel = AndroidNotificationChannel(
    'test_notifications',
    'Teste de notificação',
    description: 'Canal usado só para testar se as notificações do sistema estão chegando',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _cancelChannel = AndroidNotificationChannel(
    'appointment_cancellations',
    'Cancelamentos',
    description: 'Aviso quando uma avaliação agendada é cancelada',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'general_notifications',
    'Avisos gerais',
    description: 'Outros avisos do app enviados também como notificação do sistema',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Cria os canais explicitamente, em vez de deixar o Android criá-los
    // sozinho na primeira notificação — assim garantimos que já nascem
    // com importância alta (canais já criados com importância baixa não
    // podem ser "promovidos" de novo por código, só manualmente nas
    // configurações do aparelho).
    await androidImpl?.createNotificationChannel(_beforeChannel);
    await androidImpl?.createNotificationChannel(_afterChannel);
    await androidImpl?.createNotificationChannel(_testChannel);
    await androidImpl?.createNotificationChannel(_cancelChannel);
    await androidImpl?.createNotificationChannel(_generalChannel);

    await androidImpl?.requestNotificationsPermission();
    _exactAlarmsAllowed = await androidImpl?.requestExactAlarmsPermission() ?? false;

    _ready = true;
  }

  int _beforeId(String appointmentId) => appointmentId.hashCode & 0x3FFFFFFF;
  int _afterId(String appointmentId) => (appointmentId.hashCode & 0x3FFFFFFF) + 1;

  /// Modo de agendamento: exato (mais preciso, ignora economia de bateria)
  /// se o Android permitiu o alarme exato; senão cai para o modo
  /// aproximado, que não exige essa permissão especial e ainda funciona,
  /// só com uma margem de alguns minutos de atraso possível.
  AndroidScheduleMode get _scheduleMode =>
      _exactAlarmsAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Agenda os dois lembretes de uma avaliação marcada na agenda:
  /// - [minutesBefore] minutos antes do horário (padrão 15).
  /// - [minutesAfter] minutos depois do horário, lembrando de lançar os
  ///   dados da avaliação no cadastro do aluno (padrão 45).
  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String studentName,
    required DateTime dateTime,
    int minutesBefore = 15,
    int minutesAfter = 45,
  }) async {
    if (!_ready) await init();
    final now = DateTime.now();

    final beforeTime = dateTime.subtract(Duration(minutes: minutesBefore));
    if (beforeTime.isAfter(now)) {
      await _safeSchedule(
        id: _beforeId(appointmentId),
        title: 'Avaliação em $minutesBefore minutos',
        body: 'Avaliação de $studentName marcada para daqui a pouco.',
        dateTime: beforeTime,
        channel: _beforeChannel,
      );
    }

    final afterTime = dateTime.add(Duration(minutes: minutesAfter));
    if (afterTime.isAfter(now)) {
      await _safeSchedule(
        id: _afterId(appointmentId),
        title: 'Lançar avaliação de $studentName',
        body: 'Não esqueça de registrar os dados da avaliação no perfil do aluno.',
        dateTime: afterTime,
        channel: _afterChannel,
      );
    }
  }

  Future<void> _safeSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    required AndroidNotificationChannel channel,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: _scheduleMode,
      );
    } catch (error) {
      // Nunca deixamos isso quebrar o fluxo de agendar/cancelar uma
      // consulta — mas registramos no console pra dar pra investigar.
      debugPrint('Falha ao agendar notificação local "$title": $error');
    }
  }

  AndroidNotificationChannel _channelForType(String type) {
    switch (type) {
      case 'appointment_reminder':
        return _beforeChannel;
      case 'appointment_followup':
        return _afterChannel;
      case 'appointment_cancelled':
        return _cancelChannel;
      default:
        return _generalChannel;
    }
  }

  /// Dispara IMEDIATAMENTE, como notificação do sistema, uma notificação
  /// que acabou de chegar na central interna do app (agendamento marcado,
  /// cancelado, etc.) — usado enquanto o app está aberto (ou recém em
  /// segundo plano) e a assinatura em tempo real detecta a novidade.
  Future<void> pushNow({
    required String id,
    required String title,
    required String body,
    required String type,
  }) async {
    if (!_ready) await init();
    final channel = _channelForType(type);
    await _plugin.show(
      id.hashCode & 0x3FFFFFFF,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Dispara uma notificação IMEDIATA (sem agendamento), usada só para
  /// testar se as notificações do sistema estão chegando de verdade no
  /// aparelho, isolado de qualquer lógica de horário/permissão de alarme.
  Future<void> sendTestNotification() async {
    if (!_ready) await init();
    await _plugin.show(
      999999,
      'Notificação de teste',
      'Se você está vendo isso, as notificações do sistema estão funcionando.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _testChannel.id,
          _testChannel.name,
          channelDescription: _testChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Chamado sempre que a central de notificações do app recebe uma nova
  /// leva de dados (via stream). Dispara como notificação do sistema
  /// qualquer aviso não lido que tenha "chegado" há pouco tempo — evita
  /// notificar de novo avisos antigos toda vez que o app é reaberto, e
  /// evita repetir a mesma notificação a cada nova emissão do stream
  /// (controlado por [alreadyPushed], mantido pela tela que chama isso).
  Future<void> pushNewlyArrived(
    List<NotificationRecord> records,
    Set<String> alreadyPushed,
  ) async {
    final now = DateTime.now();
    for (final n in records) {
      if (n.read) continue;
      if (n.scheduledFor.isAfter(now)) continue;
      if (now.difference(n.scheduledFor) > const Duration(minutes: 2)) continue;
      if (alreadyPushed.contains(n.id)) continue;
      alreadyPushed.add(n.id);
      await pushNow(id: n.id, title: n.title, body: n.body, type: n.type);
    }
  }

  /// Cancela os dois lembretes de um agendamento (ex: quando ele é removido
  /// da agenda antes de disparar).
  Future<void> cancelAppointmentReminders(String appointmentId) async {
    await _plugin.cancel(_beforeId(appointmentId));
    await _plugin.cancel(_afterId(appointmentId));
  }
}
