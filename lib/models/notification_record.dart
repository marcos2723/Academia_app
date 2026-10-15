import 'package:cloud_firestore/cloud_firestore.dart';

/// Uma notificação guardada no Firestore, endereçada a um usuário
/// (personal ou aluno) pelo uid da conta dele. É a "central de
/// notificações" do app — funciona entre pessoas diferentes porque fica
/// salva no banco, diferente das notificações locais do sistema
/// operacional (que só avisam no aparelho onde foram agendadas).
class NotificationRecord {
  NotificationRecord({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.scheduledFor,
    required this.read,
    required this.type,
  });

  final String id;
  final String recipientUid;
  final String title;
  final String body;

  /// A partir de quando essa notificação "vale" — usado tanto para os
  /// lembretes de avaliação (horário do lembrete) quanto para avisos
  /// imediatos como cancelamento (igual ao momento da criação).
  final DateTime scheduledFor;
  final bool read;
  final String type;

  /// Por quanto tempo a notificação fica guardada depois de "valer". Passado
  /// esse prazo o Firestore a apaga sozinho (política TTL no campo
  /// `expireAt`).
  static const Duration retention = Duration(days: 30);

  factory NotificationRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['scheduledFor'] as Timestamp?;
    return NotificationRecord(
      id: id,
      recipientUid: data['recipientUid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      scheduledFor: ts?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
      type: data['type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'recipientUid': recipientUid,
        'title': title,
        'body': body,
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'read': read,
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(scheduledFor.add(retention)),
      };
}
