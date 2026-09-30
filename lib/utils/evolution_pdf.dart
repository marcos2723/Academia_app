import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/evaluation.dart';
import 'evaluation_metrics.dart';
import 'formatters.dart';

/// Gera os bytes do PDF com a evolução de um aluno: resumo (primeira
/// avaliação x última, com a diferença de cada medida, organizado pelos
/// mesmos grupos — Peso, Tórax, Braços, Pernas — usados nos gráficos do
/// app) seguido do histórico completo de todas as avaliações.
Future<Uint8List> buildEvolutionSummaryPdf({
  required String studentName,
  required String objective,
  required List<Evaluation> records,
}) async {
  final ordered = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final first = ordered.first;
  final last = ordered.last;
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          'Relatório de evolução',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Aluno: $studentName',
          style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 24,
          runSpacing: 4,
          children: [
            pw.Text('Objetivo: $objective', style: const pw.TextStyle(fontSize: 11)),
            pw.Text(
              'Período: ${formatDate(first.date)} a ${formatDate(last.date)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
            pw.Text('Avaliações registradas: ${ordered.length}', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'Resumo — primeira x última avaliação',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        for (final category in evaluationMetricCategories) ...[
          pw.Text(
            category.label,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Medida', 'Primeira', 'Última', 'Diferença'],
            data: category.metrics.map((m) {
              final v1 = m.extract(first);
              final v2 = m.extract(last);
              final diff = v2 - v1;
              final sign = diff > 0 ? '+' : '';
              return [
                m.label,
                '${v1.toStringAsFixed(1)} ${m.unit}',
                '${v2.toStringAsFixed(1)} ${m.unit}',
                '$sign${diff.toStringAsFixed(1)} ${m.unit}',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.5),
            },
          ),
          pw.SizedBox(height: 14),
        ],
        if (ordered.length > 1) ...[
          pw.SizedBox(height: 6),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Histórico completo',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Peso', 'IMC', '% Gordura', '% Massa magra'],
            data: ordered
                .map((e) => [
                      formatDate(e.date),
                      '${e.weight.toStringAsFixed(1)} kg',
                      e.bmi.toStringAsFixed(1),
                      '${e.bodyFat.toStringAsFixed(1)}%',
                      '${e.leanMassPercent.toStringAsFixed(1)}%',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: const {0: pw.Alignment.centerLeft},
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
