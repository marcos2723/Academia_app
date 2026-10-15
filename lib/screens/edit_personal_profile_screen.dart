import 'package:flutter/material.dart';
import '../models/availability.dart';
import '../models/callbacks.dart';

/// Tela dedicada para editar os dados pessoais do próprio personal: nome,
/// telefone e horários de atendimento.
class EditPersonalProfileScreen extends StatefulWidget {
  const EditPersonalProfileScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
    required this.initialRanges,
    required this.onSaveAvailability,
  });

  final String initialName;
  final String initialPhone;
  final Future<void> Function({required String name, required String phone}) onSave;
  final List<AvailabilityRange> initialRanges;
  final SaveAvailabilityCallback onSaveAvailability;

  @override
  State<EditPersonalProfileScreen> createState() => _EditPersonalProfileScreenState();
}

class _EditPersonalProfileScreenState extends State<EditPersonalProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(text: widget.initialPhone);
  late final List<AvailabilityRange> ranges = List.of(widget.initialRanges);
  bool saving = false;
  String? error;

  Future<void> _addRange(int weekday) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Início do atendimento',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Fim do atendimento',
    );
    if (end == null) return;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O horário de fim precisa ser depois do início.')),
        );
      }
      return;
    }
    setState(() {
      ranges.add(AvailabilityRange(weekday: weekday, startMinutes: startMinutes, endMinutes: endMinutes));
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => error = 'Informe seu nome.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(name: _name.text.trim(), phone: _phone.text.trim());
      await widget.onSaveAvailability(ranges);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Não consegui salvar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar dados pessoais')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: 'DDD + número',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),
              Text('Horários de atendimento', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var weekday = 1; weekday <= 7; weekday++) ...[
                Row(
                  children: [
                    Expanded(child: Text(weekdayNames[weekday], style: Theme.of(context).textTheme.titleSmall)),
                    IconButton(
                      onPressed: () => _addRange(weekday),
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Adicionar horário',
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ranges
                      .asMap()
                      .entries
                      .where((entry) => entry.value.weekday == weekday)
                      .map(
                        (entry) => InputChip(
                          label: Text('${entry.value.startLabel} - ${entry.value.endLabel}'),
                          onDeleted: () => setState(() => ranges.removeAt(entry.key)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
