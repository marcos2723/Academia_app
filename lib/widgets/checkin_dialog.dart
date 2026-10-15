import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../models/plan.dart';
import '../utils/adherence.dart';
import '../utils/formatters.dart';

/// Um dia a ser registrado, com o treino feito (só para treinos).
typedef CheckinEntry = ({DateTime date, String? dayLabel});

/// Resultado do diálogo de registro: o status e os dias marcados.
class CheckinDraft {
  CheckinDraft({required this.status, required this.entries, this.note});

  final CheckinStatus status;
  final List<CheckinEntry> entries;

  /// Observação (só nas dietas).
  final String? note;
}

/// Pergunta ao aluno como foi o treino ou a dieta de um dia, ou de vários
/// dias seguidos. Devolve null se ele cancelar.
Future<CheckinDraft?> showCheckinDialog(
  BuildContext context, {
  required Plan plan,
  required List<Checkin> existing,
  DateTime? date,
}) {
  final today = dateOnly(DateTime.now());
  final isTraining = plan.type == PlanType.training;
  final labels = plan.days.map((d) => d.label).toSet().toList();
  final scheduled = plan.days.expand((d) => d.weekdays).toSet();
  final noteController = TextEditingController();

  var earliest = dateOnly(plan.startDate);
  final limit = DateTime(today.year, today.month, today.day - 30);
  if (earliest.isBefore(limit)) earliest = limit;
  if (earliest.isAfter(today)) earliest = today;

  var selected = date ?? today;
  var multi = false;
  var endDate = selected;
  var status = CheckinStatus.done;
  String? dayLabel;

  DateTime lastAllowed() {
    final cap = DateTime(selected.year, selected.month, selected.day + 30);
    return cap.isAfter(today) ? today : cap;
  }

  void fill(DateTime d) {
    final key = Checkin.dateKeyOf(d);
    final found = existing.where((c) => c.planId == plan.id && c.dateKey == key);
    if (found.isNotEmpty) {
      status = found.first.status;
      dayLabel = found.first.dayLabel;
      noteController.text = found.first.note ?? '';
    } else {
      status = CheckinStatus.done;
      dayLabel = scheduledLabelFor(plan, d);
      noteController.text = '';
    }
    if (labels.isEmpty) {
      dayLabel = null;
    } else if (dayLabel == null || !labels.contains(dayLabel)) {
      dayLabel = labels.first;
    }
  }

  /// Dias que serão gravados. No treino com dias da semana definidos, um
  /// intervalo só marca os dias previstos (cada um com o seu treino).
  List<CheckinEntry> buildEntries() {
    final last = multi ? endDate : selected;
    final auto = isTraining && multi && scheduled.isNotEmpty;
    final result = <CheckinEntry>[];
    for (var d = selected; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      if (auto && !scheduled.contains(d.weekday)) continue;
      String? label;
      if (isTraining && status != CheckinStatus.missed) {
        label = auto ? scheduledLabelFor(plan, d) : dayLabel;
      }
      result.add((date: d, dayLabel: label));
    }
    return result;
  }

  fill(selected);

  return showDialog<CheckinDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) {
        final entries = buildEntries();
        final autoLabels = isTraining && multi && scheduled.isNotEmpty;
        return AlertDialog(
          title: Text(isTraining ? 'Registrar treino' : 'Registrar dieta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selected.isBefore(earliest) ? earliest : selected,
                      firstDate: earliest,
                      lastDate: today,
                    );
                    if (picked != null) {
                      setLocal(() {
                        selected = dateOnly(picked);
                        if (endDate.isBefore(selected)) endDate = selected;
                        if (endDate.isAfter(lastAllowed())) endDate = lastAllowed();
                        fill(selected);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: multi ? 'De' : 'Data',
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(formatDate(selected)),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vários dias seguidos'),
                  value: multi,
                  onChanged: (v) => setLocal(() {
                    multi = v;
                    if (endDate.isBefore(selected)) endDate = selected;
                  }),
                ),
                if (multi) ...[
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: selected,
                        lastDate: lastAllowed(),
                      );
                      if (picked != null) setLocal(() => endDate = dateOnly(picked));
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Até', border: OutlineInputBorder()),
                      child: Text(formatDate(endDate)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entries.isEmpty
                        ? 'Nenhum dia previsto no período.'
                        : 'Serão registrados: ${entries.length} ${entries.length == 1 ? 'dia' : 'dias'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in CheckinStatus.values)
                      ChoiceChip(
                        label: Text(s.actionLabel(plan.type)),
                        selected: status == s,
                        onSelected: (_) => setLocal(() => status = s),
                      ),
                  ],
                ),
                if (!isTraining) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Observação',
                      hintText: 'Ex.: pizza no jantar, aniversário',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                if (isTraining && labels.isNotEmpty && status != CheckinStatus.missed && !autoLabels) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: dayLabel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Treino', border: OutlineInputBorder()),
                    items: labels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setLocal(() => dayLabel = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: entries.isEmpty
                  ? null
                  : () {
                      final note = noteController.text.trim();
                      Navigator.pop(
                        context,
                        CheckinDraft(
                          status: status,
                          entries: entries,
                          note: (!isTraining && note.isNotEmpty) ? note : null,
                        ),
                      );
                    },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    ),
  );
}
