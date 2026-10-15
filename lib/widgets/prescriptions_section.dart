import 'dart:math';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/prescription.dart';
import '../models/student.dart';
import '../screens/prescription_form_screen.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import '../utils/prescription_pdf.dart';
import 'labeled_value.dart';
import 'registration_dialog.dart';

/// Bloco "Manipulados" da aba Dietas. A personal monta, emite e cancela;
/// o aluno só consulta e baixa o PDF.
class PrescriptionsSection extends StatelessWidget {
  const PrescriptionsSection({
    super.key,
    required this.service,
    required this.student,
    required this.prescriptions,
    required this.isPersonal,
  });

  final FirestoreService service;
  final Student student;
  final List<Prescription> prescriptions;
  final bool isPersonal;

  Future<void> _create(BuildContext context) async {
    final me = await service.getPersonal(service.ownerUid);
    if (!context.mounted) return;
    await Navigator.push<Prescription>(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionFormScreen(
          service: service,
          student: student,
          personalUid: service.ownerUid,
          personalName: me?.name ?? 'Personal',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = isPersonal ? prescriptions : prescriptions.where((p) => !p.isDraft).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medication_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Manipulados', style: Theme.of(context).textTheme.titleLarge)),
            if (isPersonal)
              FilledButton.tonalIcon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova receita'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma receita.')))
        else
          for (final p in visible)
            Card(
              child: ListTile(
                leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                title: Text(p.title),
                subtitle: Text(
                  'Manipulados: ${p.items.length}'
                  '\nEmitida: ${formatDate(p.signedAt ?? p.createdAt)}'
                  '${p.isSigned && p.validUntil != null ? ' · Válida até: ${formatDate(p.validUntil!)}' : ''}',
                ),
                isThreeLine: true,
                trailing: _StatusChip(p),
                onTap: () => showPrescriptionDetails(
                  context,
                  service: service,
                  student: student,
                  prescription: p,
                  isPersonal: isPersonal,
                ),
              ),
            ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.p);
  final Prescription p;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expired = p.isExpired;
    final color = p.isDraft
        ? scheme.outline
        : p.status == PrescriptionStatus.revoked
            ? scheme.error
            : expired
                ? Colors.amber
                : scheme.primary;
    final text = expired ? 'Vencida' : p.status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

String _newCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  String block() => List.generate(4, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  return '${block()}-${block()}-${block()}';
}

Future<void> _downloadPdf(BuildContext context, Student student, Prescription p) async {
  final bytes = await buildPrescriptionPdf(
    prescription: p,
    studentName: student.name,
    studentBirthDate: student.birthDate,
  );
  final safe = p.title.trim().isEmpty ? 'receita' : p.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final ok = await Printing.sharePdf(bytes: bytes, filename: 'receita_$safe.pdf').catchError((_) => false);
  if (context.mounted && !ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
    );
  }
}

Future<void> showPrescriptionDetails(
  BuildContext context, {
  required FirestoreService service,
  required Student student,
  required Prescription prescription,
  required bool isPersonal,
}) {
  final p = prescription;

  Future<void> issue() async {
    final me = await service.getPersonal(service.ownerUid);
    if (!context.mounted) return;
    final result = await showRegistrationDialog(context, personalName: me?.name ?? p.personalName);
    if (result == null) return;
    try {
      await service.savePrescription(
        p.copyWith(
          status: PrescriptionStatus.signed,
          signedAt: DateTime.now(),
          councilType: result.councilType,
          councilNumber: result.councilNumber,
          councilState: result.councilState,
          code: _newCode(),
        ),
      );
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receita emitida.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não consegui emitir a receita.')));
      }
    }
  }

  Future<void> confirmAndRun(String title, String action, Future<void> Function() run) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await run();
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não consegui concluir.')));
      }
    }
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(p.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledValue(label: 'Situação', value: p.isExpired ? 'Vencida' : p.status.label),
              LabeledValue(label: 'Aluno', value: student.name),
              LabeledValue(label: 'Prescritor', value: p.personalName),
              if (p.registration != null) LabeledValue(label: 'Registro', value: p.registration!),
              if (p.signedAt != null) LabeledValue(label: 'Emitida em', value: formatDateTime(p.signedAt!)),
              if (p.validUntil != null) LabeledValue(label: 'Válida até', value: formatDate(p.validUntil!)),
              if (p.code != null) LabeledValue(label: 'Código', value: p.code!),
              const Divider(height: 24),
              for (var i = 0; i < p.items.length; i++) ...[
                Text('${i + 1}. ${p.items[i].name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                LabeledValue(label: 'Forma', value: p.items[i].form),
                LabeledValue(label: 'Quantidade', value: p.items[i].quantity),
                for (final c in p.items[i].components)
                  Text('• ${c.name}${c.amount.isEmpty ? '' : ' - ${c.amount}'}'),
                const SizedBox(height: 4),
                LabeledValue(label: 'Posologia', value: p.items[i].posology),
                const SizedBox(height: 10),
              ],
              if (p.notes.isNotEmpty) LabeledValue(label: 'Orientações', value: p.notes),
            ],
          ),
        ),
      ),
      actions: [
        if (isPersonal && p.isDraft) ...[
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              confirmAndRun('Excluir rascunho?', 'Excluir', () => service.deletePrescription(p.id));
            },
            child: const Text('Excluir'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(dialogContext);
              nav.pop();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionFormScreen(
                    service: service,
                    student: student,
                    personalUid: p.personalUid,
                    personalName: p.personalName,
                    existing: p,
                  ),
                ),
              );
            },
            child: const Text('Editar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await issue();
            },
            icon: const Icon(Icons.task_alt),
            label: const Text('Emitir'),
          ),
        ],
        if (isPersonal && p.isSigned)
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              confirmAndRun(
                'Cancelar receita?',
                'Cancelar receita',
                () => service.savePrescription(p.copyWith(status: PrescriptionStatus.revoked)),
              );
            },
            child: const Text('Cancelar receita'),
          ),
        if (!p.isDraft)
          TextButton.icon(
            onPressed: () => _downloadPdf(context, student, p),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Baixar PDF'),
          ),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
      ],
    ),
  );
}
