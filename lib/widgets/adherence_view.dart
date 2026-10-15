import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../models/plan.dart';
import '../utils/adherence.dart';
import '../utils/formatters.dart';
import 'adherence_calendar.dart';
import 'labeled_value.dart';

/// Desempenho do aluno em um plano: adesão, contagem de registros e os
/// últimos dias registrados.
class AdherenceView extends StatelessWidget {
  const AdherenceView({super.key, required this.plan, required this.checkins, this.showCalendar = false, this.onRegisterDay});

  final Plan plan;
  final List<Checkin> checkins;

  /// Mostra o calendário colorido no lugar da lista dos últimos registros
  /// (usado na visão da personal).
  final bool showCalendar;

  /// Repassado ao calendário: tocar num dia registra (visão do aluno).
  final void Function(DateTime date)? onRegisterDay;

  @override
  Widget build(BuildContext context) {
    final stats = computeAdherence(plan, checkins);
    final recent = checkins.where((c) => c.planId == plan.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final percent = stats.percent;
    final isTraining = plan.type == PlanType.training;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Desempenho', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        LabeledValue(label: 'Adesão', value: percent == null ? '—' : '${percent.round()}%'),
        if (percent != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(value: percent / 100, minHeight: 6),
          ),
        LabeledValue(
          label: 'Registros',
          value: '${stats.done} ${isTraining ? 'treinos' : 'dias seguidos'} · '
              '${stats.partial} parciais · ${stats.missed} não feitos',
        ),
        if (stats.expected != null) LabeledValue(label: 'Previstos até hoje', value: '${stats.expected}'),
        if (showCalendar) ...[
          const SizedBox(height: 12),
          AdherenceCalendar(plan: plan, checkins: checkins, onRegisterDay: onRegisterDay),
        ] else if (recent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Últimos registros', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          for (final c in recent.take(7))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatDate(c.date)} · ${c.status.resultLabel(plan.type)}'
                    '${c.dayLabel == null ? '' : ' · ${c.dayLabel}'}',
                  ),
                  if (c.note != null && c.note!.isNotEmpty)
                    LabeledValue(
                      label: 'Observação',
                      value: c.note!,
                      padding: const EdgeInsets.only(top: 1),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
