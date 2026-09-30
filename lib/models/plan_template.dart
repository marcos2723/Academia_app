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
    this.exercises = const [],
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

  final List<Exercise> exercises;
  final String dietContent;
  final DateTime createdAt;

  factory PlanTemplate.fromFirestore(String id, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    final rawExercises = data['exercises'] as List<dynamic>? ?? const [];
    return PlanTemplate(
      id: id,
      type: planTypeFromString(data['type'] as String? ?? 'training'),
      title: data['title'] as String? ?? '',
      objectiveBase: data['objectiveBase'] as String? ?? '',
      level: data['level'] as String? ?? '',
      exercises: rawExercises.whereType<Map<String, dynamic>>().map(Exercise.fromMap).toList(),
      dietContent: data['dietContent'] as String? ?? '',
      createdAt: created?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': planTypeToString(type),
        'title': title,
        'objectiveBase': objectiveBase,
        'level': level,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'dietContent': dietContent,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
