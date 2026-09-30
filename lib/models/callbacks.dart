import 'plan.dart';
import 'plan_template.dart';
import 'availability.dart';

typedef AddAppointmentCallback = Future<String> Function({
  required String studentId,
  required String personalUid,
  required DateTime dateTime,
  String notes,
});

typedef DeleteAppointmentCallback = Future<void> Function(String id);

/// Cria a conta de acesso do aluno (Firebase Auth) e o cadastro dele,
/// e retorna a senha temporária gerada, para montar a mensagem do WhatsApp.
typedef AddStudentCallback = Future<String> Function({
  required String name,
  required String phone,
  required String email,
  required String goal,
  required double height,
  required double weight,
  required String observations,
  required String sex,
  required DateTime birthDate,
});

typedef UpdateStudentCallback = Future<void> Function(
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
});

typedef AddPlanCallback = Future<void> Function({
  required String studentId,
  required PlanType type,
  required String title,
  required DateTime startDate,
  required DateTime endDate,
  List<Exercise> exercises,
  String dietContent,
  String? linkedPlanId,
  String? templateId,
  String? objectiveSnapshot,
});

/// Salva um novo template reutilizável na biblioteca e devolve o id
/// gerado.
typedef SaveTemplateCallback = Future<String> Function({
  required PlanType type,
  required String title,
  required String objectiveBase,
  required String level,
  List<Exercise> exercises,
  String dietContent,
});

typedef DeleteTemplateCallback = Future<void> Function(String id);

/// Cria a conta de acesso de um(a) novo(a) colega personal e devolve a
/// senha temporária gerada.
typedef AddPersonalCallback = Future<String> Function({
  required String name,
  required String email,
  required String phone,
});

typedef SaveAvailabilityCallback = Future<void> Function(List<AvailabilityRange> ranges);
