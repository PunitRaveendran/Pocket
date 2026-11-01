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

  static const indusind = BankPreset(
    id: 'indusind',
    name: 'IndusInd Bank',
    shortName: 'IndusInd',
    senders: ['alerts@indusind.com', 'reachus@indusind.com'],
  );

  static const idfc = BankPreset(
    id: 'idfc',
    name: 'IDFC FIRST Bank',
    shortName: 'IDFC FIRST',
    senders: ['alerts@idfcfirstbank.com'],
  );

  static const pnb = BankPreset(
    id: 'pnb',
    name: 'Punjab National Bank',
    shortName: 'PNB',
    senders: ['pnbalerts@pnb.co.in'],
  );

  static const canara = BankPreset(
    id: 'canara',
    name: 'Canara Bank',
    shortName: 'Canara',
    senders: ['alert@canarabank.com'],
  );

  static const all = [
    slice,
    hdfc,
    sbi,
    icici,
    axis,
    kotak,
    jupiterFi,
    indusind,
    idfc,
    pnb,
    canara,
  ];

  static List<String> get allSenders => all.expand((b) => b.senders).toList();

  static const String defaultSendersString =
      'noreply@slice.bank.in, alerts@sliceit.com, alerts@hdfcbank.net, instalerts@hdfcbank.bank.in, alerts@sbi.co.in, donotreply@sbi.co.in, credit_cards@icicibank.com, alerts@icicibank.com, alerts@axisbank.com, creditcards@axisbank.com, alerts@kotak.com, noreply@kotak.com, support@jupiter.money, alerts@fi.money, alerts@federalbank.co.in, alerts@indusind.com, reachus@indusind.com, alerts@idfcfirstbank.com, pnbalerts@pnb.co.in, alert@canarabank.com';
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

  static final _verbAmountRegex = RegExp(
    r'\b(?:debited|credited|paid|sent|withdrawn|spent)\s+(?:by|for|with|of)?\s*(?:₹|rs\.?|inr)?\s*([\d,]+(?:\.\d{1,2})?)\b',
    caseSensitive: false,
  );

  static final _debitRegex = RegExp(
    r'\b(?:debited|debit|paid|payment|spent|sent|transferred|transfer|trf|withdrawn|purchase|charged|dr|done a transaction|transaction of|transaction on)\b',
    caseSensitive: false,
  );

  static final _creditRegex = RegExp(
    r'\b(?:credited|credit(?!\s*(?:card|-card))|received|refunded|refund|added|cashback|deposited|cr)\b',
    caseSensitive: false,
  );

  // Table key-value receiver (Debit: e.g. "To\nAkhil Asok\nRRN" or "Paid to: Akhil Asok" or "To Akhil Asok RRN" or "Beneficiary: ...")
  static final _tableReceiverRegex = RegExp(
    r'(?:^|[\n\r]|\bTransaction date[^\n\r]*?)[ \t]*(?:To|Paid to|Transfer to|Sent to|Beneficiary|Receiver|Merchant)[ \t]*[:\t \n\r]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]*(?:\n|\r|\bRRN\b|\bUPI Ref\b|\bRef No\b|\bRefno\b|\btxn id\b|\bRef\b|\bBest\b|\bTeam\b|\bAvl\.?\b|\$))',
    caseSensitive: false,
  );

  // Table key-value sender (Credit: e.g. "From\nSwiggy\nRRN" or "From SNEH NIPOON SHETH RRN" or "Received from: Sneha")
  static final _tableSenderRegex = RegExp(
    r'(?:^|[\n\r]|\bTransaction date[^\n\r]*?)[ \t]*(?:From|Received from|Refund from|Sender|Transfer from)[ \t]*[:\t \n\r]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]*(?:\n|\r|\bRRN\b|\bUPI Ref\b|\bRef No\b|\bRefno\b|\btxn id\b|\bRef\b|\bBest\b|\bTeam\b|\bAvl\.?\b|\$))',
    caseSensitive: false,
  );

  // Table or inline date (e.g. "Transaction date\n29-Oct-26", "29-10-2026", "29Oct26", "on 28-OCT-26")
  static final _dateRegex = RegExp(
    r'(?:Transaction date|Date|on|dated)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t|[ \t]+)?[ \t]*(\d{1,2})[-/ ]?([A-Za-z]{3}|\d{1,2})[-/ ]?(\d{2,4})',
    caseSensitive: false,
  );

  static final _rrnRegex = RegExp(
    r'(?:RRN|UPI Ref(?: ID| no)?|Ref No|Refno|txn id|Ref)[ \t]*(?:[:\n\r]+|[ \t]{2,}|\t|[ \t]+)[ \t]*(\d+)',
    caseSensitive: false,
  );

  // UPI slash formats: e.g. "UPI/DR/630246906599/RAMESH/PAYTM" or "UPI/430712345678/SWIGGY"
  static final _upiSlashRegex = RegExp(
    r'UPI(?:/(?:DR|CR))?/(?:\d+)/([A-Za-z0-9&.\-_ ]+?)(?:/[A-Za-z0-9&.\-_ ]+)*?(?:[ \t\n\r.]|$)',
    caseSensitive: false,
  );

  // UPI colon format: e.g. "thru UPI:430712345678:SWIGGY"
  static final _upiColonRegex = RegExp(
    r'UPI:(?:\d+):([A-Za-z0-9&.\-_ ]+?)(?:[ \t\n\r.]|$)',
    caseSensitive: false,
  );

  // UPI asterisk format: e.g. "Info: UPI*ZOMATO*630246906599*Pay"
  static final _upiStarRegex = RegExp(
    r'UPI\*([A-Za-z0-9&.\-_ ]+?)\*(?:\d+)',
    caseSensitive: false,
  );

  // UPI Info tag format (e.g. "Info: UPI*ZOMATO*630246906599*Pay" in ICICI/HDFC/Axis)
  static final _upiInfoRegex = RegExp(
    r'(?:Info|Details)?[ \t]*:?[ \t]*UPI[*\/]([A-Za-z0-9&.\-_]+)',
    caseSensitive: false,
  );

  // VPA receiver format (e.g. "to VPA swiggy@icici" or "to chaipoint@hdfcbank" or "trf to ramesh@okhdfcbank")
  static final _vpaRegex = RegExp(
    r'(?:to VPA|towards VPA|to|towards|trf to|vpa)[ \t]+([A-Za-z0-9.\-_]+)@[A-Za-z0-9.\-_]+',
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
        if (day >= 1 && day <= 31 && month >= 1 && month <= 12 && year >= 2020 && year <= 2035) {
          final hour = fallback?.hour ?? 12;
          final minute = fallback?.minute ?? 0;
          final second = fallback?.second ?? 0;
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    }
    return fallback;
  }

  static bool _determineIsDebit(String text) {
    final lower = text.toLowerCase();

    // Check clear unambiguous debit indicators
    final debitIndicators = [
      RegExp(r'\b(?:debited|debit of|is debited|was debited|has been debited|a\/c debited)\b'),
      RegExp(r'\b(?:paid|sent|spent)\s+(?:(?:₹|rs\.?|inr)\s*)?[\d,]+'),
      RegExp(r'\b(?:paid to|sent to|transfer to|trf to)\b'),
      RegExp(r'\b(?:done a transaction|transaction of|transaction on|used for a transaction)\b'),
      RegExp(r'\bupi\/dr\/'),
      RegExp(r'\bdr\b'),
    ];

    // Check clear unambiguous credit indicators
    final creditIndicators = [
      RegExp(r'\b(?:credited|credit of|is credited|was credited|has been credited|a\/c credited)\b'),
      RegExp(r'\b(?:received|refunded|deposited|cashback)\s+(?:(?:₹|rs\.?|inr)\s*)?[\d,]+'),
      RegExp(r'\b(?:received from|refund from|cashback from|transfer from|trf from)\b'),
      RegExp(r'\bupi\/cr\/'),
      RegExp(r'\bcr\b'),
    ];

    int firstDebitPos = -1;
    for (final r in debitIndicators) {
      final m = r.firstMatch(lower);
      if (m != null) {
        if (firstDebitPos == -1 || m.start < firstDebitPos) {
          firstDebitPos = m.start;
        }
      }
    }

    int firstCreditPos = -1;
    for (final r in creditIndicators) {
      final m = r.firstMatch(lower);
      if (m != null) {
        if (firstCreditPos == -1 || m.start < firstCreditPos) {
          firstCreditPos = m.start;
        }
      }
    }

    if (firstDebitPos != -1 && firstCreditPos == -1) return true;
    if (firstCreditPos != -1 && firstDebitPos == -1) return false;
    if (firstDebitPos != -1 && firstCreditPos != -1) {
      return firstDebitPos <= firstCreditPos;
    }

    // Fallback regex matching
    final isDebit = _debitRegex.hasMatch(lower);
    final isCredit = _creditRegex.hasMatch(lower);
    if (isDebit && !isCredit) return true;
    if (isCredit && !isDebit) return false;
    return true; // Default to debit for transaction alerts
  }

  // Inline debit matchers (looking for receiver/merchant)
  static final _inlineDebitRegexes = [
    // 1. "Sent/Paid/Transferred <amount> [from ...] to <merchant>" (amount between verb and preposition)
    RegExp(
      r'(?:sent|paid|transferred|transfer of|payment of)[ \t]+(?:(?:₹|rs\.?|inr)[ \t]*)?[\d,]+(?:\.\d{1,2})?[ \t]+(?:from[ \t]+[^.\n]+?[ \t]+)?to[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:on|using|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail|from)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 2. "done a transaction of INR 899.00 on your Credit Card ending 9876 at ZOMATO"
    RegExp(
      r'(?:transaction of|done a transaction of)[ \t]+(?:(?:₹|rs\.?|inr)[ \t]*)?[\d,]+(?:\.\d{1,2})?[ \t]+(?:on[ \t]+[^.\n]+?[ \t]+)?at[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:on|using|via|with|ref|refno|rrn|avail|bal|was|has|is)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 3. "spent on your HDFC Bank Card ending 1234 at AMAZON INDIA on 29-10-2026"
    RegExp(
      r'(?:spent|transaction) on [^.\n]+ at ([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:on|using|via|with|ref|refno|rrn|avail|bal|was|has|is)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 4. "spent Rs. 210.00 at Starbucks using..."
    RegExp(
      r'spent[ \t]+(?:(?:₹|rs\.?|inr)[ \t]*)?[\d,]+(?:\.\d{1,2})?[ \t]+(?:on[ \t]+[^.\n]+?[ \t]+)?at[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:on|using|via|with|ref|refno|rrn|avail|bal|was|has|is)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 5. "UPI transaction of Rs. 450.00 to SWIGGY"
    RegExp(
      r'UPI transaction of [^.\n]+ to ([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 4. "debited ... trf to / transfer to / towards UPI payment to / towards / to / at <merchant>"
    RegExp(
      r'debited [^.\n]*?(?:trf to|transfer to|transferred to|towards UPI payment to|towards payment to|towards|to|at)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|txn|from|avail|bal|account|was|has|is|successful)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 5. "trf to / transfer to / transferred to <merchant>"
    RegExp(
      r'(?:trf to|transfer to|transferred to|towards transfer to)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 6. "paid to / sent to / towards payment to / towards <merchant>"
    RegExp(
      r'(?:paid to|sent to|towards payment to|towards)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 7. "at <merchant>" or "paid <merchant>"
    RegExp(
      r'\b(?:at|paid)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 8. "to <merchant>"
    RegExp(
      r'\bto[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|was|has|successful|account|bal|avail)|\.|\n|<|$)',
      caseSensitive: false,
    ),
  ];

  // Inline credit matchers (looking for sender)
  static final _inlineCreditRegexes = [
    // 1. "credited ... by transfer from / from transfer from / from / by <sender>"
    RegExp(
      r'credited [^.\n]*?(?:by transfer from|from transfer from|from|by)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|txn|bal)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 2. "received from / refund from / cashback from / transfer from / trf from <sender>"
    RegExp(
      r'(?:received from|refund from|cashback from|transfer from|trf from)[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|account|bal)|\.|\n|<|$)',
      caseSensitive: false,
    ),
    // 3. "from <sender>"
    RegExp(
      r'\bfrom[ \t]+([A-Za-z0-9&.\-]+(?:[ \t]+[A-Za-z0-9&.\-]+)*?)(?:[ \t]+(?:using|on|via|ref|refno|rrn|upi|with|for|is|account|bal)|\.|\n|<|$)',
      caseSensitive: false,
    ),
  ];

  /// Strips HTML tags and normalizes whitespace while preserving line structure.
  static String _htmlToPlainText(String html) {
    if (!html.contains('<') || !html.contains('>')) {
      return html;
    }

    var text = html;
    // Strip styles and scripts
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false), ' ');

    // Break lines at block elements and table cells
    text = text.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<\/(?:p|div|tr|table|h[1-6]|li)>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<\/(?:td|th)>', caseSensitive: false), '\t');

    // Strip remaining tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Decode HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#8377;', '₹')
        .replaceAll('&inr;', '₹');

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });

    final lines = text.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];
    for (final l in lines) {
      final c = l.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (c.isNotEmpty) {
        cleaned.add(c);
      }
    }
    return cleaned.join('\n');
  }

  static ParsedEmailTransaction? parse({
    required String subject,
    required String bodyText,
    DateTime? emailDate,
    String? messageId,
  }) {
    final cleanSubject = _htmlToPlainText(subject).trim();
    final cleanBody = _htmlToPlainText(bodyText).trim();
    final combined = '$cleanSubject\n$cleanBody'.trim();
    if (combined.isEmpty) return null;

    final isDebitCandidate = _debitRegex.hasMatch(combined);
    final isCreditCandidate = _creditRegex.hasMatch(combined);

    // If it's neither debit nor credit (e.g. OTP, terms update), ignore
    if (!isDebitCandidate && !isCreditCandidate) return null;

    final isDebit = _determineIsDebit(combined);

    // Try verb-linked amount first (e.g. "debited by 320.00" or "paid ₹350.00")
    // as it explicitly matches the transaction rather than an account balance
    var match = _verbAmountRegex.firstMatch(combined);

    if (match == null) {
      // Strip balance numbers from consideration so remaining balance isn't mistaken for spend
      final noBalanceText = combined.replaceAll(
        RegExp(r'\b(?:Avl\.?|Avail\.?|Available|Bal\.?|Balance|Limit)\s*:?\s*(?:₹|rs\.?|inr)?\s*[\d,]+(?:\.\d{1,2})?', caseSensitive: false),
        '',
      );
      match = _amountPrefixRegex.firstMatch(noBalanceText) ??
          _amountPostfixRegex.firstMatch(noBalanceText) ??
          _amountPrefixRegex.firstMatch(combined) ??
          _amountPostfixRegex.firstMatch(combined);
    }
    if (match == null) return null;

    final rawAmountStr = match.group(1)?.replaceAll(',', '') ?? '';
    final amountFloat = double.tryParse(rawAmountStr);
    if (amountFloat == null || amountFloat <= 0) return null;
    final amountPaise = (amountFloat * 100).round();

    var merchant = '';

    // Priority 0: Check UPI slash, colon, star, and info formats
    final upiSlashMatch = _upiSlashRegex.firstMatch(cleanBody) ?? _upiSlashRegex.firstMatch(cleanSubject);
    if (upiSlashMatch != null && upiSlashMatch.group(1) != null) {
      final cand = _cleanMerchant(upiSlashMatch.group(1)!);
      if (cand.isNotEmpty && !_isNoise(cand)) {
        merchant = cand;
      }
    }

    if (merchant.isEmpty) {
      final upiColonMatch = _upiColonRegex.firstMatch(cleanBody) ?? _upiColonRegex.firstMatch(cleanSubject);
      if (upiColonMatch != null && upiColonMatch.group(1) != null) {
        final cand = _cleanMerchant(upiColonMatch.group(1)!);
        if (cand.isNotEmpty && !_isNoise(cand)) {
          merchant = cand;
        }
      }
    }

    if (merchant.isEmpty) {
      final upiStarMatch = _upiStarRegex.firstMatch(cleanBody) ?? _upiStarRegex.firstMatch(cleanSubject);
      if (upiStarMatch != null && upiStarMatch.group(1) != null) {
        final cand = _cleanMerchant(upiStarMatch.group(1)!);
        if (cand.isNotEmpty && !_isNoise(cand)) {
          merchant = cand;
        }
      }
    }


    // Priority 1: Check table key-value format in body text
    if (merchant.isEmpty) {
      final primaryTableRegex = isDebit ? _tableReceiverRegex : _tableSenderRegex;
      final secondaryTableRegex = isDebit ? _tableSenderRegex : _tableReceiverRegex;

      var tableMatch = primaryTableRegex.firstMatch(cleanBody);
      if (tableMatch == null || tableMatch.group(1) == null) {
        tableMatch = secondaryTableRegex.firstMatch(cleanBody);
      }

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
    if (merchant.isEmpty && cleanSubject.isNotEmpty) {
      for (final r in inlineRegexes) {
        final m = r.firstMatch(cleanSubject);
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
        for (final m in r.allMatches(cleanBody)) {
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

    // Priority 4.5: Check UPI Info / Details tag (e.g. "Info: UPI*ZOMATO" or "Info: UPI/STARBUCKS")
    if (merchant.isEmpty) {
      final upiInfoMatch = _upiInfoRegex.firstMatch(cleanBody) ?? _upiInfoRegex.firstMatch(cleanSubject);
      if (upiInfoMatch != null && upiInfoMatch.group(1) != null) {
        final cand = _cleanMerchant(upiInfoMatch.group(1)!);
        if (cand.isNotEmpty && !_isNoise(cand)) {
          merchant = cand;
        }
      }
    }

    // Priority 5: Fallback to detected bank name
    if (merchant.isEmpty) {
      merchant = _detectBankFallback(combined, isDebit: isDebit);
    }

    final occurredAt = _extractDate(combined, emailDate) ?? emailDate ?? DateTime.now();

    String snippet = cleanSubject.isNotEmpty ? cleanSubject : combined.substring(0, combined.length.clamp(0, 100));
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
      isDebit: isDebit,
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
      return isDebit ? 'Slice Payment' : 'Slice Credit';
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

    // Strip trailing metadata or RRN if captured
    final stopPatterns = [
      RegExp(r'\b(?:RRN|UPI Ref(?: ID| no)?|Ref No|Refno|txn id|Ref)[ \t]*:?[ \t]*\d+.*$', caseSensitive: false),
      RegExp(r'\b(?:Best|Team slice|Digital safety|To talk to us).*$', caseSensitive: false),
      RegExp(r'\b(?:Avl\.?|Avail\.?|Available|Avlbl)\s*(?:Bal\.?|Balance)?.*$', caseSensitive: false),
      RegExp(r'\b(?:Bal\.?|Balance)\s*:?.*$', caseSensitive: false),
      RegExp(r'\b(?:A\/c|Account)\s*(?:no\.?|ending)?\s*\d+.*$', caseSensitive: false),
      RegExp(r'\b(?:was|is|has been|has|successfully|successful)\b.*$', caseSensitive: false),
      RegExp(r'\b(?:If not done by you|Not you\?|Call|T&C).*$', caseSensitive: false),
      RegExp(r'\b(?:on|using|via|with|through|for|ref)\s+\d+.*$', caseSensitive: false),
      RegExp(r'\b(?:on|dated)\s+\d{1,2}[-/ ]?[A-Za-z0-9]+.*$', caseSensitive: false),
    ];
    for (final sp in stopPatterns) {
      s = s.replaceAll(sp, '');
    }

    // Strip trailing punctuation
    s = s.replaceAll(RegExp(r'[\s.,;:\-_|/\\]+$'), '');
    s = s.replaceAll(RegExp(r'^[\s.,;:\-_|/\\]+'), '');
    // Collapse spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  static bool _isNoise(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.length < 2) return true;
    if (RegExp(r'^[\d.,\s]+$').hasMatch(lower)) return true;
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
        lower.contains('talk to us') ||
        lower.contains('drop an email') ||
        lower.contains('team slice') ||
        lower.startsWith('xx') ||
        lower.startsWith('****') ||
        lower == 'rrn' ||
        lower == 'upi' ||
        lower == 'slice' ||
        lower == 'digital safety' ||
        lower == 'digital safety tips' ||
        lower == 'avail limit' ||
        lower == 'available limit' ||
        lower == 'vpa' ||
        lower == 'dr' ||
        lower == 'cr') {
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
      'successfully',
      'transfer',
      'payment',
      'txn',
      'ref',
      'refno',
      'info',
      'dr',
      'cr',
      'bal',
      'balance',
      'avbl',
      'available',
      'vpa',
      'upi',
      'to',
      'from',
      'at',
      'on',
      'call',
      'done',
    ];
    return noiseWords.contains(lower);
  }
}

/// Backward compatibility alias for SliceEmailParser
typedef SliceEmailParser = BankEmailParser;
