import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../state/ledger.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/hairline.dart';
import '../widgets/primary_button.dart';

Future<bool?> showBillSplitSheet(
  BuildContext context, {
  required int totalAmountPaise,
  String merchant = '',
  LocalDate? initialDate,
  String? initialCategoryId,
  String? pendingInboxId,
  bool allowEditTotal = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BillSplitSheet(
      totalAmountPaise: totalAmountPaise,
      merchant: merchant,
      initialDate: initialDate,
      initialCategoryId: initialCategoryId,
      pendingInboxId: pendingInboxId,
      allowEditTotal: allowEditTotal,
    ),
  );
}

class BillSplitSheet extends ConsumerStatefulWidget {
  const BillSplitSheet({
    super.key,
    required this.totalAmountPaise,
    this.merchant = '',
    this.initialDate,
    this.initialCategoryId,
    this.pendingInboxId,
    this.allowEditTotal = false,
  });

  final int totalAmountPaise;
  final String merchant;
  final LocalDate? initialDate;
  final String? initialCategoryId;
  final String? pendingInboxId;
  final bool allowEditTotal;

  @override
  ConsumerState<BillSplitSheet> createState() => _BillSplitSheetState();
}

class _BillSplitSheetState extends ConsumerState<BillSplitSheet> {
  late int _totalPaise;
  late TextEditingController _totalController;
  late TextEditingController _merchantController;
  late TextEditingController _friendsController;
  late TextEditingController _myShareController;

  late String _categoryId;
  late LocalDate _date;
  bool _isEqualSplit = true;
  int _stepperCount = 2; // Total people including user

  @override
  void initState() {
    super.initState();
    _totalPaise = widget.totalAmountPaise > 0 ? widget.totalAmountPaise : 10000;
    _totalController = TextEditingController(
      text: '${_totalPaise ~/ 100}',
    );
    _merchantController = TextEditingController(text: widget.merchant);
    _friendsController = TextEditingController();
    _myShareController = TextEditingController();
    _categoryId = widget.initialCategoryId ?? 'food';
    _date = widget.initialDate ?? LocalDate.today();

    _updateMyShareDefault();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _merchantController.dispose();
    _friendsController.dispose();
    _myShareController.dispose();
    super.dispose();
  }

  void _updateMyShareDefault() {
    if (_totalPaise <= 0) return;
    final people = _computePeopleCount();
    final share = _totalPaise ~/ people;
    if (_isEqualSplit) {
      _myShareController.text = '${share ~/ 100}';
    }
  }

  List<String> _parsedFriendNames() {
    return _friendsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  int _computePeopleCount() {
    final names = _parsedFriendNames();
    if (names.isNotEmpty) {
      return max(2, names.length + 1);
    }
    return max(2, _stepperCount);
  }

  int _computeMySharePaise() {
    if (_totalPaise <= 0) return 0;
    if (!_isEqualSplit) {
      final valRupees = int.tryParse(_myShareController.text.trim()) ?? 0;
      return (valRupees * 100).clamp(0, _totalPaise);
    }
    final people = _computePeopleCount();
    return _totalPaise ~/ people;
  }

  int _computeFriendsTotalPaise() {
    final myShare = _computeMySharePaise();
    return max(0, _totalPaise - myShare);
  }

  void _toggleFriendChip(String name) {
    final current = _parsedFriendNames();
    if (current.contains(name)) {
      current.remove(name);
    } else {
      current.add(name);
    }
    setState(() {
      _friendsController.text = current.join(', ');
      _stepperCount = max(2, current.length + 1);
      _updateMyShareDefault();
    });
  }

  Future<void> _submit() async {
    if (widget.allowEditTotal || _totalPaise <= 0) {
      final raw = int.tryParse(_totalController.text.trim()) ?? 0;
      _totalPaise = raw * 100;
    }

    if (_totalPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bill amount')),
      );
      return;
    }

    final rawNames = _parsedFriendNames();
    final peopleCount = _computePeopleCount();
    final friendCount = peopleCount - 1;

    // Build friends list
    final friendsList = <({String friendName, int amountPaise})>[];
    final friendsTotalPaise = _computeFriendsTotalPaise();

    if (friendCount <= 0 || friendsTotalPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify friends to split with')),
      );
      return;
    }

    final sharePerFriend = friendsTotalPaise ~/ friendCount;
    var remainder = friendsTotalPaise % friendCount;

    for (var i = 0; i < friendCount; i++) {
      final name = i < rawNames.length ? rawNames[i] : 'Friend ${i + 1}';
      final friendShare = sharePerFriend + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      friendsList.add((friendName: name, amountPaise: friendShare));
    }

    final mySharePaise = _computeMySharePaise();
    final merchant = _merchantController.text.trim().isNotEmpty
        ? _merchantController.text.trim()
        : 'Bill Split';

    await ref.read(ledgerProvider.notifier).splitBill(
          totalAmountPaise: _totalPaise,
          mySharePaise: mySharePaise,
          friends: friendsList,
          date: _date,
          categoryId: _categoryId,
          merchant: merchant,
          note: 'Split with ${friendsList.map((f) => f.friendName).join(", ")}',
          pendingInboxId: widget.pendingInboxId,
        );

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded ${Money.formatPaise(mySharePaise)} to Today’s spend and ${Money.formatPaise(friendsTotalPaise)} in Splits!',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final ledger = ref.watch(ledgerProvider).valueOrNull;
    final cats = (ledger?.categories ?? []).where((c) => c.id != 'income').toList();

    // Known past friends for quick tap chips
    final pastFriends = <String>{};
    if (ledger != null) {
      for (final s in ledger.friendSplits) {
        if (s.friendName.trim().isNotEmpty) pastFriends.add(s.friendName.trim());
      }
    }

    final parsedNames = _parsedFriendNames();
    final peopleCount = _computePeopleCount();
    final friendCount = peopleCount - 1;
    final mySharePaise = _computeMySharePaise();
    final friendsTotalPaise = _computeFriendsTotalPaise();
    final perFriendPaise = friendCount > 0 ? friendsTotalPaise ~/ friendCount : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: t.rule, borderRadius: BorderRadius.circular(2)),
              ),

              // Scrollable Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Space.margin, Space.x3, Space.margin, Space.x4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: t.accentTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.call_split_rounded, size: 20, color: t.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Split with Friends', style: TypeScale.title(t.ink)),
                                Text(
                                  'Only your share will be charged to Today. The rest goes to Splits.',
                                  style: TypeScale.caption(t.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: t.inkSoft),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x4),

                      // Total Bill Display / Input
                      Container(
                        padding: const EdgeInsets.all(Space.x3),
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(color: t.rule),
                          borderRadius: BorderRadius.circular(Space.cardRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL BILL AMOUNT',
                              style: TypeScale.caption(t.inkSoft).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (widget.allowEditTotal || _totalPaise <= 0)
                              TextField(
                                controller: _totalController,
                                keyboardType: TextInputType.number,
                                style: TypeScale.title(t.ink).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                                cursorColor: t.accent,
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  prefixStyle: TypeScale.title(t.ink).copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                                  hintText: '100',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                onChanged: (v) {
                                  final num = int.tryParse(v.trim()) ?? 0;
                                  setState(() {
                                    _totalPaise = num * 100;
                                    _updateMyShareDefault();
                                  });
                                },
                              )
                            else
                              Text(
                                Money.formatPaise(_totalPaise),
                                style: TypeScale.title(t.ink).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.x3),

                      // Split Mode Selector (Equal vs Custom)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isEqualSplit = true;
                                  _updateMyShareDefault();
                                });
                              },
                              borderRadius: BorderRadius.circular(Space.controlRadius),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isEqualSplit ? t.accentTint : t.card,
                                  border: Border.all(color: _isEqualSplit ? t.accent : t.rule),
                                  borderRadius: BorderRadius.circular(Space.controlRadius),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Split Equally (Recommended)',
                                  style: TypeScale.caption(_isEqualSplit ? t.accent : t.inkSoft).copyWith(
                                    fontWeight: _isEqualSplit ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.x2),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isEqualSplit = false;
                                  if (_myShareController.text.isEmpty && _totalPaise > 0) {
                                    _myShareController.text = '${(_totalPaise ~/ 100) ~/ 2}';
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(Space.controlRadius),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isEqualSplit ? t.accentTint : t.card,
                                  border: Border.all(color: !_isEqualSplit ? t.accent : t.rule),
                                  borderRadius: BorderRadius.circular(Space.controlRadius),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Custom Share',
                                  style: TypeScale.caption(!_isEqualSplit ? t.accent : t.inkSoft).copyWith(
                                    fontWeight: !_isEqualSplit ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x4),

                      // Equal Split People Stepper
                      if (_isEqualSplit) ...[
                        Row(
                          children: [
                            Text(
                              'How many people total?',
                              style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Container(
                              decoration: BoxDecoration(
                                color: t.card,
                                border: Border.all(color: t.rule),
                                borderRadius: BorderRadius.circular(Space.controlRadius),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: _stepperCount > 2
                                        ? () {
                                            setState(() {
                                              _stepperCount--;
                                              _updateMyShareDefault();
                                            });
                                          }
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '$peopleCount ($friendCount friend${friendCount > 1 ? "s" : ""} + You)',
                                      style: TypeScale.caption(t.ink).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _stepperCount = peopleCount + 1;
                                        _updateMyShareDefault();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.x3),
                      ] else ...[
                        // Custom My Share Field
                        TextField(
                          controller: _myShareController,
                          keyboardType: TextInputType.number,
                          style: TypeScale.body(t.ink),
                          cursorColor: t.accent,
                          decoration: InputDecoration(
                            labelText: 'Your personal share (₹)',
                            prefixText: '₹ ',
                            hintText: '20',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Space.controlRadius),
                              borderSide: BorderSide(color: t.accent),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: Space.x3),
                      ],

                      // Friend Names Input
                      TextField(
                        controller: _friendsController,
                        style: TypeScale.body(t.ink),
                        cursorColor: t.accent,
                        decoration: InputDecoration(
                          labelText: 'Friend names (comma separated)',
                          hintText: 'Rahul, Aman, Sneha, Rohan',
                          prefixIcon: Icon(Icons.people_outline, color: t.inkSoft),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                            borderSide: BorderSide(color: t.accent),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            final names = _parsedFriendNames();
                            if (names.isNotEmpty) {
                              _stepperCount = max(2, names.length + 1);
                            }
                            _updateMyShareDefault();
                          });
                        },
                      ),

                      // Quick friend chips
                      if (pastFriends.isNotEmpty) ...[
                        const SizedBox(height: Space.x2),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text('Quick add:', style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11)),
                              const SizedBox(width: 6),
                              for (final f in pastFriends)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: LedgerChip(
                                    label: f,
                                    selected: parsedNames.contains(f),
                                    onTap: () => _toggleFriendChip(f),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: Space.x4),

                      // Dynamic Live Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.card,
                          border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
                          borderRadius: BorderRadius.circular(Space.cardRadius),
                        ),
                        child: Column(
                          children: [
                            // User's Share
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle),
                                  child: const Icon(Icons.person, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your Personal Share',
                                        style: TypeScale.body(t.ink).copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        'Charged to Today’s spending allowance',
                                        style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Money.formatPaise(mySharePaise),
                                  style: TypeScale.title(t.ink).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Hairline(),
                            const SizedBox(height: 12),
                            // Friends' Split Section
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                                  child: const Icon(Icons.group, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Friends’ Debt ($friendCount friend${friendCount > 1 ? "s" : ""})',
                                        style: TypeScale.body(t.accent).copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        friendCount > 0
                                            ? '${Money.formatPaise(perFriendPaise)} each · Tracked in Splits'
                                            : 'Tracked in Splits section',
                                        style: TypeScale.caption(t.inkSoft).copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Money.formatPaise(friendsTotalPaise),
                                  style: TypeScale.title(t.accent).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.x4),

                      // Category selection
                      Text(
                        'Category for your share',
                        style: TypeScale.caption(t.inkSoft).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: Space.x2),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: cats.map((cat) {
                          final isSelected = cat.id == _categoryId;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  categoryIcon(cat.icon),
                                  size: 14,
                                  color: isSelected ? t.accent : t.inkSoft,
                                ),
                                const SizedBox(width: 6),
                                Text(cat.name),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: t.accentTint,
                            backgroundColor: t.card,
                            labelStyle: TypeScale.caption(isSelected ? t.accent : t.ink).copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? t.accent : t.rule,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) setState(() => _categoryId = cat.id);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: Space.x3),

                      // Merchant / Note
                      TextField(
                        controller: _merchantController,
                        style: TypeScale.body(t.ink),
                        cursorColor: t.accent,
                        decoration: InputDecoration(
                          labelText: 'Where or what was this for?',
                          hintText: 'e.g. Swiggy, Canteen bill, Cab share',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Space.controlRadius)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Space.controlRadius),
                            borderSide: BorderSide(color: t.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.x6),

                      // Action Button
                      PrimaryButton(
                        label: 'Record ${Money.formatPaise(mySharePaise)} to Today & ${Money.formatPaise(friendsTotalPaise)} to Splits',
                        onPressed: _totalPaise > 0 ? _submit : null,
                      ),
                      const SizedBox(height: Space.x2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
