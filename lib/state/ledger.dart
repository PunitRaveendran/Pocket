import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/slice_email_sync.dart';
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
  bool _isSyncingSlice = false;
  bool get isSyncingSlice => _isSyncingSlice;

  @override
  Future<Ledger> build() async {
    final ledger = await _repo.load();
    if (ledger.settings.emailSyncEnabled &&
        ledger.settings.emailSyncAddress.isNotEmpty &&
        ledger.settings.emailSyncAppPassword.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () => syncSliceEmails());
    }
    return ledger;
  }

  Future<void> _reload() async {
    final loaded = await _repo.load();
    state = AsyncData(loaded);
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
    await _repo.addOutingWithSpend(
      title: title,
      amountPaise: amountPaise,
      date: date,
      itemTitle: itemTitle,
      note: note,
      existingOutingId: existingOutingId,
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

  Future<FriendSplit> addFriendSplit({
    required String friendName,
    required int amountPaise,
    required SplitDirection direction,
    required LocalDate date,
    String note = '',
    bool deductFromDaily = false,
  }) async {
    final split = await _repo.addFriendSplit(
      friendName: friendName,
      amountPaise: amountPaise,
      direction: direction,
      localDate: date,
      note: note,
      deductFromDaily: deductFromDaily,
    );
    await _reload();
    return split;
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

  Future<void> splitBill({
    required int totalAmountPaise,
    required int mySharePaise,
    required List<({String friendName, int amountPaise})> friends,
    required LocalDate date,
    required String categoryId,
    required String merchant,
    String note = '',
    String? pendingInboxId,
  }) async {
    await _repo.splitBill(
      totalAmountPaise: totalAmountPaise,
      mySharePaise: mySharePaise,
      friends: friends,
      date: date,
      categoryId: categoryId,
      merchant: merchant,
      note: note,
      pendingInboxId: pendingInboxId,
    );
    await _reload();
  }

  Future<void> borrowFromTomorrow({
    required int amountPaise,
    required LocalDate today,
  }) async {
    await _repo.borrowFromTomorrow(amountPaise: amountPaise, today: today);
    await _reload();
  }

  Future<void> reclassifyTxnAsOuting(Txn txn, {String outingTitle = 'Overspend Splurge'}) async {
    await _repo.reclassifyTxnAsOuting(txn, outingTitle: outingTitle);
    await _reload();
  }

  Future<SliceSyncResult> syncSliceEmails({bool force = false}) async {
    if (_isSyncingSlice) {
      return const SliceSyncResult(
        success: true,
        errorMessage: null,
      );
    }

    var ledger = state.valueOrNull;
    if (ledger == null) {
      try {
        ledger = await _repo.load();
      } catch (e) {
        return SliceSyncResult(
          success: false,
          errorMessage: 'Ledger is not ready: $e',
        );
      }
    }

    final s = ledger.settings;
    if (!force && !s.emailSyncEnabled) {
      return const SliceSyncResult(
        success: false,
        errorMessage: 'Email sync is disabled in Settings.',
      );
    }

    if (s.emailSyncAddress.trim().isEmpty || s.emailSyncAppPassword.trim().isEmpty) {
      return const SliceSyncResult(
        success: false,
        errorMessage: 'Please configure your Gmail address and Google App Password in Settings.',
      );
    }

    _isSyncingSlice = true;
    try {
      const service = SliceEmailSyncService();
      final result = await service.sync(
        email: s.emailSyncAddress,
        appPassword: s.emailSyncAppPassword,
        sender: s.emailSyncSender.trim().isEmpty ? 'noreply@slice.bank.in' : s.emailSyncSender.trim(),
        isAlreadyProcessed: (msgId) => _repo.isEmailMessageProcessed(msgId),
      );

      if (result.success && result.transactions.isNotEmpty) {
        final pendingList = result.transactions.map((p) {
          return PendingTransaction(
            id: '',
            amountPaise: p.amountPaise,
            direction: p.isDebit ? Direction.debit : Direction.credit,
            occurredAtMs: p.occurredAt.millisecondsSinceEpoch,
            localDate: p.localDate,
            merchant: p.merchant,
            rawSource: 'slice_email',
            messageId: p.messageId,
            status: InboxStatus.pending,
          );
        }).toList();

        await _repo.addPendingTransactions(pendingList);
      }

      if (result.success) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await _repo.saveSettings(s.copyWith(emailSyncLastSyncedMs: now));
      }

      await _reload();
      return result;
    } finally {
      _isSyncingSlice = false;
    }
  }

  Future<SliceSyncResult> clearPendingAndResync() async {
    await _repo.clearPendingInbox();
    return syncSliceEmails();
  }

  Future<Txn> approveInboxTransaction(
    PendingTransaction pending, {
    required String categoryId,
    Bucket bucket = Bucket.daily,
    String? outingId,
    String? note,
  }) async {
    final txn = await _repo.approvePendingTransaction(
      pending,
      categoryId: categoryId,
      bucket: bucket,
      outingId: outingId,
      note: note,
    );
    await _reload();
    return txn;
  }

  Future<void> dismissInboxTransaction(String id) async {
    await _repo.dismissPendingTransaction(id);
    await _reload();
  }

  /// Compacts and defragments database pages and re-optimizes query planner statistics.
  Future<void> optimizeStorage() async {
    await _repo.optimizeDatabase();
    await _reload();
  }

  /// Retrieves on-disk storage size of the local SQLite database in bytes.
  Future<int> getStorageSizeBytes() => _repo.getStorageSizeBytes();

  /// Permanently removes soft-deleted records older than [olderThanDays] and vacuums the database.
  Future<int> purgeDeletedRecords({int olderThanDays = 30}) async {
    final count = await _repo.purgeDeletedRecords(olderThanDays: olderThanDays);
    if (count > 0) {
      await _reload();
    }
    return count;
  }

  /// Checks SQLite database integrity.
  Future<String> checkIntegrity() => _repo.checkIntegrity();

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

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _repo.saveSettings(current.settings.copyWith(appThemeMode: mode));
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
    } else if (t.categoryId != 'income' && !t.note.toLowerCase().contains('top-up')) {
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
  final cycleStipend = effectiveStipendForCycle(ledger, cycle);
  var weekAllowance = 0;

  if (ledger.settings.leftoverPolicy == LeftoverPolicy.dynamicDistribute && cycle.contains(day)) {
    var spentBeforeWeek = 0;
    for (var d = cycle.start; d.dateTime.isBefore(weekStart.dateTime); d = d.addDays(1)) {
      for (final t in ledger.transactions) {
        if (t.bucket == Bucket.daily && t.localDate == d) {
          if (t.direction == Direction.debit) {
            spentBeforeWeek += t.amountPaise;
          } else if (t.categoryId != 'income' && !t.note.toLowerCase().contains('top-up')) {
            spentBeforeWeek -= t.amountPaise;
          }
        }
      }
    }
    final remainingStipend = (cycleStipend - spentBeforeWeek).clamp(0, 999999999);
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
          stipendPaise: cycleStipend,
          cycle: cycle,
          day: d,
        );
      }
    }
  } else {
    for (var d = weekStart; !d.dateTime.isAfter(weekEnd.dateTime); d = d.addDays(1)) {
      weekAllowance += engine.allowanceFor(
        stipendPaise: cycleStipend,
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
    } else if (t.categoryId != 'income' && !t.note.toLowerCase().contains('top-up')) {
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

  final cycleStipend = effectiveStipendForCycle(ledger, cycle);
  int allowancePaise;
  if (ledger.settings.leftoverPolicy == LeftoverPolicy.dynamicDistribute && cycle.contains(day)) {
    var spentBefore = 0;
    for (final t in ledger.transactions) {
      if (t.bucket == Bucket.daily && cycle.contains(t.localDate) && t.localDate.isBefore(day)) {
        if (t.direction == Direction.debit) {
          spentBefore += t.amountPaise;
        } else if (t.categoryId != 'income' && !t.note.toLowerCase().contains('top-up')) {
          spentBefore -= t.amountPaise;
        }
      }
    }
    final remainingStipend = cycleStipend - spentBefore;
    final remainingDays = cycle.endInclusive.dateTime.difference(day.dateTime).inDays + 1;
    if (remainingDays > 0 && remainingStipend > 0) {
      final base = remainingStipend ~/ remainingDays;
      final leftover = remainingStipend % remainingDays;
      allowancePaise = cycle.isLastDay(day) ? (base + leftover) : base;
    } else {
      allowancePaise = const BudgetEngine().allowanceFor(
        stipendPaise: cycleStipend,
        cycle: cycle,
        day: day,
      );
    }
  } else {
    allowancePaise = const BudgetEngine().allowanceFor(
      stipendPaise: cycleStipend,
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

int extraTopUpForCycle(Ledger ledger, PayCycle cycle) {
  var topUp = 0;
  for (final t in ledger.transactions) {
    if (cycle.contains(t.localDate) &&
        t.direction == Direction.credit &&
        (t.categoryId == 'income' || t.note.toLowerCase().contains('top-up') || t.note.toLowerCase().contains('extra money'))) {
      topUp += t.amountPaise;
    }
  }
  return topUp;
}

int ordinaryThisCycle(Ledger ledger, PayCycle cycle) {
  var sum = 0;
  for (final t in ledger.transactions) {
    if (t.bucket != Bucket.daily) continue;
    if (!cycle.contains(t.localDate)) continue;
    if (t.direction == Direction.debit) sum += t.amountPaise;
    if (t.direction == Direction.credit && t.categoryId != 'income' && !t.note.toLowerCase().contains('top-up')) {
      sum -= t.amountPaise;
    }
  }
  return sum;
}

/// Unspent savings rolled over from the previous cycle if [Settings.rolloverUnspent] is enabled.
int rolloverSavingsFromPreviousCycle(Ledger ledger, PayCycle currentCycle) {
  if (!ledger.settings.rolloverUnspent) return 0;
  final prevDay = currentCycle.start.addDays(-1);
  final prevCycle = PayCycle.containing(prevDay, ledger.settings.cycleStartDay);

  // Only roll over if the user was actively logging in that previous cycle
  final hasPrevTxns = ledger.transactions.any((t) => prevCycle.contains(t.localDate));
  if (!hasPrevTxns) return 0;

  final prevEffective = effectiveStipendForCycle(ledger, prevCycle, checkPrior: false);
  final prevSpent = ordinaryThisCycle(ledger, prevCycle);
  final leftover = prevEffective - prevSpent;
  return leftover > 0 ? leftover : 0;
}

/// The effective stipend for [cycle], incorporating unspent rollover from the prior cycle
/// if [Settings.rolloverUnspent] is active, plus any extra stipend top-ups added in this cycle.
int effectiveStipendForCycle(Ledger ledger, PayCycle cycle, {bool checkPrior = true}) {
  final base = ledger.settings.effectiveStipendPaise;
  final topUps = extraTopUpForCycle(ledger, cycle);
  if (!ledger.settings.rolloverUnspent || !checkPrior) return base + topUps;

  final rollover = rolloverSavingsFromPreviousCycle(ledger, cycle);
  return base + rollover + topUps;
}

int safeDailyPace(Ledger ledger, PayCycle cycle, LocalDate day) {
  final ordinary = ordinaryThisCycle(ledger, cycle);
  final cycleStipend = effectiveStipendForCycle(ledger, cycle);
  final remainingStipend = cycleStipend - ordinary;
  final daysRemaining = cycle.endInclusive.dateTime.difference(day.dateTime).inDays + 1;
  return (daysRemaining > 0 && remainingStipend > 0) ? remainingStipend ~/ daysRemaining : 0;
}

int outingsPiggyBank(Ledger ledger, PayCycle cycle, LocalDate today) {
  const engine = BudgetEngine();
  final stipend = effectiveStipendForCycle(ledger, cycle);

  // Single-pass O(N) daily aggregation
  final dailySpentMap = <LocalDate, int>{};
  for (final t in ledger.transactions) {
    if (t.bucket == Bucket.daily &&
        cycle.contains(t.localDate) &&
        t.localDate.isBefore(today) &&
        t.categoryId != 'income' &&
        !t.note.toLowerCase().contains('top-up')) {
      dailySpentMap[t.localDate] = (dailySpentMap[t.localDate] ?? 0) + t.signedPaise;
    }
  }

  var savings = 0;
  for (var d = cycle.start; d.isBefore(today); d = d.addDays(1)) {
    final allow = engine.allowanceFor(stipendPaise: stipend, cycle: cycle, day: d);
    final spent = dailySpentMap[d] ?? 0;
    if (spent < allow) {
      savings += (allow - spent);
    }
  }
  return savings;
}
