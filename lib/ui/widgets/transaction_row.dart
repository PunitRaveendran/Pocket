import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'category_icon.dart';

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.txn,
    required this.categoryName,
    required this.categoryIconKey,
    required this.hideAmounts,
    required this.onTap,
  });

  final Txn txn;
  final String categoryName;
  final String categoryIconKey;
  final bool hideAmounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final credit = txn.direction == Direction.credit;
    final amount = Money.formatPaise(
      txn.amountPaise,
      hide: hideAmounts,
      withSign: credit,
    );
    final time = DateFormat('h:mm a').format(txn.occurredAt.toLocal());
    final title = txn.merchant.isEmpty ? categoryName : txn.merchant;
    return Semantics(
      button: true,
      label: '$title, $categoryName, ${Money.spokenRupees(txn.amountPaise)}',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.margin),
            child: Row(
              children: [
                Icon(categoryIcon(categoryIconKey), size: 20, color: t.inkSoft),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TypeScale.body(t.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$categoryName  ·  $time', style: TypeScale.caption(t.inkSoft)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                Text(
                  amount,
                  style: TypeScale.money(credit ? t.accent : t.ink, size: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
