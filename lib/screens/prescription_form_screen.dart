import 'package:flutter/material.dart';
import '../models/prescription.dart';
import '../models/student.dart';
import '../services/firestore_service.dart';

class _ComponentDraft {
  _ComponentDraft({String name = '', String amount = ''})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);
  final TextEditingController name;
  final TextEditingController amount;
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _ItemDraft {
  _ItemDraft({PrescriptionItem? item})
      : name = TextEditingController(text: item?.name ?? ''),
        quantity = TextEditingController(text: item?.quantity ?? ''),
        posology = TextEditingController(text: item?.posology ?? ''),
        form = item?.form ?? kPharmaceuticalForms.first,
        components = [
          for (final c in item?.components ?? <PrescriptionComponent>[])
            _ComponentDraft(name: c.name, amount: c.amount),
          if (item == null || item.components.isEmpty) _ComponentDraft(),
        ];
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController posology;
  String form;
  final List<_ComponentDraft> components;
  void dispose() {
    name.dispose();
    quantity.dispose();
    posology.dispose();
    for (final c in components) {
      c.dispose();
    }
  }
}

/// Monta ou edita um rascunho de receita de manipulados.
class PrescriptionFormScreen extends StatefulWidget {
  const PrescriptionFormScreen({
    super.key,
    required this.service,
    required this.student,
    required this.personalUid,
    required this.personalName,
    this.existing,
  });

  final FirestoreService service;
  final Student student;
  final String personalUid;
  final String personalName;
  final Prescription? existing;

  @override
  State<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends State<PrescriptionFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? 'Receita de manipulados');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late int _validity = widget.existing?.validityDays ?? 30;
  late final List<_ItemDraft> _items = [
    for (final i in widget.existing?.items ?? <PrescriptionItem>[]) _ItemDraft(item: i),
    if (widget.existing == null || widget.existing!.items.isEmpty) _ItemDraft(),
  ];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final items = <PrescriptionItem>[];
    for (final d in _items) {
      if (d.name.text.trim().isEmpty) {
        setState(() => _error = 'Todo manipulado precisa de um nome.');
        return;
      }
      final comps = [
        for (final c in d.components)
          if (c.name.text.trim().isNotEmpty)
            PrescriptionComponent(name: c.name.text.trim(), amount: c.amount.text.trim()),
      ];
      if (comps.isEmpty) {
        setState(() => _error = 'Informe ao menos um componente em "${d.name.text.trim()}".');
        return;
      }
      items.add(PrescriptionItem(
        name: d.name.text.trim(),
        form: d.form,
        quantity: d.quantity.text.trim(),
        components: comps,
        posology: d.posology.text.trim(),
      ));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final base = widget.existing;
    final p = Prescription(
      id: base?.id ?? widget.service.newPrescriptionId(),
      studentId: widget.student.id,
      personalUid: widget.personalUid,
      personalName: widget.personalName,
      title: _title.text.trim().isEmpty ? 'Receita de manipulados' : _title.text.trim(),
      items: items,
      createdAt: base?.createdAt ?? DateTime.now(),
      notes: _notes.text.trim(),
      validityDays: _validity,
    );
    try {
      await widget.service.savePrescription(p);
      if (mounted) Navigator.pop(context, p);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não consegui salvar a receita.';
        });
      }
    }
  }

  Widget _buildItem(int index) {
    final d = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Manipulado ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (_items.length > 1)
                  IconButton(
                    tooltip: 'Remover',
                    onPressed: () => setState(() => _items.removeAt(index).dispose()),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            TextField(
              controller: d.name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: d.form,
                    decoration: const InputDecoration(labelText: 'Forma'),
                    items: [for (final f in kPharmaceuticalForms) DropdownMenuItem(value: f, child: Text(f))],
                    onChanged: (v) => setState(() => d.form = v ?? d.form),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: d.quantity,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Fórmula', style: TextStyle(fontWeight: FontWeight.w600)),
            for (var ci = 0; ci < d.components.length; ci++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: d.components[ci].name,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(labelText: 'Componente'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: d.components[ci].amount,
                        decoration: const InputDecoration(labelText: 'Dose'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover componente',
                      onPressed: d.components.length > 1
                          ? () => setState(() => d.components.removeAt(ci).dispose())
                          : null,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => d.components.add(_ComponentDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Componente'),
              ),
            ),
            TextField(
              controller: d.posology,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Posologia'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nova receita' : 'Editar receita'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Aluno: ${widget.student.name}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 14),
                for (var i = 0; i < _items.length; i++) _buildItem(i),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar manipulado'),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Orientações'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: _validity,
                  decoration: const InputDecoration(labelText: 'Validade'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 dias')),
                    DropdownMenuItem(value: 60, child: Text('60 dias')),
                    DropdownMenuItem(value: 90, child: Text('90 dias')),
                    DropdownMenuItem(value: 180, child: Text('180 dias')),
                  ],
                  onChanged: (v) => setState(() => _validity = v ?? _validity),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
