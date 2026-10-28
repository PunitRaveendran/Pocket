import '../data/models.dart';

class LedgerExport {
  const LedgerExport._();

  static String toCsv(Ledger ledger) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Date,Time,Bucket,Category,Type,Title/Merchant,Note,Amount (Rupees),Outing');

    final sorted = List<Txn>.from(ledger.transactions)
      ..sort((a, b) => b.occurredAtMs.compareTo(a.occurredAtMs));

    for (final t in sorted) {
      final date = t.localDate.ymd;
      final time = _formatTime(t.occurredAt);
      final bucket = t.bucket == Bucket.outing ? 'Outing' : 'Daily';
      final category = ledger.categoryById(t.categoryId)?.name ?? 'Misc';
      final type = t.direction == Direction.credit ? 'Credit/Refund' : 'Expense';
      final merchant = _escapeCsv(t.merchant);
      final note = _escapeCsv(t.note);
      final rupees = (t.amountPaise / 100).toStringAsFixed(2);
      final outing = t.outingId != null ? _escapeCsv(ledger.outingById(t.outingId!)?.title ?? '') : '';

      buffer.writeln('$date,$time,$bucket,$category,$type,$merchant,$note,$rupees,$outing');
    }

    return buffer.toString();
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
