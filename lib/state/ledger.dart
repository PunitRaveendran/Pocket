import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/glance_widget.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../domain/budget.dart';

final databaseProvider = Provider<PocketDatabase>((ref) => PocketDatabase.instance);

final repositoryProvider = Provider<PocketRepository>(
  (ref) => PocketRepository(ref.watch(databaseProvider)),
);

final ledgerProvider = AsyncNotifierProvider<LedgerNotifier, Ledger>(LedgerNotifier.new);

class LedgerNotifier extends AsyncNotifier<Ledger> {
  PocketRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<Ledger> build() async {
    final ledger = await _repo.load();
    // Fire and forget widget update
    GlanceWidgetService.update(ledger);
    return ledger;
  }

  Future<void> _reload() async {
    final loaded = await _repo.load();
    state = AsyncData(loaded);
    GlanceWidgetService.update(loaded);
  }

  Future<void> completeOnboarding({
    required int stipendPaise,
    required int cycleStartDay,
  }) async {
    await _repo.saveSettings(
      Settings(
        stipendPaise: stipendPaise,
        cycleStartDay: cycleStartDay,
        hideAmounts: false,
        onboarded: true,
      ),
    );
    await _reload();
  }

  Future<void> updateSettings(Settings settings) async {
    await _repo.saveSettings(settings);
    await _reload();
  }

  Future<void> addCategory(String name, {String icon = 'custom'}) async {
    await _repo.addCategory(name, icon: icon);
    await _reload();
  }

  Future<void> deleteCategory(String id) async {
    await _repo.deleteCategory(id);
    await _reload();
  }

  Future<void> addDailySpend({
    required int amountPaise,
    required String categoryId,
    required LocalDate date,
    required String merchant,
    Direction direction = Direction.debit,
    String note = '',
    Txn? editing,
  }) async {
    if (editing != null) {
      await _repo.updateTxn(
        Txn(
          id: editing.id,
          amountPaise: amountPaise,
          direction: direction,
          occurredAtMs: editing.occurredAtMs,
          localDate: date,
          merchant: merchant,
          categoryId: categoryId,
          bucket: Bucket.daily,
          note: note,
        ),
      );
    } else {
      await _repo.addTxn(
        amountPaise: amountPaise,
        direction: direction,
        localDate: date,
        merchant: merchant,
        categoryId: categoryId,
        bucket: Bucket.daily,
        note: note,
      );
    }
    await _reload();
  }

  Future<void> addOutingWithSpend({
    required String title,
    required int amountPaise,
    required LocalDate date,
    String itemTitle = '',
    String note = '',
    String? existingOutingId,
  }) async {
    final outingId = existingOutingId ??
        (await _repo.addOuting(title: title, localDate: date, note: note)).id;
    await _repo.addTxn(
      amountPaise: amountPaise,
      direction: Direction.debit,
      localDate: date,
      merchant: itemTitle.isNotEmpty ? itemTitle : title,
      categoryId: 'misc',
      bucket: Bucket.outing,
      outingId: outingId,
      note: note,
    );
    await _reload();
  }

  Future<void> updateOuting(Outing outing) async {
    await _repo.updateOuting(outing);
    await _reload();
  }

  Future<void> deleteTxn(String id) async {
    await _repo.softDeleteTxn(id);
    await _reload();
  }

  Future<void> deleteOuting(String id) async {
    await _repo.softDeleteOuting(id);
    await _reload();
  }

  Future<void> setPacingMode(PacingMode mode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repo.saveSettings(current.settings.copyWith(pacingMode: mode));
    await _reload();
  }

  Future<void> addFriendSplit({
    required String friendName,
    required int amountPaise,
    required SplitDirection direction,
    required LocalDate date,
    String note = '',
    bool deductFromDaily = false,
  }) async {
    await _repo.addFriendSplit(
      friendName: friendName,
      amountPaise: amountPaise,
      direction: direction,
      localDate: date,
      note: note,
    );
    if (deductFromDaily && direction == SplitDirection.youAreOwed) {
      await _repo.addTxn(
        amountPaise: amountPaise,
        direction: Direction.debit,
        localDate: date,
        merchant: 'Lent to $friendName',
        categoryId: 'misc',
        bucket: Bucket.daily,
        note: note.isNotEmpty ? 'Split: $note' : 'Lent to $friendName',
      );
    }
    await _reload();
  }

  Future<void> updateFriendSplit(FriendSplit split) async {
    await _repo.updateFriendSplit(split);
    await _reload();
  }

  Future<void> settleFriendSplit(String id, {bool creditDaily = false}) async {
    await _repo.settleFriendSplit(id, creditDaily: creditDaily);
    await _reload();
  }

  Future<void> deleteFriendSplit(String id) async {
    await _repo.softDeleteFriendSplit(id);
    await _reload();
  }

  Future<void> borrowFromTomorrow({
    required int amountPaise,
    required LocalDate today,
  }) async {
    final tomorrow = today.addDays(1);
    await _repo.addTxn(
      amountPaise: amountPaise,
      direction: Direction.credit,
      localDate: today,
      merchant: "Borrowed from tomorrow's allowance",
      categoryId: 'misc',
      bucket: Bucket.daily,
      note: 'Overspend recovery',
    );
    await _repo.addTxn(
      amountPaise: amountPaise,
      direction: Direction.debit,
      localDate: tomorrow,
      merchant: 'Carried forward from yesterday',
      categoryId: 'misc',
      bucket: Bucket.daily,
      note: 'Overspend recovery',
    );
    await _reload();
  }

  Future<void> reclassifyTxnAsOuting(Txn txn, {String outingTitle = 'Overspend Splurge'}) async {
    final outing = await _repo.addOuting(
      title: outingTitle,
      localDate: txn.localDate,
      note: 'Reclassified from daily (${txn.merchant})',
    );
    await _repo.updateTxn(
      Txn(
        id: txn.id,
        amountPaise: txn.amountPaise,
        direction: txn.direction,
        occurredAtMs: txn.occurredAtMs,
        localDate: txn.localDate,
        merchant: txn.merchant,
        categoryId: txn.categoryId,
        bucket: Bucket.outing,
        outingId: outing.id,
        note: txn.note,
      ),
    );
    await _reload();
  }

  Future<void> addFixedDeduction({
    required String title,
    required int amountPaise,
    bool isEnabled = true,
  }) async {
    await _repo.addFixedDeduction(title: title, amountPaise: amountPaise, isEnabled: isEnabled);
    await _reload();
  }

  Future<void> updateFixedDeduction(FixedDeduction d) async {
    await _repo.updateFixedDeduction(d);
    await _reload();
  }

  Future<void> deleteFixedDeduction(String id) async {
    await _repo.deleteFixedDeduction(id);
    await _reload();
  }

  Future<void> setLeftoverPolicy(LeftoverPolicy policy) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repo.saveSettings(current.settings.copyWith(leftoverPolicy: policy));
    await _reload();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repo.saveSettings(current.settings.copyWith(biometricEnabled: enabled));
    await _reload();
  }

  Future<void> wipe() async {
    await _repo.wipe();
    await _reload();
  }
}

class WeekView {
  const WeekView({
    required this.budget,
    required this.txns,
    required this.topCategoryName,
    required this.topCategoryPaise,
    required this.cycle,
  });

  final WeekBudget budget;
  final List<Txn> txns;
  final String? topCategoryName;
  final int topCategoryPaise;
  final PayCycle cycle;
}

WeekView buildCurrentWeek(Ledger ledger, {LocalDate? date}) {
  final day = date ?? LocalDate.today();
  final cycle = PayCycle.containing(day, ledger.settings.cycleStartDay);
  final weeks = cycle.calendarWeeks();
  final currentWeek = weeks.firstWhere(
    (w) => w.contains(day),
    orElse: () => weeks.last,
  );

  final weekStart = currentWeek.start;
  final weekEnd = currentWeek.end;

  final weekTxns = ledger.transactions.where((t) {
    if (t.bucket != Bucket.daily) return false;
    final dt = t.localDate.dateTime;
    return !dt.isBefore(weekStart.dateTime) && !dt.isAfter(weekEnd.dateTime);
  }).toList();

  var spent = 0;
  var refunds = 0;
  final byCat = <String, int>{};
  for (final t in weekTxns) {
    if (t.direction == Direction.debit) {
      spent += t.amountPaise;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amountPaise;
    } else {
      refunds += t.amountPaise;
    }
  }

  String? topName;
  var topPaise = 0;
  byCat.forEach((id, v) {
    if (v > topPaise) {
      topPaise = v;
      topName = ledger.categoryById(id)?.name;
    }
  });

  const engine = BudgetEngine();
  var weekAllowance = 0;

  if (ledger.settings.leftoverPolicy == LeftoverPolicy.dynamicDistribute && cycle.contains(day)) {
    var spentBeforeWeek = 0;
    for (var d = cycle.start; d.dateTime.isBefore(weekStart.dateTime); d = d.addDays(1)) {
      for (final t in ledger.transactions) {
        if (t.bucket == Bucket.daily && t.localDate == d) {
          spentBeforeWeek += t.signedPaise;
        }
      }
    }
    final remainingStipend = ledger.settings.effectiveStipendPaise - spentBeforeWeek;
    final remainingDaysInCycle = cycle.endInclusive.dateTime.difference(weekStart.dateTime).inDays + 1;
    final daysInThisWeek = currentWeek.lengthDays;

    if (remainingDaysInCycle > 0 && remainingStipend > 0) {
      if (weekEnd == cycle.endInclusive) {
        // Final week of month receives full remaining balance
        weekAllowance = remainingStipend;
      } else {
        final dailyPace = remainingStipend ~/ remainingDaysInCycle;
        weekAllowance = dailyPace * daysInThisWeek;
      }
    } else {
      for (var d = weekStart; !d.dateTime.isAfter(weekEnd.dateTime); d = d.addDays(1)) {
        weekAllowance += engine.allowanceFor(
          stipendPaise: ledger.settings.effectiveStipendPaise,
          cycle: cycle,
          day: d,
        );
      }
    }
  } else {
    for (var d = weekStart; !d.dateTime.isAfter(weekEnd.dateTime); d = d.addDays(1)) {
      weekAllowance += engine.allowanceFor(
        stipendPaise: ledger.settings.effectiveStipendPaise,
        cycle: cycle,
        day: d,
      );
    }
  }

  final budget = WeekBudget(
    startDate: weekStart,
    endDate: weekEnd,
    allowancePaise: weekAllowance,
    spentPaise: spent,
    refundsPaise: refunds,
    weekNumber: currentWeek.weekNumber,
    totalWeeks: weeks.length,
  );

  return WeekView(
    budget: budget,
    txns: weekTxns,
    topCategoryName: topName,
    topCategoryPaise: topPaise,
    cycle: cycle,
  );
}

class TodayView {
  const TodayView({
    required this.budget,
    required this.txns,
    required this.topCategoryName,
    required this.topCategoryPaise,
    required this.cycle,
  });

  final DayBudget budget;
  final List<Txn> txns;
  final String? topCategoryName;
  final int topCategoryPaise;
  final PayCycle cycle;
}

TodayView buildToday(Ledger ledger, {LocalDate? date}) {
  final day = date ?? LocalDate.today();
  final cycle = PayCycle.containing(day, ledger.settings.cycleStartDay);
  final daily = ledger.transactions
      .where((t) => t.bucket == Bucket.daily && t.localDate == day)
      .toList();
  var spent = 0;
  var refunds = 0;
  final byCat = <String, int>{};
  for (final t in daily) {
    if (t.direction == Direction.debit) {
      spent += t.amountPaise;
      byCat[t.categoryId] = (byCat[t.categoryId] ?? 0) + t.amountPaise;
    } else {
      refunds += t.amountPaise;
    }
  }
  String? topName;
  var topPaise = 0;
  byCat.forEach((id, v) {
    if (v > topPaise) {
      topPaise = v;
      topName = ledger.categoryById(id)?.name;
    }
  });

  int allowancePaise;
  if (ledger.settings.leftoverPolicy == LeftoverPolicy.dynamicDistribute && cycle.contains(day)) {
    var spentBefore = 0;
    for (var d = cycle.start; d.dateTime.isBefore(day.dateTime); d = d.addDays(1)) {
      for (final t in ledger.transactions) {
        if (t.bucket == Bucket.daily && t.localDate == d) {
          spentBefore += t.signedPaise;
        }
      }
    }
    final remainingStipend = ledger.settings.effectiveStipendPaise - spentBefore;
    final remainingDays = cycle.endInclusive.dateTime.difference(day.dateTime).inDays + 1;
    if (remainingDays > 0 && remainingStipend > 0) {
      final base = remainingStipend ~/ remainingDays;
      final leftover = remainingStipend % remainingDays;
      allowancePaise = cycle.isLastDay(day) ? (base + leftover) : base;
    } else {
      allowancePaise = const BudgetEngine().allowanceFor(
        stipendPaise: ledger.settings.effectiveStipendPaise,
        cycle: cycle,
        day: day,
      );
    }
  } else {
    allowancePaise = const BudgetEngine().allowanceFor(
      stipendPaise: ledger.settings.effectiveStipendPaise,
      cycle: cycle,
      day: day,
    );
  }

  final budget = DayBudget(
    date: day,
    allowancePaise: allowancePaise,
    spentPaise: spent,
    refundsPaise: refunds,
  );
  return TodayView(
    budget: budget,
    txns: daily,
    topCategoryName: topName,
    topCategoryPaise: topPaise,
    cycle: cycle,
  );
}

int extraThisCycle(Ledger ledger, PayCycle cycle) {
  var sum = 0;
  for (final t in ledger.transactions) {
    if (t.bucket != Bucket.outing) continue;
    if (!cycle.contains(t.localDate)) continue;
    if (t.direction == Direction.debit) sum += t.amountPaise;
    if (t.direction == Direction.credit) sum -= t.amountPaise;
  }
  return sum;
}

int ordinaryThisCycle(Ledger ledger, PayCycle cycle) {
  var sum = 0;
  for (final t in ledger.transactions) {
    if (t.bucket != Bucket.daily) continue;
    if (!cycle.contains(t.localDate)) continue;
    if (t.direction == Direction.debit) sum += t.amountPaise;
    if (t.direction == Direction.credit) sum -= t.amountPaise;
  }
  return sum;
}

int safeDailyPace(Ledger ledger, PayCycle cycle, LocalDate day) {
  final ordinary = ordinaryThisCycle(ledger, cycle);
  final remainingStipend = ledger.settings.effectiveStipendPaise - ordinary;
  final daysRemaining = cycle.endInclusive.dateTime.difference(day.dateTime).inDays + 1;
  return (daysRemaining > 0 && remainingStipend > 0) ? remainingStipend ~/ daysRemaining : 0;
}

int outingsPiggyBank(Ledger ledger, PayCycle cycle, LocalDate today) {
  const engine = BudgetEngine();
  final stipend = ledger.settings.effectiveStipendPaise;
  var savings = 0;
  for (var d = cycle.start; d.dateTime.isBefore(today.dateTime); d = d.addDays(1)) {
    final allow = engine.allowanceFor(stipendPaise: stipend, cycle: cycle, day: d);
    final spent = ledger.transactions
        .where((t) => t.bucket == Bucket.daily && t.localDate == d)
        .fold<int>(0, (sum, t) => sum + t.signedPaise);
    if (spent < allow) {
      savings += (allow - spent);
    }
  }
  return savings;
}
