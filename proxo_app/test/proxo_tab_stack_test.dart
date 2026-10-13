import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/proxo_tab_stack.dart';

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  final scroll = ScrollController();
  int ticks = 0;
  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(() => ticks++)
      ..repeat();
  }

  @override
  void dispose() {
    animation.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: scroll,
        itemCount: 100,
        itemExtent: 40,
        itemBuilder: (_, i) => Text('Row $i'),
      );
}

void main() {
  for (final optimized in [false, true]) {
    testWidgets('${optimized ? "Scoped" : "Original"} kept-alive tab ticker lifecycle', (t) async {
      final first = GlobalKey<_ProbeState>(), second = GlobalKey<_ProbeState>();
      Future<void> mount(int index) => t.pumpWidget(MaterialApp(home: SizedBox(
        height: 400,
        child: optimized
            ? ProxoTabStack(index: index, children: [_Probe(key: first), _Probe(key: second)])
            : IndexedStack(index: index, children: [_Probe(key: first), _Probe(key: second)]),
      )));
      await mount(0);
      await t.pump(const Duration(milliseconds: 16));
      final retained = first.currentState!;
      retained.scroll.jumpTo(400);
      await mount(1);
      final hiddenBefore = retained.ticks;
      final activeBefore = second.currentState!.ticks;
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      print('TAB_TICKS optimized=$optimized hidden=${retained.ticks-hiddenBefore} active=${second.currentState!.ticks-activeBefore} pumps=10');
      expect(second.currentState!.ticks, greaterThan(activeBefore));
      if (optimized) {
        expect(retained.ticks, hiddenBefore);
      } else {
        // Reproduces wasted hidden frame callbacks in the current shell.
        expect(retained.ticks, greaterThan(hiddenBefore));
      }
      await mount(0);
      await t.pump(const Duration(milliseconds: 16));
      expect(first.currentState, same(retained));
      expect(retained.scroll.offset, 400);
      expect(retained.ticks, greaterThan(hiddenBefore));
      await t.pumpWidget(const SizedBox.shrink());
      expect(t.takeException(), isNull);
    });
  }
}
