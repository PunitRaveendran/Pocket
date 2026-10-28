import '../core/dates.dart';

enum Direction { debit, credit }

enum Bucket { daily, outing }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.isSystem,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String icon;
  final bool isSystem;
  final int sortOrder;
}

class Outing {
  const Outing({
    required this.id,
    required this.title,
    required this.localDate,
    required this.note,
  });

  final String id;
  final String title;
  final LocalDate localDate;
  final String note;
}

class Txn {
  const Txn({
    required this.id,
    required this.amountPaise,
    required this.direction,
    required this.occurredAtMs,
    required this.localDate,
    required this.merchant,
    required this.categoryId,
    required this.bucket,
    this.outingId,
    required this.note,
  });

  final String id;
  final int amountPaise;
  final Direction direction;
  final int occurredAtMs;
  final LocalDate localDate;
  final String merchant;
  final String categoryId;
  final Bucket bucket;
  final String? outingId;
  final String note;

  int get signedPaise => direction == Direction.debit ? amountPaise : -amountPaise;

  DateTime get occurredAt => DateTime.fromMillisecondsSinceEpoch(occurredAtMs);
}

enum PacingMode { daily, weekly }

enum SplitDirection { youAreOwed, youOwe }

class FriendSplit {
  const FriendSplit({
    required this.id,
    required this.friendName,
    required this.amountPaise,
    required this.direction,
    required this.occurredAtMs,
    required this.localDate,
    this.note = '',
    this.isSettled = false,
    this.settledAtMs,
  });

  final String id;
  final String friendName;
  final int amountPaise;
  final SplitDirection direction;
  final int occurredAtMs;
  final LocalDate localDate;
  final String note;
  final bool isSettled;
  final int? settledAtMs;

  int get signedPaise => direction == SplitDirection.youAreOwed ? amountPaise : -amountPaise;

  DateTime get occurredAt => DateTime.fromMillisecondsSinceEpoch(occurredAtMs);
  DateTime? get settledAt =>
      settledAtMs != null ? DateTime.fromMillisecondsSinceEpoch(settledAtMs!) : null;

  FriendSplit copyWith({
    String? id,
    String? friendName,
    int? amountPaise,
    SplitDirection? direction,
    int? occurredAtMs,
    LocalDate? localDate,
    String? note,
    bool? isSettled,
    int? settledAtMs,
  }) {
    return FriendSplit(
      id: id ?? this.id,
      friendName: friendName ?? this.friendName,
      amountPaise: amountPaise ?? this.amountPaise,
      direction: direction ?? this.direction,
      occurredAtMs: occurredAtMs ?? this.occurredAtMs,
      localDate: localDate ?? this.localDate,
      note: note ?? this.note,
      isSettled: isSettled ?? this.isSettled,
      settledAtMs: settledAtMs ?? this.settledAtMs,
    );
  }
}

class Settings {
  const Settings({
    required this.stipendPaise,
    required this.cycleStartDay,
    required this.hideAmounts,
    required this.onboarded,
    this.pacingMode = PacingMode.daily,
  });

  final int stipendPaise;
  final int cycleStartDay;
  final bool hideAmounts;
  final bool onboarded;
  final PacingMode pacingMode;

  Settings copyWith({
    int? stipendPaise,
    int? cycleStartDay,
    bool? hideAmounts,
    bool? onboarded,
    PacingMode? pacingMode,
  }) {
    return Settings(
      stipendPaise: stipendPaise ?? this.stipendPaise,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      onboarded: onboarded ?? this.onboarded,
      pacingMode: pacingMode ?? this.pacingMode,
    );
  }

  static const defaults = Settings(
    stipendPaise: 250000,
    cycleStartDay: 1,
    hideAmounts: false,
    onboarded: false,
    pacingMode: PacingMode.daily,
  );
}

class Ledger {
  const Ledger({
    required this.settings,
    required this.categories,
    required this.transactions,
    required this.outings,
    this.friendSplits = const [],
  });

  final Settings settings;
  final List<Category> categories;
  final List<Txn> transactions;
  final List<Outing> outings;
  final List<FriendSplit> friendSplits;

  List<Txn> get liveTxns => transactions;

  int get totalOwedToMePaise => friendSplits
      .where((s) => !s.isSettled && s.direction == SplitDirection.youAreOwed)
      .fold(0, (sum, s) => sum + s.amountPaise);

  int get totalIOwePaise => friendSplits
      .where((s) => !s.isSettled && s.direction == SplitDirection.youOwe)
      .fold(0, (sum, s) => sum + s.amountPaise);

  int get netFriendBalancePaise => totalOwedToMePaise - totalIOwePaise;

  Category? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Outing? outingById(String id) {
    for (final o in outings) {
      if (o.id == id) return o;
    }
    return null;
  }
}
