import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
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
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => OutingSheet(existingOutingId: existingOutingId, presetTitle: title),
  );
}

class OutingSheet extends ConsumerStatefulWidget {
  const OutingSheet({super.key, this.existingOutingId, this.presetTitle});

  final String? existingOutingId;
  final String? presetTitle;

  @override
  ConsumerState<OutingSheet> createState() => _OutingSheetState();
}

class _OutingSheetState extends ConsumerState<OutingSheet> {
  late AmountValue _amount;
  late final TextEditingController _title;
  late final TextEditingController _itemLabel;
  late LocalDate _date;

  @override
  void initState() {
    super.initState();
    _amount = const AmountValue(rupeeDigits: '0', paise: 0);
    _title = TextEditingController(text: widget.presetTitle ?? '');
    _itemLabel = TextEditingController();
    _date = LocalDate.today();
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

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final isExisting = widget.existingOutingId != null;

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
                    isExisting ? 'Add to ${widget.presetTitle}' : Copy.addOuting,
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
              if (!isExisting) ...[
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
                  labelText: isExisting ? 'What was this spend for?' : 'First expense item (optional)',
                  labelStyle: TypeScale.caption(t.inkSoft),
                  hintText: isExisting ? 'e.g. Bus fare, Dinner, Ticket' : 'e.g. Tickets, Fuel, Snacks',
                  hintStyle: TypeScale.body(t.inkSoft),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.rule)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                ),
              ),
              const SizedBox(height: Space.x4),
              AmountPad(value: _amount, onChanged: (v) => setState(() => _amount = v)),
              const SizedBox(height: Space.x4),
              PrimaryButton(
                label: Copy.save,
                onPressed: _amount.paiseTotal > 0 ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
