import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/prescription.dart';
import 'formatters.dart';

/// Gera o PDF da receita de manipulados, para o aluno levar à farmácia.
Future<Uint8List> buildPrescriptionPdf({
  required Prescription prescription,
  required String studentName,
  required DateTime studentBirthDate,
}) async {
  final p = prescription;
  final doc = pw.Document();

  pw.Widget label(String text) => pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          p.code == null ? 'Rascunho - não emitida' : 'Código de validação: ${p.code}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        pw.Text(
          'RECEITA DE MANIPULADOS',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(p.title, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('PACIENTE'),
                  pw.Text(studentName, style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                label('NASCIMENTO'),
                pw.Text(formatDate(studentBirthDate), style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(width: 28),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                label('EMISSÃO'),
                pw.Text(
                  formatDate(p.signedAt ?? p.createdAt),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (p.validUntil != null) ...[
              pw.SizedBox(width: 28),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('VÁLIDA ATÉ'),
                  pw.Text(formatDate(p.validUntil!), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(),
        pw.SizedBox(height: 10),
        for (var i = 0; i < p.items.length; i++) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${i + 1}. ${p.items[i].name}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Forma: ${p.items[i].form}   |   Quantidade: ${p.items[i].quantity.isEmpty ? '-' : p.items[i].quantity}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                if (p.items[i].components.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  label('FÓRMULA'),
                  for (final c in p.items[i].components)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text(c.name, style: const pw.TextStyle(fontSize: 11))),
                          pw.Text(c.amount, style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
                if (p.items[i].posology.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  label('POSOLOGIA'),
                  pw.Text(p.items[i].posology, style: const pw.TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        if (p.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          label('ORIENTAÇÕES'),
          pw.Text(p.notes, style: const pw.TextStyle(fontSize: 11)),
        ],
        pw.SizedBox(height: 40),
        pw.Center(
          child: pw.Column(
            children: [
              pw.SizedBox(height: 50),
              pw.Container(width: 240, height: 0.8, color: PdfColors.grey800),
              pw.SizedBox(height: 4),
              pw.Text(p.personalName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (p.registration != null)
                pw.Text(p.registration!, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        ),
        if (p.status == PrescriptionStatus.revoked) ...[
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              'RECEITA CANCELADA',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
            ),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}
