import 'plan.dart';

/// Como foi o dia do aluno em relação ao treino ou à dieta.
enum CheckinStatus { done, partial, missed }

extension CheckinStatusInfo on CheckinStatus {
  /// Texto dito pelo aluno ao registrar ("Treinei", "Segui"...).
  String actionLabel(PlanType type) {
    final training = type == PlanType.training;
    return switch (this) {
      CheckinStatus.done => training ? 'Treinei' : 'Segui',
      CheckinStatus.partial => 'Em parte',
      CheckinStatus.missed => training ? 'Não treinei' : 'Não segui',
    };
  }

  /// Texto do resultado ("Treinou", "Seguiu"...), para quem consulta.
  String resultLabel(PlanType type) {
    final training = type == PlanType.training;
    return switch (this) {
      CheckinStatus.done => training ? 'Treinou' : 'Seguiu',
      CheckinStatus.partial => 'Parcial',
      CheckinStatus.missed => training ? 'Não treinou' : 'Não seguiu',
    };
  }
}

CheckinStatus checkinStatusFromString(String? value) =>
    CheckinStatus.values.firstWhere((s) => s.name == value, orElse: () => CheckinStatus.done);

/// Registro de um dia de treino ou dieta feito pelo aluno. Existe no
/// máximo um por plano e por dia (o id é plano + data).
class Checkin {
  Checkin({
    required this.id,
    required this.studentId,
    required this.planId,
    required this.type,
    required this.date,
    required this.status,
    this.dayLabel,
    this.note,
  });

  final String id;
  final String studentId;
  final String planId;
  final PlanType type;

  /// Só a data (sem hora).
  final DateTime date;
  final CheckinStatus status;

  /// Qual treino da ficha foi feito (só para treinos).
  final String? dayLabel;

  /// Observação do aluno (usada nas dietas: o que foi comido fora do
  /// combinado e por quê).
  final String? note;

  String get dateKey => dateKeyOf(date);

  static String dateKeyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String docId(String planId, DateTime date) => '${planId}_${dateKeyOf(date)}';

  factory Checkin.fromFirestore(String id, Map<String, dynamic> data) {
    final key = data['dateKey'] as String? ?? '';
    final parsed = DateTime.tryParse(key) ?? DateTime(2000, 1, 1);
    return Checkin(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      planId: data['planId'] as String? ?? '',
      type: planTypeFromString(data['type'] as String? ?? 'training'),
      date: DateTime(parsed.year, parsed.month, parsed.day),
      status: checkinStatusFromString(data['status'] as String?),
      dayLabel: data['dayLabel'] as String?,
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'planId': planId,
        'type': planTypeToString(type),
        'dateKey': dateKey,
        'status': status.name,
        'dayLabel': dayLabel,
        'note': note,
      };
}
