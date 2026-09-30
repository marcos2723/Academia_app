import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/plan.dart';
import '../models/evaluation.dart';
import '../models/appointment.dart';
import '../services/whatsapp_service.dart';
import '../utils/formatters.dart';
import '../utils/app_colors.dart';
import '../widgets/page_shell.dart';
import '../widgets/metric_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.students,
    required this.plans,
    required this.evaluations,
    required this.appointments,
    required this.studentName,
  });

  final List<Student> students;
  final List<Plan> plans;
  final List<Evaluation> evaluations;
  final List<Appointment> appointments;
  final String Function(String id) studentName;

  Future<void> _inviteForEvaluation(BuildContext context, Student student, int? daysSince) async {
    final opened = await WhatsAppService.inviteForEvaluation(
      phone: student.phone,
      studentName: student.name,
      daysSinceLastEvaluation: daysSince,
    );
    if (context.mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não consegui abrir o WhatsApp para ${student.name}. Confira o telefone cadastrado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final evaluationsThisMonth = evaluations.where((e) => !e.date.isBefore(currentMonthStart)).length;
    final evaluationsLastMonth = evaluations
        .where((e) => !e.date.isBefore(lastMonthStart) && e.date.isBefore(currentMonthStart))
        .length;

    final newStudentsThisMonth =
        students.where((s) => s.createdAt != null && !s.createdAt!.isBefore(currentMonthStart)).length;
    final newStudentsLastMonth = students
        .where((s) => s.createdAt != null && !s.createdAt!.isBefore(lastMonthStart) && s.createdAt!.isBefore(currentMonthStart))
        .length;

    // Data da avaliação mais recente de cada aluno, pra sinalizar quem está
    // há mais tempo sem ser reavaliado (ou nunca foi avaliado).
    final lastEvaluationByStudent = <String, DateTime>{};
    for (final e in evaluations) {
      final current = lastEvaluationByStudent[e.studentId];
      if (current == null || e.date.isAfter(current)) lastEvaluationByStudent[e.studentId] = e.date;
    }
    final staleStudents = students.map((s) {
      final last = lastEvaluationByStudent[s.id];
      final daysSince = last == null ? null : now.difference(last).inDays;
      return (student: s, daysSince: daysSince);
    }).where((entry) => entry.daysSince == null || entry.daysSince! > 30).toList()
      ..sort((a, b) {
        if (a.daysSince == null && b.daysSince == null) return 0;
        if (a.daysSince == null) return -1;
        if (b.daysSince == null) return 1;
        return b.daysSince!.compareTo(a.daysSince!);
      });
    final staleTop5 = staleStudents.take(5).toList();

    final nextAppointments = appointments.where((a) => !a.dateTime.isBefore(now)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final next3 = nextAppointments.take(3).toList();

    return PageShell(
      title: 'Visão geral',
      subtitle: 'Acompanhamento físico e nutricional dos alunos.',
      child: ListView(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              MetricCard(label: 'Alunos ativos', value: '${students.length}', icon: Icons.people, color: kAlunosAccent),
              MetricCard(
                label: 'Avaliações neste mês',
                value: '$evaluationsThisMonth',
                icon: Icons.assignment_turned_in,
                color: kAvaliacoesAccent,
              ),
              MetricCard(
                label: 'Treinos vigentes',
                value: '${plans.where((p) => p.type == PlanType.training && p.isActive).length}',
                icon: Icons.fitness_center,
                color: kTrainingAccent,
              ),
              MetricCard(
                label: 'Dietas vigentes',
                value: '${plans.where((p) => p.type == PlanType.diet && p.isActive).length}',
                icon: Icons.restaurant_menu,
                color: kDietAccent,
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('Comparado ao mês passado', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  _ComparisonRow(
                    icon: Icons.assignment_turned_in,
                    color: kAvaliacoesAccent,
                    label: 'Avaliações realizadas',
                    current: evaluationsThisMonth,
                    previous: evaluationsLastMonth,
                  ),
                  const Divider(height: 1),
                  _ComparisonRow(
                    icon: Icons.person_add_alt,
                    color: kAlunosAccent,
                    label: 'Novos alunos',
                    current: newStudentsThisMonth,
                    previous: newStudentsLastMonth,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Alunos sem avaliação recente', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (staleTop5.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Todo mundo foi avaliado nos últimos 30 dias. 👍'),
              ),
            )
          else
            ...staleTop5.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined, color: Colors.amber),
                  title: Text(entry.student.name),
                  subtitle: Text(
                    entry.daysSince == null ? 'Nunca avaliado' : 'Última avaliação há ${entry.daysSince} dias',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined),
                    tooltip: 'Chamar para uma avaliação',
                    onPressed: () => _inviteForEvaluation(context, entry.student, entry.daysSince),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text('Próximas avaliações', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (next3.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Nenhuma avaliação agendada.'),
              ),
            )
          else
            ...next3.map(
              (a) => Card(
                child: ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(studentName(a.studentId)),
                  subtitle: Text(formatDateTime(a.dateTime)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uma linha do comparativo mês atual x mês passado: valor atual grande,
/// valor anterior menor ao lado, e uma seta/cor indicando se subiu, caiu
/// ou ficou igual.
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.current,
    required this.previous,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final IconData trendIcon;
    final Color trendColor;
    final String trendText;
    if (diff > 0) {
      trendIcon = Icons.trending_up;
      trendColor = Colors.greenAccent;
      trendText = '+$diff';
    } else if (diff < 0) {
      trendIcon = Icons.trending_down;
      trendColor = Colors.redAccent;
      trendText = '$diff';
    } else {
      trendIcon = Icons.trending_flat;
      trendColor = Theme.of(context).colorScheme.onSurfaceVariant;
      trendText = '0';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  'Mês passado: $previous',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Text('$current', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 10),
          Row(
            children: [
              Icon(trendIcon, color: trendColor, size: 20),
              const SizedBox(width: 2),
              Text(trendText, style: TextStyle(color: trendColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
