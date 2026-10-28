class UpiParseResult {
  const UpiParseResult({
    required this.amountPaise,
    required this.merchant,
    required this.isDebit,
    this.rawText = '',
  });

  final int amountPaise;
  final String merchant;
  final bool isDebit;
  final String rawText;
}

/// 100% on-device regular expression parser for Indian bank & UPI SMS notifications.
class UpiSmsParser {
  const UpiSmsParser._();

  static final _amountRegex = RegExp(
    r'(?:rs\.?|inr)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _debitRegex = RegExp(
    r'\b(?:debited|paid|spent|sent|transferred|withdrawn)\b',
    caseSensitive: false,
  );

  static final _creditRegex = RegExp(
    r'\b(?:credited|received|refunded|added)\b',
    caseSensitive: false,
  );

  static final _merchantRegexes = [
    RegExp(r'(?:to|towards|at|from|paid to)\s+([A-Za-z0-9\s&.\-]+?)(?:\s+(?:on|using|via|ref|upi|bal|a\/c|\.|$))', caseSensitive: false),
    RegExp(r'vpa\s+([A-Za-z0-9@.\-]+)', caseSensitive: false),
  ];

  static UpiParseResult? parse(String text) {
    if (text.trim().isEmpty) return null;

    final isDebit = _debitRegex.hasMatch(text);
    final isCredit = _creditRegex.hasMatch(text);

    // If it's neither debit nor credit, it's likely an OTP or promotional message
    if (!isDebit && !isCredit) return null;

    final match = _amountRegex.firstMatch(text);
    if (match == null) return null;

    final rawAmountStr = match.group(1)?.replaceAll(',', '') ?? '';
    final amountFloat = double.tryParse(rawAmountStr);
    if (amountFloat == null || amountFloat <= 0) return null;
    final amountPaise = (amountFloat * 100).round();

    var merchant = '';
    for (final r in _merchantRegexes) {
      for (final m in r.allMatches(text)) {
        if (m.group(1) != null) {
          final cand = m.group(1)!.trim();
          // Clean out noise words
          final cleaned = cand
              .replaceAll(
                RegExp(r'\b(?:your|bank|ac|a\/c|account|upi|ref|inr|rs)\b', caseSensitive: false),
                '',
              )
              .trim();
          if (RegExp(r'^[\d.,\s]+$').hasMatch(cleaned)) continue;
          if (cleaned.length >= 2 && cleaned.length <= 40) {
            merchant = cleaned;
            break;
          }
        }
      }
      if (merchant.isNotEmpty) break;
    }

    if (merchant.isEmpty) {
      merchant = isDebit ? 'UPI Spend' : 'UPI Received';
    }

    return UpiParseResult(
      amountPaise: amountPaise,
      merchant: merchant,
      isDebit: isDebit || !isCredit,
      rawText: text,
    );
  }
}
