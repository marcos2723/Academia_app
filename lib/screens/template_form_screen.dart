import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../models/callbacks.dart';
import '../utils/input_formatters.dart';
import 'plan_form_screen.dart' show planObjectives, planLevels;

class _ExerciseRow {
  _ExerciseRow({String name = '', int sets = 3, int reps = 12})
      : nameController = TextEditingController(text: name),
        setsController = TextEditingController(text: sets.toString()),
        repsController = TextEditingController(text: reps.toString());

  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
}

/// Tela dedicada para a personal criar um modelo (template) de ficha de
/// treino ou dieta — não pertence a nenhum aluno. Depois, na hora de
/// atribuir um plano a um aluno específico, ela parte de um desses
/// modelos e ajusta as particularidades daquele aluno.
class TemplateFormScreen extends StatefulWidget {
  const TemplateFormScreen({super.key, required this.onSaveTemplate, this.fixedType});

  final SaveTemplateCallback onSaveTemplate;

  /// Quando informado (aberto a partir da aba Treinos ou da aba Dietas),
  /// o tipo já vem definido e o seletor some da tela.
  final PlanType? fixedType;

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  late PlanType type = widget.fixedType ?? PlanType.training;
  final title = TextEditingController();
  final dietContent = TextEditingController();
  final List<_ExerciseRow> exercises = [_ExerciseRow()];
  String objectiveBase = planObjectives.first;
  String level = planLevels.first;
  bool saving = false;
  String? errorText;

  void _addExerciseRow() => setState(() => exercises.add(_ExerciseRow()));

  void _removeExerciseRow(int index) => setState(() => exercises.removeAt(index));

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      setState(() => errorText = 'Dê um nome para o modelo.');
      return;
    }
    List<Exercise> exerciseList = const [];
    String diet = '';
    if (type == PlanType.training) {
      exerciseList = exercises
          .where((row) => row.nameController.text.trim().isNotEmpty)
          .map((row) => Exercise(
                name: row.nameController.text.trim(),
                sets: int.tryParse(row.setsController.text.trim()) ?? 0,
                reps: int.tryParse(row.repsController.text.trim()) ?? 0,
              ))
          .toList();
      if (exerciseList.isEmpty) {
        setState(() => errorText = 'Adicione ao menos um exercício.');
        return;
      }
    } else {
      diet = dietContent.text.trim();
      if (diet.isEmpty) {
        setState(() => errorText = 'Monte o conteúdo da dieta (refeições e horários).');
        return;
      }
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    await widget.onSaveTemplate(
      type: type,
      title: title.text.trim(),
      objectiveBase: objectiveBase,
      level: level,
      exercises: exerciseList,
      dietContent: diet,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fixedType == null
              ? 'Novo modelo'
              : (type == PlanType.training ? 'Novo modelo de treino' : 'Novo modelo de dieta'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              if (widget.fixedType == null) ...[
                SegmentedButton<PlanType>(
                  segments: const [
                    ButtonSegment(value: PlanType.training, label: Text('Treino'), icon: Icon(Icons.fitness_center)),
                    ButtonSegment(value: PlanType.diet, label: Text('Dieta'), icon: Icon(Icons.restaurant_menu)),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: type == PlanType.training ? 'Nome do modelo de treino' : 'Nome do modelo de dieta',
                  hintText: type == PlanType.training ? 'Ex: ABC Hipertrofia Intermediário' : 'Ex: Low Carb 2200kcal',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: objectiveBase,
                      decoration: const InputDecoration(labelText: 'Objetivo base'),
                      items: planObjectives.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (v) => setState(() => objectiveBase = v ?? objectiveBase),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: level,
                      decoration: const InputDecoration(labelText: 'Nível'),
                      items: planLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) => setState(() => level = v ?? level),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (type == PlanType.training) ...[
                Row(
                  children: [
                    Expanded(child: Text('Exercícios', style: Theme.of(context).textTheme.titleMedium)),
                    TextButton.icon(
                      onPressed: _addExerciseRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < exercises.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: exercises[i].nameController,
                              decoration: const InputDecoration(labelText: 'Exercício', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: exercises[i].setsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: integerInputFormatters,
                              decoration: const InputDecoration(labelText: 'Séries', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: exercises[i].repsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: integerInputFormatters,
                              decoration: const InputDecoration(labelText: 'Repetições', isDense: true),
                            ),
                          ),
                          IconButton(
                            onPressed: exercises.length > 1 ? () => _removeExerciseRow(i) : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else ...[
                Text(
                  'Monte a dieta livremente: refeições, horários e alimentos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dietContent,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    hintText: 'Ex:\n'
                        '07h00 - Café da manhã: 2 ovos, aveia, banana\n'
                        '10h00 - Lanche: iogurte natural + castanhas\n'
                        '13h00 - Almoço: arroz, feijão, frango grelhado, salada\n'
                        '...',
                  ),
                ),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar modelo'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
