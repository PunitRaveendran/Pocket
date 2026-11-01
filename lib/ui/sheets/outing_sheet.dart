import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/primary_button.dart';

Future<void> showOutingSheet(
  BuildContext context, {
  String? existingOutingId,
  String? title,
  Txn? editingTxn,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => OutingSheet(
      existingOutingId: existingOutingId,
      presetTitle: title,
      editingTxn: editingTxn,
    ),
  );
}

class OutingSheet extends ConsumerStatefulWidget {
  const OutingSheet({
    super.key,
    this.existingOutingId,
    this.presetTitle,
    this.editingTxn,
  });

  final String? existingOutingId;
  final String? presetTitle;
  final Txn? editingTxn;

  @override
  ConsumerState<OutingSheet> createState() => _OutingSheetState();
}

class _OutingSheetState extends ConsumerState<OutingSheet> {
  late AmountValue _amount;
  late final TextEditingController _title;
  late final TextEditingController _itemLabel;
  late LocalDate _date;
  bool _clearOnFirstDigit = false;

  @override
  void initState() {
    super.initState();
    if (widget.editingTxn != null) {
      _amount = AmountValue.fromPaise(widget.editingTxn!.amountPaise);
      _title = TextEditingController(text: widget.presetTitle ?? '');
      _itemLabel = TextEditingController(
        text: widget.editingTxn!.note.isNotEmpty
            ? widget.editingTxn!.note
            : widget.editingTxn!.merchant,
      );
      _date = widget.editingTxn!.localDate;
      _clearOnFirstDigit = true;
    } else {
      _amount = const AmountValue(rupeeDigits: '0', paise: 0);
      _title = TextEditingController(text: widget.presetTitle ?? '');
      _itemLabel = TextEditingController();
      _date = LocalDate.today();
      _clearOnFirstDigit = false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _itemLabel.dispose();
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

    if (widget.editingTxn != null) {
      final item = _itemLabel.text.trim().isEmpty ? 'Spend' : _itemLabel.text.trim();
      await ref.read(ledgerProvider.notifier).updateTxn(
            widget.editingTxn!.copyWith(
              amountPaise: _amount.paiseTotal,
              note: item,
              merchant: item,
              localDate: _date,
            ),
          );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final title = _title.text.trim().isEmpty ? 'Outing' : _title.text.trim();
    final item = _itemLabel.text.trim().isEmpty ? title : _itemLabel.text.trim();

    await ref.read(ledgerProvider.notifier).addOutingWithSpend(
          title: title,
          itemTitle: item,
          amountPaise: _amount.paiseTotal,
          date: _date,
          existingOutingId: widget.existingOutingId,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.editingTxn == null) return;
    final t = TokenScope.of(context);
    final txn = widget.editingTxn!;
    final label = txn.note.isNotEmpty ? txn.note : (txn.merchant.isNotEmpty ? txn.merchant : 'this spend');
    final amountStr = Money.formatPaise(txn.amountPaise);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete spend?', style: TypeScale.heading(t.ink)),
        content: Text('Remove "$label" ($amountStr) from this outing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Copy.cancel, style: TypeScale.body(t.inkSoft)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.over),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Copy.remove, style: TypeScale.body(Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      await ref.read(ledgerProvider.notifier).deleteTxn(txn.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(Space.margin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Space.controlRadius),
              side: BorderSide(color: t.rule),
            ),
            backgroundColor: t.card,
            content: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: t.inkSoft),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: Text(
                    'Deleted "$label" ($amountStr)',
                    style: TypeScale.body(t.ink).copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: t.accent,
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(ledgerProvider.notifier).restoreTxn(txn);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isExisting = widget.existingOutingId != null;
    final isEditing = widget.editingTxn != null;

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
                    isEditing
                        ? 'Edit Spend'
                        : (isExisting ? 'Add to ${widget.presetTitle}' : Copy.addOuting),
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
                                : DateFormat('d MMM').format(_date.dateTime),
                            style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Kept in your Outings tab so it does not reduce your daily food allowance.',
                style: TypeScale.caption(t.inkSoft),
              ),
              const SizedBox(height: Space.x4),
              AmountDisplay(value: _amount),
              const SizedBox(height: Space.x4),
              if (!isExisting && !isEditing) ...[
                TextField(
                  controller: _title,
                  style: TypeScale.body(t.ink),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    labelText: 'Trip or Outing Name',
                    labelStyle: TypeScale.caption(t.inkSoft),
                    hintText: 'e.g. Weekend Trek, Movie Night, Fest',
                    hintStyle: TypeScale.body(t.inkSoft),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                  ),
                ),
                const SizedBox(height: Space.x3),
              ],
              TextField(
                controller: _itemLabel,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: isEditing
                      ? 'What was this spend for?'
                      : (isExisting ? 'What was this spend for?' : 'First expense item (optional)'),
                  labelStyle: TypeScale.caption(t.inkSoft),
                  hintText: isExisting || isEditing ? 'e.g. Bus fare, Dinner, Ticket' : 'e.g. Tickets, Fuel, Snacks',
                  hintStyle: TypeScale.body(t.inkSoft),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                ),
              ),
              const SizedBox(height: Space.x4),
              AmountPad(
                value: _amount,
                clearOnFirstDigit: _clearOnFirstDigit,
                onFirstDigitCleared: () => setState(() => _clearOnFirstDigit = false),
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x4),
              PrimaryButton(
                label: isEditing ? 'Update spend' : Copy.save,
                onPressed: _amount.paiseTotal > 0 ? _save : null,
              ),
              if (isEditing) ...[
                const SizedBox(height: Space.x3),
                Center(
                  child: TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: t.over),
                    label: Text('Delete this spend', style: TypeScale.body(t.over)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
