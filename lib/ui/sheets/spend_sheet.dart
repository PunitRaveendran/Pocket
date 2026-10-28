import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/upi_sms_parser.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/primary_button.dart';

Future<void> showSpendSheet(
  BuildContext context, {
  Txn? editing,
  String? initialCategoryId,
  LocalDate? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SpendSheet(
      editing: editing,
      initialCategoryId: initialCategoryId,
      initialDate: initialDate,
    ),
  );
}

class SpendSheet extends ConsumerStatefulWidget {
  const SpendSheet({
    super.key,
    this.editing,
    this.initialCategoryId,
    this.initialDate,
  });

  final Txn? editing;
  final String? initialCategoryId;
  final LocalDate? initialDate;

  @override
  ConsumerState<SpendSheet> createState() => _SpendSheetState();
}

class _SpendSheetState extends ConsumerState<SpendSheet> {
  late AmountValue _amount;
  late String _categoryId;
  late LocalDate _date;
  late Direction _direction;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  bool _splitWithFriend = false;
  late final TextEditingController _friendNameController;
  late final TextEditingController _friendShareController;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _amount = e == null
        ? const AmountValue(rupeeDigits: '0', paise: 0)
        : AmountValue.fromPaise(e.amountPaise);
    _categoryId = e?.categoryId ?? widget.initialCategoryId ?? 'food';
    _date = e?.localDate ?? widget.initialDate ?? LocalDate.today();
    _direction = e?.direction ?? Direction.debit;
    _merchant = TextEditingController(text: e?.merchant ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _friendNameController = TextEditingController();
    _friendShareController = TextEditingController();
  }

  @override
  void dispose() {
    _merchant.dispose();
    _note.dispose();
    _friendNameController.dispose();
    _friendShareController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _date = LocalDate(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pasteUpiSms() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final parsed = UpiSmsParser.parse(text);

    if (parsed != null) {
      setState(() {
        _amount = AmountValue.fromPaise(parsed.amountPaise);
        _merchant.text = parsed.merchant;
        _direction = parsed.isDebit ? Direction.debit : Direction.credit;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-detected ₹${parsed.amountPaise ~/ 100} at ${parsed.merchant}',
            ),
          ),
        );
      }
    } else {
      _showManualSmsPasteDialog();
    }
  }

  Future<void> _showManualSmsPasteDialog() async {
    final t = TokenScope.of(context);
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Paste Bank / UPI SMS', style: TypeScale.heading(t.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste any SBI, HDFC, ICICI, GPay or Paytm message. Pocket will extract the amount and merchant on-device.',
              style: TypeScale.caption(t.inkSoft),
            ),
            const SizedBox(height: Space.x3),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: TypeScale.body(t.ink),
              decoration: InputDecoration(
                hintText: 'e.g. Paid Rs 40.00 at Sharma Canteen UPI...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft))),
          TextButton(
            onPressed: () {
              final parsed = UpiSmsParser.parse(controller.text);
              if (parsed != null) {
                setState(() {
                  _amount = AmountValue.fromPaise(parsed.amountPaise);
                  _merchant.text = parsed.merchant;
                  _direction = parsed.isDebit ? Direction.debit : Direction.credit;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Auto-filled ₹${parsed.amountPaise ~/ 100} at ${parsed.merchant}')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not find debit/credit amount in this text')),
                );
              }
            },
            child: Text('Extract', style: TypeScale.body(t.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_amount.paiseTotal <= 0) return;

    final friendShareRupees = int.tryParse(_friendShareController.text.trim()) ?? 0;
    final friendSharePaise = friendShareRupees * 100;
    final friendName = _friendNameController.text.trim();

    if (_splitWithFriend && friendName.isNotEmpty && friendSharePaise > 0) {
      await ref.read(ledgerProvider.notifier).addFriendSplit(
            friendName: friendName,
            amountPaise: friendSharePaise,
            direction: SplitDirection.youAreOwed,
            date: _date,
            note: 'Split share of ${_merchant.text.trim().isNotEmpty ? _merchant.text.trim() : "bill"}',
          );
    }

    await ref.read(ledgerProvider.notifier).addDailySpend(
          amountPaise: _amount.paiseTotal,
          categoryId: _categoryId,
          date: _date,
          merchant: _merchant.text.trim(),
          direction: _direction,
          note: _note.text.trim(),
          editing: widget.editing,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.editing;
    if (e == null) return;
    await ref.read(ledgerProvider.notifier).deleteTxn(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  List<String> _getSuggestions(String catId) {
    switch (catId) {
      case 'food':
        return const ['Canteen lunch', 'Mess thali', 'Hostel dinner', 'Breakfast'];
      case 'snacks':
        return const ['Chai', 'Coffee', 'Samosa', 'Maggi', 'Juice', 'Biscuits'];
      case 'study':
        return const ['Xerox / Print', 'Notebook', 'Pen / Pencil', 'Course material'];
      case 'misc':
        return const ['Bus ticket', 'Auto fare', 'Mobile recharge', 'Laundry'];
      case 'travel':
      case 'commute':
        return const ['Metro pass', 'Bus fare', 'Auto', 'Cab share'];
      default:
        return const ['Daily spend', 'Split share'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final cats = ledger?.categories ?? [];
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final suggestions = _getSuggestions(_categoryId);
    final isCredit = _direction == Direction.credit;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x4, Space.margin, Space.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: t.rule, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: Space.x4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editing == null
                        ? (isCredit ? 'Record refund / split' : Copy.addSpend)
                        : 'Edit entry',
                    style: TypeScale.title(t.ink),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: t.inkSoft),
                          const SizedBox(width: 4),
                          Text(
                            _date == LocalDate.today()
                                ? 'Today'
                                : _date == LocalDate.today().addDays(-1)
                                    ? 'Yesterday'
                                    : DateFormat('d MMM').format(_date.dateTime),
                            style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              // Direction Toggle: Expense vs Refund/Split
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _direction = Direction.debit),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isCredit ? t.accentTint : Colors.transparent,
                          border: Border.all(color: !isCredit ? t.accent : t.rule),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Expense',
                          style: TypeScale.caption(!isCredit ? t.accent : t.inkSoft)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _direction = Direction.credit),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isCredit ? t.accentTint : Colors.transparent,
                          border: Border.all(color: isCredit ? t.accent : t.rule),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Refund / Split in (+)',
                          style: TypeScale.caption(isCredit ? t.accent : t.inkSoft)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
              // On-Device UPI SMS Auto-detection button
              InkWell(
                onTap: _pasteUpiSms,
                borderRadius: BorderRadius.circular(Space.controlRadius),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.rule),
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sms_outlined, size: 14, color: t.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Auto-Fill from UPI / Bank SMS',
                        style: TypeScale.caption(t.accent).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.x4),
              AmountDisplay(value: _amount),
              if (isCredit)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Restores this amount back to today’s allowance.',
                    style: TypeScale.caption(t.accent),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: Space.x4),
              // Category chips
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  for (final c in cats)
                    LedgerChip(
                      label: c.name,
                      icon: categoryIcon(c.icon),
                      selected: _categoryId == c.id,
                      onTap: () => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
              const SizedBox(height: Space.x4),
              // Student Quick Suggestion Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(s, style: TypeScale.caption(t.inkSoft)),
                          backgroundColor: t.paper,
                          side: BorderSide(color: t.rule),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onPressed: () {
                            _merchant.text = s;
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.x3),
              TextField(
                controller: _merchant,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  hintText: Copy.merchantHint,
                  hintStyle: TypeScale.body(t.inkSoft),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                ),
              ),
              if (!isCredit && widget.editing == null) ...[
                const SizedBox(height: Space.x3),
                // Inline Friend Split section
                InkWell(
                  onTap: () => setState(() => _splitWithFriend = !_splitWithFriend),
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _splitWithFriend ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                          size: 18,
                          color: _splitWithFriend ? t.accent : t.inkSoft,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Split part of this bill with a friend',
                          style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_splitWithFriend) ...[
                  const SizedBox(height: Space.x2),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.card,
                      border: Border.all(color: t.rule),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _friendNameController,
                                style: TypeScale.body(t.ink),
                                cursorColor: t.accent,
                                decoration: InputDecoration(
                                  labelText: "Friend's name",
                                  labelStyle: TypeScale.caption(t.inkSoft),
                                  hintText: 'e.g. Rahul',
                                  isDense: true,
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                                ),
                              ),
                            ),
                            const SizedBox(width: Space.x3),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _friendShareController,
                                keyboardType: TextInputType.number,
                                style: TypeScale.body(t.ink),
                                cursorColor: t.accent,
                                decoration: InputDecoration(
                                  labelText: "Their share (₹)",
                                  labelStyle: TypeScale.caption(t.inkSoft),
                                  hintText: 'e.g. 150',
                                  isDense: true,
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This will log the full expense and automatically create a split in Splits screen owed to you.',
                          style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: Space.x4),
              AmountPad(
                value: _amount,
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x4),
              PrimaryButton(
                label: Copy.save,
                onPressed: _amount.paiseTotal > 0 ? _save : null,
              ),
              if (widget.editing != null) ...[
                const SizedBox(height: Space.x2),
                GhostButton(label: Copy.remove, onPressed: _delete),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
