import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanType { training, diet }

PlanType planTypeFromString(String value) =>
    value == 'diet' ? PlanType.diet : PlanType.training;

String planTypeToString(PlanType type) =>
    type == PlanType.diet ? 'diet' : 'training';

/// Tipos de série que a personal pode escolher para cada exercício.
enum SetType { normal, warmup, dropset, biset, triset, restPause, cluster, pyramid, failure }

extension SetTypeInfo on SetType {
  String get label => switch (this) {
        SetType.normal => 'Normal',
        SetType.warmup => 'Aquecimento',
        SetType.dropset => 'Drop set',
        SetType.biset => 'Bi-set',
        SetType.triset => 'Tri-set',
        SetType.restPause => 'Rest-pause',
        SetType.cluster => 'Cluster',
        SetType.pyramid => 'Pirâmide',
        SetType.failure => 'Até a falha',
      };

  /// Lembrete curto mostrado ao escolher o tipo.
  String get hint => switch (this) {
        SetType.normal => '',
        SetType.warmup => 'Séries leves de preparo.',
        SetType.dropset => 'Reduz a carga sem descanso.',
        SetType.biset => 'Com o exercício seguinte, sem pausa.',
        SetType.triset => 'Com os dois seguintes, sem pausa.',
        SetType.restPause => 'Falha, pausa curta e continua.',
        SetType.cluster => 'Mini-blocos com pausas curtas.',
        SetType.pyramid => 'Mais carga, menos repetições.',
        SetType.failure => 'Até a falha técnica.',
      };
}

SetType setTypeFromString(String? value) =>
    SetType.values.firstWhere((t) => t.name == value, orElse: () => SetType.normal);

const List<String> _weekdayNames = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];

const List<String> _weekdayShort = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Nome do dia da semana (1 = segunda ... 7 = domingo).
String weekdayLabel(int weekday) => _weekdayNames[(weekday - 1).clamp(0, 6)];

/// Nome curto do dia da semana (Seg, Ter, ...).
String weekdayShortLabel(int weekday) => _weekdayShort[(weekday - 1).clamp(0, 6)];

/// "Seg, Qua, Sex" a partir de uma lista de dias da semana.
String weekdaysSummary(List<int> weekdays) => weekdays.map(weekdayShortLabel).join(', ');

/// Um exercício dentro de um dia de treino.
class Exercise {
  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.setType = SetType.normal,
    this.restSeconds,
    this.notes = '',
  });

  final String name;
  final int sets;

  /// Texto livre: "12", "8-12", "Até a falha"... (fichas antigas guardavam
  /// só um número, que continua sendo lido normalmente).
  final String reps;
  final SetType setType;

  /// Descanso entre as séries, em segundos (opcional).
  final int? restSeconds;
  final String notes;

  factory Exercise.fromMap(Map<String, dynamic> map) {
    final rawReps = map['reps'];
    return Exercise(
      name: map['name'] as String? ?? '',
      sets: (map['sets'] as num?)?.toInt() ?? 0,
      reps: rawReps is num ? rawReps.toInt().toString() : (rawReps as String? ?? ''),
      setType: setTypeFromString(map['setType'] as String?),
      restSeconds: (map['restSeconds'] as num?)?.toInt(),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'setType': setType.name,
        'restSeconds': restSeconds,
        'notes': notes,
      };
}

/// Uma divisão da ficha semanal (ex.: "Treino A - Peito e tríceps"),
/// com os dias da semana em que ela é feita.
class TrainingDay {
  TrainingDay({required this.label, this.weekdays = const [], this.exercises = const []});

  final String label;

  /// Dias da semana em que este treino é feito (1 = segunda ... 7 =
  /// domingo). Vazio = sem dia fixo.
  final List<int> weekdays;
  final List<Exercise> exercises;

  factory TrainingDay.fromMap(Map<String, dynamic> map) {
    final rawWeekdays = map['weekdays'] as List<dynamic>?;
    final legacyWeekday = (map['weekday'] as num?)?.toInt();
    final weekdays = rawWeekdays != null
        ? rawWeekdays.whereType<num>().map((n) => n.toInt()).toList()
        : (legacyWeekday == null ? <int>[] : [legacyWeekday]);
    weekdays.sort();
    return TrainingDay(
        label: map['label'] as String? ?? '',
        weekdays: weekdays,
        exercises: (map['exercises'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Exercise.fromMap)
            .toList(),
      );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'weekdays': weekdays,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };
}

/// Lê os dias de treino de um documento do Firestore. Fichas antigas (que
/// tinham só uma lista plana de exercícios) viram um único dia "Treino".
List<TrainingDay> trainingDaysFromData(Map<String, dynamic> data) {
  final rawDays = data['days'] as List<dynamic>? ?? const [];
  final days = rawDays.whereType<Map<String, dynamic>>().map(TrainingDay.fromMap).toList();
  if (days.isNotEmpty) return days;
  final legacy = (data['exercises'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(Exercise.fromMap)
      .toList();
  return legacy.isEmpty ? const [] : [TrainingDay(label: 'Treino', exercises: legacy)];
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
    this.days = const [],
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

  /// Preenchido quando [type] é [PlanType.training]: os dias da ficha
  /// semanal, cada um com seus exercícios.
  final List<TrainingDay> days;

  /// Todos os exercícios da ficha, de todos os dias, numa lista só.
  List<Exercise> get exercises => days.expand((d) => d.exercises).toList();

  int get exerciseCount => days.fold(0, (sum, d) => sum + d.exercises.length);

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
    return Plan(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      type: planTypeFromString(data['type'] as String? ?? 'training'),
      title: data['title'] as String? ?? '',
      startDate: start?.toDate() ?? DateTime.now(),
      endDate: end?.toDate() ?? (start?.toDate() ?? DateTime.now()).add(const Duration(days: 30)),
      days: trainingDaysFromData(data),
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
        'days': days.map((d) => d.toMap()).toList(),
        'dietContent': dietContent,
        'linkedPlanId': linkedPlanId,
        'templateId': templateId,
        'objectiveSnapshot': objectiveSnapshot,
        'initialEvaluationId': initialEvaluationId,
        'finalEvaluationId': finalEvaluationId,
      };
}
