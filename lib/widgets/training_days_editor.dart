import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../utils/input_formatters.dart';

/// Rascunho (campos de texto) de um exercício enquanto a ficha é montada.
class ExerciseDraft {
  ExerciseDraft({
    String name = '',
    int sets = 3,
    String reps = '12',
    this.setType = SetType.normal,
    int? rest,
    String notes = '',
  })  : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets.toString()),
        repsController = TextEditingController(text: reps),
        restController = TextEditingController(text: rest?.toString() ?? ''),
        notesController = TextEditingController(text: notes);

  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController restController;
  final TextEditingController notesController;
  SetType setType;
}

/// Rascunho de um dia da ficha semanal.
class DayDraft {
  DayDraft({String label = '', Set<int>? weekdays, List<ExerciseDraft>? exercises})
      : labelController = TextEditingController(text: label),
        weekdays = weekdays ?? <int>{},
        exercises = exercises ?? [ExerciseDraft()];

  final TextEditingController labelController;
  final Set<int> weekdays;
  final List<ExerciseDraft> exercises;
}

/// Guarda o estado da ficha semanal em edição. A tela que usa o editor lê
/// o resultado com [build] na hora de salvar e carrega um modelo com [load].
class TrainingDaysController {
  TrainingDaysController({bool startWithOneDay = false}) {
    if (startWithOneDay) days.add(DayDraft(label: defaultLabel(0)));
  }

  final List<DayDraft> days = [];

  static String defaultLabel(int index) => 'Treino ${String.fromCharCode(65 + index % 26)}';

  void clear() => days.clear();

  void load(List<TrainingDay> source) {
    days.clear();
    if (source.isEmpty) {
      days.add(DayDraft(label: defaultLabel(0)));
      return;
    }
    for (final d in source) {
      days.add(
        DayDraft(
          label: d.label,
          weekdays: d.weekdays.toSet(),
          exercises: d.exercises.isEmpty
              ? [ExerciseDraft()]
              : d.exercises
                  .map((e) => ExerciseDraft(
                        name: e.name,
                        sets: e.sets,
                        reps: e.reps,
                        setType: e.setType,
                        rest: e.restSeconds,
                        notes: e.notes,
                      ))
                  .toList(),
        ),
      );
    }
  }

  /// Converte o rascunho em dias de treino, ignorando exercícios sem nome
  /// e dias sem nenhum exercício.
  List<TrainingDay> build() {
    final result = <TrainingDay>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final exercises = d.exercises
          .where((e) => e.nameController.text.trim().isNotEmpty)
          .map((e) => Exercise(
                name: e.nameController.text.trim(),
                sets: int.tryParse(e.setsController.text.trim()) ?? 0,
                reps: e.repsController.text.trim(),
                setType: e.setType,
                restSeconds: int.tryParse(e.restController.text.trim()),
                notes: e.notesController.text.trim(),
              ))
          .toList();
      if (exercises.isEmpty) continue;
      final label = d.labelController.text.trim();
      result.add(TrainingDay(
        label: label.isEmpty ? defaultLabel(i) : label,
        weekdays: (d.weekdays.toList()..sort()),
        exercises: exercises,
      ));
    }
    return result;
  }

  /// Se o mesmo dia da semana foi marcado em dois treinos, devolve uma
  /// mensagem de erro; senão, null.
  String? weekdayConflict() {
    final owner = <int, String>{};
    for (var i = 0; i < days.length; i++) {
      final label = days[i].labelController.text.trim().isEmpty
          ? defaultLabel(i)
          : days[i].labelController.text.trim();
      for (final w in days[i].weekdays) {
        if (owner.containsKey(w)) {
          return '${weekdayLabel(w)} está marcado em dois treinos (${owner[w]} e $label). '
              'Deixe cada dia da semana em um treino só.';
        }
        owner[w] = label;
      }
    }
    return null;
  }
}

/// Editor da ficha semanal: vários dias, cada um com seus exercícios, e
/// para cada exercício o tipo de série (drop set, bi-set, etc.).
class TrainingDaysEditor extends StatefulWidget {
  const TrainingDaysEditor({super.key, required this.controller});

  final TrainingDaysController controller;

  @override
  State<TrainingDaysEditor> createState() => _TrainingDaysEditorState();
}

class _TrainingDaysEditorState extends State<TrainingDaysEditor> {
  List<DayDraft> get _days => widget.controller.days;

  void _addDay() => setState(
        () => _days.add(DayDraft(label: TrainingDaysController.defaultLabel(_days.length))),
      );

  Widget _exerciseCard(DayDraft day, ExerciseDraft ex) {
    return Card(
      key: ObjectKey(ex),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ex.nameController,
                    decoration: const InputDecoration(labelText: 'Exercício', isDense: true),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover exercício',
                  onPressed: day.exercises.length > 1 ? () => setState(() => day.exercises.remove(ex)) : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ex.setsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: integerInputFormatters,
                    decoration: const InputDecoration(labelText: 'Séries', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ex.repsController,
                    decoration: const InputDecoration(
                      labelText: 'Repetições',
                      hintText: '12 ou 8-12',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ex.restController,
                    keyboardType: TextInputType.number,
                    inputFormatters: integerInputFormatters,
                    decoration: const InputDecoration(labelText: 'Descanso (s)', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<SetType>(
              value: ex.setType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de série', isDense: true),
              items: SetType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => ex.setType = v ?? ex.setType),
            ),
            if (ex.setType.hint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ex.setType.hint, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: ex.notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Ex.: 3 quedas de 20% da carga',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(DayDraft day, int index) {
    return Card(
      key: ObjectKey(day),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: day.labelController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do treino',
                      hintText: 'Ex.: Treino A - Peito e tríceps',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover treino',
                  onPressed: _days.length > 1 ? () => setState(() => _days.remove(day)) : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Dias da semana', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var w = 1; w <= 7; w++)
                  FilterChip(
                    label: Text(weekdayShortLabel(w)),
                    selected: day.weekdays.contains(w),
                    onSelected: (on) => setState(() {
                      if (on) {
                        day.weekdays.add(w);
                      } else {
                        day.weekdays.remove(w);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final ex in day.exercises) _exerciseCard(day, ex),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => day.exercises.add(ExerciseDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar exercício'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _days.length; i++) _dayCard(_days[i], i),
        OutlinedButton.icon(
          onPressed: _addDay,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar treino (A, B, C...)'),
        ),
      ],
    );
  }
}
