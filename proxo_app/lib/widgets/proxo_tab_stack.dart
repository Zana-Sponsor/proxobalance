import 'package:flutter/widgets.dart';

/// A short arrival animation around a stable kept-alive tab tree. Hidden tabs
/// retain scroll/form state and their tickers remain muted.
class ProxoTabStack extends StatefulWidget {
  const ProxoTabStack({super.key, required this.index, required this.children});
  final int index;
  final List<Widget> children;
  @override
  State<ProxoTabStack> createState() => _ProxoTabStackState();
}

class _ProxoTabStackState extends State<ProxoTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
      vsync: this, value: 1, duration: const Duration(milliseconds: 280));
  late final Animation<double> _ease =
      CurvedAnimation(parent: _arrival, curve: Curves.easeOutCubic);
  @override
  void didUpdateWidget(covariant ProxoTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _arrival.value = 1;
      } else {
        _arrival.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ease,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, .012), end: Offset.zero)
                  .animate(_ease),
          child: IndexedStack(index: widget.index, children: [
            for (var i = 0; i < widget.children.length; i++)
              TickerMode(enabled: i == widget.index, child: widget.children[i]),
          ]),
        ),
      );
}
