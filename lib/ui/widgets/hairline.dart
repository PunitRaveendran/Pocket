import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: indent),
      height: 1,
      color: TokenScope.of(context).rule,
    );
  }
}
