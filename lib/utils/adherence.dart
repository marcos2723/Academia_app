import '../models/checkin.dart';
import '../models/plan.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Resumo do desempenho do aluno em um plano.
class Adherence {
  const Adherence({
    required this.done,
    required this.partial,
    required this.missed,
    required this.expected,
    required this.percent,
  });

  final int done;
  final int partial;
  final int missed;

  /// Dias previstos até hoje (null se a ficha não tem dias da semana
  /// definidos, então não dá para saber quantos treinos eram esperados).
  final int? expected;

  /// 0 a 100; null quando não dá para calcular.
  final double? percent;

  int get logged => done + partial + missed;
}

/// Treino previsto para uma data, segundo os dias da semana da ficha.
String? scheduledLabelFor(Plan plan, DateTime date) {
  for (final d in plan.days) {
    if (d.weekdays.contains(date.weekday)) return d.label;
  }
  return null;
}

Adherence computeAdherence(Plan plan, List<Checkin> all, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final mine = all.where((c) => c.planId == plan.id);
  final done = mine.where((c) => c.status == CheckinStatus.done).length;
  final partial = mine.where((c) => c.status == CheckinStatus.partial).length;
  final missed = mine.where((c) => c.status == CheckinStatus.missed).length;

  final start = dateOnly(plan.startDate);
  var end = dateOnly(plan.endDate);
  if (end.isAfter(today)) end = today;

  int? expected;
  if (end.isBefore(start)) {
    expected = 0;
  } else {
    final scheduled = plan.days.expand((d) => d.weekdays).toSet();
    if (plan.type == PlanType.training && scheduled.isEmpty) {
      expected = null;
    } else {
      var count = 0;
      for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
        if (plan.type == PlanType.diet || scheduled.contains(d.weekday)) count++;
      }
      expected = count;
    }
  }

  double? percent;
  if (expected != null && expected > 0) {
    percent = ((done + partial * 0.5) / expected * 100).clamp(0, 100).toDouble();
  }
  return Adherence(done: done, partial: partial, missed: missed, expected: expected, percent: percent);
}

/// "78%" ou "—" quando não dá para calcular.
String adherenceLabel(Plan plan, List<Checkin> all) {
  final p = computeAdherence(plan, all).percent;
  return p == null ? '—' : '${p.round()}%';
}
