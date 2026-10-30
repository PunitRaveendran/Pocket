import 'dates.dart';

class ParsedEmailTransaction {
  const ParsedEmailTransaction({
    required this.amountPaise,
    required this.merchant,
    required this.isDebit,
    required this.occurredAt,
    this.messageId,
    this.rawSnippet = '',
  });

  final int amountPaise;
  final String merchant;
  final bool isDebit;
  final DateTime occurredAt;
  final String? messageId;
  final String rawSnippet;

  LocalDate get localDate => LocalDate.fromDateTime(occurredAt);
}

/// 100% on-device regular expression parser for Slice Bank and UPI transaction emails.
class SliceEmailParser {
  const SliceEmailParser._();

  static final _amountRegex = RegExp(
    r'(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _debitRegex = RegExp(
    r'\b(?:debited|paid|spent|sent|transferred|withdrawn|purchase)\b',
    caseSensitive: false,
  );

  static final _creditRegex = RegExp(
    r'\b(?:credited|received|refunded|added|cashback)\b',
    caseSensitive: false,
  );

  // Table key-value receiver (Debit: e.g. "To\nAkhil Asok\nRRN" or "Paid to: Akhil Asok" or "To   Akhil Asok")
  static final _tableReceiverRegex = RegExp(
    r'(?:^|\n)[ \t]*(?:To|Paid to|Transfer to|Sent to)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*)',
    caseSensitive: false,
  );

  // Table key-value sender (Credit: e.g. "From\nSwiggy\nRRN" or "Received from: Sneha" or "From   Swiggy")
  static final _tableSenderRegex = RegExp(
    r'(?:^|\n)[ \t]*(?:From|Received from|Refund from|Sender)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*)',
    caseSensitive: false,
  );

  // Table date (e.g. "Transaction date\n29-Oct-26" or "Transaction date   29-Oct-26")
  static final _dateRegex = RegExp(
    r'(?:Transaction date|Date)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*(\d{1,2})[-/ ]([A-Za-z]{3}|\d{1,2})[-/ ](\d{2,4})',
    caseSensitive: false,
  );

  static final _rrnRegex = RegExp(
    r'(?:RRN|UPI Ref(?: ID)?|Ref No)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*(\d+)',
    caseSensitive: false,
  );

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static DateTime? _extractDate(String text, DateTime? fallback) {
    final m = _dateRegex.firstMatch(text);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final rawMonth = m.group(2)!.toLowerCase();
      var month = int.tryParse(rawMonth);
      if (month == null && _months.containsKey(rawMonth)) {
        month = _months[rawMonth];
      }
      var year = int.tryParse(m.group(3)!);
      if (year != null && year < 100) {
        year += 2000;
      }
      if (day != null && month != null && year != null) {
        final hour = fallback?.hour ?? 12;
        final minute = fallback?.minute ?? 0;
        final second = fallback?.second ?? 0;
        return DateTime(year, month, day, hour, minute, second);
      }
    }
    return fallback;
  }

  // Inline debit matchers (looking for receiver)
  static final _inlineDebitRegexes = [
    RegExp(
      r'(?:paid to|sent to|transfer to|towards|at|paid)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bto[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
  ];

  // Inline credit matchers (looking for sender)
  static final _inlineCreditRegexes = [
    RegExp(
      r'(?:received from|refund from|cashback from)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bfrom[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
  ];

  static ParsedEmailTransaction? parse({
    required String subject,
    required String bodyText,
    DateTime? emailDate,
    String? messageId,
  }) {
    final combined = '$subject\n$bodyText'.trim();
    if (combined.isEmpty) return null;

    final isDebit = _debitRegex.hasMatch(combined);
    final isCredit = _creditRegex.hasMatch(combined);

    // If it's neither debit nor credit (e.g. OTP, terms update), ignore
    if (!isDebit && !isCredit) return null;

    final match = _amountRegex.firstMatch(combined);
    if (match == null) return null;

    final rawAmountStr = match.group(1)?.replaceAll(',', '') ?? '';
    final amountFloat = double.tryParse(rawAmountStr);
    if (amountFloat == null || amountFloat <= 0) return null;
    final amountPaise = (amountFloat * 100).round();

    var merchant = '';

    // Priority 1: Check table key-value format in body text
    final tableRegex = isDebit ? _tableReceiverRegex : _tableSenderRegex;
    final tableMatch = tableRegex.firstMatch(bodyText);
    if (tableMatch != null && tableMatch.group(1) != null) {
      final cand = _cleanMerchant(tableMatch.group(1)!);
      if (cand.isNotEmpty && !_isNoise(cand)) {
        merchant = cand;
      }
    }

    final inlineRegexes = isDebit ? _inlineDebitRegexes : _inlineCreditRegexes;

    // Priority 2: Look in the subject line
    if (merchant.isEmpty && subject.isNotEmpty) {
      for (final r in inlineRegexes) {
        final m = r.firstMatch(subject);
        if (m != null && m.group(1) != null) {
          final cand = _cleanMerchant(m.group(1)!);
          if (cand.isNotEmpty && !_isNoise(cand)) {
            merchant = cand;
            break;
          }
        }
      }
    }

    // Priority 3: Look inline in body text
    if (merchant.isEmpty) {
      for (final r in inlineRegexes) {
        for (final m in r.allMatches(bodyText)) {
          if (m.group(1) != null) {
            final cand = _cleanMerchant(m.group(1)!);
            if (cand.isNotEmpty && !_isNoise(cand)) {
              merchant = cand;
              break;
            }
          }
        }
        if (merchant.isNotEmpty) break;
      }
    }

    if (merchant.isEmpty) {
      merchant = isDebit ? 'Slice Payment' : 'Slice Refund';
    }

    final occurredAt = _extractDate(combined, emailDate) ?? emailDate ?? DateTime.now();

    String snippet = subject.isNotEmpty ? subject : combined.substring(0, combined.length.clamp(0, 100));
    final rrnMatch = _rrnRegex.firstMatch(combined);
    if (rrnMatch != null && rrnMatch.group(1) != null) {
      snippet = '$snippet (RRN: ${rrnMatch.group(1)})';
    }

    return ParsedEmailTransaction(
      amountPaise: amountPaise,
      merchant: merchant,
      isDebit: isDebit || !isCredit,
      occurredAt: occurredAt,
      messageId: messageId,
      rawSnippet: snippet,
    );
  }

  static String _cleanMerchant(String raw) {
    var s = raw.trim();
    // Strip trailing punctuation
    s = s.replaceAll(RegExp(r'[\s.,;:\-_]+$'), '');
    s = s.replaceAll(RegExp(r'^[\s.,;:\-_]+'), '');
    // Collapse spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  static bool _isNoise(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.length < 2) return true;
    if (lower.contains('slice account') ||
        lower.contains('slice bank') ||
        lower.contains('your slice') ||
        lower.contains('your bank') ||
        lower.contains('bank account') ||
        lower.contains('slice app') ||
        lower.startsWith('xx') ||
        lower == 'rrn' ||
        lower == 'upi' ||
        lower == 'slice' ||
        lower == 'digital safety' ||
        lower == 'digital safety tips') {
      return true;
    }
    const noiseWords = [
      'the',
      'your',
      'account',
      'bank',
      'rs',
      'inr',
      'success',
      'successful',
    ];
    return noiseWords.contains(lower);
  }
}
