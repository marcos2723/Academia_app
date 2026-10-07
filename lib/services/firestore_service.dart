import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/evaluation.dart';
import '../models/appointment.dart';
import '../models/personal.dart';
import '../models/availability.dart';
import '../models/notification_record.dart';
import '../utils/body_composition.dart';
import '../utils/formatters.dart';

class FirestoreService {
  FirestoreService({required this.ownerUid, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String ownerUid;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _students => _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _plans => _db.collection('plans');
  CollectionReference<Map<String, dynamic>> get _evaluations => _db.collection('evaluations');
  CollectionReference<Map<String, dynamic>> get _appointments => _db.collection('appointments');
  CollectionReference<Map<String, dynamic>> get _personals => _db.collection('personals');
  CollectionReference<Map<String, dynamic>> get _availability => _db.collection('availability');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _templates => _db.collection('plan_templates');

  // ---------------------------------------------------------------------
  // Appointments (agenda)
  // ---------------------------------------------------------------------

  Stream<List<Appointment>> watchAppointments() {
    return _appointments
        .orderBy('dateTime')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromFirestore(d.id, d.data())).toList());
  }

  /// Agendamentos de UM aluno específico — usado pelo próprio aluno, cuja
  /// permissão de leitura só cobre o que casa com esse filtro.
  Stream<List<Appointment>> watchAppointmentsForStudent(String studentId) {
    return _appointments
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Appointment.fromFirestore(d.id, d.data())).toList());
  }

  /// Retorna o id do agendamento criado, usado para agendar as notificações.
  Future<String> addAppointment({
    required String studentId,
    required String personalUid,
    required DateTime dateTime,
    String notes = '',
  }) async {
    final appointment = Appointment(
      id: '',
      studentId: studentId,
      personalUid: personalUid,
      dateTime: dateTime,
      notes: notes,
    );
    final doc = await _appointments.add(appointment.toMap(ownerUid));
    return doc.id;
  }

  Future<void> deleteAppointment(String id) => _appointments.doc(id).delete();

  // ---------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------

  Stream<List<Student>> watchStudents() {
    return _students
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Student.fromFirestore(d.id, d.data())).toList());
  }

  /// O aluno lê só o próprio cadastro através desse filtro (é o que a
  /// regra de segurança exige para permitir a leitura).
  Stream<Student?> watchStudentByAuthUid(String authUid) {
    return _students.where('authUid', isEqualTo: authUid).snapshots().map(
          (snap) => snap.docs.isEmpty ? null : Student.fromFirestore(snap.docs.first.id, snap.docs.first.data()),
        );
  }

  Future<Student?> fetchStudentByAuthUid(String authUid) async {
    final snap = await _students.where('authUid', isEqualTo: authUid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Student.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  /// Cria o cadastro do aluno já vinculado à conta de login ([authUid])
  /// criada para ele.
  Future<void> addStudent({
    required String name,
    required String phone,
    required String email,
    required String goal,
    required double height,
    required double weight,
    required String observations,
    required String sex,
    required DateTime birthDate,
    String? authUid,
  }) {
    return _students.add(
      Student(
        id: '',
        name: name,
        phone: phone,
        email: email,
        goal: goal,
        height: height,
        weight: weight,
        observations: observations,
        sex: sex,
        birthDate: birthDate,
        authUid: authUid,
        mustChangePassword: authUid != null,
      ).toMap(ownerUid),
    );
  }

  Future<void> updateStudent(
    String studentId, {
    required String name,
    required String phone,
    required String email,
    required String goal,
    required double height,
    required double weight,
    required String observations,
    required String sex,
    required DateTime birthDate,
    required bool active,
  }) {
    return _students.doc(studentId).update(
          Student(
            id: studentId,
            name: name,
            phone: phone,
            email: email,
            goal: goal,
            height: height,
            weight: weight,
            observations: observations,
            sex: sex,
            birthDate: birthDate,
            active: active,
          ).toUpdateMap(),
        );
  }

  Future<void> markPasswordChanged(String studentId) {
    return _students.doc(studentId).update({'mustChangePassword': false});
  }

  // ---------------------------------------------------------------------
  // Plans
  // ---------------------------------------------------------------------

  Stream<List<Plan>> watchPlans() {
    return _plans
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Plan.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<Plan>> watchPlansForStudent(String studentId) {
    return _plans
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Plan.fromFirestore(d.id, d.data())).toList());
  }

  /// Acha a avaliação física de um aluno mais próxima (antes ou depois)
  /// de uma data de referência — usada para "fotografar" o estado físico
  /// no início e no fim de um plano.
  Future<String?> _nearestEvaluationId(String studentId, DateTime referenceDate) async {
    final snap = await _evaluations.where('studentId', isEqualTo: studentId).get();
    if (snap.docs.isEmpty) return null;
    final evaluations = snap.docs.map((d) => Evaluation.fromFirestore(d.id, d.data())).toList();
    evaluations.sort(
      (a, b) => a.date.difference(referenceDate).abs().compareTo(b.date.difference(referenceDate).abs()),
    );
    return evaluations.first.id;
  }

  Future<void> addPlan({
    required String studentId,
    required PlanType type,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    List<Exercise> exercises = const [],
    String dietContent = '',
    String? linkedPlanId,
    String? templateId,
    String? objectiveSnapshot,
  }) async {
    final initialEvaluationId = await _nearestEvaluationId(studentId, startDate);
    final plan = Plan(
      id: '',
      studentId: studentId,
      type: type,
      title: title,
      startDate: startDate,
      endDate: endDate,
      exercises: exercises,
      dietContent: dietContent,
      linkedPlanId: linkedPlanId,
      templateId: templateId,
      objectiveSnapshot: objectiveSnapshot,
      initialEvaluationId: initialEvaluationId,
    );
    await _plans.add(plan.toMap(ownerUid));
  }

  /// Encerra o ciclo de um plano, "fotografando" a avaliação mais próxima
  /// de hoje como referência final — usado depois para medir a eficiência
  /// do plano (comparando a avaliação inicial com a final).
  Future<void> closePlanCycle(String planId, String studentId) async {
    final finalEvaluationId = await _nearestEvaluationId(studentId, DateTime.now());
    if (finalEvaluationId == null) return;
    await _plans.doc(planId).update({'finalEvaluationId': finalEvaluationId});
  }

  // ---------------------------------------------------------------------
  // Biblioteca de templates (fichas de treino e dietas reutilizáveis)
  // ---------------------------------------------------------------------

  Stream<List<PlanTemplate>> watchTemplates() {
    return _templates
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PlanTemplate.fromFirestore(d.id, d.data())).toList());
  }

  Future<String> saveTemplate({
    required PlanType type,
    required String title,
    required String objectiveBase,
    required String level,
    List<Exercise> exercises = const [],
    String dietContent = '',
  }) async {
    final template = PlanTemplate(
      id: '',
      type: type,
      title: title,
      objectiveBase: objectiveBase,
      level: level,
      exercises: exercises,
      dietContent: dietContent,
      createdAt: DateTime.now(),
    );
    final doc = await _templates.add(template.toMap());
    return doc.id;
  }

  Future<void> deleteTemplate(String id) => _templates.doc(id).delete();

  // ---------------------------------------------------------------------
  // Evaluations
  // ---------------------------------------------------------------------

  Stream<List<Evaluation>> watchEvaluations() {
    return _evaluations
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Evaluation.fromFirestore(d.id, d.data())).toList());
  }

  Stream<List<Evaluation>> watchEvaluationsForStudent(String studentId) {
    return _evaluations
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Evaluation.fromFirestore(d.id, d.data())).toList());
  }

  /// [student] é usado para pegar sexo e idade na data da avaliação,
  /// necessários para a fórmula de Pollock 7 dobras.
  Future<void> addEvaluation({
    required Student student,
    required double weight,
    required double height,
    required double neck,
    required double shoulders,
    required double chest,
    required double waist,
    required double hip,
    required double armRight,
    required double armLeft,
    required double forearmRight,
    required double forearmLeft,
    required double thighRight,
    required double thighLeft,
    required double calfRight,
    required double calfLeft,
    required double skinfoldChest,
    required double skinfoldAbdominal,
    required double skinfoldThigh,
    required double skinfoldTriceps,
    required double skinfoldSubscapular,
    required double skinfoldSuprailiac,
    required double skinfoldMidaxillary,
  }) {
    final now = DateTime.now();
    final bodyFat = calculateBodyFatPercent(
      sex: student.sex,
      age: student.ageAt(now),
      skinfolds: SkinfoldMeasurements(
        chest: skinfoldChest,
        abdominal: skinfoldAbdominal,
        thigh: skinfoldThigh,
        triceps: skinfoldTriceps,
        subscapular: skinfoldSubscapular,
        suprailiac: skinfoldSuprailiac,
        midaxillary: skinfoldMidaxillary,
      ),
    );
    final evaluation = Evaluation(
      id: '',
      studentId: student.id,
      date: now,
      weight: weight,
      height: height,
      neck: neck,
      shoulders: shoulders,
      chest: chest,
      waist: waist,
      hip: hip,
      armRight: armRight,
      armLeft: armLeft,
      forearmRight: forearmRight,
      forearmLeft: forearmLeft,
      thighRight: thighRight,
      thighLeft: thighLeft,
      calfRight: calfRight,
      calfLeft: calfLeft,
      skinfoldChest: skinfoldChest,
      skinfoldAbdominal: skinfoldAbdominal,
      skinfoldThigh: skinfoldThigh,
      skinfoldTriceps: skinfoldTriceps,
      skinfoldSubscapular: skinfoldSubscapular,
      skinfoldSuprailiac: skinfoldSuprailiac,
      skinfoldMidaxillary: skinfoldMidaxillary,
      bodyFat: bodyFat,
    );
    return _evaluations.add(evaluation.toMap(ownerUid));
  }

  // ---------------------------------------------------------------------
  // Personals (equipe)
  // ---------------------------------------------------------------------

  Stream<List<Personal>> watchPersonals() {
    // Sem orderBy no Firestore de propósito: um orderBy('name') descarta
    // silenciosamente qualquer documento que não tenha o campo 'name' —
    // era o caso da conta "chefe" criada à mão no Console, que por isso
    // nunca aparecia na lista da equipe. Ordenamos no app.
    return _personals.snapshots().map((snap) {
      final list = snap.docs.map((d) => Personal.fromFirestore(d.id, d.data())).toList();
      list.sort((a, b) {
        final an = a.name.trim().isEmpty ? a.email : a.name;
        final bn = b.name.trim().isEmpty ? b.email : b.name;
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
      return list;
    });
  }

  Future<void> savePersonalProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
  }) {
    return _personals.doc(uid).set(
          Personal(uid: uid, name: name, email: email, phone: phone, mustChangePassword: true).toMap(),
        );
  }

  Future<void> markPersonalPasswordChanged(String uid) {
    return _personals.doc(uid).update({'mustChangePassword': false});
  }

  /// Atualiza só os campos editáveis do próprio perfil, sem apagar o resto.
  Future<void> updatePersonalProfile({
    required String uid,
    required String name,
    required String phone,
  }) {
    return _personals.doc(uid).set({'name': name, 'phone': phone}, SetOptions(merge: true));
  }

  /// Verifica se um e-mail já está em uso por algum aluno ou personal.
  ///
  /// O Firebase Auth já recusa e-mails duplicados, mas com a "proteção
  /// contra enumeração de e-mails" (ligada por padrão em projetos novos)
  /// ele deixa de informar isso claramente — então a conta parecia ser
  /// criada normalmente. Esta checagem explícita garante o bloqueio e uma
  /// mensagem de erro clara.
  Future<bool> isEmailTaken(String email) async {
    final normalized = email.trim().toLowerCase();
    final studentMatch = await _students.where('email', isEqualTo: normalized).limit(1).get();
    if (studentMatch.docs.isNotEmpty) return true;
    final personalMatch = await _personals.where('email', isEqualTo: normalized).limit(1).get();
    return personalMatch.docs.isNotEmpty;
  }

  // ---------------------------------------------------------------------
  // Disponibilidade dos personais
  // ---------------------------------------------------------------------

  Stream<List<PersonalAvailability>> watchAllAvailabilities() {
    return _availability.snapshots().map(
          (snap) => snap.docs.map((d) => PersonalAvailability.fromFirestore(d.id, d.data())).toList(),
        );
  }

  Stream<PersonalAvailability> watchAvailability(String personalUid) {
    return _availability.doc(personalUid).snapshots().map(
          (doc) => PersonalAvailability.fromFirestore(personalUid, doc.data() ?? const {}),
        );
  }

  Future<void> saveAvailability(String personalUid, List<AvailabilityRange> ranges) {
    return _availability.doc(personalUid).set(PersonalAvailability(personalUid: personalUid, ranges: ranges).toMap());
  }

  // ---------------------------------------------------------------------
  // Central de notificações
  // ---------------------------------------------------------------------

  Stream<List<NotificationRecord>> watchNotificationsFor(String uid) {
    return _notifications
        .where('recipientUid', isEqualTo: uid)
        .orderBy('scheduledFor', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationRecord.fromFirestore(d.id, d.data())).toList());
  }

  Future<void> markNotificationRead(String id) => _notifications.doc(id).update({'read': true});

  Future<void> _addNotification({
    required String recipientUid,
    required String title,
    required String body,
    required DateTime scheduledFor,
    required String type,
  }) {
    if (recipientUid.isEmpty) return Future.value();
    return _notifications.add(
      NotificationRecord(
        id: '',
        recipientUid: recipientUid,
        title: title,
        body: body,
        scheduledFor: scheduledFor,
        read: false,
        type: type,
      ).toMap(),
    );
  }

  /// Grava, na central de notificações, os avisos de uma avaliação recém
  /// marcada: lembrete pouco antes do horário (para aluno e personal) e o
  /// lembrete de lançar os dados depois (só para o personal).
  Future<void> writeAppointmentNotifications({
    required String studentAuthUid,
    required String studentName,
    required String personalUid,
    required String personalName,
    required DateTime dateTime,
    int minutesBefore = 15,
    int minutesAfter = 45,
  }) async {
    final beforeTime = dateTime.subtract(Duration(minutes: minutesBefore));
    final afterTime = dateTime.add(Duration(minutes: minutesAfter));
    await _addNotification(
      recipientUid: studentAuthUid,
      title: 'Avaliação em breve',
      body: 'Sua avaliação com $personalName é ${formatDateTime(dateTime)}.',
      scheduledFor: beforeTime,
      type: 'appointment_reminder',
    );
    await _addNotification(
      recipientUid: personalUid,
      title: 'Avaliação em breve',
      body: 'Avaliação com $studentName é ${formatDateTime(dateTime)}.',
      scheduledFor: beforeTime,
      type: 'appointment_reminder',
    );
    await _addNotification(
      recipientUid: personalUid,
      title: 'Lançar avaliação',
      body: 'Não esqueça de registrar os dados da avaliação de $studentName.',
      scheduledFor: afterTime,
      type: 'appointment_followup',
    );
  }

  /// Avisa a outra parte quando uma consulta é cancelada.
  Future<void> notifyAppointmentCancelled({
    required String recipientUid,
    required String cancelledByName,
    required DateTime dateTime,
  }) {
    return _addNotification(
      recipientUid: recipientUid,
      title: 'Avaliação cancelada',
      body: 'A avaliação de ${formatDateTime(dateTime)} foi cancelada por $cancelledByName.',
      scheduledFor: DateTime.now(),
      type: 'appointment_cancelled',
    );
  }
}
