import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

class AllowanceMeter extends StatelessWidget {
  const AllowanceMeter({
    super.key,
    required this.ratio,
    required this.caption,
  });

  final double ratio;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final t = TokenScope.of(context);
    final fill = ratio >= 1
        ? t.over
        : ratio >= 0.8
            ? t.caution
            : t.accent;
    final width = ratio.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, box) {
              return Stack(
                children: [
                  Container(
                    width: box.maxWidth,
                    decoration: BoxDecoration(
                      color: t.rule,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.curve,
                    width: box.maxWidth * width,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: Space.x2),
        Text(caption, style: TypeScale.caption(t.inkSoft)),
      ],
    );
  }
}
