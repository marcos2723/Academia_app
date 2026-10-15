import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/plan.dart';

/// Gera os bytes do PDF de uma ficha de treino: título, vigência,
/// objetivo e, para cada dia da semana, os exercícios com séries,
/// repetições, tipo de série e descanso.
Future<Uint8List> buildTrainingPdf({
  required String studentName,
  required String planTitle,
  required String validity,
  required String objective,
  required List<TrainingDay> days,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          planTitle,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Ficha de treino de $studentName',
          style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            pw.Text('Vigência: $validity', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(width: 28),
            pw.Text('Objetivo: $objective', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.SizedBox(height: 10),
        if (days.isEmpty)
          pw.Text('Nenhum exercício cadastrado.', style: const pw.TextStyle(fontSize: 12))
        else ...[
          if (days.any((d) => d.weekdays.isNotEmpty)) ...[
            pw.Text('Semana', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Dia', 'Treino'],
              data: List.generate(7, (i) {
                final names = days.where((d) => d.weekdays.contains(i + 1)).map((d) => d.label).toList();
                return [weekdayLabel(i + 1), names.isEmpty ? 'Descanso' : names.join(' + ')];
              }),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: const {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
              columnWidths: const {0: pw.FlexColumnWidth(1.4), 1: pw.FlexColumnWidth(3)},
            ),
            pw.SizedBox(height: 16),
          ],
          for (final day in days) ...[
            pw.Text(
              day.weekdays.isEmpty ? day.label : '${day.label} - ${weekdaysSummary(day.weekdays)}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['#', 'Exercício', 'Séries', 'Repetições', 'Tipo de série', 'Descanso'],
              data: List.generate(day.exercises.length, (i) {
                final ex = day.exercises[i];
                return [
                  '${i + 1}',
                  ex.notes.isEmpty ? ex.name : '${ex.name}\n${ex.notes}',
                  '${ex.sets}',
                  ex.reps,
                  ex.setType.label,
                  ex.restSeconds == null ? '-' : '${ex.restSeconds} s',
                ];
              }),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: const {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
              columnWidths: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(3.2),
                2: pw.FlexColumnWidth(0.9),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.4),
                5: pw.FlexColumnWidth(1.1),
              },
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ],
    ),
  );
  return doc.save();
}
