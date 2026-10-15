import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/callbacks.dart';
import '../utils/formatters.dart';
import '../widgets/training_days_editor.dart';
import 'template_form_screen.dart';

const List<String> planObjectives = [
  'Hipertrofia',
  'Emagrecimento',
  'Definição',
  'Condicionamento físico',
  'Reabilitação',
  'Performance esportiva',
];

const List<String> planLevels = ['Iniciante', 'Intermediário', 'Avançado'];

/// Tela cheia para ATRIBUIR um plano a um aluno a partir de um modelo da
/// biblioteca — os planos agora nascem sempre de um template fixo; aqui
/// a personal só ajusta o que for particular deste aluno (exercícios,
/// vigência, vínculo com outro plano) antes de salvar.
class PlanFormScreen extends StatefulWidget {
  const PlanFormScreen({
    super.key,
    required this.students,
    required this.onAddPlan,
    required this.templates,
    required this.onSaveTemplate,
    this.initialStudentId,
    this.existingPlans = const [],
    this.fixedType,
    this.existing,
    this.onUpdatePlan,
  });

  final List<Student> students;
  final AddPlanCallback onAddPlan;
  final List<PlanTemplate> templates;
  final SaveTemplateCallback onSaveTemplate;
  final String? initialStudentId;

  /// Planos já existentes para o(s) aluno(s) em questão, usados para
  /// oferecer o vínculo treino <-> dieta.
  final List<Plan> existingPlans;

  /// Quando informado (ex: aberto a partir da aba Treinos ou da aba
  /// Dietas do aluno), o tipo já vem definido e o seletor de tipo some
  /// da tela — a pessoa não precisa escolher de novo algo que já
  /// escolheu ao abrir a aba certa.
  final PlanType? fixedType;

  /// Ficha já atribuída a editar (null para atribuir uma nova).
  final Plan? existing;
  final UpdatePlanCallback? onUpdatePlan;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  String? studentId;
  late PlanType type = widget.existing?.type ?? widget.fixedType ?? PlanType.training;
  bool get _editing => widget.existing != null;
  final title = TextEditingController();
  final dietContent = TextEditingController();
  final TrainingDaysController daysController = TrainingDaysController();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  String? linkedPlanId;
  bool saving = false;
  String? errorText;

  String? loadedTemplateId;

  @override
  void initState() {
    super.initState();
    studentId = widget.initialStudentId ?? (widget.students.isEmpty ? null : widget.students.first.id);
    final e = widget.existing;
    if (e != null) {
      studentId = e.studentId;
      title.text = e.title;
      startDate = e.startDate;
      endDate = e.endDate;
      linkedPlanId = e.linkedPlanId;
      loadedTemplateId = e.templateId;
      if (e.type == PlanType.training) {
        daysController.load(e.days);
      } else {
        dietContent.text = e.dietContent;
      }
    }
  }

  List<Plan> get _linkableOptions {
    final opposite = type == PlanType.training ? PlanType.diet : PlanType.training;
    return widget.existingPlans
        .where((p) => p.type == opposite && p.studentId == studentId && p.id != widget.existing?.id)
        .toList();
  }

  void _applyTemplate(PlanTemplate template) {
    setState(() {
      loadedTemplateId = template.id;
      title.text = template.title;
      if (template.type == PlanType.training) {
        daysController.load(template.days);
      } else {
        dietContent.text = template.dietContent;
      }
    });
  }

  Future<void> _createTemplateNow() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TemplateFormScreen(onSaveTemplate: widget.onSaveTemplate)),
    );
  }

  Future<void> _save() async {
    if (studentId == null) {
      setState(() => errorText = 'Selecione um aluno.');
      return;
    }
    if (!_editing && loadedTemplateId == null) {
      setState(() => errorText = 'Escolha um modelo para partir dele.');
      return;
    }
    if (title.text.trim().isEmpty) {
      setState(() => errorText = 'Dê um nome para a ficha.');
      return;
    }
    if (endDate.isBefore(startDate)) {
      setState(() => errorText = 'A data de término não pode ser antes do início.');
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

    if (_editing) {
      try {
        await widget.onUpdatePlan!(
          id: widget.existing!.id,
          title: title.text.trim(),
          startDate: startDate,
          endDate: endDate,
          days: dayList,
          dietContent: diet,
          linkedPlanId: linkedPlanId,
        );
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          setState(() {
            saving = false;
            errorText = 'Não consegui salvar as alterações.';
          });
        }
      }
      return;
    }

    final student = widget.students.firstWhere((s) => s.id == studentId);
    await widget.onAddPlan(
      studentId: studentId!,
      type: type,
      title: title.text.trim(),
      startDate: startDate,
      endDate: endDate,
      days: dayList,
      dietContent: diet,
      linkedPlanId: linkedPlanId,
      templateId: loadedTemplateId,
      objectiveSnapshot: student.goal,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: [DateTime.now().subtract(const Duration(days: 365)), startDate, endDate]
          .reduce((a, b) => a.isBefore(b) ? a : b),
      lastDate: [DateTime.now().add(const Duration(days: 730)), startDate, endDate]
          .reduce((a, b) => a.isAfter(b) ? a : b),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        startDate = picked;
      } else {
        endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final linkable = _linkableOptions;
    final options = widget.templates.where((t) => t.type == type).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? (type == PlanType.training ? 'Editar ficha de treino' : 'Editar dieta')
              : (type == PlanType.training ? 'Nova ficha de treino' : 'Nova dieta'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: studentId,
                decoration: const InputDecoration(labelText: 'Aluno', border: OutlineInputBorder()),
                items: widget.students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: widget.initialStudentId != null
                    ? null
                    : (v) => setState(() {
                          studentId = v;
                          linkedPlanId = null;
                        }),
              ),
              if (widget.fixedType == null && !_editing) ...[
                const SizedBox(height: 14),
                SegmentedButton<PlanType>(
                  segments: const [
                    ButtonSegment(value: PlanType.training, label: Text('Treino'), icon: Icon(Icons.fitness_center)),
                    ButtonSegment(value: PlanType.diet, label: Text('Dieta'), icon: Icon(Icons.restaurant_menu)),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() {
                    type = v.first;
                    linkedPlanId = null;
                    loadedTemplateId = null;
                    title.clear();
                    dietContent.clear();
                    daysController.clear();
                  }),
                ),
              ],
              if (!_editing) ...[
              const SizedBox(height: 18),
              Text('Modelo base', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              if (options.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type == PlanType.training
                              ? 'Nenhum modelo de treino cadastrado ainda.'
                              : 'Nenhum modelo de dieta cadastrado ainda.',
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _createTemplateNow,
                          icon: const Icon(Icons.add),
                          label: const Text('Criar modelo agora'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: loadedTemplateId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Escolher modelo', border: OutlineInputBorder()),
                  items: options
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.title} · ${t.objectiveBase} · ${t.level}'),
                          ))
                      .toList(),
                  onChanged: (id) {
                    final match = options.where((t) => t.id == id);
                    if (match.isNotEmpty) _applyTemplate(match.first);
                  },
                ),
              ],
              if (_editing || loadedTemplateId != null) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: type == PlanType.training ? 'Nome da ficha' : 'Nome da dieta',
                  ),
                ),
                const SizedBox(height: 18),
                Text('Vigência', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Início', border: OutlineInputBorder()),
                          child: Text(formatDate(startDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(isStart: false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Término', border: OutlineInputBorder()),
                          child: Text(formatDate(endDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (linkable.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String?>(
                    value: linkedPlanId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: type == PlanType.training
                          ? 'Vincular a uma dieta (opcional)'
                          : 'Vincular a uma ficha de treino (opcional)',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Nenhum')),
                      ...linkable.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.title))),
                    ],
                    onChanged: (v) => setState(() => linkedPlanId = v),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  type == PlanType.training ? 'Treinos' : 'Dieta',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (type == PlanType.training) ...[
                  TrainingDaysEditor(controller: daysController),
                ] else ...[
                  TextField(
                    controller: dietContent,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
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
                    : Text(_editing ? 'Salvar alterações' : 'Atribuir ao aluno'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
