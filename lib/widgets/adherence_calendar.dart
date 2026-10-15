import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../models/plan.dart';
import '../utils/adherence.dart';
import '../utils/formatters.dart';
import 'labeled_value.dart';

const Color kCheckinDone = Color(0xFF66BB6A);
const Color kCheckinPartial = Color(0xFFFFCA28);
const Color kCheckinMissed = Color(0xFFEF5350);

const List<String> _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const List<String> _weekdayInitials = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

Color checkinColor(CheckinStatus s) => switch (s) {
      CheckinStatus.done => kCheckinDone,
      CheckinStatus.partial => kCheckinPartial,
      CheckinStatus.missed => kCheckinMissed,
    };

/// Calendário mensal do plano: cada dia registrado ganha a cor do
/// resultado (feito, parcial, não feito). Dias previstos que já passaram
/// sem registro ficam com contorno cinza.
class AdherenceCalendar extends StatefulWidget {
  const AdherenceCalendar({super.key, required this.plan, required this.checkins, this.onRegisterDay});

  final Plan plan;
  final List<Checkin> checkins;

  /// Quando informado (visão do aluno), tocar num dia dentro do período
  /// permitido chama esta função para registrar ou alterar o dia.
  final void Function(DateTime date)? onRegisterDay;

  @override
  State<AdherenceCalendar> createState() => _AdherenceCalendarState();
}

class _AdherenceCalendarState extends State<AdherenceCalendar> {
  late DateTime _month;
  DateTime? _selected;

  DateTime get _firstMonth => DateTime(widget.plan.startDate.year, widget.plan.startDate.month);
  DateTime get _lastMonth {
    final end = widget.plan.endDate;
    final today = DateTime.now();
    final last = end.isBefore(today) ? end : today;
    final endMonth = DateTime(last.year, last.month);
    return endMonth.isBefore(_firstMonth) ? _firstMonth : endMonth;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    var m = DateTime(now.year, now.month);
    if (m.isAfter(_lastMonth)) m = _lastMonth;
    if (m.isBefore(_firstMonth)) m = _firstMonth;
    _month = m;
  }

  Map<String, Checkin> get _byDate => {
        for (final c in widget.checkins.where((c) => c.planId == widget.plan.id)) c.dateKey: c,
      };

  /// Mesmo período aceito pelo diálogo de registro: dentro da vigência,
  /// até hoje e no máximo 30 dias para trás.
  bool _canRegister(DateTime d) {
    final today = dateOnly(DateTime.now());
    var earliest = dateOnly(widget.plan.startDate);
    final limit = DateTime(today.year, today.month, today.day - 30);
    if (earliest.isBefore(limit)) earliest = limit;
    var latest = dateOnly(widget.plan.endDate);
    if (latest.isAfter(today)) latest = today;
    return !d.isBefore(earliest) && !d.isAfter(latest);
  }

  bool _expected(DateTime d) {
    final start = dateOnly(widget.plan.startDate);
    final end = dateOnly(widget.plan.endDate);
    if (d.isBefore(start) || d.isAfter(end)) return false;
    if (widget.plan.type == PlanType.diet) return true;
    final scheduled = widget.plan.days.expand((x) => x.weekdays).toSet();
    return scheduled.contains(d.weekday);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final byDate = _byDate;
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final canPrev = _month.isAfter(_firstMonth);
    final canNext = _month.isBefore(_lastMonth);
    final type = widget.plan.type;
    final selectedCheckin = _selected == null ? null : byDate[Checkin.dateKeyOf(_selected!)];

    Widget cell(int day) {
      final date = DateTime(_month.year, _month.month, day);
      final c = byDate[Checkin.dateKeyOf(date)];
      final inPlan = !date.isBefore(dateOnly(widget.plan.startDate)) && !date.isAfter(dateOnly(widget.plan.endDate));
      final missingRecord = c == null && _expected(date) && date.isBefore(today);
      final isToday = date == today;
      final isSelected = _selected != null && dateOnly(_selected!) == date;
      final fill = c == null ? null : checkinColor(c.status);
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selected = date);
          if (widget.onRegisterDay != null && _canRegister(date)) widget.onRegisterDay!(date);
        },
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : isToday
                      ? scheme.onSurface
                      : missingRecord
                          ? scheme.outline
                          : Colors.transparent,
              width: isSelected || isToday ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontWeight: c != null ? FontWeight.w700 : FontWeight.w400,
              color: c != null
                  ? Colors.black87
                  : inPlan
                      ? scheme.onSurface
                      : scheme.onSurface.withOpacity(0.35),
            ),
          ),
        ),
      );
    }

    Widget legend(Color? color, String text, {bool outline = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: outline ? Border.all(color: scheme.outline) : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in _weekdayInitials)
              Expanded(
                child: Center(child: Text(w, style: Theme.of(context).textTheme.bodySmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1.15,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++) cell(d),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            legend(kCheckinDone, CheckinStatus.done.resultLabel(type)),
            legend(kCheckinPartial, CheckinStatus.partial.resultLabel(type)),
            legend(kCheckinMissed, CheckinStatus.missed.resultLabel(type)),
            legend(null, 'Sem registro', outline: true),
          ],
        ),
        if (widget.onRegisterDay != null) ...[
          const SizedBox(height: 8),
          Text('Toque em um dia para registrar.', style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 10),
          if (selectedCheckin == null)
            LabeledValue(label: formatDate(_selected!), value: 'Sem registro')
          else ...[
            LabeledValue(
              label: formatDate(selectedCheckin.date),
              value: '${selectedCheckin.status.resultLabel(type)}'
                  '${selectedCheckin.dayLabel == null ? '' : ' · ${selectedCheckin.dayLabel}'}',
            ),
            if (selectedCheckin.note != null && selectedCheckin.note!.isNotEmpty)
              LabeledValue(label: 'Observação', value: selectedCheckin.note!),
          ],
        ],
      ],
    );
  }
}
