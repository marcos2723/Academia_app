import 'package:flutter/material.dart';
import '../models/plan.dart';
import 'labeled_value.dart';

/// Mostra a ficha semanal (somente leitura): cada dia com seus exercícios,
/// séries, repetições, tipo de série, descanso e observações.
class TrainingDaysView extends StatelessWidget {
  const TrainingDaysView({super.key, required this.days});

  final List<TrainingDay> days;

  String _details(Exercise ex) {
    final parts = <String>[
      'Séries: ${ex.sets}',
      'Repetições: ${ex.reps.isEmpty ? '—' : ex.reps}',
      if (ex.setType != SetType.normal) 'Tipo de série: ${ex.setType.label}',
      if (ex.restSeconds != null) 'Descanso: ${ex.restSeconds} s',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('Nenhum exercício cadastrado.');
    final theme = Theme.of(context);
    final hasSchedule = days.any((d) => d.weekdays.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSchedule) ...[
          Text('Semana', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (var w = 1; w <= 7; w++)
            LabeledValue(
              label: weekdayLabel(w),
              value: days.where((d) => d.weekdays.contains(w)).map((d) => d.label).join(' + ').isEmpty
                  ? 'Descanso'
                  : days.where((d) => d.weekdays.contains(w)).map((d) => d.label).join(' + '),
            ),
          const Divider(height: 24),
        ],
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.weekdays.isEmpty ? day.label : '${day.label} · ${weekdaysSummary(day.weekdays)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < day.exercises.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${day.exercises[i].name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(_details(day.exercises[i]), style: theme.textTheme.bodyMedium),
                        if (day.exercises[i].notes.isNotEmpty)
                          LabeledValue(
                            label: 'Observações',
                            value: day.exercises[i].notes,
                            padding: const EdgeInsets.only(top: 2),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
