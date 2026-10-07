import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/plan.dart';
import '../../models/student.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/app_colors.dart';
import '../../utils/diet_pdf.dart';
import '../../utils/training_pdf.dart';
import '../../widgets/page_shell.dart';

class AlunoPlansPage extends StatefulWidget {
  const AlunoPlansPage({super.key, required this.service, required this.student, required this.fixedType});

  final FirestoreService service;
  final Student student;

  /// Treino ou dieta — cada aba da navegação do aluno abre esta página
  /// com um tipo fixo.
  final PlanType fixedType;

  @override
  State<AlunoPlansPage> createState() => _AlunoPlansPageState();
}

class _AlunoPlansPageState extends State<AlunoPlansPage> {
  late final Stream<List<Plan>> _plansStream = widget.service.watchPlansForStudent(widget.student.id);

  bool get _isTraining => widget.fixedType == PlanType.training;
  Color get _accent => _isTraining ? kTrainingAccent : kDietAccent;

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

  Future<void> _downloadTrainingPdf(Plan p) async {
    final bytes = await buildTrainingPdf(
      studentName: widget.student.name,
      planTitle: p.title,
      validity: '${formatDate(p.startDate)} a ${formatDate(p.endDate)}',
      objective: widget.student.goal,
      exercises: p.exercises,
    );
    final safeName = p.title.trim().isEmpty
        ? 'treino'
        : p.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ok = await Printing.sharePdf(bytes: bytes, filename: 'treino_$safeName.pdf')
        .catchError((_) => false);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
      );
    }
  }

  void _showDetails(Plan p, List<Plan> allPlans) {
    String? linkedTitle;
    if (p.linkedPlanId != null) {
      final match = allPlans.where((other) => other.id == p.linkedPlanId);
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
                      p.type == PlanType.training ? 'Integrado à dieta: $linkedTitle' : 'Integrado ao treino: $linkedTitle',
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
          if (p.type == PlanType.training)
            TextButton.icon(
              onPressed: () => _downloadTrainingPdf(p),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Baixar PDF'),
            ),
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

  Widget _buildList(List<Plan> myPlans) {
    final filtered = myPlans.where((p) => p.type == widget.fixedType).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    if (filtered.isEmpty) {
      return Center(
        child: Text(_isTraining ? 'Nenhuma ficha de treino no momento.' : 'Nenhuma dieta no momento.'),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = filtered[i];
        return Card(
          child: ListTile(
            leading: Icon(_isTraining ? Icons.fitness_center : Icons.restaurant, color: _accent),
            title: Text(p.title),
            subtitle: Text(_isTraining ? '${p.exercises.length} exercício(s)' : 'Dieta'),
            trailing: Text(
              '${formatDate(p.startDate)} - ${formatDate(p.endDate)}',
              style: p.isActive
                  ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)
                  : null,
            ),
            onTap: () => _showDetails(p, myPlans),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Plan>>(
      stream: _plansStream,
      initialData: const [],
      builder: (context, snapshot) {
        final myPlans = snapshot.data ?? const <Plan>[];
        return PageShell(
          title: _isTraining ? 'Treinos' : 'Dietas',
          subtitle: _isTraining
              ? 'Fichas de treino montadas pelo seu personal.'
              : 'Dietas montadas pelo seu personal.',
          child: _buildList(myPlans),
        );
      },
    );
  }
}
