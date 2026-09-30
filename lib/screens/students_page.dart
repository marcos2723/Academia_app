import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/plan_template.dart';
import '../models/callbacks.dart';
import '../services/firestore_service.dart';
import '../services/whatsapp_service.dart';
import '../services/app_exceptions.dart';
import '../utils/formatters.dart';
import '../utils/student_goals.dart';
import '../utils/input_formatters.dart';
import '../widgets/page_shell.dart';
import 'student_detail_screen.dart';
import 'evaluation_form_screen.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.students,
    required this.service,
    required this.onAddStudent,
    required this.onUpdateStudent,
    required this.onAddEvaluation,
    required this.onAddPlan,
    required this.templates,
    required this.onSaveTemplate,
  });

  final List<Student> students;
  final FirestoreService service;
  final AddStudentCallback onAddStudent;
  final UpdateStudentCallback onUpdateStudent;
  final AddEvaluationCallback onAddEvaluation;
  final AddPlanCallback onAddPlan;
  final List<PlanTemplate> templates;
  final SaveTemplateCallback onSaveTemplate;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final students = widget.students
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return PageShell(
      title: 'Alunos',
      subtitle: 'Cadastre, pesquise e atualize os dados de cada aluno.',
      action: FilledButton.icon(
        onPressed: () => _openStudentForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo aluno'),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar aluno pelo nome',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('Nenhum aluno cadastrado ainda.'))
                : ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final s = students[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(initials(s.name))),
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.goal} · ${s.weight.toStringAsFixed(1)} kg · ${s.height.toStringAsFixed(2)} m',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
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
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStudentForm(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final height = TextEditingController();
    final weight = TextEditingController();
    final observations = TextEditingController();
    String goal = studentGoals.first;
    String sex = 'M';
    DateTime? birthDate;
    bool saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo aluno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone (WhatsApp)',
                    hintText: 'DDD + número',
                  ),
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'Usado para o primeiro acesso do aluno ao app',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: sex,
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Masculino')),
                          DropdownMenuItem(value: 'F', child: Text('Feminino')),
                        ],
                        onChanged: (v) => setDialogState(() => sex = v ?? sex),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(DateTime.now().year - 25),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setDialogState(() => birthDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Nascimento'),
                          child: Text(birthDate == null ? 'Selecionar' : formatDate(birthDate!)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: height,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimalInputFormatters,
                        decoration: const InputDecoration(labelText: 'Altura (m)', hintText: 'Ex: 1.70'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimalInputFormatters,
                        decoration: const InputDecoration(labelText: 'Peso (kg)', hintText: 'Ex: 72.5'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: goal,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Objetivo'),
                  items: studentGoals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setDialogState(() => goal = v ?? goal),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: observations,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText: 'Restrições, lesões, preferências...',
                    alignLabelWithHint: true,
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final h = parseNumber(height.text);
                      final w = parseNumber(weight.text);
                      if (name.text.trim().isEmpty) {
                        setDialogState(() => errorText = 'Informe o nome do aluno.');
                        return;
                      }
                      if (phone.text.trim().isEmpty) {
                        setDialogState(() => errorText = 'Informe o telefone (WhatsApp) do aluno.');
                        return;
                      }
                      if (!email.text.contains('@') || !email.text.contains('.')) {
                        setDialogState(() => errorText = 'Informe um e-mail válido.');
                        return;
                      }
                      if (h == null || h <= 0) {
                        setDialogState(() => errorText = 'Informe uma altura válida.');
                        return;
                      }
                      if (w == null || w <= 0) {
                        setDialogState(() => errorText = 'Informe um peso válido.');
                        return;
                      }
                      if (birthDate == null) {
                        setDialogState(() => errorText = 'Selecione a data de nascimento.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final tempPassword = await widget.onAddStudent(
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                          email: email.text.trim(),
                          goal: goal,
                          height: h,
                          weight: w,
                          observations: observations.text.trim(),
                          sex: sex,
                          birthDate: birthDate!,
                        );
                        if (context.mounted) Navigator.pop(context);
                        final opened = await WhatsAppService.sendCredentials(
                          phone: phone.text.trim(),
                          studentName: name.text.trim(),
                          email: email.text.trim(),
                          temporaryPassword: tempPassword,
                        );
                        if (context.mounted && !opened) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não consegui abrir o WhatsApp automaticamente. '
                                'Anote a senha temporária e envie manualmente.',
                              ),
                            ),
                          );
                        }
                      } on AppException catch (e) {
                        setDialogState(() {
                          saving = false;
                          errorText = e.message;
                        });
                      } on FirebaseAuthException catch (e) {
                        final message = e.code == 'email-already-in-use'
                            ? 'Este e-mail já está em uso por outra conta.'
                            : 'Erro ao criar o acesso do aluno (${e.code}).';
                        setDialogState(() {
                          saving = false;
                          errorText = message;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
