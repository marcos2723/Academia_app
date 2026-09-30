import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/evaluation.dart';
import '../../models/student.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/evaluation_metrics.dart';
import '../../utils/evolution_pdf.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/weight_chart.dart';

class AlunoEvaluationsPage extends StatefulWidget {
  const AlunoEvaluationsPage({super.key, required this.service, required this.student});

  final FirestoreService service;
  final Student student;

  @override
  State<AlunoEvaluationsPage> createState() => _AlunoEvaluationsPageState();
}

class _AlunoEvaluationsPageState extends State<AlunoEvaluationsPage> {
  int categoryIndex = 0;

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

  void _showDetails(Evaluation e) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Evaluation>>(
      stream: widget.service.watchEvaluationsForStudent(widget.student.id),
      builder: (context, snapshot) {
        final records = (snapshot.data ?? const <Evaluation>[]).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final latest = records.isEmpty ? null : records.last;
        final category = evaluationMetricCategories[categoryIndex];

        return PageShell(
          title: 'Minhas avaliações',
          subtitle: 'Acompanhe sua evolução física ao longo do tempo.',
          child: records.isEmpty
              ? const Center(child: Text('Você ainda não tem avaliações registradas.'))
              : ListView(
                  children: [
                    if (latest != null)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Chip(label: 'IMC', value: latest.bmi.toStringAsFixed(1)),
                          _Chip(label: '% Gordura', value: '${latest.bodyFat.toStringAsFixed(1)}%'),
                          _Chip(label: '% Massa magra', value: '${latest.leanMassPercent.toStringAsFixed(1)}%'),
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
                                  SizedBox(height: 200, child: EvolutionChart(values: values, dates: dates)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
                        if (records.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _downloadEvolutionPdf(records),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Relatório em PDF'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...records.reversed.map(
                      (e) => Card(
                        child: ListTile(
                          title: Text(formatDate(e.date)),
                          subtitle: Text(
                            '${e.weight.toStringAsFixed(1)} kg · IMC ${e.bmi.toStringAsFixed(1)} · '
                            '${e.bodyFat.toStringAsFixed(1)}% gordura',
                          ),
                          trailing: TextButton(onPressed: () => _showDetails(e), child: const Text('Detalhes')),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});
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
