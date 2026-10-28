/// Money is always integer paise. No floating point anywhere.
class Money {
  const Money._();

  static int rupeesToPaise(int rupees) => rupees * 100;

  static int fromDigitsAndPaise(String rupeeDigits, int paise) {
    final rupees = rupeeDigits.isEmpty ? 0 : int.parse(rupeeDigits);
    return rupees * 100 + paise;
  }

  /// Indian grouping: 1,23,456
  static String groupRupees(int rupees) {
    final sign = rupees < 0 ? '-' : '';
    final n = rupees.abs().toString();
    if (n.length <= 3) return '$sign$n';
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return '$sign${parts.join(',')},$last3';
  }

  static String formatPaise(int paise, {bool hide = false, bool withSign = false}) {
    if (hide) return '₹····';
    final sign = withSign && paise > 0 ? '+' : (paise < 0 ? '-' : '');
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final rem = abs % 100;
    final grouped = groupRupees(rupees);
    if (rem == 0) return '$sign₹$grouped';
    return '$sign₹$grouped.${rem.toString().padLeft(2, '0')}';
  }

  static String spokenRupees(int paise) {
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final rem = abs % 100;
    final words = _inWords(rupees);
    if (rem == 0) return 'rupees $words';
    return 'rupees $words and $rem paise';
  }

  static String _inWords(int n) {
    if (n == 0) return 'zero';
    const ones = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    String underThousand(int x) {
      if (x == 0) return '';
      if (x < 20) return ones[x];
      if (x < 100) {
        final t = tens[x ~/ 10];
        final o = ones[x % 10];
        return o.isEmpty ? t : '$t $o';
      }
      final h = ones[x ~/ 100];
      final rest = underThousand(x % 100);
      return rest.isEmpty ? '$h hundred' : '$h hundred $rest';
    }

    final crore = n ~/ 10000000;
    n %= 10000000;
    final lakh = n ~/ 100000;
    n %= 100000;
    final thousand = n ~/ 1000;
    n %= 1000;
    final parts = <String>[];
    if (crore > 0) parts.add('${underThousand(crore)} crore');
    if (lakh > 0) parts.add('${underThousand(lakh)} lakh');
    if (thousand > 0) parts.add('${underThousand(thousand)} thousand');
    if (n > 0) parts.add(underThousand(n));
    return parts.join(' ');
  }
}
