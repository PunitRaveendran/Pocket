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

class Settings {
  const Settings({
    required this.stipendPaise,
    required this.cycleStartDay,
    required this.hideAmounts,
    required this.onboarded,
  });

  final int stipendPaise;
  final int cycleStartDay;
  final bool hideAmounts;
  final bool onboarded;

  Settings copyWith({
    int? stipendPaise,
    int? cycleStartDay,
    bool? hideAmounts,
    bool? onboarded,
  }) {
    return Settings(
      stipendPaise: stipendPaise ?? this.stipendPaise,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      hideAmounts: hideAmounts ?? this.hideAmounts,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  static const defaults = Settings(
    stipendPaise: 250000,
    cycleStartDay: 1,
    hideAmounts: false,
    onboarded: false,
  );
}

class Ledger {
  const Ledger({
    required this.settings,
    required this.categories,
    required this.transactions,
    required this.outings,
  });

  final Settings settings;
  final List<Category> categories;
  final List<Txn> transactions;
  final List<Outing> outings;

  List<Txn> get liveTxns => transactions;

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
