import '../models/checkin.dart';
import '../models/plan.dart';
import '../models/student.dart';
import 'adherence.dart';

/// Janela (em dias) usada para medir a adesão recente.
const int kAlertWindowDays = 14;

/// Abaixo disso (%) o aluno entra no alerta.
const double kLowAdherenceThreshold = 50;

/// Dias seguidos sem nenhum registro para entrar no alerta.
const int kSilentDaysThreshold = 7;

class AdherenceAlert {
  const AdherenceAlert({required this.student, this.percent, this.daysSilent});

  final Student student;

  /// Adesão (0-100) nos últimos [kAlertWindowDays] dias; null se não calculável.
  final double? percent;

  /// Dias desde o último registro (null = nunca registrou).
  final int? daysSilent;
}

/// Alunos ativos, com plano vigente, que registraram pouco ou pararam de
/// registrar. Os piores primeiro.
List<AdherenceAlert> computeAdherenceAlerts({
  required List<Student> students,
  required List<Plan> plans,
  required List<Checkin> checkins,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final windowStart = DateTime(today.year, today.month, today.day - (kAlertWindowDays - 1));
  final alerts = <AdherenceAlert>[];

  for (final s in students.where((s) => s.active)) {
    final active = plans.where((p) {
      if (p.studentId != s.id) return false;
      final start = dateOnly(p.startDate);
      final end = dateOnly(p.endDate);
      return !start.isAfter(today) && !end.isBefore(today);
    }).toList();
    if (active.isEmpty) continue;

    final mine = checkins.where((c) => c.studentId == s.id).toList();

    var expected = 0;
    var score = 0.0;
    DateTime? firstStart;
    for (final p in active) {
      final scheduled = p.days.expand((d) => d.weekdays).toSet();
      if (p.type == PlanType.training && scheduled.isEmpty) continue;
      var from = dateOnly(p.startDate);
      if (from.isBefore(windowStart)) from = windowStart;
      if (firstStart == null || dateOnly(p.startDate).isBefore(firstStart)) firstStart = dateOnly(p.startDate);
      // Hoje ainda não conta como falta: o aluno pode registrar até o fim do dia.
      final until = DateTime(today.year, today.month, today.day - 1);
      for (var d = from; !d.isAfter(until); d = DateTime(d.year, d.month, d.day + 1)) {
        if (p.type == PlanType.diet || scheduled.contains(d.weekday)) expected++;
      }
      for (final c in mine.where((c) => c.planId == p.id && !c.date.isBefore(from) && !c.date.isAfter(today))) {
        score += c.status == CheckinStatus.done ? 1 : (c.status == CheckinStatus.partial ? 0.5 : 0);
      }
    }

    double? percent;
    if (expected >= 3) percent = (score / expected * 100).clamp(0, 100).toDouble();

    DateTime? last;
    for (final c in mine) {
      if (last == null || c.date.isAfter(last)) last = c.date;
    }
    int? daysSilent;
    if (last != null) {
      daysSilent = today.difference(last).inDays;
    } else if (firstStart != null) {
      // Nunca registrou: só conta se o plano já começou há tempo suficiente.
      final sinceStart = today.difference(firstStart).inDays;
      if (sinceStart < kSilentDaysThreshold) continue;
    }

    final low = percent != null && percent < kLowAdherenceThreshold;
    final silent = last == null || (daysSilent != null && daysSilent >= kSilentDaysThreshold);
    if (low || silent) {
      alerts.add(AdherenceAlert(student: s, percent: percent, daysSilent: daysSilent));
    }
  }

  alerts.sort((a, b) {
    // Quem nunca registrou ou está mais tempo parado vem primeiro.
    int rank(AdherenceAlert x) => x.daysSilent == null ? 9999 : x.daysSilent!;
    final byDays = rank(b).compareTo(rank(a));
    if (byDays != 0) return byDays;
    return (a.percent ?? 100).compareTo(b.percent ?? 100);
  });
  return alerts;
}
