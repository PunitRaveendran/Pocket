class LocalDate {
  const LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory LocalDate.fromDateTime(DateTime dt) {
    final l = dt.toLocal();
    return LocalDate(l.year, l.month, l.day);
  }

  factory LocalDate.parse(String ymd) {
    final p = ymd.split('-');
    return LocalDate(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  String get ymd =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime get dateTime => DateTime(year, month, day);

  LocalDate addDays(int n) => LocalDate.fromDateTime(dateTime.add(Duration(days: n)));

  int get weekday => dateTime.weekday;

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => ymd;
}

class PayCycle {
  const PayCycle({required this.start, required this.endInclusive});

  final LocalDate start;
  final LocalDate endInclusive;

  int get lengthDays => endInclusive.dateTime.difference(start.dateTime).inDays + 1;

  bool contains(LocalDate d) {
    final t = d.dateTime;
    return !t.isBefore(start.dateTime) && !t.isAfter(endInclusive.dateTime);
  }

  bool isLastDay(LocalDate d) => d == endInclusive;

  int dayIndex(LocalDate d) => d.dateTime.difference(start.dateTime).inDays;

  /// Cycle from [startDay] (1–28) containing [day].
  static PayCycle containing(LocalDate day, int startDay) {
    final sd = startDay.clamp(1, 28);
    LocalDate start;
    if (day.day >= sd) {
      start = LocalDate(day.year, day.month, sd);
    } else {
      final prev = DateTime(day.year, day.month, 1).subtract(const Duration(days: 1));
      final dim = DateTime(prev.year, prev.month + 1, 0).day;
      start = LocalDate(prev.year, prev.month, sd.clamp(1, dim));
    }
    final nextMonth = DateTime(start.year, start.month + 1, start.day);
    final end = LocalDate.fromDateTime(nextMonth.subtract(const Duration(days: 1)));
    return PayCycle(start: start, endInclusive: end);
  }
}
