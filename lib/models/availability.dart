/// Uma faixa de horário disponível de um personal em um dia da semana.
/// [weekday] segue a convenção de DateTime: 1 = segunda ... 7 = domingo.
/// [startMinutes]/[endMinutes] são minutos desde 00:00 (ex: 8h30 = 510).
class AvailabilityRange {
  AvailabilityRange({required this.weekday, required this.startMinutes, required this.endMinutes});

  final int weekday;
  final int startMinutes;
  final int endMinutes;

  factory AvailabilityRange.fromMap(Map<String, dynamic> map) => AvailabilityRange(
        weekday: (map['weekday'] as num?)?.toInt() ?? 1,
        startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 0,
        endMinutes: (map['endMinutes'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  String get startLabel => _label(startMinutes);
  String get endLabel => _label(endMinutes);

  static String _label(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

const List<String> weekdayNames = [
  '',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

/// A disponibilidade semanal completa de um personal para atendimento
/// de avaliações.
class PersonalAvailability {
  PersonalAvailability({required this.personalUid, required this.ranges});

  final String personalUid;
  final List<AvailabilityRange> ranges;

  factory PersonalAvailability.fromFirestore(String personalUid, Map<String, dynamic> data) {
    final raw = data['ranges'] as List<dynamic>? ?? const [];
    return PersonalAvailability(
      personalUid: personalUid,
      ranges: raw.whereType<Map<String, dynamic>>().map(AvailabilityRange.fromMap).toList(),
    );
  }

  Map<String, dynamic> toMap() => {'ranges': ranges.map((r) => r.toMap()).toList()};

  List<AvailabilityRange> forWeekday(int weekday) => ranges.where((r) => r.weekday == weekday).toList();
}
