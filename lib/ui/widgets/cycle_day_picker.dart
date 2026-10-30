import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Interactive 1-31 calendar grid picker for cycle start day.
class CycleDayPicker extends StatelessWidget {
  const CycleDayPicker({
    super.key,
    required this.selectedDay,
    required this.onSelected,
  });

  final int selectedDay;
  final ValueChanged<int> onSelected;

  static String ordinal(int d) {
    if (d == 1) return '1st';
    if (d == 2) return '2nd';
    if (d == 3) return '3rd';
    if (d >= 11 && d <= 13) return '${d}th';
    switch (d % 10) {
      case 1:
        return '${d}st';
      case 2:
        return '${d}nd';
      case 3:
        return '${d}rd';
      default:
        return '${d}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 31,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final day = index + 1;
            final isSelected = day == selectedDay;

            return InkWell(
              onTap: () => onSelected(day),
              borderRadius: BorderRadius.circular(Space.controlRadius),
              child: AnimatedContainer(
                duration: Motion.fast,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? t.accent : t.card,
                  border: Border.all(
                    color: isSelected ? t.accent : t.rule,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(Space.controlRadius),
                ),
                child: Text(
                  '$day',
                  style: TypeScale.body(isSelected ? t.paper : t.ink).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<int?> showCycleDayPickerSheet(BuildContext context, {required int initialDay}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final t = TokenScope.of(ctx);
      var current = initialDay;

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.margin, Space.x6, Space.margin, Space.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('When does pocket money land?', style: TypeScale.title(t.ink)),
                  const SizedBox(height: Space.x2),
                  Text(
                    'Select the day of the month (1–31) when your stipend arrives.',
                    style: TypeScale.caption(t.inkSoft),
                  ),
                  const SizedBox(height: Space.x6),
                  CycleDayPicker(
                    selectedDay: current,
                    onSelected: (d) => setSheetState(() => current = d),
                  ),
                  const SizedBox(height: Space.x6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.paper,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Space.controlRadius),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, current),
                    child: Text(
                      'Confirm · ${CycleDayPicker.ordinal(current)} of every month',
                      style: TypeScale.body(t.paper).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
