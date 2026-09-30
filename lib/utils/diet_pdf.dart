import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Gera os bytes do PDF de uma dieta, pronto para download ou
/// impressão a partir do arquivo salvo (em vez de imprimir direto pelo
/// navegador, que tinha se mostrado pouco confiável).
Future<Uint8List> buildDietPdf({
  required String studentName,
  required String planTitle,
  required String validity,
  required String objective,
  required String dietContent,
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
          'Dieta de $studentName',
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
        pw.Text(
          dietContent.trim().isEmpty ? 'Nenhum conteúdo cadastrado.' : dietContent,
          style: const pw.TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
  return doc.save();
}
