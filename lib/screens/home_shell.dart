import 'dart:async';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/evaluation.dart';
import '../models/appointment.dart';
import '../models/personal.dart';
import '../models/availability.dart';
import '../models/notification_record.dart';
import '../models/checkin.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/account_provisioning_service.dart';
import '../services/app_exceptions.dart';
import '../services/notification_service.dart';
import 'change_password_screen.dart';
import 'dashboard_page.dart';
import 'students_page.dart';
import 'templates_page.dart';
import 'agenda_page.dart';
import 'personals_page.dart';
import 'personal_profile_page.dart';
import 'notifications_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.uid});
  final String uid;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final FirestoreService service = FirestoreService(ownerUid: widget.uid);
  final _auth = AuthService();

  // Streams com instância única e reaproveitada: passadas para telas que
  // precisam se manter atualizadas sozinhas (ex: StudentDetailScreen),
  // sem depender do momento em que a tela foi aberta.
  late final Stream<List<Evaluation>> evaluationsStream = service.watchEvaluations();
  late final Stream<List<Plan>> plansStream = service.watchPlans();
  late final Stream<PersonalAvailability> myAvailabilityStream = service.watchAvailability(widget.uid);
  late final Stream<List<NotificationRecord>> notificationsStream = service.watchNotificationsFor(widget.uid);
  late final Stream<List<PlanTemplate>> templatesStream = service.watchTemplates();

  List<Student> students = [];
  List<Plan> plans = [];
  List<Evaluation> evaluations = [];
  List<Checkin> checkins = [];
  List<Appointment> appointments = [];
  List<Personal> personals = [];
  List<PlanTemplate> templates = [];
  bool loading = true;
  String? loadError;
  int section = 0;

  StreamSubscription<List<Student>>? _studentsSub;
  StreamSubscription<List<Plan>>? _plansSub;
  StreamSubscription<List<Evaluation>>? _evaluationsSub;
  StreamSubscription<List<Checkin>>? _checkinsSub;
  StreamSubscription<List<Appointment>>? _appointmentsSub;
  StreamSubscription<List<Personal>>? _personalsSub;
  StreamSubscription<List<NotificationRecord>>? _notificationsSub;
  StreamSubscription<List<PlanTemplate>>? _templatesSub;
  final _pushedNotificationIds = <String>{};

  Personal? get myProfile {
    final matches = personals.where((p) => p.uid == widget.uid);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void initState() {
    super.initState();
    _studentsSub = service.watchStudents().listen(
      (data) => setState(() {
        students = data;
        loading = false;
      }),
      onError: (Object error) => setState(() {
        loading = false;
        loadError = 'Erro ao carregar alunos: $error';
      }),
    );
    _plansSub = plansStream.listen(
      (data) => setState(() => plans = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar planos: $error'),
    );
    _evaluationsSub = evaluationsStream.listen(
      (data) => setState(() => evaluations = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar avaliações: $error'),
    );
    _checkinsSub = service.watchRecentCheckins().listen(
      (data) => setState(() => checkins = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar registros: $error'),
    );
    _appointmentsSub = service.watchAppointments().listen(
      (data) => setState(() => appointments = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar agenda: $error'),
    );
    // Assinatura persistente (ativa a vida toda da tela, não só quando a
    // aba Equipe/Perfil está visível) — sem isso, a lista de personais
    // "esfriava" ao trocar de aba e parava de trazer o estado atual.
    _personalsSub = service.watchPersonals().listen(
      (data) => setState(() => personals = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar equipe: $error'),
    );
    // Sempre que uma notificação nova (marcada/cancelada/lembrete) chega
    // na central interna, também disparamos como notificação do sistema
    // — funciona enquanto este app está aberto ou recém em segundo plano.
    _notificationsSub = notificationsStream.listen((data) {
      NotificationService.instance.pushNewlyArrived(data, _pushedNotificationIds);
    });
    // Mesma lógica da assinatura persistente de personais: sem isso, o
    // formulário de novo plano/ficha só recebia a lista de modelos se
    // fosse o primeiro a "ligar" o stream compartilhado, ficando vazio
    // quando aberto depois da aba Modelos (ou vice-versa).
    _templatesSub = templatesStream.listen(
      (data) => setState(() => templates = data),
      onError: (Object error) => setState(() => loadError = 'Erro ao carregar modelos: $error'),
    );
  }

  @override
  void dispose() {
    _studentsSub?.cancel();
    _plansSub?.cancel();
    _evaluationsSub?.cancel();
    _checkinsSub?.cancel();
    _appointmentsSub?.cancel();
    _personalsSub?.cancel();
    _notificationsSub?.cancel();
    _templatesSub?.cancel();
    super.dispose();
  }

  String studentName(String id) {
    final match = students.where((s) => s.id == id);
    return match.isEmpty ? 'Aluno removido' : match.first.name;
  }

  /// Cria a conta de login do aluno (sem derrubar a sessão da personal) e o
  /// cadastro dele, e devolve a senha temporária para a mensagem do WhatsApp.
  Future<String> _createStudentWithAccount({
    required String name,
    required String phone,
    required String email,
    required String goal,
    required double height,
    required double weight,
    required String observations,
    required String sex,
    required DateTime birthDate,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await service.isEmailTaken(normalizedEmail)) {
      throw AppException('Este e-mail já está cadastrado para outro aluno ou personal.');
    }
    final tempPassword = AccountProvisioningService.generateTemporaryPassword();
    final authUid = await AccountProvisioningService.createAccount(
      email: normalizedEmail,
      password: tempPassword,
    );
    await service.addStudent(
      name: name,
      phone: phone,
      email: normalizedEmail,
      goal: goal,
      height: height,
      weight: weight,
      observations: observations,
      sex: sex,
      birthDate: birthDate,
      authUid: authUid,
    );
    return tempPassword;
  }

  /// Cria a conta de login de um(a) novo(a) colega personal e devolve a
  /// senha temporária gerada.
  Future<String> _createPersonalAccount({
    required String name,
    required String email,
    required String phone,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (await service.isEmailTaken(normalizedEmail)) {
      throw AppException('Este e-mail já está cadastrado para outro aluno ou personal.');
    }
    final tempPassword = AccountProvisioningService.generateTemporaryPassword();
    final uid = await AccountProvisioningService.createAccount(
      email: normalizedEmail,
      password: tempPassword,
    );
    await service.savePersonalProfile(
      uid: uid,
      name: name,
      email: normalizedEmail,
      phone: phone,
    );
    return tempPassword;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (myProfile?.mustChangePassword == true) {
      return ChangePasswordScreen(onChanged: () => service.markPersonalPasswordChanged(widget.uid));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pages = [
          DashboardPage(
            students: students,
            plans: plans,
            templates: templates,
            evaluations: evaluations,
            checkins: checkins,
            appointments: appointments,
            studentName: studentName,
          ),
          StudentsPage(
            students: students,
            service: service,
            onAddStudent: _createStudentWithAccount,
            onUpdateStudent: service.updateStudent,
            onAddEvaluation: service.addEvaluation,
            onAddPlan: service.addPlan,
            templates: templates,
            onSaveTemplate: service.saveTemplate,
          ),
          TemplatesPage(
            fixedType: PlanType.training,
            templates: templates,
            onSaveTemplate: service.saveTemplate,
            onDeleteTemplate: service.deleteTemplate,
            students: students,
            service: service,
            onUpdateStudent: service.updateStudent,
            onAddEvaluation: service.addEvaluation,
            onAddPlan: service.addPlan,
          ),
          TemplatesPage(
            fixedType: PlanType.diet,
            templates: templates,
            onSaveTemplate: service.saveTemplate,
            onDeleteTemplate: service.deleteTemplate,
            students: students,
            service: service,
            onUpdateStudent: service.updateStudent,
            onAddEvaluation: service.addEvaluation,
            onAddPlan: service.addPlan,
          ),
          AgendaPage(
            students: students,
            appointments: appointments,
            studentName: studentName,
            currentPersonalUid: widget.uid,
            currentPersonalName: myProfile?.name.isNotEmpty == true ? myProfile!.name : 'Personal',
            service: service,
            onAddAppointment: service.addAppointment,
            onDeleteAppointment: service.deleteAppointment,
          ),
          PersonalsPage(
            currentUid: widget.uid,
            personals: personals,
            onAddPersonal: _createPersonalAccount,
          ),
          PersonalProfilePage(
            myProfile: myProfile,
            myAvailabilityStream: myAvailabilityStream,
            onSaveAvailability: (ranges) => service.saveAvailability(widget.uid, ranges),
            onSaveProfile: ({required String name, required String phone}) =>
                service.updatePersonalProfile(uid: widget.uid, name: name, phone: phone),
            onOpenAgenda: () => setState(() => section = 4),
            onOpenEquipe: () => setState(() => section = 5),
          ),
        ];
        return PopScope(
          // As abas (Painel/Alunos/Treinos/...) são só uma troca de estado
          // interna, não empilham tela no Navigator — sem isso, apertar
          // voltar em qualquer aba que não seja a primeira fechava o app
          // direto, por não ter nada pra "desempilhar". Agora primeiro
          // volta pra aba inicial (Painel); só sai do app se já estiver
          // nela.
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
                        builder: (_) => NotificationsPage(service: service, uid: widget.uid),
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
          body: Column(
            children: [
              if (loadError != null)
                MaterialBanner(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  content: Text(loadError!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => loadError = null),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              Expanded(
                child: Row(
                  children: [
                    if (!compact)
                      NavigationRail(
                        // Mesma lógica da barra de baixo do celular: Agenda
                        // e Equipe saíram da lista, acessíveis só pelos
                        // atalhos dentro de Perfil — assim as duas telas
                        // (larga e estreita) navegam do mesmo jeito.
                        selectedIndex: section <= 3 ? section : 4,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (value) => setState(() => section = value == 4 ? 6 : value),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Painel'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: Text('Alunos'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.fitness_center_outlined),
                            selectedIcon: Icon(Icons.fitness_center),
                            label: Text('Treinos'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.restaurant_menu_outlined),
                            selectedIcon: Icon(Icons.restaurant_menu),
                            label: Text('Dietas'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: Text('Perfil'),
                          ),
                        ],
                      ),
                    if (!compact) const VerticalDivider(width: 1),
                    Expanded(child: pages[section]),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: compact
              ? NavigationBar(
                  // Agenda (índice 4) e Equipe (índice 5) na lista de páginas
                  // saíram da barra — quem está em qualquer uma delas (só dá
                  // pra chegar lá pelos atalhos dentro de Perfil agora) vê a
                  // aba "Perfil" destacada, já que é de lá que elas partem.
                  selectedIndex: section <= 3 ? section : 4,
                  onDestinationSelected: (value) => setState(() => section = value == 4 ? 6 : value),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
                    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Alunos'),
                    NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Treinos'),
                    NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Dietas'),
                    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
                  ],
                )
              : null,
          ),
        );
      },
    );
  }
}
