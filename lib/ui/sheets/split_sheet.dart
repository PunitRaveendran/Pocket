import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../l10n/copy.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/amount_pad.dart';
import '../widgets/chips.dart';
import '../widgets/primary_button.dart';

Future<void> showSplitSheet(
  BuildContext context, {
  FriendSplit? editing,
  String? initialFriendName,
  SplitDirection? initialDirection,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SplitSheet(
      editing: editing,
      initialFriendName: initialFriendName,
      initialDirection: initialDirection,
    ),
  );
}

class SplitSheet extends ConsumerStatefulWidget {
  const SplitSheet({
    super.key,
    this.editing,
    this.initialFriendName,
    this.initialDirection,
  });

  final FriendSplit? editing;
  final String? initialFriendName;
  final SplitDirection? initialDirection;

  @override
  ConsumerState<SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends ConsumerState<SplitSheet> {
  late AmountValue _amount;
  late SplitDirection _direction;
  late TextEditingController _nameController;
  late TextEditingController _noteController;
  bool _deductFromDaily = false;
  LocalDate _date = LocalDate.today();

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _amount = e != null ? AmountValue.fromPaise(e.amountPaise) : AmountValue.fromPaise(0);
    _direction = e?.direction ?? widget.initialDirection ?? SplitDirection.youAreOwed;
    _nameController = TextEditingController(text: e?.friendName ?? widget.initialFriendName ?? '');
    _noteController = TextEditingController(text: e?.note ?? '');
    _date = e?.localDate ?? LocalDate.today();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter friend’s name')),
      );
      return;
    }
    if (_amount.paiseTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final e = widget.editing;
    if (e != null) {
      await ref.read(ledgerProvider.notifier).updateFriendSplit(
            e.copyWith(
              friendName: name,
              amountPaise: _amount.paiseTotal,
              direction: _direction,
              note: _noteController.text.trim(),
              localDate: _date,
            ),
          );
    } else {
      await ref.read(ledgerProvider.notifier).addFriendSplit(
            friendName: name,
            amountPaise: _amount.paiseTotal,
            direction: _direction,
            date: _date,
            note: _noteController.text.trim(),
            deductFromDaily: _deductFromDaily,
          );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;

    // Collect distinct existing friend names for autocomplete chips
    final existingNames = <String>{};
    if (ledger != null) {
      for (final s in ledger.friendSplits) {
        if (s.friendName.trim().isNotEmpty) existingNames.add(s.friendName.trim());
      }
    }

    final isOwed = _direction == SplitDirection.youAreOwed;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing != null ? 'Edit Friend Split' : 'Add Friend Split',
                style: TypeScale.title(t.ink),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'Track money owed between you and friends (hostel, canteen, xerox).',
                style: TypeScale.caption(t.inkSoft),
              ),
              const SizedBox(height: Space.x4),

              // Direction Switcher
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _direction = SplitDirection.youAreOwed),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isOwed ? t.accentTint : t.card,
                          border: Border.all(color: isOwed ? t.accent : t.rule, width: isOwed ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.arrow_downward, size: 18, color: isOwed ? t.accent : t.inkSoft),
                            const SizedBox(height: 4),
                            Text(
                              'They owe me',
                              style: TypeScale.body(isOwed ? t.accent : t.inkSoft).copyWith(
                                fontWeight: isOwed ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _direction = SplitDirection.youOwe),
                      borderRadius: BorderRadius.circular(Space.controlRadius),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isOwed ? t.accentTint : t.card,
                          border: Border.all(color: !isOwed ? t.accent : t.rule, width: !isOwed ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(Space.controlRadius),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.arrow_upward, size: 18, color: !isOwed ? t.accent : t.inkSoft),
                            const SizedBox(height: 4),
                            Text(
                              'I owe them',
                              style: TypeScale.body(!isOwed ? t.accent : t.inkSoft).copyWith(
                                fontWeight: !isOwed ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),

              // Friend Name Input
              TextField(
                controller: _nameController,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'Friend’s name',
                  hintText: 'e.g. Rahul, Sneha, Aman',
                  labelStyle: TypeScale.body(t.inkSoft),
                  prefixIcon: Icon(Icons.person_outline, color: t.inkSoft),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.rule),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              if (existingNames.isNotEmpty) ...[
                const SizedBox(height: Space.x2),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final name in existingNames)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: LedgerChip(
                            label: name,
                            selected: _nameController.text.trim().toLowerCase() == name.toLowerCase(),
                            onTap: () => setState(() => _nameController.text = name),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.x4),

              // Note Input
              TextField(
                controller: _noteController,
                style: TypeScale.body(t.ink),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Biryani at canteen, Xerox, Movie ticket',
                  labelStyle: TypeScale.body(t.inkSoft),
                  prefixIcon: Icon(Icons.notes_outlined, color: t.inkSoft),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.rule),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Space.controlRadius),
                    borderSide: BorderSide(color: t.accent),
                  ),
                ),
              ),
              const SizedBox(height: Space.x4),

              // Optional checkbox for "They owe me"
              if (widget.editing == null && isOwed) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _deductFromDaily,
                  activeColor: t.accent,
                  title: Text(
                    'I paid upfront for this from today’s allowance',
                    style: TypeScale.caption(t.ink),
                  ),
                  subtitle: Text(
                    'Also records an expense in Today so your daily balance stays accurate.',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  onChanged: (val) => setState(() => _deductFromDaily = val ?? false),
                ),
                const SizedBox(height: Space.x2),
              ],

              // Amount Entry
              AmountDisplay(value: _amount),
              const SizedBox(height: Space.x2),
              AmountPad(
                value: _amount,
                onChanged: (v) => setState(() => _amount = v),
              ),
              const SizedBox(height: Space.x6),

              PrimaryButton(
                label: widget.editing != null ? Copy.save : 'Record Split',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
