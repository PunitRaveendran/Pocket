class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  factory LocalDate.fromDateTime(DateTime dt) {
    final l = dt.toLocal();
    return LocalDate(l.year, l.month, l.day);
  }

  factory LocalDate.parse(String ymd) {
    final parsed = tryParse(ymd);
    if (parsed == null) {
      throw FormatException('Invalid date format: "$ymd" (expected YYYY-MM-DD)');
    }
    return parsed;
  }

  static LocalDate? tryParse(String? ymd) {
    if (ymd == null) return null;
    final p = ymd.trim().split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return LocalDate(y, m, d);
  }

  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  String get ymd =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime get dateTime => DateTime(year, month, day);

  LocalDate addDays(int n) => LocalDate.fromDateTime(dateTime.add(Duration(days: n)));

  int get weekday => dateTime.weekday;

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool isSameDay(LocalDate other) => year == other.year && month == other.month && day == other.day;

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
    return !d.isBefore(start) && !d.isAfter(endInclusive);
  }

  bool isLastDay(LocalDate d) => d == endInclusive;

  int dayIndex(LocalDate d) => d.dateTime.difference(start.dateTime).inDays;

  /// Cycle from [startDay] (1–31) containing [day].
  /// Dynamically clamps to the maximum days of the relevant month.
  static PayCycle containing(LocalDate day, int startDay) {
    final sd = startDay.clamp(1, 31);

    int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

    final thisMonthStartDay = sd.clamp(1, daysInMonth(day.year, day.month));

    LocalDate start;
    if (day.day >= thisMonthStartDay) {
      start = LocalDate(day.year, day.month, thisMonthStartDay);
    } else {
      // Belongs to the cycle that started in the previous calendar month
      final prevMonthDt = DateTime(day.year, day.month, 1).subtract(const Duration(days: 1));
      final prevDim = daysInMonth(prevMonthDt.year, prevMonthDt.month);
      start = LocalDate(prevMonthDt.year, prevMonthDt.month, sd.clamp(1, prevDim));
    }

    // Next cycle starts in the following calendar month
    final nextMonthDt = DateTime(start.year, start.month + 1, 1);
    final nextDim = daysInMonth(nextMonthDt.year, nextMonthDt.month);
    final nextStart = LocalDate(nextMonthDt.year, nextMonthDt.month, sd.clamp(1, nextDim));

    final end = nextStart.addDays(-1);
    return PayCycle(start: start, endInclusive: end);
  }

  /// Partitions the pay cycle into standard Monday-to-Sunday student weeks,
  /// cleanly bounded by the cycle's start and end dates.
  List<CycleWeek> calendarWeeks() {
    final weeks = <CycleWeek>[];
    var currentStart = start;
    var w = 1;

    while (!currentStart.dateTime.isAfter(endInclusive.dateTime)) {
      final daysToSunday = DateTime.sunday - currentStart.weekday;
      final candidateEnd = currentStart.addDays(daysToSunday);
      final currentEnd = candidateEnd.dateTime.isAfter(endInclusive.dateTime)
          ? endInclusive
          : candidateEnd;

      weeks.add(CycleWeek(
        weekNumber: w++,
        start: currentStart,
        end: currentEnd,
      ));

      currentStart = currentEnd.addDays(1);
    }
    return weeks;
  }
}

class CycleWeek {
  const CycleWeek({
    required this.weekNumber,
    required this.start,
    required this.end,
  });

  final int weekNumber;
  final LocalDate start;
  final LocalDate end;

  int get lengthDays => end.dateTime.difference(start.dateTime).inDays + 1;

  bool contains(LocalDate d) {
    final t = d.dateTime;
    return !t.isBefore(start.dateTime) && !t.isAfter(end.dateTime);
  }
}
