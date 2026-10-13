import 'package:flutter/widgets.dart';

/// Keeps visited tab state while muting frame tickers in hidden tabs.
/// Data subscriptions and timers retain their existing lifecycle.
class ProxoTabStack extends StatelessWidget {
  const ProxoTabStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < children.length; i++)
            TickerMode(enabled: i == index, child: children[i]),
        ],
      );
}
