import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/plan.dart';

/// Gera os bytes do PDF de uma ficha de treino: título, vigência,
/// objetivo e a lista de exercícios com séries e repetições.
Future<Uint8List> buildTrainingPdf({
  required String studentName,
  required String planTitle,
  required String validity,
  required String objective,
  required List<Exercise> exercises,
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
        if (exercises.isEmpty)
          pw.Text('Nenhum exercício cadastrado.', style: const pw.TextStyle(fontSize: 12))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Exercício', 'Séries', 'Repetições'],
            data: List.generate(exercises.length, (i) {
              final ex = exercises[i];
              return ['${i + 1}', ex.name, '${ex.sets}', '${ex.reps}'];
            }),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(0.6),
              1: pw.FlexColumnWidth(3.2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.3),
            },
          ),
      ],
    ),
  );
  return doc.save();
}
