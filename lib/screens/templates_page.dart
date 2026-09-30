import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/student.dart';
import '../models/callbacks.dart';
import '../services/firestore_service.dart';
import '../utils/app_colors.dart';
import '../widgets/page_shell.dart';
import 'template_form_screen.dart';
import 'student_detail_screen.dart';
import 'evaluation_form_screen.dart';

/// Hub de treinos OU de dietas (conforme [fixedType]): de um lado a
/// biblioteca de modelos daquele tipo, sem vínculo com nenhum aluno
/// específico, do outro um atalho para buscar um aluno e ir direto à
/// ficha dele, sem precisar passar pela lista completa de Alunos.
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({
    super.key,
    required this.fixedType,
    required this.templates,
    required this.onSaveTemplate,
    required this.onDeleteTemplate,
    required this.students,
    required this.service,
    required this.onUpdateStudent,
    required this.onAddEvaluation,
    required this.onAddPlan,
  });

  /// Treino ou dieta — cada seção da navegação abre esta página com um
  /// tipo fixo, sem seletor.
  final PlanType fixedType;

  final List<PlanTemplate> templates;
  final SaveTemplateCallback onSaveTemplate;
  final DeleteTemplateCallback onDeleteTemplate;

  final List<Student> students;
  final FirestoreService service;
  final UpdateStudentCallback onUpdateStudent;
  final AddEvaluationCallback onAddEvaluation;
  final AddPlanCallback onAddPlan;

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  String studentQuery = '';

  bool get _isTraining => widget.fixedType == PlanType.training;
  Color get _accent => _isTraining ? kTrainingAccent : kDietAccent;

  Future<void> _openNewTemplate(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateFormScreen(onSaveTemplate: widget.onSaveTemplate, fixedType: widget.fixedType),
      ),
    );
  }

  void _openStudent(Student s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(
          student: s,
          service: widget.service,
          onUpdateStudent: widget.onUpdateStudent,
          onAddEvaluation: widget.onAddEvaluation,
          onAddPlan: widget.onAddPlan,
          templates: widget.templates,
          onSaveTemplate: widget.onSaveTemplate,
        ),
      ),
    );
  }

  void _showDetails(PlanTemplate t) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.objectiveBase} · ${t.level}'),
                const Divider(height: 24),
                if (t.type == PlanType.training)
                  if (t.exercises.isEmpty)
                    const Text('Nenhum exercício cadastrado.')
                  else
                    ...t.exercises.map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• ${ex.name} — ${ex.sets}x${ex.reps}'),
                      ),
                    )
                else
                  Text(t.dietContent.isEmpty ? 'Nenhum conteúdo cadastrado.' : t.dietContent),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Excluir modelo?'),
                  content: Text('"${t.title}" vai sair da biblioteca. Planos já atribuídos a alunos não são afetados.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                  ],
                ),
              );
              if (confirmed == true) {
                await widget.onDeleteTemplate(t.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.templates.where((t) => t.type == widget.fixedType).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final matchingStudents = studentQuery.trim().isEmpty
        ? const <Student>[]
        : widget.students
            .where((s) => s.name.toLowerCase().contains(studentQuery.trim().toLowerCase()))
            .toList();
    return PageShell(
      title: _isTraining ? 'Treinos' : 'Dietas',
      subtitle: _isTraining
          ? 'Modelos de treino reutilizáveis e acesso rápido à ficha de um aluno.'
          : 'Modelos de dieta reutilizáveis e acesso rápido à ficha de um aluno.',
      action: FilledButton.icon(
        onPressed: () => _openNewTemplate(context),
        icon: const Icon(Icons.add),
        label: Text(_isTraining ? 'Novo modelo de treino' : 'Novo modelo de dieta'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar aluno para acessar a ficha dele',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => studentQuery = value),
          ),
          if (matchingStudents.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...matchingStudents.map(
              (s) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(s.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openStudent(s),
                ),
              ),
            ),
          ] else if (studentQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Nenhum aluno encontrado com esse nome.'),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(_isTraining ? Icons.fitness_center : Icons.restaurant_menu, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text('Biblioteca de modelos', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _isTraining
                          ? 'Nenhum modelo de treino ainda. Crie o primeiro.'
                          : 'Nenhum modelo de dieta ainda. Crie o primeiro.',
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      return Card(
                        child: ListTile(
                          leading: Icon(_isTraining ? Icons.fitness_center : Icons.restaurant, color: _accent),
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.objectiveBase} · ${t.level}'
                            '${_isTraining ? ' · ${t.exercises.length} exercício(s)' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showDetails(t),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
