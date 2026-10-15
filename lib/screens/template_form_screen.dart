import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/callbacks.dart';
import '../widgets/training_days_editor.dart';
import 'plan_form_screen.dart' show planObjectives, planLevels;

/// Tela dedicada para a personal criar um modelo (template) de ficha de
/// treino ou dieta — não pertence a nenhum aluno. Depois, na hora de
/// atribuir um plano a um aluno específico, ela parte de um desses
/// modelos e ajusta as particularidades daquele aluno.
class TemplateFormScreen extends StatefulWidget {
  const TemplateFormScreen({super.key, required this.onSaveTemplate, this.fixedType, this.existing});

  final SaveTemplateCallback onSaveTemplate;

  /// Quando informado (aberto a partir da aba Treinos ou da aba Dietas),
  /// o tipo já vem definido e o seletor some da tela.
  final PlanType? fixedType;

  /// Modelo a editar (null para criar um novo).
  final PlanTemplate? existing;

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  late PlanType type = widget.existing?.type ?? widget.fixedType ?? PlanType.training;
  final title = TextEditingController();
  final dietContent = TextEditingController();
  final TrainingDaysController daysController = TrainingDaysController(startWithOneDay: true);
  String objectiveBase = planObjectives.first;
  String level = planLevels.first;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      title.text = e.title;
      dietContent.text = e.dietContent;
      if (planObjectives.contains(e.objectiveBase)) objectiveBase = e.objectiveBase;
      if (planLevels.contains(e.level)) level = e.level;
      if (e.type == PlanType.training) daysController.load(e.days);
    }
  }

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      setState(() => errorText = 'Dê um nome para o modelo.');
      return;
    }
    List<TrainingDay> dayList = const [];
    String diet = '';
    if (type == PlanType.training) {
      final conflict = daysController.weekdayConflict();
      if (conflict != null) {
        setState(() => errorText = conflict);
        return;
      }
      dayList = daysController.build();
      if (dayList.isEmpty) {
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
      id: widget.existing?.id,
      type: type,
      title: title.text.trim(),
      objectiveBase: objectiveBase,
      level: level,
      days: dayList,
      dietContent: diet,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? (type == PlanType.training ? 'Editar modelo de treino' : 'Editar modelo de dieta')
              : widget.fixedType == null
                  ? 'Novo modelo'
                  : (type == PlanType.training ? 'Novo modelo de treino' : 'Novo modelo de dieta'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              if (widget.fixedType == null && widget.existing == null) ...[
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
                Text('Treinos', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TrainingDaysEditor(controller: daysController),
              ] else ...[
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
                    : Text(widget.existing == null ? 'Salvar modelo' : 'Salvar alterações'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
