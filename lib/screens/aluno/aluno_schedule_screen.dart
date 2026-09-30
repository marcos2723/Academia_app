import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/personal.dart';
import '../../models/appointment.dart';
import '../../models/availability.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
import '../../utils/booking_rules.dart';
import '../../widgets/page_shell.dart';

class AlunoScheduleScreen extends StatefulWidget {
  const AlunoScheduleScreen({super.key, required this.service, required this.student});

  final FirestoreService service;
  final Student student;

  @override
  State<AlunoScheduleScreen> createState() => _AlunoScheduleScreenState();
}

class _AlunoScheduleScreenState extends State<AlunoScheduleScreen> {
  String? selectedPersonalUid;
  DateTime? selectedDate;
  int? selectedSlotMinutes;
  bool booking = false;
  String? error;
  String? success;

  List<int> _freeSlotsMinutes(List<int> rangeMinutesPairs, List<Appointment> busy, DateTime day) {
    final slots = <int>[];
    for (var i = 0; i < rangeMinutesPairs.length; i += 2) {
      final start = rangeMinutesPairs[i];
      final end = rangeMinutesPairs[i + 1];
      for (var m = start; m + 30 <= end; m += 30) {
        slots.add(m);
      }
    }
    final busyMinutes = busy
        .where((a) =>
            a.dateTime.year == day.year && a.dateTime.month == day.month && a.dateTime.day == day.day)
        .map((a) => a.dateTime.hour * 60 + a.dateTime.minute)
        .toSet();
    slots.removeWhere(busyMinutes.contains);

    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    if (isToday) {
      final nowMinutes = now.hour * 60 + now.minute;
      slots.removeWhere((m) => m <= nowMinutes);
    }
    return slots;
  }

  Future<void> _confirm(Personal selectedPersonal) async {
    if (selectedDate == null || selectedSlotMinutes == null) return;
    setState(() {
      booking = true;
      error = null;
    });
    final dateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedSlotMinutes! ~/ 60,
      selectedSlotMinutes! % 60,
    );
    if (dateTime.isBefore(DateTime.now())) {
      setState(() {
        booking = false;
        error = 'Esse horário já passou. Escolha outro.';
      });
      return;
    }
    try {
      final id = await widget.service.addAppointment(
        studentId: widget.student.id,
        personalUid: selectedPersonal.uid,
        dateTime: dateTime,
      );
      await NotificationService.instance.scheduleAppointmentReminders(
        appointmentId: id,
        studentName: widget.student.name,
        dateTime: dateTime,
      );
      await widget.service.writeAppointmentNotifications(
        studentAuthUid: widget.student.authUid ?? '',
        studentName: widget.student.name,
        personalUid: selectedPersonal.uid,
        personalName: selectedPersonal.name,
        dateTime: dateTime,
      );
      setState(() {
        booking = false;
        success = 'Avaliação marcada com ${selectedPersonal.name} em ${formatDateTime(dateTime)}.';
        selectedSlotMinutes = null;
      });
    } catch (e) {
      setState(() {
        booking = false;
        error = 'Não foi possível agendar. Tente novamente.';
      });
    }
  }

  Future<void> _cancelAppointment(Appointment a, String personalName) async {
    final tooClose = a.dateTime.difference(DateTime.now()) < minCancelNotice;
    if (tooClose) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Muito perto do horário'),
          content: const Text(
            'Faltam menos de 3 horas para essa avaliação. Cancelamentos precisam ser feitos com '
            'pelo menos 3 horas de antecedência — fale diretamente com seu personal se for '
            'realmente necessário.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi'))],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar avaliação?'),
        content: Text('Cancelar a avaliação com $personalName em ${formatDateTime(a.dateTime)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar consulta')),
        ],
      ),
    );
    if (confirmed == true) {
      await NotificationService.instance.cancelAppointmentReminders(a.id);
      await widget.service.notifyAppointmentCancelled(
        recipientUid: a.personalUid,
        cancelledByName: widget.student.name,
        dateTime: a.dateTime,
      );
      await widget.service.deleteAppointment(a.id);
      if (mounted) setState(() => success = 'Consulta cancelada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Personal>>(
      stream: widget.service.watchPersonals(),
      builder: (context, personalsSnap) {
        final personals = personalsSnap.data ?? const <Personal>[];
        final matches = personals.where((p) => p.uid == selectedPersonalUid);
        final selectedPersonal = matches.isEmpty ? null : matches.first;
        // Se o personal escolhido sumiu da lista (ex: stream ainda carregando
        // na primeira renderização), evita manter um uid "órfão" selecionado.
        if (selectedPersonalUid != null && selectedPersonal == null && personals.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => selectedPersonalUid = null);
          });
        }
        return PageShell(
          title: 'Agendar avaliação',
          subtitle: 'Escolha o personal, a data e um horário disponível.',
          child: ListView(
            children: [
              StreamBuilder<List<Appointment>>(
                stream: widget.service.watchAppointmentsForStudent(widget.student.id),
                builder: (context, apptSnap) {
                  final mine = (apptSnap.data ?? const <Appointment>[])
                      .where((a) => a.dateTime.isAfter(DateTime.now()))
                      .toList()
                    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                  if (mine.isEmpty) return const SizedBox.shrink();
                  String nameFor(String uid) {
                    final match = personals.where((p) => p.uid == uid);
                    return match.isEmpty ? 'Personal' : (match.first.name.isEmpty ? match.first.email : match.first.name);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Minhas consultas agendadas', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        ...mine.map(
                          (a) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.event_available_outlined),
                              title: Text(nameFor(a.personalUid)),
                              subtitle: Text(formatDateTime(a.dateTime)),
                              trailing: IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                tooltip: 'Cancelar',
                                onPressed: () => _cancelAppointment(a, nameFor(a.personalUid)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              DropdownButtonFormField<String>(
                value: selectedPersonal == null ? null : selectedPersonalUid,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Personal', border: OutlineInputBorder()),
                items: personals
                    .map((p) => DropdownMenuItem(value: p.uid, child: Text(p.name.isEmpty ? p.email : p.name)))
                    .toList(),
                onChanged: (uid) => setState(() {
                  selectedPersonalUid = uid;
                  selectedDate = null;
                  selectedSlotMinutes = null;
                  success = null;
                }),
              ),
              const SizedBox(height: 16),
              if (selectedPersonal != null)
                StreamBuilder<PersonalAvailabilitySnapshot>(
                  stream: _availabilityAndAppointments(selectedPersonal.uid),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final ranges = snap.data!.ranges;
                    final weekdaysWithSlots = ranges.map((r) => r.weekday).toSet();
                    if (ranges.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Este personal ainda não definiu horários de atendimento.'),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () async {
                            // O initialDate PRECISA satisfazer o selectableDayPredicate,
                            // senão o showDatePicker nem abre. Achamos o primeiro dia,
                            // a partir de hoje, que o personal realmente atende.
                            var initial = DateTime.now();
                            for (var i = 0; i < 7 && !weekdaysWithSlots.contains(initial.weekday); i++) {
                              initial = initial.add(const Duration(days: 1));
                            }
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 60)),
                              selectableDayPredicate: (day) => weekdaysWithSlots.contains(day.weekday),
                            );
                            if (picked != null) {
                              setState(() {
                                selectedDate = picked;
                                selectedSlotMinutes = null;
                                success = null;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder()),
                            child: Text(selectedDate == null ? 'Selecionar' : formatDate(selectedDate!)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (selectedDate != null) ...[
                          Text('Horários disponíveis', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Builder(builder: (context) {
                            final pairs = <int>[];
                            for (final r in ranges.where((r) => r.weekday == selectedDate!.weekday)) {
                              pairs..add(r.startMinutes)..add(r.endMinutes);
                            }
                            final free = _freeSlotsMinutes(pairs, snap.data!.appointments, selectedDate!);
                            if (free.isEmpty) {
                              return const Text('Nenhum horário livre neste dia.');
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: free.map((m) {
                                final label =
                                    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: selectedSlotMinutes == m,
                                  onSelected: (_) => setState(() => selectedSlotMinutes = m),
                                );
                              }).toList(),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (success != null) ...[
                const SizedBox(height: 12),
                Text(success!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (selectedPersonal != null && selectedDate != null && selectedSlotMinutes != null && !booking)
                    ? () => _confirm(selectedPersonal)
                    : null,
                child: booking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmar agendamento'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Stream<PersonalAvailabilitySnapshot> _availabilityAndAppointments(String personalUid) {
    return widget.service.watchAvailability(personalUid).asyncMap((availability) async {
      final appointments = await widget.service.watchAppointments().first;
      return PersonalAvailabilitySnapshot(
        ranges: availability.ranges,
        appointments: appointments.where((a) => a.personalUid == personalUid).toList(),
      );
    });
  }
}

class PersonalAvailabilitySnapshot {
  PersonalAvailabilitySnapshot({required this.ranges, required this.appointments});
  final List<AvailabilityRange> ranges;
  final List<Appointment> appointments;
}
