import 'package:flutter/material.dart';
import '../models/notification_record.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';

/// Central de notificações — funciona tanto para personal quanto para
/// aluno, mostrando os avisos endereçados a cada um: lembretes de
/// avaliações marcadas, o lembrete de lançar os dados depois, e avisos
/// de cancelamento.
///
/// A tela cria a PRÓPRIA consulta ao Firestore (em vez de reaproveitar um
/// stream já escutado pelo sino do AppBar): um stream do Firestore com
/// `.map()` aceita só um ouvinte, então compartilhar a mesma instância
/// fazia esta tela receber um erro e aparecer vazia enquanto o contador
/// do sino continuava funcionando.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.service,
    required this.uid,
  });

  final FirestoreService service;
  final String uid;

  IconData _iconFor(String type) {
    switch (type) {
      case 'appointment_reminder':
        return Icons.event_outlined;
      case 'appointment_followup':
        return Icons.assignment_turned_in_outlined;
      case 'appointment_cancelled':
        return Icons.event_busy_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<List<NotificationRecord>>(
            stream: service.watchNotificationsFor(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Não foi possível carregar as notificações.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data ?? const <NotificationRecord>[];
              // Só mostramos o que ainda não foi lido: ao tocar numa
              // notificação ela é marcada como lida e sai da lista, para a
              // tela não ficar poluída com avisos antigos.
              final due = all
                  .where((n) => !n.read && !n.scheduledFor.isAfter(DateTime.now()))
                  .toList()
                ..sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
              if (due.isEmpty) {
                return const Center(child: Text('Nenhuma notificação nova por aqui.'));
              }
              return ListView.separated(
                itemCount: due.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = due[i];
                  return Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.done_all),
                    ),
                    onDismissed: (_) => service.markNotificationRead(n.id),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: Icon(_iconFor(n.type)),
                        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${n.body}\n${formatDateTime(n.scheduledFor)}'),
                        isThreeLine: true,
                        onTap: () => service.markNotificationRead(n.id),
                        trailing: IconButton(
                          tooltip: 'Marcar como lida',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => service.markNotificationRead(n.id),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
