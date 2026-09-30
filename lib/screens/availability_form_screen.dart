import 'package:flutter/material.dart';
import '../models/availability.dart';
import '../models/callbacks.dart';

/// Tela onde o personal define, para cada dia da semana, as faixas de
/// horário em que aceita marcar avaliações. Os alunos verão isso dividido
/// em horários de meia em meia hora na tela de agendamento deles.
class AvailabilityFormScreen extends StatefulWidget {
  const AvailabilityFormScreen({
    super.key,
    required this.initialRanges,
    required this.onSave,
  });

  final List<AvailabilityRange> initialRanges;
  final SaveAvailabilityCallback onSave;

  @override
  State<AvailabilityFormScreen> createState() => _AvailabilityFormScreenState();
}

class _AvailabilityFormScreenState extends State<AvailabilityFormScreen> {
  late List<AvailabilityRange> ranges = List.of(widget.initialRanges);
  bool saving = false;

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
    setState(() => saving = true);
    await widget.onSave(ranges);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus horários de atendimento')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Text(
                'Defina os intervalos em que você atende avaliações. Os alunos vão '
                'poder marcar horários de 30 em 30 minutos dentro dessas faixas.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (var weekday = 1; weekday <= 7; weekday++) ...[
                Row(
                  children: [
                    Expanded(child: Text(weekdayNames[weekday], style: Theme.of(context).textTheme.titleMedium)),
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
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar horários'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
