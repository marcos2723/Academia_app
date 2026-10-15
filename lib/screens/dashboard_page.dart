import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/evaluation.dart';
import '../models/appointment.dart';
import '../models/checkin.dart';
import '../utils/adherence_alert.dart';
import '../services/whatsapp_service.dart';
import '../utils/formatters.dart';
import '../widgets/page_shell.dart';
import '../widgets/metric_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.students,
    required this.plans,
    required this.templates,
    required this.evaluations,
    required this.checkins,
    required this.appointments,
    required this.studentName,
  });

  final List<Student> students;
  final List<Plan> plans;
  final List<PlanTemplate> templates;
  final List<Evaluation> evaluations;
  final List<Checkin> checkins;
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

  Future<void> _encourage(BuildContext context, AdherenceAlert a) async {
    final opened = await WhatsAppService.encourageRegistration(
      phone: a.student.phone,
      studentName: a.student.name,
      percent: a.percent,
      daysSilent: a.daysSilent,
    );
    if (context.mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não consegui abrir o WhatsApp para ${a.student.name}. Confira o telefone cadastrado.')),
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
    final staleStudents = students.where((s) => s.active).map((s) {
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

    final adherenceAlerts = computeAdherenceAlerts(students: students, plans: plans, checkins: checkins);
    final alertsTop5 = adherenceAlerts.take(5).toList();

    final nextAppointments = appointments.where((a) => !a.dateTime.isBefore(now)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final next3 = nextAppointments.take(3).toList();

    return PageShell(
      title: 'Visão geral',
      subtitle: 'Visão geral dos alunos.',
      child: ListView(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              MetricCard(label: 'Alunos ativos', value: '${students.where((s) => s.active).length}', icon: Icons.people),
              MetricCard(
                label: 'Avaliações neste mês',
                value: '$evaluationsThisMonth',
                icon: Icons.assignment_turned_in,
              ),
              MetricCard(
                label: 'Treinos disponíveis',
                value: '${templates.where((t) => t.type == PlanType.training).length}',
                icon: Icons.fitness_center,
              ),
              MetricCard(
                label: 'Dietas disponíveis',
                value: '${templates.where((t) => t.type == PlanType.diet).length}',
                icon: Icons.restaurant_menu,
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
                    color: Theme.of(context).colorScheme.primary,
                    label: 'Avaliações realizadas',
                    current: evaluationsThisMonth,
                    previous: evaluationsLastMonth,
                  ),
                  const Divider(height: 1),
                  _ComparisonRow(
                    icon: Icons.person_add_alt,
                    color: Theme.of(context).colorScheme.primary,
                    label: 'Novos alunos',
                    current: newStudentsThisMonth,
                    previous: newStudentsLastMonth,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Alunos com baixa adesão', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (alertsTop5.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Todos estão registrando em dia. 👍'),
              ),
            )
          else
            ...alertsTop5.map(
              (a) => Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_down, color: Color(0xFFEF4444)),
                  title: Text('Aluno: ${a.student.name}'),
                  subtitle: Text([
                    a.daysSilent == null ? 'Nunca registrou' : (a.daysSilent! >= kSilentDaysThreshold ? 'Sem registro há ${a.daysSilent} dias' : null),
                    if (a.percent != null) 'Adesão: ${a.percent!.round()}% (${kAlertWindowDays} dias)',
                  ].whereType<String>().join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_outlined),
                    tooltip: 'Chamar no WhatsApp',
                    onPressed: () => _encourage(context, a),
                  ),
                ),
              ),
            ),
          if (adherenceAlerts.length > alertsTop5.length)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text('+ ${adherenceAlerts.length - alertsTop5.length} outros alunos',
                  style: Theme.of(context).textTheme.bodySmall),
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
                  leading: const Icon(Icons.warning_amber_outlined, color: Color(0xFFF59E0B)),
                  title: Text('Aluno: ${entry.student.name}'),
                  subtitle: Text(
                    entry.daysSince == null ? 'Última avaliação: nunca avaliado' : 'Última avaliação: há ${entry.daysSince} dias',
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
                  title: Text('Aluno: ${studentName(a.studentId)}'),
                  subtitle: Text('Data: ${formatDateTime(a.dateTime)}'),
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
      trendColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      trendText = '+$diff';
    } else if (diff < 0) {
      trendIcon = Icons.trending_down;
      trendColor = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
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
