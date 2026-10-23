import 'package:flutter/material.dart';

/// All objectives share the same local 96px PNG master and 20dp optical box.
class AdObjectiveIcon extends StatelessWidget {
  const AdObjectiveIcon(this.goal, {super.key});
  final String goal;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/objectives/$goal.png', width: 20, height: 20,
    fit: BoxFit.contain, matchTextDirection: false, excludeFromSemantics: true,
  );
}
