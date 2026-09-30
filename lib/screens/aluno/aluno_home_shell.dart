import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/plan.dart';
import '../../models/notification_record.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';
import '../change_password_screen.dart';
import '../notifications_page.dart';
import 'aluno_profile_page.dart';
import 'aluno_evaluations_page.dart';
import 'aluno_plans_page.dart';
import 'aluno_schedule_screen.dart';

/// Shell do app para quem faz login como aluno: acesso só ao próprio
/// perfil, avaliações, planos, e à opção de marcar uma avaliação.
class AlunoHomeShell extends StatefulWidget {
  const AlunoHomeShell({super.key, required this.authUid});
  final String authUid;

  @override
  State<AlunoHomeShell> createState() => _AlunoHomeShellState();
}

class _AlunoHomeShellState extends State<AlunoHomeShell> {
  late final FirestoreService service = FirestoreService(ownerUid: widget.authUid);
  late final Stream<List<NotificationRecord>> notificationsStream = service.watchNotificationsFor(widget.authUid);
  final _auth = AuthService();

  Student? student;
  bool loading = true;
  int section = 0;
  StreamSubscription<Student?>? _sub;
  StreamSubscription<List<NotificationRecord>>? _notificationsSub;
  final _pushedNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _sub = service.watchStudentByAuthUid(widget.authUid).listen((s) {
      setState(() {
        student = s;
        loading = false;
      });
    });
    // Sempre que uma notificação nova (marcada/cancelada/lembrete) chega
    // na central interna, também disparamos como notificação do sistema
    // — funciona enquanto este app está aberto ou recém em segundo plano.
    _notificationsSub = notificationsStream.listen((data) {
      NotificationService.instance.pushNewlyArrived(data, _pushedNotificationIds);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final currentStudent = student;
    if (currentStudent == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Não encontramos seu cadastro de aluno. Fale com seu personal.'),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => _auth.signOut(), child: const Text('Sair')),
              ],
            ),
          ),
        ),
      );
    }

    if (currentStudent.mustChangePassword) {
      return ChangePasswordScreen(onChanged: () => service.markPasswordChanged(currentStudent.id));
    }

    final pages = [
      AlunoProfilePage(student: currentStudent),
      AlunoEvaluationsPage(service: service, student: currentStudent),
      AlunoPlansPage(service: service, student: currentStudent, fixedType: PlanType.training),
      AlunoPlansPage(service: service, student: currentStudent, fixedType: PlanType.diet),
      AlunoScheduleScreen(service: service, student: currentStudent),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return PopScope(
          // Mesmo caso do lado da personal: as abas não empilham tela no
          // Navigator, então sem isso o botão voltar do celular fechava o
          // app direto em qualquer aba que não fosse a primeira (Perfil).
          canPop: section == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && section != 0) setState(() => section = 0);
          },
          child: Scaffold(
          appBar: AppBar(
            title: const Text('Evolui'),
            actions: [
              StreamBuilder<List<NotificationRecord>>(
                stream: notificationsStream,
                builder: (context, snap) {
                  final unread = (snap.data ?? const <NotificationRecord>[])
                      .where((n) => !n.read && !n.scheduledFor.isAfter(DateTime.now()))
                      .length;
                  return IconButton(
                    tooltip: 'Notificações',
                    icon: Badge(
                      label: Text('$unread'),
                      isLabelVisible: unread > 0,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsPage(service: service, uid: widget.authUid),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: () => _auth.signOut(),
              ),
            ],
          ),
          body: Row(
            children: [
              if (!compact)
                NavigationRail(
                  selectedIndex: section,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (value) => setState(() => section = value),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.person_outline, color: kPerfilAccent), selectedIcon: Icon(Icons.person, color: kPerfilAccent), label: Text('Perfil')),
                    NavigationRailDestination(icon: Icon(Icons.monitor_weight_outlined, color: kAvaliacoesAccent), selectedIcon: Icon(Icons.monitor_weight, color: kAvaliacoesAccent), label: Text('Avaliações')),
                    NavigationRailDestination(icon: Icon(Icons.fitness_center_outlined, color: kTrainingAccent), selectedIcon: Icon(Icons.fitness_center, color: kTrainingAccent), label: Text('Treinos')),
                    NavigationRailDestination(icon: Icon(Icons.restaurant_menu_outlined, color: kDietAccent), selectedIcon: Icon(Icons.restaurant_menu, color: kDietAccent), label: Text('Dietas')),
                    NavigationRailDestination(icon: Icon(Icons.event_available_outlined, color: kAgendarAccent), selectedIcon: Icon(Icons.event_available, color: kAgendarAccent), label: Text('Agendar')),
                  ],
                ),
              if (!compact) const VerticalDivider(width: 1),
              Expanded(child: pages[section]),
            ],
          ),
          bottomNavigationBar: compact
              ? NavigationBar(
                  selectedIndex: section,
                  onDestinationSelected: (value) => setState(() => section = value),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.person_outline, color: kPerfilAccent), selectedIcon: Icon(Icons.person, color: kPerfilAccent), label: 'Perfil'),
                    NavigationDestination(icon: Icon(Icons.monitor_weight_outlined, color: kAvaliacoesAccent), selectedIcon: Icon(Icons.monitor_weight, color: kAvaliacoesAccent), label: 'Avaliações'),
                    NavigationDestination(icon: Icon(Icons.fitness_center_outlined, color: kTrainingAccent), selectedIcon: Icon(Icons.fitness_center, color: kTrainingAccent), label: 'Treinos'),
                    NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined, color: kDietAccent), selectedIcon: Icon(Icons.restaurant_menu, color: kDietAccent), label: 'Dietas'),
                    NavigationDestination(icon: Icon(Icons.event_available_outlined, color: kAgendarAccent), selectedIcon: Icon(Icons.event_available, color: kAgendarAccent), label: 'Agendar'),
                  ],
                )
              : null,
          ),
        );
      },
    );
  }
}
