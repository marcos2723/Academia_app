import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/student.dart';
import '../models/evaluation.dart';
import '../models/plan.dart';
import '../models/plan_template.dart';
import '../models/callbacks.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import '../utils/student_goals.dart';
import '../utils/input_formatters.dart';
import '../utils/evaluation_metrics.dart';
import '../utils/app_colors.dart';
import '../utils/diet_pdf.dart';
import '../utils/evolution_pdf.dart';
import '../widgets/weight_chart.dart';
import 'evaluation_form_screen.dart';
import 'plan_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.service,
    required this.onUpdateStudent,
    required this.onAddEvaluation,
    required this.onAddPlan,
    required this.templates,
    required this.onSaveTemplate,
  });

  final Student student;
  final FirestoreService service;
  final UpdateStudentCallback onUpdateStudent;
  final AddEvaluationCallback onAddEvaluation;
  final AddPlanCallback onAddPlan;
  final List<PlanTemplate> templates;
  final SaveTemplateCallback onSaveTemplate;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final name = TextEditingController(text: widget.student.name);
  late final phone = TextEditingController(text: widget.student.phone);
  late final email = TextEditingController(text: widget.student.email);
  late final height = TextEditingController(text: widget.student.height.toStringAsFixed(2));
  late final weight = TextEditingController(text: widget.student.weight.toStringAsFixed(1));
  late final observations = TextEditingController(text: widget.student.observations);
  late String goal = studentGoals.contains(widget.student.goal) ? widget.student.goal : studentGoals.first;
  late String sex = widget.student.sex;
  late DateTime birthDate = widget.student.birthDate;
  int categoryIndex = 0;

  // Streams dedicados a ESTE aluno, criados uma única vez quando a tela
  // abre. Antes, as abas de Avaliações e Planos reaproveitavam os streams
  // globais já em uso pela tela Painel — como um stream Firestore só
  // entrega o "estado atual" para quem já está ouvindo desde o início,
  // essa segunda inscrição tardia ficava sem os dados já existentes,
  // só recebendo o que mudasse dali em diante (por isso só aparecia algo
  // depois de lançar um novo registro, e sumia de novo ao reabrir a tela).
  late final Stream<List<Evaluation>> _evaluationsStream =
      widget.service.watchEvaluationsForStudent(widget.student.id);
  late final Stream<List<Plan>> _plansStream = widget.service.watchPlansForStudent(widget.student.id);

  bool saving = false;
  String? errorText;
  String? successText;

  Future<void> _save() async {
    final h = parseNumber(height.text);
    final w = parseNumber(weight.text);
    if (name.text.trim().isEmpty) {
      setState(() => errorText = 'Informe o nome do aluno.');
      return;
    }
    if (h == null || h <= 0 || w == null || w <= 0) {
      setState(() => errorText = 'Informe altura e peso válidos.');
      return;
    }
    setState(() {
      saving = true;
      errorText = null;
      successText = null;
    });
    await widget.onUpdateStudent(
      widget.student.id,
      name: name.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim().toLowerCase(),
      goal: goal,
      height: h,
      weight: w,
      observations: observations.text.trim(),
      sex: sex,
      birthDate: birthDate,
    );
    if (!mounted) return;
    setState(() {
      saving = false;
      successText = 'Dados atualizados.';
    });
  }

  Future<void> _openNewEvaluation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluationFormScreen(
          student: widget.student,
          onAddEvaluation: widget.onAddEvaluation,
        ),
      ),
    );
  }

  Future<void> _openNewPlan(PlanType fixedType, List<Plan> existingPlans) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanFormScreen(
          students: [widget.student],
          onAddPlan: widget.onAddPlan,
          initialStudentId: widget.student.id,
          existingPlans: existingPlans,
          templates: widget.templates,
          onSaveTemplate: widget.onSaveTemplate,
          fixedType: fixedType,
        ),
      ),
    );
  }

  Future<void> _downloadEvolutionPdf(List<Evaluation> records) async {
    if (records.isEmpty) return;
    final bytes = await buildEvolutionSummaryPdf(
      studentName: widget.student.name,
      objective: widget.student.goal,
      records: records,
    );
    final ok = await Printing.sharePdf(bytes: bytes, filename: 'evolucao_${widget.student.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf')
        .catchError((_) => false);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
      );
    }
  }

  Future<void> _downloadDietPdf(Plan p) async {
    final bytes = await buildDietPdf(
      studentName: widget.student.name,
      planTitle: p.title,
      validity: '${formatDate(p.startDate)} a ${formatDate(p.endDate)}',
      objective: widget.student.goal,
      dietContent: p.dietContent,
    );
    final safeName = p.title.trim().isEmpty
        ? 'dieta'
        : p.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ok = await Printing.sharePdf(bytes: bytes, filename: 'dieta_$safeName.pdf')
        .catchError((_) => false);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
      );
    }
  }

  void _showPlanDetails(Plan p, List<Plan> allPlansForStudent) {
    String? linkedTitle;
    if (p.linkedPlanId != null) {
      final match = allPlansForStudent.where((other) => other.id == p.linkedPlanId);
      linkedTitle = match.isEmpty ? null : match.first.title;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vigência: ${formatDate(p.startDate)} até ${formatDate(p.endDate)}'
                    '${p.isActive ? ' (em andamento)' : ''}'),
                if (linkedTitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p.type == PlanType.training
                          ? 'Integrado à dieta: $linkedTitle'
                          : 'Integrado à ficha de treino: $linkedTitle',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                const Divider(height: 24),
                if (p.type == PlanType.training)
                  if (p.exercises.isEmpty)
                    const Text('Nenhum exercício cadastrado.')
                  else
                    ...p.exercises.map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('• ${ex.name} — ${ex.sets}x${ex.reps}'),
                      ),
                    )
                else
                  Text(p.dietContent.isEmpty ? 'Nenhum conteúdo cadastrado.' : p.dietContent),
              ],
            ),
          ),
        ),
        actions: [
          if (p.type == PlanType.diet)
            TextButton.icon(
              onPressed: () => _downloadDietPdf(p),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Baixar PDF'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showEvaluationDetails(Evaluation e) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Avaliação de ${formatDate(e.date)}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IMC: ${e.bmi.toStringAsFixed(1)} · % Gordura: ${e.bodyFat.toStringAsFixed(1)}% · '
                    '% Magra: ${e.leanMassPercent.toStringAsFixed(1)}%'),
                const Divider(height: 24),
                Text('Circunferências (cm)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text('Pescoço: ${e.neck.toStringAsFixed(1)} · Ombros: ${e.shoulders.toStringAsFixed(1)}'),
                Text('Tórax: ${e.chest.toStringAsFixed(1)} · Cintura: ${e.waist.toStringAsFixed(1)}'),
                Text('Quadril: ${e.hip.toStringAsFixed(1)}'),
                Text('Bíceps D/E: ${e.armRight.toStringAsFixed(1)} / ${e.armLeft.toStringAsFixed(1)}'),
                Text('Antebraço D/E: ${e.forearmRight.toStringAsFixed(1)} / ${e.forearmLeft.toStringAsFixed(1)}'),
                Text('Coxa D/E: ${e.thighRight.toStringAsFixed(1)} / ${e.thighLeft.toStringAsFixed(1)}'),
                Text('Panturrilha D/E: ${e.calfRight.toStringAsFixed(1)} / ${e.calfLeft.toStringAsFixed(1)}'),
                const Divider(height: 24),
                Text('Dobras cutâneas — mm (soma: ${e.skinfoldSum.toStringAsFixed(1)})',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text('Peitoral: ${e.skinfoldChest.toStringAsFixed(1)} · Abdominal: ${e.skinfoldAbdominal.toStringAsFixed(1)}'),
                Text('Coxa: ${e.skinfoldThigh.toStringAsFixed(1)} · Tríceps: ${e.skinfoldTriceps.toStringAsFixed(1)}'),
                Text('Subescapular: ${e.skinfoldSubscapular.toStringAsFixed(1)} · Supra-ilíaca: ${e.skinfoldSuprailiac.toStringAsFixed(1)}'),
                Text('Axilar média: ${e.skinfoldMidaxillary.toStringAsFixed(1)}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _buildDadosTab() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome completo')),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone (WhatsApp)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail (login do aluno)'),
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
                    onChanged: (v) => setState(() => sex = v ?? sex),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: birthDate,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => birthDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Nascimento'),
                      child: Text(formatDate(birthDate)),
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
                    decoration: const InputDecoration(labelText: 'Altura (m)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalInputFormatters,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
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
              onChanged: (v) => setState(() => goal = v ?? goal),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: observations,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações', alignLabelWithHint: true),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (successText != null) ...[
              const SizedBox(height: 10),
              Text(successText!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Salvar alterações'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolucaoTab() {
    return StreamBuilder<List<Evaluation>>(
      stream: _evaluationsStream,
      initialData: const [],
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <Evaluation>[]).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final latest = records.isEmpty ? null : records.last;
        final category = evaluationMetricCategories[categoryIndex];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (records.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _downloadEvolutionPdf(records),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Relatório em PDF'),
                      ),
                    FilledButton.icon(
                      onPressed: _openNewEvaluation,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova avaliação'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (latest != null)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ResultChip(label: 'IMC', value: latest.bmi.toStringAsFixed(1)),
                      _ResultChip(label: '% Gordura', value: '${latest.bodyFat.toStringAsFixed(1)}%'),
                      _ResultChip(label: '% Massa magra', value: '${latest.leanMassPercent.toStringAsFixed(1)}%'),
                      _ResultChip(label: 'Massa magra', value: '${latest.leanMassKg.toStringAsFixed(1)} kg'),
                    ],
                  ),
                const SizedBox(height: 20),
                if (records.length >= 2) ...[
                  Text('Gráficos por grupo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(evaluationMetricCategories.length, (i) {
                      final c = evaluationMetricCategories[i];
                      return ChoiceChip(
                        label: Text(c.label),
                        avatar: Icon(c.icon, size: 18),
                        selected: categoryIndex == i,
                        onSelected: (_) => setState(() => categoryIndex = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  ...category.metrics.map((metric) {
                    final values = records.map(metric.extract).toList();
                    final dates = records.map((e) => e.date).toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${metric.label}${metric.unit.isEmpty ? '' : ' (${metric.unit})'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 200,
                                child: EvolutionChart(values: values, dates: dates),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ] else if (records.length == 1)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Lance mais uma avaliação para ver os gráficos de evolução.'),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Histórico de avaliações', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (records.isEmpty)
                  const Card(
                    child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma avaliação registrada ainda.')),
                  )
                else
                  ...records.reversed.map(
                    (e) => Card(
                      child: ListTile(
                        title: Text(formatDate(e.date)),
                        subtitle: Text(
                          '${e.weight.toStringAsFixed(1)} kg · IMC ${e.bmi.toStringAsFixed(1)} · '
                          '${e.bodyFat.toStringAsFixed(1)}% gordura · ${e.leanMassPercent.toStringAsFixed(1)}% magra',
                        ),
                        trailing: TextButton(
                          onPressed: () => _showEvaluationDetails(e),
                          child: const Text('Detalhes'),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreinosTab(List<Plan> allPlans) => _buildPlansOfType(PlanType.training, allPlans);

  Widget _buildDietasTab(List<Plan> allPlans) => _buildPlansOfType(PlanType.diet, allPlans);

  Widget _buildPlansOfType(PlanType planType, List<Plan> myPlans) {
    final isTraining = planType == PlanType.training;
    final filteredPlans = myPlans.where((p) => p.type == planType).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openNewPlan(planType, myPlans),
                icon: const Icon(Icons.add),
                label: Text(isTraining ? 'Nova ficha de treino' : 'Nova dieta'),
              ),
            ),
            const SizedBox(height: 16),
            if (filteredPlans.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    isTraining ? 'Nenhuma ficha de treino cadastrada.' : 'Nenhuma dieta cadastrada.',
                  ),
                ),
              )
            else
              ...filteredPlans.map(
                (p) => Card(
                  child: ListTile(
                    leading: Icon(isTraining ? Icons.fitness_center : Icons.restaurant, color: isTraining ? kTrainingAccent : kDietAccent),
                    title: Text(p.title),
                    subtitle: Text(isTraining ? '${p.exercises.length} exercício(s)' : 'Dieta'),
                    trailing: Text(
                      '${formatDate(p.startDate)} - ${formatDate(p.endDate)}',
                      style: p.isActive
                          ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)
                          : null,
                    ),
                    onTap: () => _showPlanDetails(p, myPlans),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.student.name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dados', icon: Icon(Icons.badge_outlined, color: kAlunosAccent)),
              Tab(text: 'Avaliações', icon: Icon(Icons.monitor_weight_outlined, color: kAvaliacoesAccent)),
              Tab(text: 'Treinos', icon: Icon(Icons.fitness_center, color: kTrainingAccent)),
              Tab(text: 'Dietas', icon: Icon(Icons.restaurant_menu, color: kDietAccent)),
            ],
          ),
        ),
        // Um único StreamBuilder para os planos (treinos + dietas), aqui
        // fora, e a lista já resolvida repassada para as duas abas. Cada
        // aba tinha seu próprio StreamBuilder ouvindo o MESMO stream —
        // como um stream do Firestore só reenvia o estado atual para
        // quem já estava ouvindo desde o início, a segunda aba a "ligar"
        // (nesse caso, Treinos) ficava sem os dados já existentes.
        body: StreamBuilder<List<Plan>>(
          stream: _plansStream,
          initialData: const [],
          builder: (context, planSnapshot) {
            final allPlans = planSnapshot.data ?? const <Plan>[];
            return TabBarView(
              children: [
                _buildDadosTab(),
                _buildEvolucaoTab(),
                _buildTreinosTab(allPlans),
                _buildDietasTab(allPlans),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
