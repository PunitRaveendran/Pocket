import '../core/dates.dart';

class DayBudget {
  const DayBudget({
    required this.date,
    required this.allowancePaise,
    required this.spentPaise,
    required this.refundsPaise,
  });

  final LocalDate date;
  final int allowancePaise;
  final int spentPaise;
  final int refundsPaise;

  int get netSpent => spentPaise - refundsPaise;
  int get remaining => allowancePaise - netSpent;
  bool get isOver => remaining < 0;
  double get usedRatio {
    if (allowancePaise <= 0) return netSpent > 0 ? 2 : 0;
    return netSpent / allowancePaise;
  }
}

class WeekBudget {
  const WeekBudget({
    required this.startDate,
    required this.endDate,
    required this.allowancePaise,
    required this.spentPaise,
    required this.refundsPaise,
    required this.weekNumber,
    required this.totalWeeks,
  });

  final LocalDate startDate;
  final LocalDate endDate;
  final int allowancePaise;
  final int spentPaise;
  final int refundsPaise;
  final int weekNumber;
  final int totalWeeks;

  int get netSpent => spentPaise - refundsPaise;
  int get remaining => allowancePaise - netSpent;
  bool get isOver => remaining < 0;
  double get usedRatio {
    if (allowancePaise <= 0) return netSpent > 0 ? 2 : 0;
    return netSpent / allowancePaise;
  }
}

class BudgetEngine {
  const BudgetEngine();

  /// Daily slice of the stipend. Leftover paise from integer division
  /// land on the last day of the cycle.
  int allowanceFor({
    required int stipendPaise,
    required PayCycle cycle,
    required LocalDate day,
  }) {
    if (stipendPaise <= 0 || cycle.lengthDays <= 0) return 0;
    final base = stipendPaise ~/ cycle.lengthDays;
    final leftover = stipendPaise % cycle.lengthDays;
    if (cycle.isLastDay(day)) return base + leftover;
    return base;
  }

  DayBudget day({
    required int stipendPaise,
    required PayCycle cycle,
    required LocalDate date,
    required int spentPaise,
    required int refundsPaise,
  }) {
    return DayBudget(
      date: date,
      allowancePaise: allowanceFor(
        stipendPaise: stipendPaise,
        cycle: cycle,
        day: date,
      ),
      spentPaise: spentPaise,
      refundsPaise: refundsPaise,
    );
  }
}
