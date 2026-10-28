import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
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
  Future<Ledger> build() => _repo.load();

  Future<void> _reload() async {
    state = AsyncData(await _repo.load());
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

  Future<void> wipe() async {
    await _repo.wipe();
    await _reload();
  }
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
  final budget = const BudgetEngine().day(
    stipendPaise: ledger.settings.stipendPaise,
    cycle: cycle,
    date: day,
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
