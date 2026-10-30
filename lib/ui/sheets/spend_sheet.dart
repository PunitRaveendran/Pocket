import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/primary_button.dart';
import 'bill_split_sheet.dart';

enum ReceivedType {
  topUp,
  friendPaidBack,
  refund,
}

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
  late ReceivedType _receivedType;
  String? _selectedSplitId;
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

    if (e != null && e.direction == Direction.credit) {
      if (e.categoryId == 'income' ||
          e.note.toLowerCase().contains('top-up') ||
          e.note.toLowerCase().contains('extra money')) {
        _receivedType = ReceivedType.topUp;
      } else {
        _receivedType = ReceivedType.refund;
      }
    } else {
      _receivedType = ReceivedType.topUp;
    }

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

  Future<void> _save() async {
    if (_amount.paiseTotal <= 0) return;

    if (_direction == Direction.debit) {
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

      final mySharePaise = (_splitWithFriend && friendName.isNotEmpty && friendSharePaise > 0)
          ? max(0, _amount.paiseTotal - friendSharePaise)
          : _amount.paiseTotal;

      if (mySharePaise > 0 || !_splitWithFriend) {
        await ref.read(ledgerProvider.notifier).addDailySpend(
              amountPaise: mySharePaise,
              categoryId: _categoryId,
              date: _date,
              merchant: _merchant.text.trim(),
              direction: Direction.debit,
              note: _splitWithFriend && friendSharePaise > 0
                  ? '${_note.text.trim()} (My share of ${Money.formatPaise(_amount.paiseTotal)})'.trim()
                  : _note.text.trim(),
              editing: widget.editing,
            );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Direction == credit
    if (_receivedType == ReceivedType.topUp) {
      final source = _merchant.text.trim().isNotEmpty ? _merchant.text.trim() : 'Stipend Top-Up';
      await ref.read(ledgerProvider.notifier).addDailySpend(
            amountPaise: _amount.paiseTotal,
            categoryId: 'income',
            date: _date,
            merchant: source,
            direction: Direction.credit,
            note: _note.text.trim().isNotEmpty ? _note.text.trim() : 'Extra stipend / balance top-up',
            editing: widget.editing,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${Money.formatPaise(_amount.paiseTotal)} on top of monthly balance!'),
          ),
        );
      }
      return;
    }

    if (_receivedType == ReceivedType.friendPaidBack) {
      if (_selectedSplitId != null) {
        await ref.read(ledgerProvider.notifier).settleFriendSplit(_selectedSplitId!, creditDaily: false);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleared friend split for ${Money.formatPaise(_amount.paiseTotal)}! Balance unchanged.'),
            ),
          );
        }
        return;
      }

      final friendName =
          _friendNameController.text.trim().isNotEmpty ? _friendNameController.text.trim() : 'Friend';
      final newSplit = await ref.read(ledgerProvider.notifier).addFriendSplit(
            friendName: friendName,
            amountPaise: _amount.paiseTotal,
            direction: SplitDirection.youAreOwed,
            date: _date,
            note: _merchant.text.trim().isNotEmpty ? _merchant.text.trim() : 'Repayment settled',
          );
      await ref.read(ledgerProvider.notifier).settleFriendSplit(newSplit.id, creditDaily: false);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded repayment from $friendName without affecting daily balance.'),
          ),
        );
      }
      return;
    }

    if (_receivedType == ReceivedType.refund) {
      await ref.read(ledgerProvider.notifier).addDailySpend(
            amountPaise: _amount.paiseTotal,
            categoryId: _categoryId,
            date: _date,
            merchant: _merchant.text.trim().isNotEmpty ? _merchant.text.trim() : 'Refund',
            direction: Direction.credit,
            note: _note.text.trim(),
            editing: widget.editing,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored ${Money.formatPaise(_amount.paiseTotal)} to today\'s allowance.'),
          ),
        );
      }
      return;
    }
  }

  Future<void> _delete() async {
    final e = widget.editing;
    if (e == null) return;
    await ref.read(ledgerProvider.notifier).deleteTxn(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final cats = ledger?.categories ?? [];
    final expenseCats = cats.where((c) => c.id != 'income').toList();
    final openSplits = (ledger?.friendSplits ?? [])
        .where((s) => !s.isSettled && s.direction == SplitDirection.youAreOwed)
        .toList();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
                        ? (isCredit ? 'Received Money' : Copy.addSpend)
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
              // Main Direction Switch: Expense vs Received Money
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _direction = Direction.debit),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
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
                      onTap: () {
                        setState(() {
                          _direction = Direction.credit;
                          if (_receivedType == ReceivedType.topUp) {
                            _categoryId = 'income';
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isCredit ? t.accentTint : Colors.transparent,
                          border: Border.all(color: isCredit ? t.accent : t.rule),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Received Money (+)',
                          style: TypeScale.caption(isCredit ? t.accent : t.inkSoft)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (isCredit) ...[
                const SizedBox(height: Space.x3),
                // Received Money Subtype Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: t.paper,
                    border: Border.all(color: t.rule),
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                  child: Row(
                    children: [
                      _buildReceivedSubOption(
                        t: t,
                        type: ReceivedType.topUp,
                        label: '💰 Top-Up Balance',
                      ),
                      _buildReceivedSubOption(
                        t: t,
                        type: ReceivedType.friendPaidBack,
                        label: '🤝 Friend Paid Back',
                      ),
                      _buildReceivedSubOption(
                        t: t,
                        type: ReceivedType.refund,
                        label: '↩️ Refund',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.x2),
                // Explanatory Banner Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(color: t.rule),
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _receivedType == ReceivedType.topUp
                            ? Icons.savings_outlined
                            : _receivedType == ReceivedType.friendPaidBack
                                ? Icons.people_outline_rounded
                                : Icons.replay_rounded,
                        size: 16,
                        color: t.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _receivedType == ReceivedType.topUp
                              ? 'Adds extra money directly to your monthly balance and boosts your daily pace.'
                              : _receivedType == ReceivedType.friendPaidBack
                                  ? 'Clears what a friend owed you. Keeps your daily spending balance intact.'
                                  : 'Restores this amount back to today’s daily spending allowance.',
                          style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: Space.x4),
              AmountDisplay(value: _amount),
              const SizedBox(height: Space.x4),

              // Form fields based on selection
              if (!isCredit) ...[
                // Category Chips for Expense
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final c in expenseCats)
                      LedgerChip(
                        label: c.name,
                        icon: categoryIcon(c.icon),
                        selected: _categoryId == c.id,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                  ],
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
                if (widget.editing == null) ...[
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
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final friendRupees = int.tryParse(_friendShareController.text.trim()) ?? 0;
                              final totalRupees = _amount.paiseTotal ~/ 100;
                              final myRupees = max(0, totalRupees - friendRupees);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your share: ₹$myRupees (debited to Today) · Friend owes: ₹$friendRupees (in Splits)',
                                    style: TypeScale.caption(t.accent).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final nav = Navigator.of(context);
                                      final done = await showBillSplitSheet(
                                        context,
                                        totalAmountPaise: _amount.paiseTotal,
                                        merchant: _merchant.text.trim(),
                                        initialDate: _date,
                                        initialCategoryId: _categoryId,
                                        allowEditTotal: true,
                                      );
                                      if (done == true && mounted) {
                                        nav.pop();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.group_add_outlined, size: 14, color: t.inkSoft),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Split equally with multiple friends...',
                                            style: TypeScale.caption(t.inkSoft).copyWith(
                                              decoration: TextDecoration.underline,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ] else if (_receivedType == ReceivedType.topUp) ...[
                TextField(
                  controller: _merchant,
                  style: TypeScale.body(t.ink),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    labelText: 'Source / Reason',
                    labelStyle: TypeScale.caption(t.inkSoft),
                    hintText: 'e.g. Parents, Festival Gift, Bonus, Side Gig',
                    hintStyle: TypeScale.body(t.inkSoft),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                  ),
                ),
                const SizedBox(height: Space.x2),
                TextField(
                  controller: _note,
                  style: TypeScale.body(t.ink),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    labelStyle: TypeScale.caption(t.inkSoft),
                    hintText: 'e.g. Extra allowance for exam week',
                    hintStyle: TypeScale.body(t.inkSoft),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                  ),
                ),
              ] else if (_receivedType == ReceivedType.friendPaidBack) ...[
                if (openSplits.isNotEmpty) ...[
                  Text(
                    'Select which friend paid you back:',
                    style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Space.x2),
                  for (final s in openSplits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSplitId = s.id;
                            _amount = AmountValue.fromPaise(s.amountPaise);
                            _merchant.text = '${s.friendName} repaid split';
                          });
                        },
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedSplitId == s.id ? t.accentTint : t.card,
                            border: Border.all(
                              color: _selectedSplitId == s.id ? t.accent : t.rule,
                              width: _selectedSplitId == s.id ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedSplitId == s.id
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: _selectedSplitId == s.id ? t.accent : t.inkSoft,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.friendName,
                                      style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    if (s.note.isNotEmpty)
                                      Text(
                                        s.note,
                                        style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                Money.formatPaise(s.amountPaise),
                                style: TypeScale.title(_selectedSplitId == s.id ? t.accent : t.ink)
                                    .copyWith(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => setState(() => _selectedSplitId = null),
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _selectedSplitId == null
                                ? Icons.check_circle_outline_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 16,
                            color: _selectedSplitId == null ? t.accent : t.inkSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Other / Unlisted Friend Repayment',
                            style: TypeScale.caption(_selectedSplitId == null ? t.accent : t.inkSoft)
                                .copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (openSplits.isEmpty || _selectedSplitId == null) ...[
                  const SizedBox(height: Space.x2),
                  TextField(
                    controller: _friendNameController,
                    style: TypeScale.body(t.ink),
                    cursorColor: t.accent,
                    decoration: InputDecoration(
                      labelText: "Friend's name",
                      labelStyle: TypeScale.caption(t.inkSoft),
                      hintText: 'e.g. Rahul',
                      hintStyle: TypeScale.body(t.inkSoft),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  TextField(
                    controller: _merchant,
                    style: TypeScale.body(t.ink),
                    cursorColor: t.accent,
                    decoration: InputDecoration(
                      labelText: 'What did they pay back for?',
                      labelStyle: TypeScale.caption(t.inkSoft),
                      hintText: 'e.g. Dinner share, Movie ticket',
                      hintStyle: TypeScale.body(t.inkSoft),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                    ),
                  ),
                ],
              ] else if (_receivedType == ReceivedType.refund) ...[
                Wrap(
                  spacing: Space.x2,
                  runSpacing: Space.x2,
                  children: [
                    for (final c in expenseCats)
                      LedgerChip(
                        label: c.name,
                        icon: categoryIcon(c.icon),
                        selected: _categoryId == c.id,
                        onTap: () => setState(() => _categoryId = c.id),
                      ),
                  ],
                ),
                const SizedBox(height: Space.x3),
                TextField(
                  controller: _merchant,
                  style: TypeScale.body(t.ink),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    labelText: 'Refund from',
                    labelStyle: TypeScale.caption(t.inkSoft),
                    hintText: 'e.g. Swiggy order cancel, Amazon return',
                    hintStyle: TypeScale.body(t.inkSoft),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                  ),
                ),
              ],

              const SizedBox(height: Space.x4),
              AmountPad(
                value: _amount,
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x4),
              PrimaryButton(
                label: !isCredit
                    ? Copy.save
                    : _receivedType == ReceivedType.topUp
                        ? 'Add to Balance'
                        : _receivedType == ReceivedType.friendPaidBack
                            ? (_selectedSplitId != null ? 'Clear Split' : 'Record Repayment')
                            : 'Restore to Daily Allowance',
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

  Widget _buildReceivedSubOption({
    required PaperTokens t,
    required ReceivedType type,
    required String label,
  }) {
    final isSelected = _receivedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _receivedType = type;
            if (type == ReceivedType.topUp) {
              _categoryId = 'income';
            }
          });
        },
        borderRadius: BorderRadius.circular(Space.controlRadius - 2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? t.card : Colors.transparent,
            borderRadius: BorderRadius.circular(Space.controlRadius - 2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TypeScale.caption(isSelected ? t.accent : t.inkSoft).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
