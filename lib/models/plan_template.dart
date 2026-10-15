import 'package:cloud_firestore/cloud_firestore.dart';
import 'plan.dart';

/// Um modelo reutilizável de ficha de treino ou dieta — não pertence a
/// nenhum aluno específico. Ao atribuir um plano a um aluno, a personal
/// pode partir de um template (copiando o conteúdo dele) em vez de montar
/// tudo do zero toda vez.
class PlanTemplate {
  PlanTemplate({
    required this.id,
    required this.type,
    required this.title,
    required this.objectiveBase,
    required this.level,
    this.days = const [],
    this.dietContent = '',
    required this.createdAt,
  });

  final String id;
  final PlanType type;
  final String title;

  /// Objetivo para o qual esse template foi pensado (ex: "Hipertrofia",
  /// "Emagrecimento", "Definição") — usado para organizar a biblioteca.
  final String objectiveBase;

  /// Nível de experiência (ex: "Iniciante", "Intermediário", "Avançado").
  final String level;

  /// Dias da ficha semanal (só para modelos de treino).
  final List<TrainingDay> days;
  List<Exercise> get exercises => days.expand((d) => d.exercises).toList();
  int get exerciseCount => days.fold(0, (sum, d) => sum + d.exercises.length);
  final String dietContent;
  final DateTime createdAt;

  factory PlanTemplate.fromFirestore(String id, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    return PlanTemplate(
      id: id,
      type: planTypeFromString(data['type'] as String? ?? 'training'),
      title: data['title'] as String? ?? '',
      objectiveBase: data['objectiveBase'] as String? ?? '',
      level: data['level'] as String? ?? '',
      days: trainingDaysFromData(data),
      dietContent: data['dietContent'] as String? ?? '',
      createdAt: created?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': planTypeToString(type),
        'title': title,
        'objectiveBase': objectiveBase,
        'level': level,
        'days': days.map((d) => d.toMap()).toList(),
        'dietContent': dietContent,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
