import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanType { training, diet }

PlanType planTypeFromString(String value) =>
    value == 'diet' ? PlanType.diet : PlanType.training;

String planTypeToString(PlanType type) =>
    type == PlanType.diet ? 'diet' : 'training';

/// Um exercício dentro de uma ficha de treino.
class Exercise {
  Exercise({required this.name, required this.sets, required this.reps});

  final String name;
  final int sets;
  final int reps;

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        name: map['name'] as String? ?? '',
        sets: (map['sets'] as num?)?.toInt() ?? 0,
        reps: (map['reps'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'name': name, 'sets': sets, 'reps': reps};
}

/// Um plano é a ATRIBUIÇÃO de um treino ou dieta a um aluno específico,
/// com vigência própria — é o equivalente a um registro de
/// "atribuições_planos": já nasce vinculado ao aluno, ao invés de viver
/// numa coleção separada.
class Plan {
  Plan({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.exercises = const [],
    this.dietContent = '',
    this.linkedPlanId,
    this.templateId,
    this.objectiveSnapshot,
    this.initialEvaluationId,
    this.finalEvaluationId,
  });

  final String id;
  final String studentId;
  final PlanType type;
  final String title;

  /// Período de vigência do plano para o aluno.
  final DateTime startDate;
  final DateTime endDate;

  /// Preenchido quando [type] é [PlanType.training]: os exercícios da ficha.
  final List<Exercise> exercises;

  /// Preenchido quando [type] é [PlanType.diet]: texto livre com as
  /// refeições, horários e alimentos montados pelo personal.
  final String dietContent;

  /// Id de um plano do tipo oposto (treino <-> dieta) que está sendo
  /// aplicado junto com este, para deixar claro que os dois andam juntos.
  final String? linkedPlanId;

  /// Id do template (biblioteca reutilizável) usado como base para montar
  /// este plano, se algum — mantém a rastreabilidade até a origem.
  final String? templateId;

  /// O objetivo do aluno (Student.goal) no momento em que este plano foi
  /// atribuído — fica "congelado" aqui mesmo que o objetivo do aluno mude
  /// depois, para dar contexto histórico correto.
  final String? objectiveSnapshot;

  /// Id da avaliação física mais próxima da data de início — a "foto"
  /// inicial usada depois para medir a eficiência do plano.
  final String? initialEvaluationId;

  /// Id da avaliação física usada como "foto" final, preenchido quando o
  /// ciclo deste plano é encerrado.
  final String? finalEvaluationId;

  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }

  factory Plan.fromFirestore(String id, Map<String, dynamic> data) {
    final start = data['startDate'] as Timestamp?;
    final end = data['endDate'] as Timestamp?;
    final rawExercises = data['exercises'] as List<dynamic>? ?? const [];
    return Plan(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      type: planTypeFromString(data['type'] as String? ?? 'training'),
      title: data['title'] as String? ?? '',
      startDate: start?.toDate() ?? DateTime.now(),
      endDate: end?.toDate() ?? (start?.toDate() ?? DateTime.now()).add(const Duration(days: 30)),
      exercises: rawExercises
          .whereType<Map<String, dynamic>>()
          .map(Exercise.fromMap)
          .toList(),
      dietContent: data['dietContent'] as String? ?? '',
      linkedPlanId: data['linkedPlanId'] as String?,
      templateId: data['templateId'] as String?,
      objectiveSnapshot: data['objectiveSnapshot'] as String?,
      initialEvaluationId: data['initialEvaluationId'] as String?,
      finalEvaluationId: data['finalEvaluationId'] as String?,
    );
  }

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'studentId': studentId,
        'type': planTypeToString(type),
        'title': title,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'dietContent': dietContent,
        'linkedPlanId': linkedPlanId,
        'templateId': templateId,
        'objectiveSnapshot': objectiveSnapshot,
        'initialEvaluationId': initialEvaluationId,
        'finalEvaluationId': finalEvaluationId,
      };
}
