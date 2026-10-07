import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/appointment.dart';
import '../models/callbacks.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import '../utils/booking_rules.dart';
import '../widgets/page_shell.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    required this.students,
    required this.appointments,
    required this.studentName,
    required this.currentPersonalUid,
    required this.currentPersonalName,
    required this.service,
    required this.onAddAppointment,
    required this.onDeleteAppointment,
  });

  final List<Student> students;
  final List<Appointment> appointments;
  final String Function(String id) studentName;
  final String currentPersonalUid;
  final String currentPersonalName;
  final FirestoreService service;
  final AddAppointmentCallback onAddAppointment;
  final DeleteAppointmentCallback onDeleteAppointment;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  Future<void> _openNewAppointment() async {
    String? studentId = widget.students.isEmpty ? null : widget.students.first.id;
    DateTime? date;
    TimeOfDay? time;
    final notes = TextEditingController();
    bool saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agendar avaliação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<Student>(
                  initialValue: TextEditingValue(
                    text: widget.students.isEmpty ? '' : widget.students.first.name,
                  ),
                  displayStringForOption: (s) => s.name,
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return widget.students;
                    final query = textEditingValue.text.toLowerCase();
                    return widget.students.where((s) => s.name.toLowerCase().contains(query));
                  },
                  onSelected: (s) => setDialogState(() => studentId = s.id),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar aluno',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: SizedBox(
                        width: 320,
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: options
                              .map((s) => ListTile(title: Text(s.name), onTap: () => onSelected(s)))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setDialogState(() => date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Data'),
                          child: Text(date == null ? 'Selecionar' : formatDate(date!)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null) setDialogState(() => time = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Horário'),
                          child: Text(time == null ? 'Selecionar' : time!.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (studentId == null) {
                        setDialogState(() => errorText = 'Selecione um aluno.');
                        return;
                      }
                      if (date == null || time == null) {
                        setDialogState(() => errorText = 'Selecione data e horário.');
                        return;
                      }
                      final dt = DateTime(date!.year, date!.month, date!.day, time!.hour, time!.minute);
                      if (dt.isBefore(DateTime.now())) {
                        setDialogState(() => errorText = 'Não é possível agendar um horário no passado.');
                        return;
                      }
                      final conflict = widget.appointments.where(
                        (a) =>
                            a.personalUid == widget.currentPersonalUid &&
                            a.dateTime.difference(dt).abs() < const Duration(minutes: 30),
                      );
                      if (conflict.isNotEmpty) {
                        setDialogState(() => errorText =
                            'Você já tem uma avaliação marcada às ${formatTime(conflict.first.dateTime)}. Escolha outro horário.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      final createdId = await widget.onAddAppointment(
                        studentId: studentId!,
                        personalUid: widget.currentPersonalUid,
                        dateTime: dt,
                        notes: notes.text.trim(),
                      );
                      final student = widget.students.firstWhere((s) => s.id == studentId);
                      await NotificationService.instance.scheduleAppointmentReminders(
                        appointmentId: createdId,
                        studentName: student.name,
                        dateTime: dt,
                      );
                      await widget.service.writeAppointmentNotifications(
                        studentAuthUid: student.authUid ?? '',
                        studentName: student.name,
                        personalUid: widget.currentPersonalUid,
                        personalName: widget.currentPersonalName,
                        dateTime: dt,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Appointment a) async {
    final tooClose = a.dateTime.difference(DateTime.now()) < minCancelNotice;
    if (tooClose && a.dateTime.isAfter(DateTime.now())) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Muito perto do horário'),
          content: const Text(
            'Faltam menos de 3 horas para essa avaliação. Cancelamentos precisam ser feitos com '
            'pelo menos 3 horas de antecedência — combine diretamente com o aluno se for realmente '
            'necessário desmarcar agora.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          ],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover agendamento?'),
        content: Text('Remover a avaliação de ${widget.studentName(a.studentId)} em ${formatDateTime(a.dateTime)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService.instance.cancelAppointmentReminders(a.id);
      final student = widget.students.where((s) => s.id == a.studentId);
      if (student.isNotEmpty && (student.first.authUid ?? '').isNotEmpty) {
        await widget.service.notifyAppointmentCancelled(
          recipientUid: student.first.authUid!,
          cancelledByName: widget.currentPersonalName,
          dateTime: a.dateTime,
        );
      }
      await widget.onDeleteAppointment(a.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sorted = widget.appointments.toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final upcoming = sorted.where((a) => !a.dateTime.isBefore(now)).toList();
    final past = sorted.where((a) => a.dateTime.isBefore(now)).toList().reversed.toList();

    Widget tile(Appointment a) => Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(widget.studentName(a.studentId)),
            subtitle: Text(a.notes.isEmpty ? formatDateTime(a.dateTime) : '${formatDateTime(a.dateTime)} · ${a.notes}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(a),
            ),
          ),
        );

    return PageShell(
      title: 'Agenda',
      subtitle: 'Marque os horários das próximas avaliações.',
      action: FilledButton.icon(
        onPressed: widget.students.isEmpty ? null : _openNewAppointment,
        icon: const Icon(Icons.add),
        label: const Text('Agendar avaliação'),
      ),
      child: widget.students.isEmpty
          ? const Center(child: Text('Cadastre um aluno para agendar avaliações.'))
          : ListView(
              children: [
                Text('Próximas', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (upcoming.isEmpty)
                  const Card(
                    child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma avaliação agendada.')),
                  )
                else
                  ...upcoming.map(tile),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ExpansionTile(
                    title: Text('Anteriores (${past.length})'),
                    children: past.map(tile).toList(),
                  ),
                ],
              ],
            ),
    );
  }
}
