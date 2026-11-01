import 'dates.dart';

class BankPreset {
  const BankPreset({
    required this.id,
    required this.name,
    required this.senders,
    this.shortName,
  });

  final String id;
  final String name;
  final List<String> senders;
  final String? shortName;

  String get displayName => shortName ?? name;
}

class BankPresets {
  const BankPresets._();

  static const slice = BankPreset(
    id: 'slice',
    name: 'Slice Bank',
    shortName: 'Slice',
    senders: ['noreply@slice.bank.in', 'alerts@sliceit.com'],
  );

  static const hdfc = BankPreset(
    id: 'hdfc',
    name: 'HDFC Bank',
    shortName: 'HDFC',
    senders: ['alerts@hdfcbank.net', 'instalerts@hdfcbank.bank.in'],
  );

  static const sbi = BankPreset(
    id: 'sbi',
    name: 'State Bank of India',
    shortName: 'SBI',
    senders: ['alerts@sbi.co.in', 'donotreply@sbi.co.in'],
  );

  static const icici = BankPreset(
    id: 'icici',
    name: 'ICICI Bank',
    shortName: 'ICICI',
    senders: ['credit_cards@icicibank.com', 'alerts@icicibank.com'],
  );

  static const axis = BankPreset(
    id: 'axis',
    name: 'Axis Bank',
    shortName: 'Axis',
    senders: ['alerts@axisbank.com', 'creditcards@axisbank.com'],
  );

  static const kotak = BankPreset(
    id: 'kotak',
    name: 'Kotak Mahindra Bank',
    shortName: 'Kotak',
    senders: ['alerts@kotak.com', 'noreply@kotak.com'],
  );

  static const jupiterFi = BankPreset(
    id: 'jupiter_fi',
    name: 'Jupiter / Fi / Federal',
    shortName: 'Jupiter/Fi',
    senders: ['support@jupiter.money', 'alerts@fi.money', 'alerts@federalbank.co.in'],
  );

  static const all = [
    slice,
    hdfc,
    sbi,
    icici,
    axis,
    kotak,
    jupiterFi,
  ];

  static List<String> get allSenders => all.expand((b) => b.senders).toList();

  static const String defaultSendersString =
      'noreply@slice.bank.in, alerts@sliceit.com, alerts@hdfcbank.net, instalerts@hdfcbank.bank.in, alerts@sbi.co.in, donotreply@sbi.co.in, credit_cards@icicibank.com, alerts@icicibank.com, alerts@axisbank.com, creditcards@axisbank.com, alerts@kotak.com, noreply@kotak.com, support@jupiter.money, alerts@fi.money, alerts@federalbank.co.in';
}

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

/// 100% on-device universal parser for Indian bank and UPI transaction emails
/// (Slice, HDFC, SBI, ICICI, Axis, Kotak, Jupiter/Fi, Federal Bank, etc.).
class BankEmailParser {
  const BankEmailParser._();

  static final _amountPrefixRegex = RegExp(
    r'(?:₹|rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _amountPostfixRegex = RegExp(
    r'\b([\d,]+(?:\.\d{1,2})?)\s*(?:₹|rs\.?|inr)\b',
    caseSensitive: false,
  );

  static final _debitRegex = RegExp(
    r'\b(?:debited|paid|spent|sent|transferred|withdrawn|purchase|charged)\b',
    caseSensitive: false,
  );

  static final _creditRegex = RegExp(
    r'\b(?:credited|received|refunded|added|cashback|deposited)\b',
    caseSensitive: false,
  );

  // Table key-value receiver (Debit: e.g. "To\nAkhil Asok\nRRN" or "Paid to: Akhil Asok" or "To   Akhil Asok" or "Beneficiary: ...")
  static final _tableReceiverRegex = RegExp(
    r'(?:^|\n)[ \t]*(?:To|Paid to|Transfer to|Sent to|Beneficiary|Receiver|Merchant)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*)',
    caseSensitive: false,
  );

  // Table key-value sender (Credit: e.g. "From\nSwiggy\nRRN" or "Received from: Sneha" or "From   Swiggy")
  static final _tableSenderRegex = RegExp(
    r'(?:^|\n)[ \t]*(?:From|Received from|Refund from|Sender)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t)[ \t]*([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*)',
    caseSensitive: false,
  );

  // Table or inline date (e.g. "Transaction date\n29-Oct-26", "29-10-2026", "29Oct26", "on 28-OCT-26")
  static final _dateRegex = RegExp(
    r'(?:Transaction date|Date|on)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t|[ \t]+)[ \t]*(\d{1,2})[-/ ]?([A-Za-z]{3}|\d{1,2})[-/ ]?(\d{2,4})',
    caseSensitive: false,
  );

  static final _rrnRegex = RegExp(
    r'(?:RRN|UPI Ref(?: ID| no)?|Ref No|txn id|Ref)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t|[ \t]+)[ \t]*(\d+)',
    caseSensitive: false,
  );

  // UPI Info tag format (e.g. "Info: UPI*ZOMATO*630246906599*Pay" in ICICI/HDFC/Axis)
  static final _upiInfoRegex = RegExp(
    r'(?:Info|Details)?[ \t]*:?[ \t]*UPI[*\/]([A-Za-z0-9&.\-_]+)',
    caseSensitive: false,
  );

  // VPA receiver format (e.g. "to VPA swiggy@icici" or "to chaipoint@hdfcbank")
  static final _vpaRegex = RegExp(
    r'to VPA[ \t]+([A-Za-z0-9.\-_]+)@',
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

  // Inline debit matchers (looking for receiver/merchant)
  static final _inlineDebitRegexes = [
    // "spent on your HDFC Bank Card ending 1234 at AMAZON INDIA on 29-10-2026"
    RegExp(
      r'spent on [^.\n]+ at ([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:on|using|via|with|ref|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "UPI transaction of Rs. 450.00 to SWIGGY"
    RegExp(
      r'UPI transaction of [^.\n]+ to ([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "debited ... to/towards/transfer to/at <merchant>" (e.g. HDFC, SBI, Axis)
    RegExp(
      r'debited [^.\n]*?(?:transfer to|towards UPI payment to|towards|to|at)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|txn|from|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "paid to / sent to / transfer to / towards <merchant>"
    RegExp(
      r'(?:paid to|sent to|transfer to|towards payment to|towards)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "at <merchant>" or "paid <merchant>"
    RegExp(
      r'\b(?:at|paid)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "to <merchant>"
    RegExp(
      r'\bto[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
      caseSensitive: false,
    ),
  ];

  // Inline credit matchers (looking for sender)
  static final _inlineCreditRegexes = [
    // "credited ... by transfer from / from / by <sender>"
    RegExp(
      r'credited [^.\n]*?(?:by transfer from|from transfer from|from|by)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|txn)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // "received from / refund from / cashback from / transfer from <sender>"
    RegExp(
      r'(?:received from|refund from|cashback from|transfer from)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|upi|with|for|is|account)|\.|\n|<|$)',
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

    final match = _amountPrefixRegex.firstMatch(combined) ?? _amountPostfixRegex.firstMatch(combined);
    if (match == null) return null;

    final rawAmountStr = match.group(1)?.replaceAll(',', '') ?? '';
    final amountFloat = double.tryParse(rawAmountStr);
    if (amountFloat == null || amountFloat <= 0) return null;
    final amountPaise = (amountFloat * 100).round();

    var merchant = '';

    // Priority 0: Check UPI Info tag format (e.g. "Info: UPI*ZOMATO*...")
    final upiInfoMatch = _upiInfoRegex.firstMatch(bodyText) ?? _upiInfoRegex.firstMatch(subject);
    if (upiInfoMatch != null && upiInfoMatch.group(1) != null) {
      final cand = _cleanMerchant(upiInfoMatch.group(1)!);
      if (cand.isNotEmpty && !_isNoise(cand)) {
        merchant = cand;
      }
    }

    // Priority 1: Check table key-value format in body text
    if (merchant.isEmpty) {
      final tableRegex = isDebit ? _tableReceiverRegex : _tableSenderRegex;
      final tableMatch = tableRegex.firstMatch(bodyText);
      if (tableMatch != null && tableMatch.group(1) != null) {
        final cand = _cleanMerchant(tableMatch.group(1)!);
        if (cand.isNotEmpty && !_isNoise(cand)) {
          merchant = cand;
        }
      }
    }

    // Priority 2: Check VPA receiver format (e.g. "to VPA swiggy@icici")
    if (merchant.isEmpty && isDebit) {
      final vpaMatch = _vpaRegex.firstMatch(combined);
      if (vpaMatch != null && vpaMatch.group(1) != null) {
        final cand = _cleanMerchant(vpaMatch.group(1)!);
        if (cand.isNotEmpty && !_isNoise(cand)) {
          merchant = cand;
        }
      }
    }

    final inlineRegexes = isDebit ? _inlineDebitRegexes : _inlineCreditRegexes;

    // Priority 3: Look in the subject line
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

    // Priority 4: Look inline in body text
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

    // Priority 5: Fallback to detected bank name
    if (merchant.isEmpty) {
      merchant = _detectBankFallback(combined, isDebit: isDebit || !isCredit);
    }

    final occurredAt = _extractDate(combined, emailDate) ?? emailDate ?? DateTime.now();

    String snippet = subject.isNotEmpty ? subject : combined.substring(0, combined.length.clamp(0, 100));
    final rrnMatch = _rrnRegex.firstMatch(combined);
    if (rrnMatch != null && rrnMatch.group(1) != null) {
      final rrn = rrnMatch.group(1)!;
      if (!snippet.contains(rrn)) {
        snippet = '$snippet (RRN: $rrn)';
      }
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

  static String _detectBankFallback(String combined, {required bool isDebit}) {
    final lower = combined.toLowerCase();
    if (lower.contains('hdfc')) {
      return isDebit ? 'HDFC Payment' : 'HDFC Credit';
    }
    if (lower.contains('sbi') || lower.contains('state bank')) {
      return isDebit ? 'SBI Payment' : 'SBI Credit';
    }
    if (lower.contains('icici')) {
      return isDebit ? 'ICICI Payment' : 'ICICI Credit';
    }
    if (lower.contains('axis')) {
      return isDebit ? 'Axis Payment' : 'Axis Credit';
    }
    if (lower.contains('kotak')) {
      return isDebit ? 'Kotak Payment' : 'Kotak Credit';
    }
    if (lower.contains('slice')) {
      return isDebit ? 'Slice Payment' : 'Slice Refund';
    }
    if (lower.contains('jupiter')) {
      return isDebit ? 'Jupiter Payment' : 'Jupiter Credit';
    }
    if (lower.contains('federal') || lower.contains('fi.money')) {
      return isDebit ? 'Federal Bank Payment' : 'Federal Bank Credit';
    }
    return isDebit ? 'Bank Payment' : 'Bank Credit';
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
        lower.contains('hdfc bank') ||
        lower.contains('sbi account') ||
        lower.contains('icici bank') ||
        lower.contains('axis bank') ||
        lower.contains('kotak bank') ||
        lower.contains('your bank') ||
        lower.contains('bank account') ||
        lower.contains('saving account') ||
        lower.contains('savings account') ||
        lower.contains('current account') ||
        lower.contains('credit card') ||
        lower.contains('debit card') ||
        lower.contains('slice app') ||
        lower.startsWith('xx') ||
        lower.startsWith('****') ||
        lower == 'rrn' ||
        lower == 'upi' ||
        lower == 'slice' ||
        lower == 'digital safety' ||
        lower == 'digital safety tips' ||
        lower == 'avail limit' ||
        lower == 'available limit' ||
        lower == 'vpa') {
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
      'transfer',
      'payment',
      'txn',
      'ref',
      'info',
    ];
    return noiseWords.contains(lower);
  }
}

/// Backward compatibility alias for SliceEmailParser
typedef SliceEmailParser = BankEmailParser;
