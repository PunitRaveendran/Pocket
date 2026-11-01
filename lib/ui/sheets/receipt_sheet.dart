import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

Future<void> showMonthEndReceipt(BuildContext context, Ledger ledger) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MonthEndReceiptSheet(ledger: ledger),
  );
}

class MonthEndReceiptSheet extends StatelessWidget {
  const MonthEndReceiptSheet({super.key, required this.ledger});

  final Ledger ledger;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final today = LocalDate.today();
    final cycle = PayCycle.containing(today, ledger.settings.cycleStartDay);
    final s = ledger.settings;

    final stipend = s.stipendPaise;
    final fixedTotal = s.totalFixedDeductionsPaise;
    final effective = effectiveStipendForCycle(ledger, cycle);
    final ordinary = ordinaryThisCycle(ledger, cycle);
    final extra = extraThisCycle(ledger, cycle);
    final totalSpent = ordinary + extra;
    final balance = effective - ordinary;

    // Student stats
    var chaiCanteenCount = 0;
    var largestSingleSpend = 0;
    String largestMerchant = '';
    final catCounts = <String, int>{};

    for (final t in ledger.transactions) {
      if (!cycle.contains(t.localDate)) continue;
      if (t.direction != Direction.debit) continue;

      final m = t.merchant.toLowerCase();
      if (m.contains('chai') || m.contains('tea') || m.contains('canteen') || m.contains('samosa') || m.contains('coffee')) {
        chaiCanteenCount++;
      }
      if (t.amountPaise > largestSingleSpend) {
        largestSingleSpend = t.amountPaise;
        largestMerchant = t.merchant;
      }
      catCounts[t.categoryId] = (catCounts[t.categoryId] ?? 0) + t.amountPaise;
    }

    String topCategoryName = 'None';
    var topCatAmount = 0;
    catCounts.forEach((catId, amt) {
      if (amt > topCatAmount) {
        topCatAmount = amt;
        topCategoryName = ledger.categoryById(catId)?.name ?? catId;
      }
    });

    final cycleRangeStr =
        '${DateFormat('d MMM yyyy').format(cycle.start.dateTime)} – ${DateFormat('d MMM yyyy').format(cycle.endInclusive.dateTime)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.margin, vertical: Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thermal Receipt Paper Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Jagged tear top
                  CustomPaint(
                    size: const Size(double.infinity, 8),
                    painter: _ReceiptTearPainter(isTop: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            'P O C K E T   L E D G E R',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 2,
                              color: t.ink,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            'MONTH-END PAPER RECEIPT',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: t.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cycle: $cycleRangeStr',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: t.inkSoft),
                        ),
                        Text(
                          'Printed: ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: t.inkSoft),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '----------------------------------------',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black26),
                        ),
                        const SizedBox(height: 8),

                        _ReceiptLine(label: 'MONTHLY STIPEND', value: Money.formatPaise(stipend)),
                        if (fixedTotal > 0)
                          _ReceiptLine(
                            label: 'FIXED DEDUCTIONS',
                            value: '- ${Money.formatPaise(fixedTotal)}',
                          ),
                        _ReceiptLine(
                          label: 'EFFECTIVE ALLOWANCE',
                          value: Money.formatPaise(effective),
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '- - - - - - - - - - - - - - - - - - - -',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black26),
                        ),
                        const SizedBox(height: 6),
                        _ReceiptLine(label: 'ORDINARY DAILY SPENDS', value: Money.formatPaise(ordinary)),
                        _ReceiptLine(label: 'OUTINGS & SOCIAL EXTRA', value: Money.formatPaise(extra)),
                        _ReceiptLine(
                          label: 'TOTAL MONEY OUT',
                          value: Money.formatPaise(totalSpent),
                          isBold: true,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '========================================',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black26),
                        ),
                        const SizedBox(height: 6),
                        _ReceiptLine(
                          label: balance >= 0 ? 'NET MONTHLY SAVING' : 'NET OVERSPENT DEFICIT',
                          value: '${balance >= 0 ? "+" : "-"} ${Money.formatPaise(balance.abs())}',
                          isBold: true,
                        ),
                        const SizedBox(height: 12),

                        // Fun Student Highlights
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CAMPUS HIGHLIGHTS:',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Chai & canteen runs: $chaiCanteenCount times',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: t.inkSoft),
                              ),
                              Text(
                                '• Top spending category: $topCategoryName (${totalSpent > 0 ? ((topCatAmount / totalSpent) * 100).round() : 0}%)',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: t.inkSoft),
                              ),
                              if (largestSingleSpend > 0)
                                Text(
                                  '• Largest splurge: ${Money.formatPaise(largestSingleSpend)} ($largestMerchant)',
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: t.inkSoft),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            '*** KEEP CALM & TRACK ON ***',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 1,
                              color: t.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Jagged tear bottom
                  CustomPaint(
                    size: const Size(double.infinity, 8),
                    painter: _ReceiptTearPainter(isTop: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x4),

            // Share / Copy buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: t.card,
                      side: BorderSide(color: t.rule),
                    ),
                    icon: Icon(Icons.copy_outlined, size: 16, color: t.ink),
                    label: Text('Copy Summary', style: TypeScale.body(t.ink)),
                    onPressed: () {
                      final summaryText = '''
POCKET MONTH-END RECEIPT
Cycle: $cycleRangeStr
Stipend: ${Money.formatPaise(stipend)}
Fixed Costs: -${Money.formatPaise(fixedTotal)}
Total Spent: ${Money.formatPaise(totalSpent)}
Result: ${balance >= 0 ? "+" : "-"}${Money.formatPaise(balance.abs())}
Chai/Canteen: $chaiCanteenCount runs
Top Category: $topCategoryName
''';
                      Clipboard.setData(ClipboardData(text: summaryText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt copied to clipboard!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: t.accent,
                      foregroundColor: t.paper,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done', style: TypeScale.body(t.paper)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.label, required this.value, this.isBold = false});

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTearPainter extends CustomPainter {
  _ReceiptTearPainter({required this.isTop});
  final bool isTop;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDFBF7)
      ..style = PaintingStyle.fill;

    final path = Path();
    const toothWidth = 8.0;
    const toothHeight = 6.0;
    final count = (size.width / toothWidth).ceil();

    if (isTop) {
      path.moveTo(0, size.height);
      for (var i = 0; i < count; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, size.height - toothHeight);
        path.lineTo(x + toothWidth, size.height);
      }
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      for (var i = 0; i < count; i++) {
        final x = i * toothWidth;
        path.lineTo(x + toothWidth / 2, toothHeight);
        path.lineTo(x + toothWidth, 0);
      }
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
